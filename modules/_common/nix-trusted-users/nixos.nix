{ lib, ... }:
{
  # NixOS defaults this list to [ "root" ]; replace it so the effective value
  # is root + the wheel group instead of a duplicated root entry. The deploy
  # user is trusted so Colmena can push unsigned closures over ssh-ng.
  nix.settings.trusted-users = lib.mkForce [
    "root"
    "@wheel"
    "deploy"
  ];
}
