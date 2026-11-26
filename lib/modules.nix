# Profile-based module selection, dependency ordering and registry generation.
{ lib }:
let
  inherit (builtins)
    concatMap
    filter
    hasAttr
    mapAttrs
    ;

  errors = import ./internal/errors.nix { inherit lib; };
  depgraph = import ./depgraph.nix { inherit lib; };

  # `profiles/default/` is special: when it exists it is applied to every
  # host without being listed in host meta.
  defaultProfile = "default";

  moduleMeta =
    side: module:
    let
      shared = module.meta.shared;
      own = module.meta.${side};
    in
    {
      requires = shared.requires ++ own.requires;
      after = shared.after ++ own.after;
      before = shared.before ++ own.before;
      wants = shared.wants ++ own.wants;
      conflicts = shared.conflicts ++ own.conflicts;
    };

  # Profiles applied to a host: the implicit default profile (when present)
  # plus the host's declared profiles, in declaration order.
  selectedProfiles =
    host:
    let
      names = lib.unique (
        lib.optional (hasAttr defaultProfile host.profilesResolved) defaultProfile ++ host.meta.profiles
      );
    in
    map (name: host.profilesResolved.${name} or (errors.unknownProfile name)) names;

  # Modules imported by the selected profiles plus host-level requires.
  requestedModules =
    host:
    lib.unique (concatMap (profile: profile.requires) (selectedProfiles host) ++ host.meta.requires);

  selectSide =
    host: side:
    let
      modules = lib.filterAttrs (
        _name: module: module.side.${side} != [ ] && module.meta.${side}.enable
      ) host.modulesByName;

      members = requestedModules host;

      selected = filter (name: hasAttr name modules) members;

      graph = mapAttrs (_name: module: moduleMeta side module) modules;

      order = depgraph.sort {
        inherit graph;
        enabled = selected;
      };

      imports = concatMap (name: modules.${name}.side.${side}) order;

      profileConfig = lib.unique (concatMap (profile: profile.${side}) (selectedProfiles host));
    in
    {
      inherit imports order profileConfig;
      names = order;
    };
in
{
  registry =
    {
      discovery,
    }:
    {
      nixosModules = lib.mapAttrs (_name: module: { imports = module.side.nixos; }) (
        lib.filterAttrs (_name: module: module.side.nixos != [ ]) discovery.modulesByName
      );

      homeModules = lib.mapAttrs (_name: module: { imports = module.side.home; }) (
        lib.filterAttrs (_name: module: module.side.home != [ ]) discovery.modulesByName
      );
    };

  forHost =
    {
      discovery,
      host,
    }:
    let
      host' = host // {
        modulesByName = discovery.modulesByName;
        profilesResolved = discovery.profiles.resolved;
      };
    in
    {
      nixos = selectSide host' "nixos";
      home = selectSide host' "home";
    };
}
