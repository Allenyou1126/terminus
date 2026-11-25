{ ... }:
{
  imports = [
    ./dn42/bird.nix
    ./dn42/bird-lg-proxy.nix
    ./dn42/dns.nix
    ./dn42/wireguard.nix
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";

  system.stateVersion = "25.11";

  networking.nameservers = [
    "172.23.0.53"
    "8.8.8.8"
  ];

  services.resolved = {
    enable = true;
    settings.Resolve.FallbackDNS = [
      "1.1.1.1"
    ];
  };

  # profiles 只选择模块文件；global preset 的 enable option 仍需显式打开。
  terminus.nix.substituters.presets.global = true;

  terminus.nodeExporter = {
    enable = true;
    allowedSources = [ "106.14.99.198" ];
  };
}
