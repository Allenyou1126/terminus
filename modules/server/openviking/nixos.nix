# OpenViking 服务端实现：systemd 单元、运行用户/目录、配置生成与防火墙。
#
# 选项定义见同目录 options.nix；这里只负责把选项翻译成 NixOS 配置。
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.terminus.openviking;

  jsonFormat = pkgs.formats.json { };

  # 生成的配置：先铺默认值，再用 lib.recursiveUpdate 合并用户的 settings（用户优先）。
  # `storage.workspace` 是数据目录；不设时默认 "./data" 会相对 WorkingDirectory 解析成
  # `<dataDir>/data`，既多一层又容易误解。
  effectiveSettings = lib.recursiveUpdate {
    storage.workspace = cfg.dataDir;
  } cfg.settings;

  # 配置文件永远存在：要么是用户显式给的，要么是上面生成到 store 的那份。
  configPath =
    if cfg.configFile != null then
      toString cfg.configFile
    else
      jsonFormat.generate "ov.conf" effectiveSettings;

  environmentFiles = lib.optional (cfg.environmentFile != null) cfg.environmentFile;

  # 进程需要做的事只有「监听端口、读写数据目录、访问模型 API」。
  # ⚠️ 不要加 MemoryDenyWriteExecute：Python 依赖的 tree-sitter / 向量引擎会用到
  # JIT 或自修改代码段，加上会直接起不来。
  hardening = {
    NoNewPrivileges = true;
    PrivateDevices = true;
    PrivateTmp = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    # 默认用户的家目录就是 dataDir（在 /var/lib 下），不需要 /home；
    # 换成现有用户（例如你自己的账号）时退化成只读，便于索引家目录。
    ProtectHome = lib.mkDefault (if cfg.user == "openviking" then true else "read-only");
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectSystem = "strict";
    # AF_NETLINK：Python 枚举网卡 / 解析地址时会用到
    RestrictAddressFamilies = [
      "AF_INET"
      "AF_INET6"
      "AF_UNIX"
      "AF_NETLINK"
    ];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
    SystemCallArchitectures = "native";
    CapabilityBoundingSet = [ "" ];
    AmbientCapabilities = [ "" ];
  };
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.configFile == null || cfg.settings == { };
        message = "terminus.openviking：configFile 与 settings 只能设置一个（configFile 已设置时 settings 必须为空）";
      }
    ];

    users.users.${cfg.user} = lib.mkIf (cfg.user == "openviking") {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      # 与下面 tmpfiles 的 0750 保持一致，避免两个来源把权限改来改去。
      homeMode = "0750";
      createHome = true;
      description = "OpenViking 上下文数据库";
    };

    users.groups.${cfg.group} = lib.mkIf (cfg.group == "openviking") { };

    # 数据目录由 root 在开机时创建：参考模块在 preStart 里以服务用户身份 mkdir/chown，
    # 全新的 /var/lib 下必然因权限失败。
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
    ];

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    systemd.services.openviking = {
      description = "OpenViking 上下文数据库服务端";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      # OpenViking 会把本地 embedding 模型缓存写到 `~/.cache/openviking`、把加密根密钥
      # 写到 `~/.openviking`。以现有用户运行时 `ProtectHome = "read-only"`，这些路径
      # 不可写（日志里会出现 "Failed to generate embedding … Read-only file system"）。
      # 把 HOME 指到可写的 dataDir 后，运行期状态都落在服务自己的目录里。
      environment.HOME = cfg.dataDir;

      serviceConfig = hardening // {
        Type = "simple";
        # host / port / 配置文件都走命令行：服务端不读 OPENVIKING_HOST/PORT 环境变量，
        # 而 --config 是唯一能保证「配置一定存在」的入口（见 options.nix 头部注释）。
        ExecStart = lib.escapeShellArgs [
          "${cfg.package}/bin/openviking-server"
          "--host"
          cfg.host
          "--port"
          (toString cfg.port)
          "--config"
          configPath
        ];
        WorkingDirectory = cfg.dataDir;
        User = cfg.user;
        Group = cfg.group;
        SupplementaryGroups = cfg.extraGroups;
        EnvironmentFile = environmentFiles;
        Restart = "on-failure";
        RestartSec = 5;
        ReadOnlyPaths = cfg.readOnlyPaths;
        ReadWritePaths = [ cfg.dataDir ] ++ cfg.readWritePaths;
      };
    };
  };
}
