# Donetick 服务实现：把 terminus.donetick.* 翻译成 selfhosted.yaml、systemd 单元
# 与运行期环境变量。选项定义见同目录 options.nix。
#
# 数据流：
#   选项 → 生成的 selfhosted.yaml（非敏感值 + secret 空占位）
#        → unit Environment（DT_ENV / 端口 / README 的 Single-Circle 与 OIDC 组）
#        → 启动脚本（运行期从 *File 读入 secret 并 export，再 exec 服务端）
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.terminus.donetick;

  yamlFormat = pkgs.formats.yaml { };

  dataDir = toString cfg.dataDir;

  isPostgres = cfg.database.type == "postgres";

  # 生成的 selfhosted.yaml。所有 secret 键只写空串占位：真实值由启动脚本在
  # 运行期通过环境变量注入，这样既保留 viper 的「已知 key + 环境变量覆盖」路径，
  # 又不会把秘密写进世界可读的 Nix store。
  generatedSettings = {
    name = cfg.general.name;
    is_done_tick_dot_com = false;
    is_user_creation_disabled = cfg.general.isUserCreationDisabled;

    jwt = {
      secret = "";
      session_time = cfg.jwt.sessionTime;
      max_refresh = cfg.jwt.maxRefresh;
    };

    # sqlite 路径只认 DT_SQLITE_PATH（源码中没有 database.path 键）；
    # postgres 的 host/port/user/name 只在 postgres 时写出。
    database = {
      type = cfg.database.type;
      migration = cfg.database.migration;
      password = "";
    }
    // lib.optionalAttrs isPostgres {
      host = cfg.database.host;
      port = cfg.database.port;
      user = cfg.database.user;
      name = cfg.database.name;
    };

    server = {
      port = cfg.server.port;
      rate_period = cfg.server.ratePeriod;
      rate_limit = cfg.server.rateLimit;
      read_timeout = cfg.server.readTimeout;
      write_timeout = cfg.server.writeTimeout;
      # Donetick 的 CORS 是精确匹配白名单（main.go 里 AllowOriginFunc 查 map），
      # 且 AllowCredentials = true。官方 App 的 Origin 与站点域名不同，所以把
      # mobileAppOrigins 一并并入；去重避免重复的 Access-Control-Allow-Origin。
      cors_allow_origins = lib.unique (cfg.server.corsAllowOrigins ++ cfg.server.mobileAppOrigins);
      serve_frontend = cfg.server.serveFrontend;
    }
    // lib.optionalAttrs (cfg.server.publicHost != null) {
      public_host = cfg.server.publicHost;
    };

    telegram.token = "";
    pushover.token = "";

    scheduler_jobs = {
      due_job = cfg.schedulerJobs.dueJob;
      overdue_job = cfg.schedulerJobs.overdueJob;
      pre_due_job = cfg.schedulerJobs.preDueJob;
    };

    email = {
      email = cfg.email.address;
      key = "";
      host = cfg.email.host;
      port = cfg.email.port;
      user = cfg.email.user;
      app_host = cfg.email.appHost;
    };

    oauth2 = {
      client_id = cfg.oauth2.clientId;
      client_secret = "";
      pkce = cfg.oauth2.pkce;
      redirect_url = cfg.oauth2.redirectUrl;
      scopes = cfg.oauth2.scopes;
      auth_url = cfg.oauth2.authUrl;
      token_url = cfg.oauth2.tokenUrl;
      user_info_url = cfg.oauth2.userInfoUrl;
      name = cfg.oauth2.name;
      # admin_groups / manager_groups 按 README 用环境变量下发，不写 YAML。
    };

    webhook = {
      timeout = cfg.webhook.timeout;
      queue_size = cfg.webhook.queueSize;
      # 空占位：真实密钥由启动脚本通过 DT_WEBHOOK_SIGNING_SECRET 注入。
      signing_secret = "";
    };

    storage = {
      storage_type = cfg.storage.type;
      base_path = cfg.storage.basePath;
      bucket_name = cfg.storage.bucketName;
      region = cfg.storage.region;
      endpoint = cfg.storage.endpoint;
      access_key = "";
      secret_key = "";
      public_host = cfg.storage.publicHost;
      public_read = cfg.storage.publicRead;
      public_bucket_name = cfg.storage.publicBucketName;
      public_bucket_host = cfg.storage.publicBucketHost;
      path_style = cfg.storage.pathStyle;
      max_user_storage = cfg.storage.maxUserStorage;
      max_file_size = cfg.storage.maxFileSize;
    };

    # Bridge 是托管推送中继。上游 v0.1.89 的 BridgeConfig.Enabled 带
    # default:"true"，而 defaults.SetDefaults 在 unmarshal 之后回填零值，所以
    # 这里写 false（或环境变量 DT_BRIDGE_ENABLED=false）都会被重新置为 true；
    # 实测 /api/v1/resource 仍返回 bridge_enabled:true。保留该键只为与上游
    # selfhosted 模板一致，待上游修复后即生效；当前若要关闭，请在首次启动后
    # 通过 Web UI 断开 Bridge（持久化在 bridge_settings 表）。
    bridge.enabled = false;

    # MCP（Model Context Protocol）服务端；默认关闭，开启后端点为 /mcp。
    mcp.enabled = cfg.mcp.enabled;
  };

  configFile = yamlFormat.generate "donetick-selfhosted.yaml" generatedSettings;

  # 非敏感运行期环境变量（进 unit 文件，世界可读）。
  serviceEnvironment = {
    DT_ENV = "selfhosted";
    DT_SERVER_PORT = toString cfg.server.port;
    DT_SINGLE_CIRCLE_INSTANCE = lib.boolToString cfg.singleCircleInstance;
    DT_DISABLE_PASSWORD_AUTH = lib.boolToString cfg.disablePasswordAuth;
  }
  // lib.optionalAttrs (cfg.database.type == "sqlite") {
    DT_SQLITE_PATH = "${dataDir}/donetick.db";
  }
  // lib.optionalAttrs (cfg.oauth2.adminGroups != [ ]) {
    DT_OAUTH2_ADMIN_GROUPS = lib.concatStringsSep "," cfg.oauth2.adminGroups;
  }
  // lib.optionalAttrs (cfg.oauth2.managerGroups != [ ]) {
    DT_OAUTH2_MANAGER_GROUPS = lib.concatStringsSep "," cfg.oauth2.managerGroups;
  }
  // cfg.environment;

  # 从文件读入 secret 的规格：启动脚本统一注入，失败时报出对应选项。
  secretSpecs = lib.filter (spec: spec.file != null) [
    {
      env = "DT_DATABASE_PASSWORD";
      option = "terminus.donetick.database.passwordFile";
      file = cfg.database.passwordFile;
    }
    {
      env = "DT_EMAIL_KEY";
      option = "terminus.donetick.email.keyFile";
      file = cfg.email.keyFile;
    }
    {
      env = "DT_OAUTH2_CLIENT_SECRET";
      option = "terminus.donetick.oauth2.clientSecretFile";
      file = cfg.oauth2.clientSecretFile;
    }
    {
      env = "DT_STORAGE_ACCESS_KEY";
      option = "terminus.donetick.storage.accessKeyFile";
      file = cfg.storage.accessKeyFile;
    }
    {
      env = "DT_STORAGE_SECRET_KEY";
      option = "terminus.donetick.storage.secretKeyFile";
      file = cfg.storage.secretKeyFile;
    }
    {
      env = "DONETICK_TELEGRAM_TOKEN";
      option = "terminus.donetick.notifications.telegram.tokenFile";
      file = cfg.notifications.telegram.tokenFile;
    }
    {
      env = "DONETICK_PUSHOVER_TOKEN";
      option = "terminus.donetick.notifications.pushover.tokenFile";
      file = cfg.notifications.pushover.tokenFile;
    }
    {
      env = "DT_WEBHOOK_SIGNING_SECRET";
      option = "terminus.donetick.webhook.signingSecretFile";
      file = cfg.webhook.signingSecretFile;
    }
  ];

  readSecret = spec: ''
    read_secret ${spec.env} ${spec.option} ${lib.escapeShellArg (toString spec.file)}
  '';

  # JWT secret：优先用 jwt.secretFile；没有时首次启动生成并持久化到 dataDir。
  jwtSnippet =
    if cfg.jwt.secretFile != null then
      ''
        read_secret DT_JWT_SECRET terminus.donetick.jwt.secretFile ${lib.escapeShellArg (toString cfg.jwt.secretFile)}
      ''
    else
      ''
        jwtSecretFile=${lib.escapeShellArg "${dataDir}/jwt-secret"}
        if [ ! -s "$jwtSecretFile" ]; then
          umask 077
          head -c 48 /dev/urandom | base64 -w0 > "$jwtSecretFile"
        fi
        DT_JWT_SECRET="$(< "$jwtSecretFile")"
        export DT_JWT_SECRET
      '';

  startScript = pkgs.writeShellScript "donetick-start" ''
    set -euo pipefail
    export PATH=${lib.makeBinPath [ pkgs.coreutils ]}''${PATH:+:$PATH}

    read_secret() {
      local var="$1" option="$2" file="$3"
      if [ ! -s "$file" ]; then
        echo "terminus.donetick：$option 指向的文件不存在或为空：$file" >&2
        exit 1
      fi
      printf -v "$var" '%s' "$(< "$file")"
      export "''${var?}"
    }

    ${jwtSnippet}

    ${lib.concatMapStrings readSecret secretSpecs}

    exec ${lib.escapeShellArg "${cfg.package}/bin/donetick"} "$@"
  '';

  # 由模块生成、不允许用户通过 environment 覆盖的变量。
  reservedEnvironmentKeys = [
    "DT_ENV"
    "DT_SQLITE_PATH"
    "DT_SERVER_PORT"
    "DT_SINGLE_CIRCLE_INSTANCE"
    "DT_DISABLE_PASSWORD_AUTH"
    "DT_OAUTH2_ADMIN_GROUPS"
    "DT_OAUTH2_MANAGER_GROUPS"
    "DT_JWT_SECRET"
    "DT_DATABASE_PASSWORD"
    "DT_EMAIL_KEY"
    "DT_OAUTH2_CLIENT_SECRET"
    "DT_STORAGE_ACCESS_KEY"
    "DT_STORAGE_SECRET_KEY"
    "DONETICK_TELEGRAM_TOKEN"
    "DONETICK_PUSHOVER_TOKEN"
    "DT_WEBHOOK_SIGNING_SECRET"
  ];

  conflictingEnvironment = lib.filter (key: cfg.environment ? ${key}) reservedEnvironmentKeys;

  storageBaseOutsideDataDir =
    cfg.storage.type == "local"
    && lib.hasPrefix "/" cfg.storage.basePath
    && !(lib.hasPrefix "${dataDir}/" cfg.storage.basePath)
    && !(lib.elem cfg.storage.basePath cfg.readWritePaths);

  # 服务只需要「监听端口、读写 dataDir（及额外放行路径）、访问外部 HTTP(S)」。
  hardening = {
    NoNewPrivileges = true;
    PrivateDevices = true;
    PrivateTmp = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectHome = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectSystem = "strict";
    # AF_UNIX：journald、nss（DNS）；出站请求（SMTP / S3 / Telegram / webhook）
    # 走 AF_INET / AF_INET6。
    RestrictAddressFamilies = [
      "AF_INET"
      "AF_INET6"
      "AF_UNIX"
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
        assertion = cfg.general.name != "local";
        message = "terminus.donetick.general.name 不能是 \"local\"：该环境会跳过 JWT secret 强度校验（请用 selfhosted 等其它名字）";
      }
      {
        assertion = conflictingEnvironment == [ ];
        message =
          "terminus.donetick.environment 不能包含以下变量：${lib.concatStringsSep ", " conflictingEnvironment}"
          + "；它们由模块生成，密钥请用对应的 *File 选项或 environmentFile";
      }
      {
        assertion =
          !isPostgres || (cfg.database.host != "" && cfg.database.user != "" && cfg.database.name != "");
        message = "terminus.donetick.database：type = \"postgres\" 时必须设置 host / user / name";
      }
      {
        assertion = cfg.storage.maxFileSize > 0;
        message = "terminus.donetick.storage.maxFileSize 必须大于 0：源码以 file.Size > max_file_size 判断，0 会拒绝所有上传";
      }
      {
        assertion = cfg.storage.maxUserStorage > 0;
        message = "terminus.donetick.storage.maxUserStorage 必须大于 0：0 会让所有上传超出配额而被拒绝";
      }
      {
        assertion = cfg.storage.type != "remote" || cfg.storage.bucketName != "";
        message = "terminus.donetick.storage：type = \"remote\" 时必须设置 bucketName";
      }
    ];

    warnings =
      lib.optional (
        cfg.openFirewall && cfg.server.publicHost == null
      ) "terminus.donetick.openFirewall 已开启但未设置 server.publicHost：邮件与邀请链接会指向 localhost"
      ++ lib.optional (
        isPostgres && cfg.database.passwordFile == null
      ) "terminus.donetick.database：postgres 未设置 passwordFile，将以空密码连接"
      ++ lib.optional (
        cfg.disablePasswordAuth && cfg.oauth2.clientId == ""
      ) "terminus.donetick.disablePasswordAuth 已开启但 oauth2.clientId 为空：可能无法登录"
      ++ lib.optional (
        cfg.storage.type == "remote"
        && (cfg.storage.accessKeyFile == null || cfg.storage.secretKeyFile == null)
      ) "terminus.donetick.storage：remote 存储未同时设置 accessKeyFile / secretKeyFile，上传可能失败"
      ++ lib.optional storageBaseOutsideDataDir "terminus.donetick.storage.basePath 在 dataDir 之外且未加入 readWritePaths：写入会被 ProtectSystem 拦截";

    users.users.${cfg.user} = lib.mkIf (cfg.user == "donetick") {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      homeMode = "0750";
      createHome = true;
      description = "Donetick 任务/家务管理服务";
    };

    users.groups.${cfg.group} = lib.mkIf (cfg.group == "donetick") { };

    # 数据目录与配置符号链接由 root 在开机时创建：服务用户无法创建 /var/lib 下
    # 的目录，而配置固定从 <WorkingDirectory>/config/selfhosted.yaml 读取。
    systemd.tmpfiles.rules = [
      "d ${dataDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${dataDir}/config 0750 ${cfg.user} ${cfg.group} -"
      "L+ ${dataDir}/config/selfhosted.yaml - - - - ${configFile}"
    ];

    networking.firewall.allowedTCPPorts = lib.optional cfg.openFirewall cfg.server.port;

    systemd.services.donetick = {
      description = "Donetick 任务/家务管理服务";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      environment = serviceEnvironment;

      # 配置内容变化时 unit 文件（ExecStart/Environment）通常不变，systemd 不会
      # 自动重启，服务会继续用旧配置。restartTriggers 把生成的 YAML 纳入
      # X-Restart-Triggers，colmena/nixos-rebuild switch 时只要配置变了就重启。
      restartTriggers = [ configFile ];

      serviceConfig = hardening // {
        Type = "simple";
        ExecStart = startScript;
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = dataDir;
        EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
        Restart = "on-failure";
        RestartSec = 5;
        ReadWritePaths = [ dataDir ] ++ cfg.readWritePaths;
      };
    };
  };
}
