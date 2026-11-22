# Colmena bridge: standard nixosConfigurations stay the source of truth for
# local nixos-rebuild, while colmenaHive evaluates the same shared modules with
# a shim that makes both toplevel derivations identical.
{
  inputs,
  lib,
  nixpkgs,
}:
let
  inherit (builtins) head mapAttrs unsafeDiscardStringContext;
in
{
  shim = {
    system.nixos.revision = nixpkgs.rev or nixpkgs.dirtyRev or null;
    system.nixos.versionSuffix =
      if nixpkgs ? lastModifiedDate && nixpkgs ? shortRev then
        ".${builtins.substring 0 8 nixpkgs.lastModifiedDate}.${nixpkgs.shortRev}"
      else
        "";
    nixpkgs.flake.source = nixpkgs.outPath;
  };

  mk =
    {
      hostContexts,
      pkgsBySystem,
      systems,
      deploy,
      deployUser,
      allowApplyAll,
      nixosConfigurations,
    }:
    let
      defaultSystem = head systems;

      colmenaShim = {
        system.nixos.revision = nixpkgs.rev or nixpkgs.dirtyRev or null;
        system.nixos.versionSuffix =
          if nixpkgs ? lastModifiedDate && nixpkgs ? shortRev then
            ".${builtins.substring 0 8 nixpkgs.lastModifiedDate}.${nixpkgs.shortRev}"
          else
            "";
        nixpkgs.flake.source = nixpkgs.outPath;
      };

      hive = inputs.colmena.lib.makeHive (
        {
          meta = {
            name = "terminus";
            nixpkgs = pkgsBySystem.${defaultSystem};
            nodeNixpkgs = mapAttrs (_name: ctx: pkgsBySystem.${ctx.system}) hostContexts;
            nodeSpecialArgs = mapAttrs (_name: ctx: ctx.specialArgs) hostContexts;
            allowApplyAll = allowApplyAll;
          };
          defaults = { };
        }
        // mapAttrs (_name: ctx: {
          imports = ctx.modules ++ [
            (deploy.colmenaModule {
              host = {
                inherit (ctx) meta;
              };
              inherit deployUser;
            })
            colmenaShim
          ];
        }) hostContexts
      );

      consistencyChecks = lib.filterAttrs (_system: value: value != null) (
        lib.genAttrs systems (
          system:
          let
            hosts = lib.filterAttrs (_name: ctx: ctx.system == system) hostContexts;
            pkgs = pkgsBySystem.${system};
            checks = lib.mapAttrsToList (
              name: _ctx:
              let
                standard =
                  unsafeDiscardStringContext
                    nixosConfigurations.${name}.config.system.build.toplevel.outPath;
                colmena = unsafeDiscardStringContext hive.nodes.${name}.config.system.build.toplevel.outPath;
              in
              ''
                standard=${standard}
                colmena=${colmena}
                if [ "$standard" != "$colmena" ]; then
                  echo "terminus: Colmena toplevel mismatch for host '${name}'" >&2
                  echo "  nixosConfigurations: $standard" >&2
                  echo "  colmenaHive:         $colmena" >&2
                  exit 1
                fi
              ''
            ) hosts;
          in
          if hosts == { } then
            null
          else
            pkgs.runCommand "terminus-colmena-consistency-${system}" { } ''
              ${lib.concatStringsSep "\n" checks}
              touch $out
            ''
        )
      );
    in
    {
      inherit hive consistencyChecks;
    };
}
