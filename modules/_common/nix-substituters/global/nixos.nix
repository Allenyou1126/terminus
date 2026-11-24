{
  config,
  lib,
  terminus,
  ...
}:
let
  cfg = config.terminus.nix.substituters.presets.global;
in
{
  config = lib.mkIf cfg {
    terminus.nix.substituters.entries = with terminus.exports.substituterPresets; [
      allenyou-cache
      official
    ];
  };
}
