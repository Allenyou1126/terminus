# Donetick（任务/家务管理服务）的 NixOS 模块选项。
#
# 选项结构对齐官方 Configuration 文档
# （https://docs.donetick.com/getting-started/configration）与自托管模板
# config/selfhosted.yaml.example。与「让用户直接写 YAML」不同，这里的每个字段
# 都是强类型选项，由 nixos.nix 统一生成 selfhosted.yaml。
#
# 与官方文档/参考实现的差异（均已对照 v0.1.89 源码）：
#
# - 只支持 selfhost：DT_ENV 固定为 selfhosted，不提供 configEnv。
# - is_done_tick_dot_com 强制为 false，不暴露为选项。
# - 不提供 Stripe 配置；RevenueCat / IAP / FCM / Bridge / Realtime / MFA /
#   Logging / feature_limits 等章节也未纳入，出处见仓库说明。
# - 秘密（jwt / 数据库密码 / email key / OAuth2 client secret / S3 凭据 /
#   Telegram / Pushover token）一律用 *File 选项，由启动脚本在运行期读入并注入
#   环境变量，不写进 Nix store。
# - SQLite 路径：源码里没有 database.path 这个键，只读 DT_SQLITE_PATH
#   （internal/database/database.go），因此路径固定为 ${dataDir}/donetick.db。
# - database.logger 在源码中未被读取（GORM 级别取自 logging.level），不暴露。
# - single_circle_instance / disable_password_auth / oauth2 的 admin_groups、
#   manager_groups 按 README「Single-Circle Instance Mode & OIDC Group-Based
#   Roles」用环境变量配置（viper v1.21 的字符串→切片 hook 支持逗号分隔）。
#
# 最小用法：
#
#   terminus.donetick = {
#     enable = true;
#     openFirewall = true;
#     jwt.secretFile = config.age.secrets.donetick-jwt.path;
#     server.publicHost = "https://donetick.example.com";
#   };
{
  lib,
  self,
  pkgs,
  ...
}:
let
  # Go time.Duration 语法（如 168h、1h30m、500ms）。
  durationType = lib.types.strMatching "([0-9]+(\\.[0-9]+)?(ns|us|µs|ms|s|m|h))+";

  secretFileType = lib.types.nullOr lib.types.externalPath;
in
{
  options.terminus.donetick = {
    enable = lib.mkEnableOption "Donetick 任务/家务管理服务";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.donetick;
      defaultText = lib.literalExpression "self.packages.\${pkgs.stdenv.hostPlatform.system}.donetick";
      description = ''
        Donetick 服务端包，默认取本 flake 的 `packages.<system>.donetick`
        （已内嵌构建好的前端静态资源）。
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "donetick";
      description = ''
        运行服务的用户。默认的 `donetick` 系统用户由本模块创建（家目录 =
        {option}`terminus.donetick.dataDir`）；改成已存在的用户时不再创建。
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "donetick";
      description = ''
        运行服务的用户组。默认的 `donetick` 组由本模块创建；
        改成别的组时需要由你（或其他模块）负责创建它。
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.pathWith {
        inStore = false;
        absolute = true;
      };
      default = "/var/lib/donetick";
      description = ''
        数据目录，同时是服务的 `WorkingDirectory`、默认用户的家目录、SQLite
        数据库（`donetick.db`）、自动生成的 JWT secret（`jwt-secret`）、配置
        目录（`config/selfhosted.yaml` 符号链接）和本地附件目录（`assets/`）。

        目录由 {option}`systemd.tmpfiles.rules` 以
        {option}`terminus.donetick.user` / `.group` 的身份、权限 0750 创建。
        必须写成绝对路径字符串（Nix 路径字面量会被复制进 store）。
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "是否在防火墙中放行 {option}`terminus.donetick.server.port`。";
    };

    readWritePaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "/srv/donetick-storage" ];
      description = ''
        除 {option}`terminus.donetick.dataDir` 之外，额外允许服务写入的绝对路径
        （systemd 的 `ReadWritePaths=`）。

        典型场景：把 {option}`terminus.donetick.storage.basePath` 指到 dataDir
        之外的绝对路径（本地附件存储）。不加入这里会被
        `ProtectSystem = "strict"` 拦截。
      '';
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        DT_MCP_ENABLED = "true";
      };
      description = ''
        额外的服务进程环境变量（systemd 的 `Environment=`），用于设置本模块未
        暴露的上游环境变量。

        由模块生成的变量（`DT_ENV`、`DT_SQLITE_PATH`、`DT_SERVER_PORT`、
        `DT_SINGLE_CIRCLE_INSTANCE`、`DT_DISABLE_PASSWORD_AUTH`、
        `DT_OAUTH2_*`、各 secret 注入变量）不允许在这里覆盖，会触发断言。
        密钥请用对应的 `*File` 选项或 {option}`terminus.donetick.environmentFile`。
      '';
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.externalPath;
      default = null;
      example = "/run/secrets/donetick.env";
      description = ''
        服务进程的 `KEY=VALUE` 环境变量文件（systemd 的 `EnvironmentFile=`），
        例如用 agenix / sops-nix 生成，作为未暴露变量的逃生口。
      '';
    };

    singleCircleInstance = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        单圈实例模式，对应 README 的 `DT_SINGLE_CIRCLE_INSTANCE`。

        开启后隐藏圈子管理界面，禁用加入/离开/删除成员/接受申请等端点；新的
        OIDC 用户会加入共享的家庭圈（ID 1），而不是各自拥有独立圈子。
      '';
    };

    disablePasswordAuth = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        仅 SSO 登录，对应 README 的 `DT_DISABLE_PASSWORD_AUTH`。

        开启后拒绝所有密码登录/注册/重置，登录界面只保留 SSO。请同时配置
        {option}`terminus.donetick.oauth2`，否则可能无法登录。
      '';
    };

    general = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "donetick";
        description = ''
          实例名，对应 `name`（官方 Configuration 的 General 段）。
        '';
      };

      isUserCreationDisabled = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "是否禁止新用户注册，对应 `is_user_creation_disabled`。";
      };
    };

    jwt = {
      secretFile = lib.mkOption {
        type = secretFileType;
        default = null;
        example = "/run/secrets/donetick-jwt";
        description = ''
          存放 JWT secret 的文件（内容即 secret，行尾换行会被去掉），对应
          `jwt.secret`。文件必须对 {option}`terminus.donetick.user` 可读
          （agenix 里设 `age.secrets.<name>.owner = "donetick"`）。

          secret 至少 32 字符且不能是弱口令，否则服务拒绝启动。为 `null` 时
          首次启动生成 48 字节随机 secret 并以 0600 写到
          `''${dataDir}/jwt-secret`，之后复用；该文件丢失会使所有登录会话失效。

          本地附件存储的签名 URL 也使用该 secret（`internal/storage/signer_local.go`）。
        '';
      };

      sessionTime = lib.mkOption {
        type = durationType;
        default = "168h";
        description = "会话有效期，对应 `jwt.session_time`（Go duration 语法）。";
      };

      maxRefresh = lib.mkOption {
        type = durationType;
        default = "1440h";
        description = "会话最长可刷新时间，对应 `jwt.max_refresh`。";
      };
    };

    database = {
      type = lib.mkOption {
        type = lib.types.enum [
          "sqlite"
          "postgres"
        ];
        default = "sqlite";
        description = ''
          数据库类型，对应 `database.type`。

          sqlite 时数据库固定为 `''${dataDir}/donetick.db`（源码只认
          `DT_SQLITE_PATH`，没有 `database.path` 键）；postgres 时使用下面的
          host/port/user/name 与 {option}`terminus.donetick.database.passwordFile`。
        '';
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "127.0.0.1";
        description = "postgres 主机，对应 `database.host`（sqlite 时忽略）。";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 5432;
        description = "postgres 端口，对应 `database.port`（sqlite 时忽略）。";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "donetick";
        description = "postgres 用户，对应 `database.user`（sqlite 时忽略）。";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "donetick";
        description = "postgres 数据库名，对应 `database.name`（sqlite 时忽略）。";
      };

      passwordFile = lib.mkOption {
        type = secretFileType;
        default = null;
        example = "/run/secrets/donetick-db-password";
        description = ''
          postgres 密码文件，对应 `database.password`。内容由启动脚本注入
          `DT_DATABASE_PASSWORD`，不写进 Nix store。
        '';
      };

      migration = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "启动时是否自动迁移数据库，对应 `database.migration`。";
      };
    };

    server = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 2021;
        description = ''
          HTTP 监听端口，对应 `server.port`（同时通过 `DT_SERVER_PORT` 下发）。
          服务监听所有地址；{option}`terminus.donetick.openFirewall` 会放行该端口。
        '';
      };

      ratePeriod = lib.mkOption {
        type = durationType;
        default = "60s";
        description = "限流时间窗口，对应 `server.rate_period`。";
      };

      rateLimit = lib.mkOption {
        type = lib.types.ints.positive;
        default = 300;
        description = "每个窗口允许的请求数，对应 `server.rate_limit`。";
      };

      readTimeout = lib.mkOption {
        type = durationType;
        default = "10s";
        description = "读超时，对应 `server.read_timeout`。";
      };

      writeTimeout = lib.mkOption {
        type = durationType;
        default = "10s";
        description = "写超时，对应 `server.write_timeout`。";
      };

      corsAllowOrigins = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "http://localhost:5173"
          "http://localhost:7926"
          "https://localhost"
          "http://localhost"
          "capacitor://localhost"
        ];
        description = ''
          允许的 CORS 来源，对应 `server.cors_allow_origins`。默认值与上游
          selfhosted 模板一致（前端本地开发与 Capacitor 应用）。

          实际生效的列表还会并入
          {option}`terminus.donetick.server.mobileAppOrigins` 并去重。
        '';
      };

      mobileAppOrigins = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "https://localhost"
          "http://localhost"
          "capacitor://localhost"
        ];
        description = ''
          Capacitor 官方 App 的额外 CORS 来源，与
          {option}`terminus.donetick.server.corsAllowOrigins` 合并去重后写入
          `server.cors_allow_origins`。

          Android App 的 WebView Origin 是 `https://localhost`（Capacitor 默认
          `androidScheme = https`），iOS 是 `capacitor://localhost`。这些值来自
          上游 selfhosted 模板；Web 前端同源访问不受影响。

          单独做成选项的原因：主机常把 `corsAllowOrigins` 覆盖成自己的公网域名，
          如果 App 的 Origin 只靠默认值提供就会丢失，导致 Android/iOS App 报
          CORS 错误。设为 `[ ]` 可关闭。
        '';
      };

      serveFrontend = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          是否由本服务提供内嵌 Web UI，对应 `server.serve_frontend`。

          源码中该字段没有默认值（缺省为 false），所以模块显式写入 true；
          只想要 API 时设为 false。
        '';
      };

      publicHost = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "https://donetick.example.com";
        description = ''
          对外访问地址，对应 `server.public_host`（上游 selfhosted 模板用法）。

          邮件、邀请等链接会用到它。为 null 时不写入该键，服务端默认回落到
          `http://localhost:2021`，公网部署会得到错误链接。
        '';
      };
    };

    notifications = {
      telegram = {
        tokenFile = lib.mkOption {
          type = secretFileType;
          default = null;
          example = "/run/secrets/donetick-telegram-token";
          description = ''
            Telegram bot token 文件，对应 `telegram.token`；启动脚本注入
            `DONETICK_TELEGRAM_TOKEN`（源码显式读取的环境变量）。
          '';
        };
      };

      pushover = {
        tokenFile = lib.mkOption {
          type = secretFileType;
          default = null;
          example = "/run/secrets/donetick-pushover-token";
          description = ''
            Pushover token 文件，对应 `pushover.token`；启动脚本注入
            `DONETICK_PUSHOVER_TOKEN`。
          '';
        };
      };
    };

    schedulerJobs = {
      dueJob = lib.mkOption {
        type = durationType;
        default = "30m";
        description = "到期任务调度间隔，对应 `scheduler_jobs.due_job`。";
      };

      overdueJob = lib.mkOption {
        type = durationType;
        default = "3h";
        description = "逾期任务调度间隔，对应 `scheduler_jobs.overdue_job`。";
      };

      preDueJob = lib.mkOption {
        type = durationType;
        default = "3h";
        description = "提前提醒调度间隔，对应 `scheduler_jobs.pre_due_job`。";
      };
    };

    email = {
      address = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "donetick@example.com";
        description = "发件地址，对应 `email.email`。";
      };

      keyFile = lib.mkOption {
        type = secretFileType;
        default = null;
        example = "/run/secrets/donetick-email-key";
        description = ''
          SMTP 密码 / API key 文件，对应 `email.key`；启动脚本注入
          `DT_EMAIL_KEY`，不写进 Nix store。
        '';
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "smtp.example.com";
        description = "SMTP 主机，对应 `email.host`。";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 587;
        description = "SMTP 端口，对应 `email.port`。";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "donetick@example.com";
        description = ''
          SMTP 用户名，对应 `email.user`（上游 selfhosted 模板字段；留空时
          服务端以 {option}`terminus.donetick.email.address` 作为用户名）。
        '';
      };

      appHost = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "https://donetick.example.com";
        description = "邮件里链接使用的外部地址，对应 `email.app_host`。";
      };
    };

    oauth2 = {
      clientId = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          OIDC client ID，对应 `oauth2.client_id`。留空表示不启用 OIDC 登录。
        '';
      };

      clientSecretFile = lib.mkOption {
        type = secretFileType;
        default = null;
        example = "/run/secrets/donetick-oidc-secret";
        description = ''
          OIDC client secret 文件，对应 `oauth2.client_secret`；启动脚本注入
          `DT_OAUTH2_CLIENT_SECRET`。
        '';
      };

      pkce = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          OAuth2 PKCE（`code_challenge` / `code_verifier`），对应 `oauth2.pkce`。

          开启后 `/api/v1/resource` 会向 Web / App 前端宣告 PKCE：授权请求带
          `code_challenge`（S256），服务端兑换 code 时带 `verifier`。

          注意这跟 IdP 的「认证方式」是两件事：Donetick 0.1.89 只在 `clientId`
          **和** `clientSecret` 都非空时才启用 OIDC
          （`internal/auth/identity_provider.go`），所以 ZITADEL 侧仍应选
          **Native + Auth Method `Basic` 或 `Post`**（会签发 secret），再按 IdP
          是否接受 confidential client 的 PKCE 决定是否打开本选项。若选
          ZITADEL 的 `PKCE` / `None` 认证方式（不签发 secret），Donetick 会
          直接禁用 OIDC。
        '';
      };

      redirectUrl = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "https://donetick.example.com/auth/oauth2";
        description = ''
          OIDC 回调地址，对应 `oauth2.redirect_url`。

          注意这只是**服务端兜底值**：前端会自己带上 `redirect_uri`——Web 端是
          `https://<你的域名>/auth/oauth2`，Android/iOS App 是
          `donetick://auth/oauth2`（App 的 deep link scheme 就是 `donetick`）。
          服务端在 `/api/v1/oauth/...` 的 code 交换中优先使用前端传来的值，
          所以 IdP 侧必须同时登记这两条 URI：

          - `https://<你的域名>/auth/oauth2`（Web；不是 `/api/v1/oauth2/callback`）
          - `donetick://auth/oauth2`（Android / iOS App）

          ZITADEL 中自定义 scheme 只允许用于 **Native** 类型的应用（code grant）；
          Web 类型应用会报 `CustomOnlyForNative`，且应用类型创建后不能修改，
          需要新建 Native 应用并把 Client ID/Secret 换过来。Donetick 要求
          ClientSecret 非空（否则 OIDC 被禁用），因此 ZITADEL 的 Auth Method
          选 `Basic` 或 `Post`；PKCE 参数是否下发由
          {option}`terminus.donetick.oauth2.pkce` 单独控制（ZITADEL 的
          `PKCE` / `None` 认证方式不签发 secret，会让 OIDC 被禁用）。
        '';
      };

      scopes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "openid"
          "profile"
          "email"
          "groups"
        ];
        description = ''
          OIDC scopes，对应 `oauth2.scopes`。基于分组的角色映射需要
          `groups` scope 且 IdP 在 userinfo 中返回 `groups` claim。
        '';
      };

      authUrl = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "授权端点，对应 `oauth2.auth_url`。";
      };

      tokenUrl = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "token 端点，对应 `oauth2.token_url`。";
      };

      userInfoUrl = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "userinfo 端点，对应 `oauth2.user_info_url`。";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "Authentik";
        description = "登录按钮显示的名称，对应 `oauth2.name`。";
      };

      adminGroups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "donetick-admins" ];
        description = ''
          授予 `admin` 角色的 OIDC 组名，对应 README 的
          `DT_OAUTH2_ADMIN_GROUPS`（模块以逗号连接后通过环境变量下发）。

          角色同步在每次 OIDC 登录时执行；admin 优先于 manager。组名匹配是
          精确且区分大小写的。两个组列表都为空时不会修改用户角色。
        '';
      };

      managerGroups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "donetick-managers" ];
        description = ''
          授予 `manager` 角色的 OIDC 组名，对应 README 的
          `DT_OAUTH2_MANAGER_GROUPS`。
        '';
      };
    };

    webhook = {
      timeout = lib.mkOption {
        type = durationType;
        default = "5s";
        description = "webhook 请求超时，对应 `webhook.timeout`。";
      };

      queueSize = lib.mkOption {
        type = lib.types.ints.positive;
        default = 100;
        description = "webhook 队列长度，对应 `webhook.queue_size`。";
      };
    };

    storage = {
      type = lib.mkOption {
        type = lib.types.enum [
          "local"
          "remote"
        ];
        default = "local";
        description = ''
          存储后端，对应 `storage.storage_type`。

          `local` 使用 dataDir 下的本地目录；`remote` 表示 S3 兼容对象存储
          （AWS S3 / Cloudflare R2 / MinIO / 其他 S3 兼容服务）。源码里只有
          `"local"` 是特殊值，其余任何值（包括空）都会走 S3，因此这里显式给出
          枚举并默认 `local`，避免空值意外启用未配置的 S3。
        '';
      };

      basePath = lib.mkOption {
        type = lib.types.str;
        default = "assets";
        description = ''
          存储根路径，对应 `storage.base_path`。

          local 时是相对 `WorkingDirectory`（即 {option}`terminus.donetick.dataDir`）
          的目录（默认落在 `''${dataDir}/assets`）；remote 时是对象前缀。
          指到 dataDir 之外的绝对路径时，需要把该路径加入
          {option}`terminus.donetick.readWritePaths`。
        '';
      };

      bucketName = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "donetick-assets";
        description = "S3 bucket，对应 `storage.bucket_name`。";
      };

      region = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "us-east-1";
        description = "S3 region，对应 `storage.region`。";
      };

      endpoint = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "https://<account>.r2.cloudflarestorage.com";
        description = "S3 兼容端点，对应 `storage.endpoint`（R2 / MinIO 等）。";
      };

      accessKeyFile = lib.mkOption {
        type = secretFileType;
        default = null;
        example = "/run/secrets/donetick-s3-access-key";
        description = ''
          S3 access key 文件，对应 `storage.access_key`；启动脚本注入
          `DT_STORAGE_ACCESS_KEY`。
        '';
      };

      secretKeyFile = lib.mkOption {
        type = secretFileType;
        default = null;
        example = "/run/secrets/donetick-s3-secret-key";
        description = ''
          S3 secret key 文件，对应 `storage.secret_key`；启动脚本注入
          `DT_STORAGE_SECRET_KEY`。
        '';
      };

      publicHost = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "https://cdn.example.com";
        description = "公开访问 URL 主机，对应 `storage.public_host`。";
      };

      publicRead = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          返回不带签名的公开 URL，对应 `storage.public_read`（源码字段，
          Storage 文档页未列出）。bucket 需要配置匿名读权限。
        '';
      };

      publicBucketName = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          可公开读取的独立 bucket，对应 `storage.public_bucket_name`
          （源码字段）；留空时公开资源回落到私有 bucket。
        '';
      };

      publicBucketHost = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          公开 bucket 的 CDN / 自定义域名，对应 `storage.public_bucket_host`
          （源码字段）。
        '';
      };

      pathStyle = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          强制 path-style 寻址，对应 `storage.path_style`（源码字段）。
          MinIO 等不提供 `*.<endpoint>` DNS 通配的服务通常需要开启。
        '';
      };

      maxUserStorage = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 1073741824;
        description = ''
          单个圈子可用的存储字节数，对应 `storage.max_user_storage`。

          ⚠️ 源码用 `已用空间 + 新文件大小 > max_user_storage` 判断，**0 会
          拒绝所有上传**，因此默认 1 GiB。官方 Storage 文档示例是 100 MiB。
        '';
      };

      maxFileSize = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 10485760;
        description = ''
          单个文件大小上限（字节），对应 `storage.max_file_size`。

          ⚠️ **0 会拒绝所有上传**（`file.Size > max_file_size`），因此默认
          10 MiB。官方 Storage 文档示例是 2 MiB。
        '';
      };
    };

    mcp = {
      enabled = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          MCP（Model Context Protocol）服务端开关，对应 `mcp.enabled`
          （README「MCP Server」；也可用 `DT_MCP_ENABLED` 环境变量设置）。

          开启后 Donetick 在 `/mcp` 提供 Streamable HTTP MCP 端点，AI 客户端用
          Donetick API token 认证（`Authorization: Bearer <token>` 或
          `secretkey` 头）。带 `Origin` 头的请求还会要求 Origin 是本服务地址，
          或在 {option}`terminus.donetick.server.corsAllowOrigins` 中。
        '';
      };
    };
  };
}
