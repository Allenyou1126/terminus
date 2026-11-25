{ inputs, ... }:

{
  imports = [
    inputs.nixos-wsl.nixosModules.wsl
  ];

  wsl.enable = true;
  security.sudo.wheelNeedsPassword = true;
}
