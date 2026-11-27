{
  config,
  terminus,
  ...
}:

let
  publicHost = "https://todo.allenyou.wang";
in
{
  age.secrets.donetick-database-password = terminus.secrets.secret {
    name = "services/donetick/database-password";
    owner = "donetick";
    group = "donetick";
  };
  age.secrets.donetick-smtp-password = terminus.secrets.secret {
    name = "services/donetick/smtp-password";
    owner = "donetick";
    group = "donetick";
  };
  age.secrets.donetick-oauth-secret = terminus.secrets.secret {
    name = "services/donetick/oauth-secret";
    owner = "donetick";
    group = "donetick";
  };
  age.secrets.donetick-s3-access-key = terminus.secrets.secret {
    name = "services/donetick/s3-access-key";
    owner = "donetick";
    group = "donetick";
  };
  age.secrets.donetick-s3-secret = terminus.secrets.secret {
    name = "services/donetick/s3-secret";
    owner = "donetick";
    group = "donetick";
  };

  terminus.donetick = {
    enable = true;
    disablePasswordAuth = true;

    general.name = "Allenyou TODO";

    # MCP Server：AI 客户端通过 /mcp（Bearer API token）管理任务
    mcp.enabled = true;

    database = {
      type = "postgres";
      host = "127.0.0.1";
      user = "donetick";
      name = "donetick";
      passwordFile = config.age.secrets.donetick-database-password.path;
    };

    server.port = 58390;
    server.corsAllowOrigins = [
      publicHost
    ];
    server.publicHost = publicHost;

    email = {
      address = "todo@allenyou.wang";
      keyFile = config.age.secrets.donetick-smtp-password.path;
      host = "smtp.fastmail.com";
      port = 465;
      user = "i@allenyou.wang";
      appHost = publicHost;
    };

    # ZITADEL 应用必须是 Native 类型：code grant 下自定义 scheme 只对 native 允许
    # （否则报 CustomOnlyForNative），且应用类型创建后不能修改。Redirect URIs
    # 需要同时登记：
    #   ${publicHost}/auth/oauth2   （Web 前端回调）
    #   donetick://auth/oauth2      （Android / iOS App）
    # 换成 Native 应用后，用它的 Client ID 替换 clientId，并重新加密
    # services/donetick/oauth-secret.age；Auth Method 选 Basic 或 Post
    # （Donetick 要求 ClientSecret 非空；ZITADEL 的 PKCE/None 认证方式不签发
    # secret，会让 OIDC 被禁用——下面的 pkce 开关只控制是否下发 PKCE 参数）。
    oauth2 = {
      clientId = "401457800212977862";
      clientSecretFile = config.age.secrets.donetick-oauth-secret.path;
      pkce = true;
      redirectUrl = "${publicHost}/auth/oauth2";
      scopes = [
        "sub"
        "preferred_username"
        "name"
        "email"
        "picture"
        "groups"
      ];
      authUrl = "https://auth.allenyou.top/oauth/v2/authorize";
      tokenUrl = "https://auth.allenyou.top/oauth/v2/token";
      userInfoUrl = "https://auth.allenyou.top/oidc/v1/userinfo";
      name = "Allenyou Auth";
      adminGroups = [ "todo.admin" ];
      managerGroups = [ "todo.manager" ];
    };

    storage = {
      type = "remote";
      basePath = "todo";
      bucketName = "blog-hk";
      accessKeyFile = config.age.secrets.donetick-s3-access-key.path;
      secretKeyFile = config.age.secrets.donetick-s3-secret.path;
      region = "oss-cn-hongkong";
      endpoint = "oss-cn-hongkong.aliyuncs.com";
      publicHost = "https://blog-oss.allenyou.top";
      publicRead = true;
    };
  };
  services.nginx.virtualHosts.donetick = {
    forceSSL = true;
    serverName = "todo.allenyou.wang";
    locations."/" = {
      proxyPass = "http://127.0.0.1:58390";
      proxyWebsockets = true;
      recommendedProxySettings = true;
      # CORS 由 Donetick 自己处理（server.cors_allow_origins，已并入 App 的
      # https://localhost / capacitor://localhost）。不要在这里 add_header
      # CORS 头：会与上游响应重复 Access-Control-Allow-Origin，浏览器会拒绝。
    };
    sslCertificate = "/var/ssl/allenyou.wang.crt";
    sslCertificateKey = "/var/ssl/allenyou.wang.key";
  };
}
