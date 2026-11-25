{
  config,
  terminus,
  ...
}:

{
  age.secrets.gotify = terminus.secrets.secret {
    name = "services/gotify";
  };

  services.gotify = {
    enable = true;
    environment = {
      GOTIFY_SERVER_PORT = "5135";
      GOTIFY_DATABASE_DIALECT = "postgres";
    };
    environmentFiles = [
      config.age.secrets.gotify.path
    ];
  };
  services.nginx.virtualHosts.gotify = {
    forceSSL = true;
    serverName = "gotify.allenyou.wang";
    locations."/" = {
      proxyPass = "http://127.0.0.1:5135";
      proxyWebsockets = true;
      recommendedProxySettings = true;
    };
    sslCertificate = "/var/ssl/allenyou.wang.crt";
    sslCertificateKey = "/var/ssl/allenyou.wang.key";
  };
}
