{
  description = "Terminus — Snowveil-inspired NixOS configuration framework";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix/0.18.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    colmena = {
      url = "github:nix-community/colmena/v0.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    (import ./lib { lib = nixpkgs.lib; }).mkFlake {
      inherit inputs self;

      root = ./.;
      systems = [ "x86_64-linux" ];

      nixpkgs.config.allowUnfree = true;

      secretsDir = ./secrets;

      colmena = {
        enable = true;
        allowApplyAll = false;
      };
    };
}
