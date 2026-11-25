{ ... }:
{
  imports = [
    ./nginx.nix
    ./postgres.nix
    ./wireguard.nix
    ./exporters.nix

    ./apps/certimate.nix
    ./apps/waline.nix
    ./apps/waline-zlight106.nix
    ./apps/webdav.nix
    ./apps/bird-lg.nix
    ./apps/miniflux.nix
    ./apps/vaultwarden.nix
    ./apps/wakapi.nix
    ./apps/lotusland.nix
    ./apps/blog.nix
    ./apps/zlight106-blog.nix
    ./apps/umami.nix
    ./apps/openwebui.nix
    ./apps/gotify.nix
    ./apps/sub-store.nix
    ./apps/nokoribi.nix
    ./apps/openviking.nix
    ./apps/recado.nix
  ];

  boot.loader.grub.enable = true;

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
}
