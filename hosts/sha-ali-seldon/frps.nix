{
  config,
  terminus,
  ...
}:
{
  age.secrets.frp-token = terminus.secrets.secret {
    name = "services/frp-token";
  };

  terminus.frp.server = {
    enable = true;

    bindPort = 20000;
    quicBindPort = 20000;

    allowedPortRanges = [
      {
        start = 20001;
        end = 20099;
      }
    ];

    openFirewall = true;
    environmentFiles = [ config.age.secrets.frp-token.path ];

    settings = {
      transport = {
        maxPoolCount = 2000;
        tcpMux = true;
        tcpMuxKeepaliveInterval = 60;
        tcpKeepalive = 7200;
        tls.force = false;
      };

      log = {
        level = "info";
        disablePrintColor = false;
      };

      webServer = {
        addr = "127.0.0.1";
        port = 9500;
      };

      enablePrometheus = true;
      maxPortsPerClient = 8;
      udpPacketSize = 1500;
      natholeAnalysisDataReserveHours = 168;
    };
  };
}
