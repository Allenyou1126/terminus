{ lib, ... }:
{
  # NixOS defaults this list to [ "root" ]; replace it so the effective value
  # is exactly root + the wheel group instead of a duplicated root entry.
  nix.settings.trusted-users = lib.mkForce [
    "root"
    "@wheel"
  ];
}
