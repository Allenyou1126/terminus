{
  config,
  lib,
  ...
}:
let
  cfg = config.terminus.nginxExporter;

  firewallRules = lib.concatMapStrings (source: ''
    iptables -C INPUT -s ${source} -p tcp -m tcp --dport ${toString cfg.port} -j ACCEPT 2>/dev/null \
      || iptables -A INPUT -s ${source} -p tcp -m tcp --dport ${toString cfg.port} -j ACCEPT
  '') cfg.allowedSources;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.nginx.enable;
        message = "terminus.nginxExporter 需要 services.nginx.enable = true：exporter 通过 nginx stub_status 读取指标";
      }
    ];

    services.prometheus.exporters.nginx = {
      enable = true;
      inherit (cfg) listenAddress port;
    };

    networking.firewall.extraCommands = lib.mkIf (cfg.allowedSources != [ ]) firewallRules;
  };
}
