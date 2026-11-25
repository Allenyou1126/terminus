{
  config,
  terminus,
  ...
}:
{
  age.secrets.zitadel-master-key = terminus.secrets.secret {
    name = "zitadel-master-key.sha-ali-gaal";
    owner = "zitadel";
    mode = "0400";
  };

  age.secrets.zitadel-secret-settings = terminus.secrets.secret {
    name = "zitadel-secret-config.sha-ali-gaal";
    owner = "zitadel";
    mode = "0400";
  };

  services.zitadel = {
    enable = true;
    masterKeyFile = config.age.secrets.zitadel-master-key.path;
    extraSettingsPaths = [ config.age.secrets.zitadel-secret-settings.path ];
    tlsMode = "external";
    openFirewall = false;
    settings = {
      Port = 39999;
      Database.postgres = {
        Database = "zitadel";
        Host = "127.0.0.1";
        Port = 5432;
        User.SSL.Mode = "disable";
        Admin.SSL.Mode = "disable";
      };
      ExternalDomain = "auth.allenyou.top";
      ExternalPort = 443;
      ExternalSecure = true;
      TLS.Enabled = false;
    };
  };

  services.nginx.virtualHosts.zitadel = {
    forceSSL = true;
    serverName = "auth.allenyou.top";
    locations."/" = {
      proxyPass = "http://127.0.0.1:39999";
      proxyWebsockets = true;
      recommendedProxySettings = true;
    };
    sslCertificate = "/var/ssl/allenyou.top.crt";
    sslCertificateKey = "/var/ssl/allenyou.top.key";
  };
}
