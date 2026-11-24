# DeepSeek Harness 用户级实例：Home Manager 模块 + 可选 systemd user unit。
#
# `client.enable` 只安装 dsh、设置 DSH_HOME；只有 `service.enable = true`
# 才注册 systemd user unit。每个启用 service 的用户都会得到独立的
# `<service.name>.service`、独立的 DSH_HOME、数据目录和端口；不创建系统用户、
# 不修改防火墙。
#
# 选项见同目录 options.nix（`terminus.deepseekHarness.client`）；系统级实例见
# `modules/server/deepseek-harness`。
#
# 用法（homes/<user>/<client-host>.nix 或全局 home 配置）：
#
#   terminus.deepseekHarness.client = {
#     enable = true;                  # 安装 dsh、设置 DSH_HOME
#     service = {
#       enable = true;                # 再注册 systemd user unit
#       port = 3081;
#       environment.LANG = "zh_CN.UTF-8";
#       path.mode = "merge";          # 模块工具 + 继承的用户 PATH
#       extraArgs = [ "--verbose" ];
#     };
#   };
#
# 如需追加任意 systemd 设置，可直接定义
# `systemd.user.services.<service.name>`；Home Manager 会与这里生成的 unit
# 合并（列表追加；标量冲突用 lib.mkForce 覆盖）。
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.terminus.deepseekHarness.client;
  service = cfg.service;

  dataDir =
    if cfg.dataDir != null then
      toString cfg.dataDir
    else
      "${config.home.homeDirectory}/.local/share/deepseek-harness";

  dshHome = "${dataDir}";
  dshBin = "${cfg.package}/bin/dsh";

  # 模块管理的默认 agent 工具集。path.packages = null 时使用它；用户设置为
  # 列表时整体替换。额外工具追加到 path.extraPackages。
  defaultRuntimePackages = with pkgs; [
    bash
    coreutils
    findutils
    gnugrep
    gnused
    systemd

    tmux
    pnpm
    git
    gawk

    diffutils
    patch

    gnutar
    gzip
    xz
    bzip2
    zstd
    unzip
    zip

    procps
    psmisc
    util-linux

    file
    which

    wget
    curl
    gh

    ripgrep
    fd
    jq
    yq-go

    openssh
    rsync
    python3

    gnupg
    git-lfs

    tree

    nix

    openssl

    iproute2
  ];

  managedPackages =
    if service.path.packages != null then service.path.packages else defaultRuntimePackages;

  managedPath = lib.makeBinPath (managedPackages ++ service.path.extraPackages);

  dshArgs = [
    "--profile"
    service.profile
  ]
  ++ lib.optional (!service.openBrowser) "--no-open"
  ++ [
    "--host"
    service.host
    "--port"
    (toString service.port)
  ]
  ++ lib.optionals (service.publicUrl != null) [
    "--public-url"
    service.publicUrl
  ]
  ++ lib.concatMap (trustedHost: [
    "--trusted-host"
    trustedHost
  ]) service.trustedHosts
  ++ service.extraArgs;

  # 只有显式设置 fromDefaultProfile 时才预创建自定义 profile；web 等内置
  # profile 由 dsh 首次启动时自动创建。
  profileInit = lib.optionalString (service.fromDefaultProfile != null) ''
    if [ ! -d ${lib.escapeShellArg "${dshHome}/profiles/${service.profile}"} ]; then
      ${lib.escapeShellArg dshBin} --profile ${lib.escapeShellArg service.profile} \
        --from-default-profile ${lib.escapeShellArg service.fromDefaultProfile} \
        --no-open --dump-config
    fi
  '';

  # PATH 在启动脚本里设置：managed 固定为模块包集合；merge 把模块包集合放在
  # 继承的 PATH 前面；inherit 不设置。PATH 为空时不要前置空段（会引入当前
  # 目录）。
  pathSetup =
    lib.optionalString (service.path.mode == "managed" && managedPath != "") ''
      export PATH=${lib.escapeShellArg managedPath}
    ''
    + lib.optionalString (service.path.mode == "merge" && managedPath != "") ''
      export PATH=${lib.escapeShellArg managedPath}''${PATH:+:$PATH}
    '';

  defaultEnvironment = {
    HOME = config.home.homeDirectory;
    DSH_HOME = dshHome;
    SHELL = "${pkgs.bash}/bin/bash";
    LANG = "C.UTF-8";
  };

  environmentOverrides = lib.filterAttrs (_: value: value != null) service.environment;
  environmentRemovals = lib.attrNames (lib.filterAttrs (_: value: value == null) service.environment);
  effectiveEnvironment =
    (lib.filterAttrs (name: _: !(builtins.elem name environmentRemovals)) defaultEnvironment)
    // environmentOverrides;

  environmentValues = lib.mapAttrsToList (
    name: value: "${name}=${lib.escapeShellArg value}"
  ) effectiveEnvironment;

  startScript = pkgs.writeShellScript "deepseek-harness-start" ''
    set -eu
    ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg dataDir}
    ${pkgs.coreutils}/bin/chmod 700 ${lib.escapeShellArg dataDir}
    ${pathSetup}
    ${profileInit}
    cd ${lib.escapeShellArg dataDir}
    exec ${lib.escapeShellArg dshBin} ${lib.escapeShellArgs dshArgs}
  '';
in
{
  config = {
    assertions = [
      {
        assertion = !service.enable || cfg.enable;
        message = "terminus.deepseekHarness.client.service.enable 需要同时设置 terminus.deepseekHarness.client.enable = true";
      }
      {
        assertion = !cfg.enable || dataDir != "/";
        message = "terminus.deepseekHarness.client.dataDir 不能是根目录";
      }
      {
        assertion = !service.enable || (service.host != "0.0.0.0" && service.host != "::");
        message = "terminus.deepseekHarness.client.service.host 必须是具体的本机 IPv4/IPv6 地址；dsh 不接受 0.0.0.0 / :: 通配地址";
      }
      {
        assertion = !service.enable || (!(service.environment ? PATH) && !(service.environment ? DSH_HOME));
        message = "PATH 由 terminus.deepseekHarness.client.service.path 控制，DSH_HOME 由 terminus.deepseekHarness.client.dataDir 控制；不能在 service.environment 中设置这两个变量";
      }
      {
        assertion =
          !service.enable
          || (
            builtins.match "[A-Za-z0-9:_.@-]+" service.name != null && !(lib.hasSuffix ".service" service.name)
          );
        message = "terminus.deepseekHarness.client.service.name 必须是合法 systemd unit 名（不含 .service 后缀、斜杠或空白）";
      }
      {
        assertion = !service.enable || service.target != "";
        message = "terminus.deepseekHarness.client.service.target 不能为空";
      }
      {
        assertion = !service.enable || service.profile != "";
        message = "terminus.deepseekHarness.client.service.profile 不能为空";
      }
      {
        assertion =
          !service.enable || service.fromDefaultProfile == null || service.fromDefaultProfile != "";
        message = "terminus.deepseekHarness.client.service.fromDefaultProfile 不能为空字符串；不需要预初始化时请设为 null";
      }
    ];

    warnings =
      lib.optional (service.enable && service.port == 0)
        "terminus.deepseekHarness.client.service.port = 0：端口由内核分配，重启后可能变化；用 `journalctl --user -u ${service.name}` 查看实际 URL，或设置每个用户各不相同的固定端口。"
      ++
        lib.optional
          (
            service.enable
            && service.path.mode == "inherit"
            && (service.path.packages != null || service.path.extraPackages != [ ])
          )
          "terminus.deepseekHarness.client.service.path.mode = \"inherit\" 会忽略 packages/extraPackages；需要追加工具请改用 \"merge\"。"
      ++
        lib.optional (service.enable && service.path.mode != "inherit" && managedPath == "")
          "terminus.deepseekHarness.client.service.path 的 managed 包集合为空；启动脚本不会覆盖 PATH，将继承 user manager 的 PATH。";

    home.packages = lib.optional cfg.enable cfg.package;

    home.sessionVariables = lib.mkIf cfg.enable {
      DSH_HOME = dshHome;
    };

    systemd.user.services = lib.mkIf (cfg.enable && service.enable) {
      ${service.name} = {
        Unit = {
          Description = "DeepSeek Harness Web UI (user instance, profile: ${service.profile})";
          After = [ service.target ];
          StartLimitBurst = 5;
          StartLimitIntervalSec = 300;
        };

        Install.WantedBy = [ service.target ];

        Service = {
          Type = "exec";
          ExecStart = "${startScript}";

          Restart = "on-failure";
          RestartSec = "15";

          KillSignal = "SIGTERM";
          TimeoutStopSec = "45";

          StandardOutput = "journal";
          StandardError = "journal";
          SyslogIdentifier = service.name;

          Environment = environmentValues;

          EnvironmentFile = lib.optional (service.environmentFile != null) service.environmentFile;
        };
      };
    };
  };
}
