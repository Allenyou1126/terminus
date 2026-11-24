{ lib, ... }:
{
  options.terminus.nix.substituters.presets.cn =
    lib.mkEnableOption "CN Nix binary cache substituter preset.";
}
