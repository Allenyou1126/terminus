{ terminus, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "25.05";

  terminus.nodeExporter = {
    enable = true;
    allowedSources = [ "172.24.24.198" ];
  };

  terminus.nix.substituters.entries = [
    terminus.exports.substituterPresets.ustc
    terminus.exports.substituterPresets.r2
    terminus.exports.substituterPresets.official
  ];
}
