# Role filtering, profiles, host overrides and module dependency ordering.
{ lib }:
let
  inherit (builtins)
    attrNames
    baseNameOf
    concatMap
    elem
    filter
    head
    listToAttrs
    mapAttrs
    ;

  errors = import ./internal/errors.nix { inherit lib; };
  depgraph = import ./depgraph.nix { inherit lib; };

  fileKind = path: lib.removeSuffix ".nix" (baseNameOf path);

  # Roles only decide which side files are imported. They never set options:
  # a role-selected module with `mkIf option` stays disabled until the option
  # is set. Module-level meta.*.enable and host meta.modules are separate
  # import-selection mechanisms.
  roleAllowed =
    host: module:
    let
      roles = host.meta.roles;
      first = head (lib.splitString "." module.name);
    in
    if roles == null then true else lib.hasPrefix "_" first || elem first roles;

  # Files that would be injected by role filtering alone.
  roleFiles =
    host: side: module:
    filter (
      path:
      let
        kind = fileKind path;
      in
      if kind == "options" || kind == "default" then true else roleAllowed host module
    ) module.side.${side};

  sideEnabled = side: module: module.meta.${side}.enable;

  profileMembers =
    host: side:
    concatMap (
      name:
      let
        profile = host.profilesResolved.${name} or (errors.unknownProfile name);
      in
      profile.common ++ profile.${side}
    ) host.meta.profiles;

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

  selectSide =
    host: side:
    let
      modules = lib.filterAttrs (
        _name: module: module.side.${side} != [ ] && sideEnabled side module
      ) host.modulesByName;

      base = filter (name: roleFiles host side modules.${name} != [ ]) (attrNames modules);

      members = profileMembers host side;

      _validateMembers = map (
        name: if modules ? ${name} then null else errors.unknownModule "profile module" name
      ) members;

      candidates = lib.unique (base ++ members ++ attrNames host.meta.modules);

      explicitlyEnabled = lib.unique (
        members ++ filter (name: (host.meta.modules.${name} or null) == true) (attrNames host.meta.modules)
      );

      selected = filter (
        name:
        let
          override = host.meta.modules.${name} or null;
        in
        if override == false then
          false
        else if override == true then
          modules ? ${name}
        else
          elem name (base ++ members)
      ) candidates;

      graph = mapAttrs (_name: module: moduleMeta side module) modules;

      order = depgraph.sort {
        inherit graph;
        enabled = selected;
      };

      imports = concatMap (
        name:
        if elem name explicitlyEnabled then
          modules.${name}.side.${side}
        else
          roleFiles host side modules.${name}
      ) order;
    in
    lib.deepSeq _validateMembers {
      inherit
        imports
        order
        ;
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
