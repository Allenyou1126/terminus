# OpenViking（面向 AI Agent 的上下文数据库）的 NixOS 模块选项。
#
# 搬运自 github:Daaboulex/openviking-nix 的 module.nix（MIT），并按 Terminus 的
# `terminus.*` 选项命名与 modules/server 角色约定重写。参考模块的选项形状保留，
# 但下列几处与 OpenViking v0.5.0 源码不符的地方都改掉了：
#
# - 服务端**不读** `OPENVIKING_HOST` / `OPENVIKING_PORT` 环境变量（那两行是死代码），
#   监听地址只能来自 `--host` / `--port` 或 ov.conf 的 `server` 段。本模块统一用
#   命令行参数，让 `terminus.openviking.host` / `.port` 成为唯一事实来源。
# - **配置文件是必需的**：`openviking-server` 依次查找 `--config` →
#   `OPENVIKING_CONFIG_FILE` → `~/.openviking/ov.conf` → `/etc/openviking/ov.conf`，
#   一个都找不到就以退出码 1 结束。所以 `configFile = null` 时本模块一定会生成一份
#   配置（内容来自 `settings`，默认 `{}` 也合法 —— 每个配置段都有默认值），并用
#   `--config` 传给服务端。
# - 配置加载会对 JSON 文本做 `os.path.expandvars()`：`settings` 里可以写
#   `${OPENVIKING_EMBEDDING_API_KEY}` 这类占位符，由服务的环境变量展开 —— 密钥走
#   `environmentFile`，**不要**写进 `settings`（Nix store 是全局可读的）。
# - 参考模块的 `preStart` 以服务用户身份 `mkdir` + `chown`，在全新的 `/var/lib` 下
#   必然失败；这里改用 `systemd.tmpfiles.rules`，由 root 在开机时创建。
#
# 最小用法（包默认取本 flake 的 `packages.<system>.openviking`，不需要设置 package）：
#
#   terminus.openviking = {
#     enable = true;
#     environmentFile = "/run/secrets/openviking.env";   # 用 sops-nix / agenix 生成
#     settings.embedding.dense = {
#       provider = "openai";
#       model = "text-embedding-3-small";
#       api_key = "\${OPENVIKING_EMBEDDING_API_KEY}";   # Nix 里 ${…} 要转义
#     };
#   };
#
# ⚠️ 认证：默认配置里没有 `server.root_api_key`，服务端会以 **dev** 模式启动（不做
# 鉴权）。只监听 127.0.0.1 时没有问题；一旦用 `host = "0.0.0.0"` / `openFirewall = true`
# 暴露到网络，请同时配置 `server.root_api_key`（同样用环境变量占位符）或 OIDC / LDAP，
# 否则任何客户端都能直接读写数据。OIDC 的 Python 依赖已随包提供；LDAP 需要
# `python-ldap`（未打包），使用 LDAP 前请自行 override 补上。
{
  lib,
  pkgs,
  self,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };
in
{
  options.terminus.openviking = {
    enable = lib.mkEnableOption "OpenViking 上下文数据库服务端";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.openviking;
      defaultText = lib.literalExpression "self.packages.\${pkgs.stdenv.hostPlatform.system}.openviking";
      description = ''
        服务端包。默认取本 flake 的 `packages.<system>.openviking`，通常无需设置；
        想换（例如换成上游 flake 的产物）时用 {option}`terminus.openviking.package`
        覆盖。
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        监听地址，以 `--host` 传给 `openviking-server`。

        该选项**覆盖** ov.conf 里的 `server.host`（源码里命令行参数优先）。
        需要对外提供 HTTP 时改成 `0.0.0.0` 或具体网卡地址，并注意文件头的认证提醒：
        默认配置是 dev 模式，不做鉴权。
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 1933;
      description = ''
        监听端口，以 `--port` 传给 `openviking-server`，并覆盖 ov.conf 里的
        `server.port`。

        模块默认清空了进程的 capabilities，因此低于 1024 的端口无法直接绑定；
        确实需要时请自行在 `systemd.services.openviking.serviceConfig` 里加回
        `AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ]`。
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.pathWith {
        inStore = false;
        absolute = true;
      };
      default = "/var/lib/openviking";
      description = ''
        数据目录。它同时是：服务的 `WorkingDirectory`、默认用户的家目录、
        以及生成配置里 `storage.workspace` 的默认值。

        目录由 {option}`systemd.tmpfiles.rules` 以 `terminus.openviking.user` /
        `.group` 的身份、权限 0750 创建（root 在开机时执行，不需要 preStart）。

        必须写成绝对路径字符串（例如 `"/var/lib/openviking"`）：Nix 路径字面量
        会被复制进 store，不能当作运行期目录用。
      '';
    };

    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/etc/openviking/ov.conf";
      description = ''
        直接使用的 ov.conf（JSON）路径，以 `--config` 传给服务端。

        为 `null`（默认）时，本模块用 {option}`terminus.openviking.settings` 生成
        一份配置，同样通过 `--config` 传入。两者只能选一个：同时设置 `configFile`
        和非空 `settings` 会触发断言失败。
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf jsonFormat.type;
      default = { };
      example = lib.literalExpression ''
        {
          embedding.dense = {
            provider = "openai";
            model = "text-embedding-3-small";
            api_key = "\''${OPENVIKING_EMBEDDING_API_KEY}";
          };
        }
      '';
      description = ''
        ov.conf 的声明式内容（JSON 结构，完整字段见上游 `examples/ov.conf.example`）。
        只在 `configFile = null` 时生效。

        配置加载时会对 JSON 文本做 `$VAR` / `''${VAR}` 展开，因此值里可以写环境变量
        占位符（Nix 字符串里要转义成 `"\''${VAR}"`），实际值由
        {option}`terminus.openviking.environmentFile` 提供：
        **密钥不要直接写在这里**（会进世界可读的 Nix store），用占位符 + 环境变量文件。

        注意：`server.host` / `server.port` 写在这里也会被
        {option}`terminus.openviking.host` / `.port` 的命令行参数覆盖；
        `server.workers` 等其余字段则按配置生效。
      '';
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.externalPath;
      default = null;
      example = "/run/secrets/openviking.env";
      description = ''
        密钥 / 环境变量文件（`KEY=VALUE`），由 systemd 的 `EnvironmentFile=` 读取，
        例如用 sops-nix / agenix 生成。

        里面的变量会进入服务进程的环境：既能被 ov.conf 里的 `''${OPENVIKING_...}`
        占位符展开（见 {option}`terminus.openviking.settings`），也可以直接作为
        OpenViking 识别的环境变量使用（例如 `OPENVIKING_API_KEY`）。
        ⚠️ 不要把密钥放进 `settings`：那会写进世界可读的 Nix store。
      '';
    };

    readOnlyPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "/home/alice/projects" ];
      description = ''
        额外允许服务**只读**访问的路径（映射到 systemd 的 `ReadOnlyPaths=`）。
        典型场景：以现有用户身份运行，需要索引自己的代码仓库。

        注意 `ProtectHome` 的默认值：`user = "openviking"` 时是 `true`（完全看不到
        /home）；换成别的用户时是 `"read-only"`。若要在默认用户下读取 /home 里的
        路径，需要自己把 `systemd.services.openviking.serviceConfig.ProtectHome`
        覆盖成 `"read-only"`。
      '';
    };

    readWritePaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "/srv/openviking-data" ];
      description = ''
        除 {option}`terminus.openviking.dataDir` 之外，额外允许**写入**的绝对路径
        （映射到 systemd 的 `ReadWritePaths=`）。例如把 `settings.storage.workspace`
        指到 dataDir 之外时，需要把那个目录加进来。
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "是否在防火墙中放行 {option}`terminus.openviking.port`。";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "openviking";
      description = ''
        运行服务的用户。默认的 `openviking` 系统用户由本模块创建（家目录 = `dataDir`）；
        改成已存在的用户（例如你自己的账号）时本模块不会再创建它，也不会改它的家目录。
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "openviking";
      description = ''
        运行服务的用户组。默认的 `openviking` 组由本模块创建；
        改成别的组时需要由你（或其他模块）负责创建它。
      '';
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "users" ];
      description = "服务进程的附加用户组（systemd 的 `SupplementaryGroups=`）。";
    };
  };
}
