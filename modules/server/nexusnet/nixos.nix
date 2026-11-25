{
  config,
  lib,
  ...
}:
let
  cfg = config.terminus.nexusnet;

  postUp = lib.optionalString cfg.nat.enable ''
    iptables -t nat -A POSTROUTING -s ${cfg.nat.source} -o ${cfg.nat.externalInterface} -j MASQUERADE
    iptables -A FORWARD -i ${cfg.interface} -j ACCEPT
    iptables -A FORWARD -o ${cfg.interface} -j ACCEPT
  '';

  postDown = lib.optionalString cfg.nat.enable ''
    iptables -t nat -D POSTROUTING -s ${cfg.nat.source} -o ${cfg.nat.externalInterface} -j MASQUERADE
    iptables -D FORWARD -i ${cfg.interface} -j ACCEPT
    iptables -D FORWARD -o ${cfg.interface} -j ACCEPT
  '';

  peers = lib.mapAttrsToList (_name: peer: {
    inherit (peer) publicKey allowedIPs;
    presharedKeyFile = if peer.preSharedKeyFile == null then null else toString peer.preSharedKeyFile;
    inherit (peer) endpoint persistentKeepalive;
  }) cfg.peers;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.stringLength cfg.interface <= 15;
        message = "terminus.nexusnet.interface 必须不超过 15 个字符（Linux 接口名限制）";
      }
      {
        assertion = cfg.addresses != [ ];
        message = "terminus.nexusnet.addresses 至少需要一个地址";
      }
      {
        assertion = !cfg.nat.enable || (cfg.nat.source != null && cfg.nat.source != "");
        message = "terminus.nexusnet.nat.enable = true 时必须设置 terminus.nexusnet.nat.source";
      }
    ];

    networking.wg-quick.interfaces.${cfg.interface} = {
      autostart = true;
      address = cfg.addresses;
      inherit (cfg) listenPort mtu;
      privateKeyFile = toString cfg.privateKeyFile;
      inherit postUp postDown;
      inherit peers;
    };

    networking.firewall.allowedUDPPorts = [ cfg.listenPort ];

    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.default.forwarding" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
      "net.ipv4.conf.default.rp_filter" = 0;
      "net.ipv4.conf.all.rp_filter" = 0;
      "net.ipv6.conf.default.rp_filter" = 0;
      "net.ipv6.conf.all.rp_filter" = 0;
    };
  };
}
