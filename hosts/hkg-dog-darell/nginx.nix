{ pkgs, ... }:

let
  nginxPackage = pkgs.nginxMainline;
in

{
  services.nginx = {
    enable = true;
    package = nginxPackage;
    recommendedBrotliSettings = true;
    recommendedGzipSettings = true;
    statusPage = true;
    clientMaxBodySize = "100M";
    virtualHosts = {
      defaultHttp = {
        listen = [
          {
            addr = "0.0.0.0";
            port = 80;
          }
        ];
        reuseport = true;
        extraConfig = ''
          return 444;
        '';
        default = true;
      };
      defaultHttps = {
        listen = [
          {
            addr = "0.0.0.0";
            port = 443;
          }
        ];
        reuseport = true;
        rejectSSL = true;
        default = true;
      };
    };
  };

  terminus.nginxExporter = {
    enable = true;
    listenAddress = "0.0.0.0";
    port = 9090;
    allowedSources = [ "106.14.99.198" ];
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
  networking.firewall.allowedUDPPorts = [
    80
    443
  ];
}
