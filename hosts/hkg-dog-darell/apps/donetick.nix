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

    oauth2 = {
      clientId = "401446959094765766";
      clientSecretFile = config.age.secrets.donetick-oauth-secret.path;
      redirectUrl = "${publicHost}/api/v1/oauth2/callback";
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
      extraConfig = ''
        add_header 'Access-Control-Allow-Origin' $http_origin;
        add_header 'Access-Control-Allow-Credentials' 'true';
        add_header 'Access-Control-Allow-Methods' 'GET, PUT, DELETE, POST, OPTIONS';
        add_header 'Access-Control-Allow-Headers' $http_access_control_request_headers;
        add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range';
        if ($request_method = 'OPTIONS') {
          add_header 'Access-Control-Allow-Origin' $http_origin;
          add_header 'Access-Control-Allow-Methods' 'GET, PUT, DELETE, POST, OPTIONS';
          add_header 'Access-Control-Allow-Headers' $http_access_control_request_headers;
          add_header 'Access-Control-Allow-Credentials' 'true';
          add_header 'Access-Control-Max-Age' 1728000;
          return 204;
        }
      '';
    };
    sslCertificate = "/var/ssl/allenyou.wang.crt";
    sslCertificateKey = "/var/ssl/allenyou.wang.key";
  };
}
