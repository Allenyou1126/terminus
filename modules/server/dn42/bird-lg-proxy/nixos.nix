# bird-lg-proxy 实现：systemd 单元、BIRD socket 环境变量和防火墙。
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.terminus.dn42.bird-lg-proxy;

  # BIRDLG_LISTEN 需要 host:port；IPv6 字面量必须加方括号，否则代理会把
  # 最后一个冒号后的部分当成端口。
  listenAddress =
    if lib.hasInfix ":" cfg.address && !(lib.hasPrefix "[" cfg.address) then
      "[${cfg.address}]:${toString cfg.port}"
    else
      "${cfg.address}:${toString cfg.port}";
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.terminus.dn42.bird2.enable;
        message = "terminus.dn42.bird-lg-proxy 需要 terminus.dn42.bird2.enable = true：它通过 /run/bird/bird.ctl 查询 BIRD";
      }
    ];

    systemd.services.bird-lg-proxy = {
      description = "bird-lg proxy for DN42";
      wantedBy = [ "multi-user.target" ];
      after = [ "bird.service" ];
      path = [
        pkgs.traceroute
        pkgs.whois
      ];
      environment = {
        BIRD_SOCKET = "/run/bird/bird.ctl";
        BIRDLG_LISTEN = listenAddress;
      };
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = 3;
        ExecStart = "${cfg.package}/bin/proxy";

        # mtr 和 traceroute 需要 raw socket / 改路由的能力。
        AmbientCapabilities = [
          "CAP_NET_ADMIN"
          "CAP_NET_RAW"
        ];
        CapabilityBoundingSet = [
          "CAP_NET_ADMIN"
          "CAP_NET_RAW"
        ];
        SystemCallFilter = [ ];

        User = "bird";
        Group = "bird";
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
