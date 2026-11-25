{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.terminus.blackboxExporter;

  configFile = (pkgs.formats.yaml { }).generate "blackbox-exporter.yml" {
    modules = {
      http_2xx = {
        prober = "http";
        timeout = "10s";
        http = {
          valid_http_versions = [
            "HTTP/1.1"
            "HTTP/2.0"
          ];
          method = "GET";
          follow_redirects = true;
          fail_if_ssl = false;
          fail_if_not_ssl = false;
          preferred_ip_protocol = "ip4";
          ip_protocol_fallback = false;
        };
      };
      tcp = {
        prober = "tcp";
        timeout = "5s";
        tcp = {
          preferred_ip_protocol = "ip4";
        };
      };
      icmp = {
        prober = "icmp";
        timeout = "5s";
        icmp = {
          preferred_ip_protocol = "ip4";
        };
      };
    };
  };
in
{
  config = lib.mkIf cfg.enable {
    services.prometheus.exporters.blackbox = {
      enable = true;
      inherit (cfg) listenAddress port;
      inherit configFile;
    };
  };
}
