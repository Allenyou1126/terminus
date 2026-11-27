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
    user = "donetick";
    group = "donetick";
  };
  age.secrets.donetick-smtp-password = terminus.secrets.secret {
    name = "services/donetick/smtp-password";
    user = "donetick";
    group = "donetick";
  };
  age.secrets.donetick-oauth2-secret = terminus.secrets.secret {
    name = "services/donetick/oauth2-secret";
    user = "donetick";
    group = "donetick";
  };
  age.secrets.donetick-s3-access-key = terminus.secrets.secret {
    name = "services/donetick/s3-access-key";
    user = "donetick";
    group = "donetick";
  };
  age.secrets.donetick-s3-secret = terminus.secrets.secret {
    name = "services/donetick/s3-secret";
    user = "donetick";
    group = "donetick";
  };

  terminus.donetick = {
    enable = true;
    disablePasswordAuth = true;

    general.name = "Allenyou TODO";

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
      clientSecretFile = config.age.secrets.donetick-oauth2-secret.path;
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
    };
    sslCertificate = "/var/ssl/allenyou.wang.crt";
    sslCertificateKey = "/var/ssl/allenyou.wang.key";
  };
}
