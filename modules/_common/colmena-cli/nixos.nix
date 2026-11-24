{ inputs, pkgs, ... }:
{
  environment.systemPackages = [
    inputs.colmena.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
