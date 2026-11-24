# DeepSeek Harness 系统服务（NixOS）；迁移自 home-ebeling 的 host 级
# `deepseek-harness.nix`，以系统用户运行。
#
# 选项见同目录 options.nix（`terminus.deepseekHarness.server`）；用户级实例见
# `modules/client/deepseek-harness`（Home Manager + systemd user unit）。
#
# home-ebeling 的等效配置（主机迁移时照抄到 hosts/<name>/default.nix）：
#
#   terminus.deepseekHarness.server = {
#     enable = true;
#     host = "192.168.100.60";
#     publicUrl = "https://dsh.allenyou.top/";
#     trustedHosts = [ "dsh.allenyou.top" ];
#     openFirewall = true;
#     environmentFile = config.age.secrets.deepseek-harness-secret.path;
#   };
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.terminus.deepseekHarness.server;

  dataDir = toString cfg.dataDir;
  dshHome = "${dataDir}/.dsh";
  dshBin = "${cfg.package}/bin/dsh";

  # 交互式 sudo 入口：环境变量与 systemd 单元保持一致，否则 profile 会落到
  # 用户自己的 HOME 下。PATH 保留系统 profile，方便 agent 调用系统工具。
  dshSudo = pkgs.writeShellScript "dsh-sudo" ''
    export HOME=${lib.escapeShellArg dataDir}
    export DSH_HOME=${lib.escapeShellArg dshHome}
    export PATH=/run/current-system/sw/bin:$PATH
    exec ${lib.escapeShellArg dshBin} "$@"
  '';

  dshArgs = [
    "--profile"
    "web"
    "--no-open"
    "--host"
    cfg.host
    "--port"
    (toString cfg.port)
  ]
  ++ lib.optionals (cfg.publicUrl != null) [
    "--public-url"
    cfg.publicUrl
  ]
  ++ lib.concatMap (trustedHost: [
    "--trusted-host"
    trustedHost
  ]) cfg.trustedHosts
  ++ cfg.extraArgs;

  # 迁移自旧模块：agent 运行时需要的常用工具都在服务的 PATH 里，不依赖主机的
  # environment.systemPackages。
  runtimePath = with pkgs; [
    bash
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
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = dataDir != "/";
        message = "terminus.deepseekHarness.server.dataDir 不能是根目录";
      }
      {
        assertion = cfg.host != "0.0.0.0" && cfg.host != "::";
        message = "terminus.deepseekHarness.server.host 必须是具体的本机 IPv4/IPv6 地址；dsh 不接受 0.0.0.0 / :: 通配地址";
      }
      {
        assertion = !cfg.sudo.agent.enable || cfg.sudo.agent.commands != [ ];
        message = "terminus.deepseekHarness.server.sudo.agent.commands 不能为空；启用 Agent sudo 时至少要给出一条 sudoers 命令";
      }
    ];

    warnings = lib.optional cfg.sudo.agent.enable "terminus.deepseekHarness.server.sudo.agent.enable = true：服务用户 ${cfg.user} 获得 sudo 权限（NOPASSWD，范围见 sudo.agent.commands）；commands 含 ALL 时等价于 root，请确认提示注入/沙箱风险。";

    users.groups.${cfg.group} = lib.mkIf (cfg.group == "deepseek-harness") { };

    users.users.${cfg.user} = lib.mkIf (cfg.user == "deepseek-harness") {
      isSystemUser = true;
      group = cfg.group;
      home = dataDir;
      homeMode = "0700";
      createHome = true;
      description = "DeepSeek Harness service user";
    };

    # 数据目录由 root 在开机时创建；默认用户的 createHome 也会建一次，但保持
    # 同一属主/权限，避免自定义 user 时目录不存在。
    systemd.tmpfiles.rules = [
      "d ${dataDir} 0700 ${cfg.user} ${cfg.group} -"
    ];

    # 旧模块没有 wantedBy，服务不会开机自启；迁移后按常规服务行为补上。
    # 需要旧的手动启动行为时，在主机配置里把 wantedBy 覆盖成 [ ]。
    systemd.services.deepseek-harness = {
      description = "DeepSeek Harness Web UI (profile: web)";
      wantedBy = [ "multi-user.target" ];

      startLimitBurst = 5;
      startLimitIntervalSec = 300;

      after = [ "dbus.socket" ];
      requires = [ "dbus.socket" ];

      environment = {
        DSH_HOME = dshHome;
        HOME = dataDir;
        SHELL = "${pkgs.bash}/bin/bash";
        LANG = "C.UTF-8";
      };

      # Agent sudo 依赖 NixOS 的 setuid wrapper；只有启用时才把 wrapper
      # 目录加到 PATH，避免无谓地改变普通服务的 PATH。
      path = lib.optional cfg.sudo.agent.enable "/run/wrappers/bin" ++ runtimePath ++ cfg.extraPackages;

      serviceConfig = {
        Type = "exec";
        WorkingDirectory = dataDir;
        ExecStart = lib.escapeShellArgs ([ dshBin ] ++ dshArgs);

        Restart = "on-failure";
        RestartSec = "15";

        User = cfg.user;
        Group = cfg.group;

        KillSignal = "SIGTERM";
        TimeoutStopSec = "45";

        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "deepseek-harness";

        EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
      };
    };

    environment.systemPackages = with pkgs; [
      pnpm
      gh
    ];

    # 1. Agent 提权：只对服务用户生效的独立 sudoers 规则，不加入 wheel。
    # 2. userAccess：其他用户 sudo 到服务用户运行 dsh（不授予 root）。
    # 3. serviceControl：其他用户以 root 启停服务（与 sudo 到服务用户分开）。
    environment.shellAliases = lib.mkIf cfg.sudo.userAccess.enable {
      dsh = "sudo -u ${cfg.user} ${dshSudo}";
    };

    security.sudo.extraRules =
      lib.optionals cfg.sudo.agent.enable [
        {
          users = [ cfg.user ];
          commands = map (command: {
            inherit command;
            options = [ "NOPASSWD" ];
          }) cfg.sudo.agent.commands;
        }
      ]
      ++ lib.optionals cfg.sudo.userAccess.enable [
        {
          groups = cfg.sudo.userAccess.groups;
          runAs = cfg.user;
          commands = [
            {
              command = toString dshSudo;
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ]
      ++ lib.optionals cfg.sudo.serviceControl.enable [
        {
          groups = cfg.sudo.serviceControl.groups;
          commands = [
            {
              command = "/run/current-system/sw/bin/systemctl ^(start|stop|restart) deepseek-harness(\\.service)?$";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];

    networking.firewall.allowedTCPPorts = lib.optional cfg.openFirewall cfg.port;
  };
}
