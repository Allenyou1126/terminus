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

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/release-26.05";
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

      # TODO(2026-11-19): openviking 的 [auth] extra 依赖 python-jose 3.5.0，
      # nixpkgs 将其标记为 insecure（CVE-2026-120459：空 HMAC key 可伪造
      # JWT；3.5.0 是上游最新版，暂无修复版本）。等上游发版或 nixpkgs 撤销
      # 标记后删除这个例外。
      nixpkgs.config.permittedInsecurePackages = [ "python3.13-python-jose-3.5.0" ];

      secretsDir = ./secrets;

      colmena = {
        enable = true;
        allowApplyAll = false;
      };
    };
}
