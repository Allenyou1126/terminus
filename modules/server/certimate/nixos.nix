# Certimate 服务实现：systemd 单元、运行用户/组、数据目录与防火墙。
#
# 选项定义见同目录 options.nix；这里只负责把选项翻译成 NixOS 配置。
#
# ProtectSystem / ProtectHome 用 mkDefault，主机配置可以直接覆盖；其余 hardening
# 项如果需要放宽，用 lib.mkForce 覆盖 systemd.services.certimate.serviceConfig。
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.terminus.certimate;

  stateDir = toString cfg.stateDirectory;

  # `--http` 需要 host:port；IPv6 字面量必须加方括号，否则 Go 会把最后
  # 一个冒号后的部分当成端口。
  httpAddress =
    if lib.hasInfix ":" cfg.addr && !(lib.hasPrefix "[" cfg.addr) then
      "[${cfg.addr}]:${toString cfg.port}"
    else
      "${cfg.addr}:${toString cfg.port}";

  # 用 wrapper 而不是直接拼 ExecStart：extraArgs 可能包含空格等特殊字符，
  # 交给 shell 转义比手写 systemd 引号可靠；exec 保证主进程仍是 certimate。
  startScript = pkgs.writeShellScript "certimate-start" ''
    exec ${
      lib.escapeShellArgs (
        [
          "${cfg.package}/bin/certimate"
          "serve"
          "--dir=${stateDir}"
          "--http=${httpAddress}"
        ]
        ++ cfg.extraArgs
      )
    }
  '';

  # 部署节点会执行 shell 命令、SSH 和证书格式转换；其余工具由
  # extraPackages 追加。
  basePath = [
    pkgs.bash
    pkgs.coreutils
    pkgs.openssh
    pkgs.openssl
  ];
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = stateDir != "/";
        message = "terminus.certimate.stateDirectory 不能是根目录";
      }
      {
        assertion = cfg.addr != "";
        message = "terminus.certimate.addr 不能为空";
      }
      {
        assertion = cfg.port != 0;
        message = "terminus.certimate.port 不能是 0（随机端口）";
      }
    ];

    warnings = lib.optional (cfg.port > 0 && cfg.port < 1024 && cfg.user != "root") (
      "terminus.certimate.port=${toString cfg.port} 是特权端口；非 root 用户需要 "
      + "CAP_NET_BIND_SERVICE，本模块默认不授予。请改用反向代理，或自行覆盖 "
      + "systemd.services.certimate.serviceConfig.AmbientCapabilities。"
    );

    users.groups.${cfg.group} = lib.mkIf (cfg.group == "certimate") { };

    users.users.${cfg.user} = lib.mkIf (cfg.user == "certimate") {
      isSystemUser = true;
      group = cfg.group;
      home = stateDir;
      homeMode = "0750";
      description = "Certimate service user";
    };

    # 数据目录归属服务用户；tmpfiles 在 activation 阶段执行，早于服务启动。
    systemd.tmpfiles.rules = [
      "d ${stateDir} 0750 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.certimate = {
      description = "Certimate TLS certificate manager";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      unitConfig.RequiresMountsFor = [ stateDir ];

      environment = cfg.environment;
      path = basePath ++ cfg.extraPackages;

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = stateDir;
        ExecStart = "${startScript}";
        Restart = "always";
        RestartSec = 5;
        UMask = "0077";
        SupplementaryGroups = cfg.extraGroups;
        EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;

        # 刻意不设置 NoNewPrivileges / CapabilityBoundingSet / RestrictSUIDSGID：
        # Certimate 的部署节点可能需要 sudo（见 extraPackages），这些限制会让
        # 提权失败。不需要提权的部署可在主机配置里自行收紧。
        #
        # ProtectSystem 用 full 而不是 strict：strict 会把 /run、/var 整体
        # 变只读，sudo 的时间戳文件和本地证书写入通常直接失败。需要写 /etc
        # 下的证书目录时用 readWritePaths 放行。
        ProtectSystem = lib.mkDefault "full";
        ProtectHome = lib.mkDefault (if cfg.user == "certimate" then true else "read-only");
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
          "AF_NETLINK"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        LockPersonality = true;
        SystemCallArchitectures = "native";
        ReadOnlyPaths = cfg.readOnlyPaths;
        ReadWritePaths = [ stateDir ] ++ cfg.readWritePaths;
      };
    };

    networking.firewall.allowedTCPPorts = lib.optional cfg.openFirewall cfg.port;
  };
}
