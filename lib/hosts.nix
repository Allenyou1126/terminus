# Shared host module assembly. The same module list feeds both standard
# nixosConfigurations and the Colmena hive.
{
  inputs,
  self,
  lib,
}:
let
  inherit (builtins)
    filter
    hasAttr
    isAttrs
    isBool
    isFunction
    ;

  users = import ./users.nix { inherit lib; };
  exportsTools = import ./internal/exports.nix { inherit lib; };

  frameworkOptions =
    { lib, ... }:
    {
      options.terminus = {
        users = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Users associated with this host by users/*/meta.nix.";
        };

        homeManager = {
          backupFileExtension = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Forwarded to home-manager.backupFileExtension when embedding HM.";
          };

          embed = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Read-only view of the resolved HM embed policy.";
          };
        };
      };
    };

  resolvePolicy =
    global: hostValue: hostName:
    if hostValue != null then
      hostValue
    else if isBool global then
      global
    else if isFunction global then
      global hostName
    else if isAttrs global then
      if global ? hosts && builtins.hasAttr hostName global.hosts then
        global.hosts.${hostName}
      else if global ? default then
        global.default
      else
        true
    else
      true;

  hasHome =
    discovery: host: user:
    let
      homes =
        discovery.homesByUser.${user.name} or {
          default = null;
          hosts = { };
        };
    in
    homes.default != null || hasAttr host.name homes.hosts;
in
{
  mk =
    {
      discovery,
      secrets,
      modules,
      home,
      deploy,
      deployUser,
      embed,
      secretsIdentityPaths,
      useGlobalPkgs,
      extraNixosModules ? [ ],
      nixosSpecialArgs ? { },
      homeSpecialArgs ? { },
      extraHomeModules ? [ ],
    }:
    let
      moduleExports = exportsTools.collect {
        inherit discovery inputs self;
      };

      contexts = lib.mapAttrs (
        name: host:
        let
          selected = modules.forHost {
            inherit discovery;
            host = host // {
              meta = host.meta;
            };
          };

          associatedUsers = filter (user: builtins.elem name user.hosts) discovery.users;
          homeUsers = filter (hasHome discovery host) associatedUsers;

          hostEmbed = resolvePolicy embed host.meta.home.embed name;
          hostUseGlobalPkgs = resolvePolicy useGlobalPkgs host.meta.home.useGlobalPkgs name;

          host' = host // {
            home = {
              embed = hostEmbed;
              useGlobalPkgs = hostUseGlobalPkgs;
            };
          };

          identityPaths =
            if host.meta.secrets.identityPaths != null then
              host.meta.secrets.identityPaths
            else
              secretsIdentityPaths;

          specialArgs = {
            inherit inputs self;
            hostname = name;
            terminus = {
              version = {
                major = 0;
                minor = 1;
                patch = 0;
                string = "0.1.0";
              };
              host = host.meta;
              secrets = secrets;
              deployKeys = discovery.deployKeys;
              exports = moduleExports;
            };
          }
          // nixosSpecialArgs;

          homeSpecialArgs' = specialArgs // homeSpecialArgs;

          embeddedHome =
            if hostEmbed && homeUsers != [ ] then
              home.embeddedModule {
                inherit discovery;
                host = host';
                users = homeUsers;
                homeImportsFor = _user: selected.home.imports ++ selected.home.profileConfig ++ extraHomeModules;
                specialArgs = homeSpecialArgs';
              }
            else
              null;

          usersModule = users.mk {
            inherit discovery secrets;
            host = host';
          };

          deployUserModule =
            if
              deploy.isRemote host
              && (
                if host.meta.deployment.sshUser != null then
                  host.meta.deployment.sshUser == deployUser.name
                else
                  true
              )
            then
              deploy.userModule {
                inherit host deployUser;
                deployKeys = discovery.deployKeys;
              }
            else
              null;

          nixosImports = [
            frameworkOptions
          ]
          ++ [ inputs.agenix.nixosModules.default ]
          ++ [
            {
              age.identityPaths = lib.mkDefault identityPaths;
            }
          ]
          ++ [ usersModule.module ]
          ++ (map (user: user.defaultPath) (filter (user: user.defaultPath != null) associatedUsers))
          ++ lib.optional (deployUserModule != null) deployUserModule
          ++ lib.optional (embeddedHome != null) embeddedHome
          ++ selected.nixos.imports
          ++ selected.nixos.profileConfig
          ++ host'.modulePaths
          ++ extraNixosModules
          ++ [
            {
              networking.hostName = lib.mkDefault name;
            }
          ];
        in
        {
          name = name;
          system = host.system;
          meta = host.meta;
          inherit specialArgs;
          homeSpecialArgs = homeSpecialArgs';
          modules = nixosImports;
          homeImports = selected.home.imports ++ selected.home.profileConfig ++ extraHomeModules;
          homeUsers = homeUsers;
          embed = hostEmbed;
          useGlobalPkgs = hostUseGlobalPkgs;
          deployment = host.meta.deployment;
        }
      ) discovery.hostsByName;
    in
    {
      inherit contexts;

      globalHomeModules =
        { name, system }:
        let
          globalHost = home.globalHost { inherit name system; };
          selected = modules.forHost {
            inherit discovery;
            host = globalHost;
          };
        in
        selected.home.imports ++ selected.home.profileConfig ++ extraHomeModules;

      globalHomeSpecialArgs = {
        inherit inputs self;
        hostname = null;
        terminus = {
          version = {
            major = 0;
            minor = 1;
            patch = 0;
            string = "0.1.0";
          };
          host = null;
          secrets = secrets;
          deployKeys = discovery.deployKeys;
          exports = moduleExports;
        };
      }
      // homeSpecialArgs;
    };
}
