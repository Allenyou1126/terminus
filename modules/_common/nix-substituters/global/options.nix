{ lib, ... }:
{
  options.terminus.nix.substituters.presets.global =
    lib.mkEnableOption "Global Nix binary cache substituter preset.";
}
