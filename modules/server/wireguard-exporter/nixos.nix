{
  config,
  lib,
  ...
}:
let
  cfg = config.terminus.wireguardExporter;

  firewallRules = lib.concatMapStrings (source: ''
    iptables -C INPUT -s ${source} -p tcp -m tcp --dport ${toString cfg.port} -j ACCEPT 2>/dev/null \
      || iptables -A INPUT -s ${source} -p tcp -m tcp --dport ${toString cfg.port} -j ACCEPT
  '') cfg.allowedSources;
in
{
  config = lib.mkIf cfg.enable {
    services.prometheus.exporters.wireguard = {
      enable = true;
      inherit (cfg)
        listenAddress
        port
        withRemoteIp
        latestHandshakeDelay
        verbose
        ;
    };

    networking.firewall.extraCommands = lib.mkIf (cfg.allowedSources != [ ]) firewallRules;
  };
}
