{
  config,
  lib,
  ...
}:
let
  cfg = config.terminus.nix.substituters;
  entries = cfg.entries;

  render =
    entry:
    if entry.priority == null then
      entry.url
    else
      "${entry.url}${if lib.hasInfix "?" entry.url then "&" else "?"}priority=${toString entry.priority}";

  substituters = lib.unique (map render entries);
  trustedPublicKeys = lib.unique (lib.concatMap (entry: entry.trustedPublicKeys) entries);
in
{
  config = lib.mkIf (entries != [ ]) {
    nix.settings.substituters = substituters;
    nix.settings.trusted-public-keys = trustedPublicKeys;
  };
}
