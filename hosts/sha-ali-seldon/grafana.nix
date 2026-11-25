{
  config,
  terminus,
  ...
}:
{
  age.secrets.grafana-db-password = terminus.secrets.secret {
    name = "grafana-db-password.sha-ali-gaal";
    owner = "grafana";
    group = "grafana";
    mode = "0400";
  };
  age.secrets.grafana-secret-key = terminus.secrets.secret {
    name = "grafana-secret-key.sha-ali-gaal";
    owner = "grafana";
    group = "grafana";
    mode = "0400";
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_port = 39998;
        http_addr = "127.0.0.1";
        root_url = "https://grafana.allenyou.top";
      };
      database = {
        type = "postgres";
        host = "127.0.0.1:5432";
        user = "grafana";
        name = "grafana";
        password = "$__file{${config.age.secrets.grafana-db-password.path}}";
      };
      security = {
        secret_key = "$__file{${config.age.secrets.grafana-secret-key.path}}";
      };
    };
  };

  services.nginx.virtualHosts.grafana = {
    forceSSL = true;
    serverName = "grafana.allenyou.top";
    locations."/" = {
      proxyPass = "http://127.0.0.1:39998";
      proxyWebsockets = true;
      recommendedProxySettings = true;
    };
    sslCertificate = "/var/ssl/allenyou.top.crt";
    sslCertificateKey = "/var/ssl/allenyou.top.key";
  };
}
