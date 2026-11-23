# Certimate 自托管 TLS 证书管理服务。
#
# Certimate 基于 PocketBase：ACME 账户、DNS/部署凭据和工作流都存在
# stateDirectory 下的 SQLite 数据库里，所以本模块只描述进程与数据目录，
# 不提供声明式 settings（所有内容通过 Web UI 管理）。
#
# 首次启动会创建默认管理员 `admin@certimate.fun` / `1234567890`，登录后
# 请立即修改。若要在首次初始化时覆盖默认管理员，可在 environment 或
# environmentFile 里设置 CERTIMATE_ADMIN_USERNAME / CERTIMATE_ADMIN_PASSWORD
# （数据库里已有 superuser 后这两个变量不再生效）。
#
# 默认只监听 127.0.0.1:8090，通常放在 nginx/Caddy 后面；需要直接对外时
# 同时设置 addr = "0.0.0.0" 和 openFirewall = true。
{
  lib,
  pkgs,
  self,
  ...
}:
{
  options.terminus.certimate = {
    enable = lib.mkEnableOption "Certimate 自托管 TLS 证书管理服务";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.certimate;
      defaultText = lib.literalExpression "self.packages.\${pkgs.stdenv.hostPlatform.system}.certimate";
      description = ''
        Certimate 服务端包。默认取本 flake 的 `packages.<system>.certimate`，
        通常不需要覆盖；需要换用上游 release 或其他打包时再改。
      '';
    };

    stateDirectory = lib.mkOption {
      type = lib.types.pathWith {
        inStore = false;
        absolute = true;
      };
      default = "/var/lib/certimate";
      example = "/var/lib/certimate";
      description = ''
        PocketBase 数据目录，对应 `certimate serve --dir=...`。数据库、
        备份和上传的证书都在这里，升级/迁移时备份该目录即可保留全部
        工作流与凭据。

        必须写成绝对路径字符串（例如 `"/var/lib/certimate"`）：Nix 路径
        字面量会被复制进 store，不能作为运行期可写目录。目录由模块创建
        （默认用户的 home + systemd.tmpfiles），属主是
        {option}`terminus.certimate.user` / `.group`，并作为服务的工作目录。
      '';
    };

    addr = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = ''
        监听地址，与 {option}`terminus.certimate.port` 一起组成
        `certimate serve --http` 参数。

        默认只监听回环地址。改成 `0.0.0.0` 或具体网卡地址前，请确认前面
        有反向代理/鉴权，并已修改默认管理员密码。IPv6 地址请写成
        `[::1]` 这类带方括号的形式。
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8090;
      example = 8090;
      description = ''
        监听端口，与 {option}`terminus.certimate.addr` 一起组成
        `certimate serve --http` 参数。

        低于 1024 的端口需要 `CAP_NET_BIND_SERVICE`。本模块默认不收紧
        capabilities（为了不破坏可能需要 `sudo` 的部署工作流），需要低端口
        时请自行在 `systemd.services.certimate.serviceConfig` 里添加
        `AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ]`，或直接用反向代理
        转发到 8090。
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        是否在防火墙中放行 {option}`terminus.certimate.port`。仅当
        {option}`terminus.certimate.addr` 不是回环地址、且客户端需要直连
        时开启；通过反向代理访问时保持 `false`。
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "certimate";
      description = ''
        运行服务的用户。默认的 `certimate` 系统用户由本模块创建，家目录
        就是 {option}`terminus.certimate.stateDirectory`。改成已存在的
        用户时，模块不会创建它，但 tmpfiles 仍会把数据目录的属主设为该
        用户；用户本身需要由你或其他模块保证存在。
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "certimate";
      description = ''
        运行服务的用户组。默认组由本模块创建；改成其他组时需要由你或
        其他模块负责创建，tmpfiles 会把数据目录的属组设为该组。
      '';
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "nginx" ];
      description = ''
        服务进程的附加用户组（systemd 的 `SupplementaryGroups=`）。需要
        读取其他服务的证书或密钥（例如 nginx 的私钥目录）时使用。
      '';
    };

    readOnlyPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "/etc/ssl/private" ];
      description = ''
        额外允许服务**只读**访问的绝对路径（systemd 的 `ReadOnlyPaths=`）。
        例如把仓库里统一管理的私钥放在 `/etc/ssl/private`，让 Certimate
        读取后导入到某个部署目标。

        注意 `ProtectHome` 的默认值：默认用户下是 `true`（完全看不到
        `/home`）；换成已有用户时退化为 `"read-only"`，可以读但不能写。
      '';
    };

    readWritePaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "/etc/nginx/ssl" ];
      description = ''
        除 {option}`terminus.certimate.stateDirectory` 外，额外允许服务
        **写入**的绝对路径（systemd 的 `ReadWritePaths=`）。本地部署节点
        要把证书写到 `/etc/nginx/ssl` 这类目录时，把该目录加进来。

        `ProtectSystem` 默认是 `"full"`，`/etc`、`/usr` 等是只读的；路径
        必须已经存在（或由 tmpfiles 预先创建），否则服务启动失败。
      '';
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        CERTIMATE_WORKFLOW_MULTIPROC = "0";
      };
      description = ''
        额外注入服务进程的环境变量。Certimate 识别的常用变量：

        - `CERTIMATE_WORKFLOW_MULTIPROC`：是否把 ACME 申请放到独立进程
          执行（默认 `true`）。排查崩溃或节省内存时可以设为 `"0"`；
        - `CERTIMATE_WORKFLOW_MAX_WORKERS`：工作流并发上限（默认等于
          `GOMAXPROCS`）。

        这里只放非密钥值；密码、API token 等请用
        {option}`terminus.certimate.environmentFile`。不要在这里覆盖
        `PATH`：服务的基础 `PATH` 由 {option}`terminus.certimate.extraPackages`
        管理。
      '';
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.externalPath;
      default = null;
      example = "/run/secrets/certimate.env";
      description = ''
        `KEY=VALUE` 格式的环境变量文件，由 systemd 的 `EnvironmentFile=`
        读取，例如由 agenix/sops-nix 生成。

        典型用途：首次初始化时设置 `CERTIMATE_ADMIN_USERNAME` /
        `CERTIMATE_ADMIN_PASSWORD` 覆盖默认管理员，或提供某些部署插件
        需要的云厂商凭据。
      '';
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "with pkgs; [ nginx openssh ]";
      description = ''
        追加到服务 `PATH` 的包。基础 `PATH` 已包含 `bash`、`coreutils`、
        `openssh` 和 `openssl`（Certimate 的部署节点会执行 shell 命令、
        SSH 和证书格式转换）。

        工作流需要调用其他命令（例如 `nginx -s reload`、`systemctl`、
        `kubectl`）时，把对应的包加进来；需要 `sudo` 也在这里显式添加。
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "--dev" ];
      description = ''
        追加到 `certimate serve` 的额外参数，例如 `--dev`、`--https` 或
        `--origins`。参数排在模块生成的 `--dir` / `--http` 之后，同名
        flag 以这里为准（pflag 后出现的值生效），因此也可以覆盖默认监听
        参数 —— 但这两种方式只需要选一种。

        一般的监听配置请优先用 {option}`terminus.certimate.addr` /
        `.port`，保持选项可被其他模块引用。
      '';
    };
  };
}
