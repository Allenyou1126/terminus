{ ... }:
{
  imports = [
    ./hardware.nix
    ./wireguard.nix
    ./frps.nix
    ./nginx.nix
    ./postgres.nix
    ./zitadel.nix
    ./prometheus.nix
    ./grafana.nix
    ./deepseek-harness.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/efi";

  system.stateVersion = "25.11";

  terminus.nodeExporter = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9100;
  };
}
