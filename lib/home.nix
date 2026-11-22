# Home Manager assembly: embedded users and standalone homeConfigurations.
{ inputs, lib }:
let
  inherit (builtins) filter listToAttrs;

  defaults =
    user:
    { lib, ... }:
    {
      home.username = lib.mkDefault user.name;
      home.homeDirectory = lib.mkDefault (
        if user.meta.home != null then user.meta.home else "/home/${user.name}"
      );
    };

  fileModules =
    {
      discovery,
      user,
      host ? null,
    }:
    let
      homes =
        discovery.homesByUser.${user.name} or {
          default = null;
          hosts = { };
        };
      hostFile =
        if host != null && builtins.hasAttr host.name homes.hosts then homes.hosts.${host.name} else null;
    in
    lib.optional (homes.default != null) homes.default ++ lib.optional (hostFile != null) hostFile;
in
{
  inherit defaults fileModules;

  embeddedModule =
    {
      discovery,
      host,
      users,
      homeImportsFor,
      specialArgs,
    }:
    { lib, ... }:
    {
      imports = [ inputs.home-manager.nixosModules.home-manager ];

      home-manager.useGlobalPkgs = lib.mkDefault host.home.useGlobalPkgs;
      home-manager.useUserPackages = lib.mkDefault true;
      home-manager.extraSpecialArgs = specialArgs;

      home-manager.users = listToAttrs (
        map (user: {
          name = user.name;
          value = {
            imports = [
              (defaults user)
            ]
            ++ homeImportsFor user
            ++ fileModules {
              inherit discovery user host;
            };
          };
        }) users
      );
    };

  standalone =
    {
      discovery,
      pkgs,
      user,
      host ? null,
      modules,
      specialArgs,
    }:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = specialArgs;
      modules = [
        (defaults user)
      ]
      ++ modules
      ++ fileModules {
        inherit discovery user host;
      };
    };

  # A synthetic host used for the global `homeConfigurations.<user>` output:
  # roles are not host-specific there, so every home module is eligible.
  globalHost =
    {
      name,
      system,
    }:
    {
      inherit name system;
      meta = {
        roles = null;
        profiles = [ ];
        modules = { };
      };
    };
}
