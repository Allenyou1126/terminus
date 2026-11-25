{
  config,
  lib,
  ...
}:
let
  cfg = config.terminus.birdExporter;

  firewallRules = lib.concatMapStrings (source: ''
    iptables -C INPUT -s ${source} -p tcp -m tcp --dport ${toString cfg.port} -j ACCEPT 2>/dev/null \
      || iptables -A INPUT -s ${source} -p tcp -m tcp --dport ${toString cfg.port} -j ACCEPT
  '') cfg.allowedSources;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.bird.enable;
        message = "terminus.birdExporter 需要 services.bird.enable = true：exporter 通过 BIRD socket 读取路由状态";
      }
    ];

    services.prometheus.exporters.bird = {
      enable = true;
      inherit (cfg) listenAddress port;
    };

    networking.firewall.extraCommands = lib.mkIf (cfg.allowedSources != [ ]) firewallRules;
  };
}
