{
  config,
  lib,
  terminus,
  ...
}:
let
  cfg = config.terminus.nix.substituters.presets.cn;
in
{
  config = lib.mkIf cfg {
    terminus.nix.substituters.entries = with terminus.exports.substituterPresets; [
      ustc-mirror
      allenyou-cache
      official-cloudflare-mirror
    ];
  };
}
