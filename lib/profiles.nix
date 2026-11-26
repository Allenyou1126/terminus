# profiles/<name>/ discovery, inheritance and validation.
{ lib }:
let
  inherit (builtins)
    attrNames
    concatMap
    elem
    filter
    head
    listToAttrs
    mapAttrs
    pathExists
    ;

  errors = import ./internal/errors.nix { inherit lib; };
  fs = import ./fs.nix { inherit lib; };
  metadata = import ./metadata.nix { inherit lib; };

  legacyFiles = dir: filter (e: e.type == "regular" && lib.hasSuffix ".nix" e.name) (fs.listDir dir);

  parse =
    entry:
    let
      metaPath = entry.path + "/meta.nix";
      rawMeta = if pathExists metaPath then metadata.readMeta metaPath else errors.missingFile metaPath;
      meta = metadata.normalizeProfileMeta metaPath rawMeta;
    in
    {
      name = entry.name;
      dir = entry.path;
      inherit metaPath meta;
      requires = meta.requires;
      extends = meta.extends;
      nixosPath = fs.optionalPath (entry.path + "/nixos.nix");
      homePath = fs.optionalPath (entry.path + "/home.nix");
    };
in
{
  load =
    { dir }:
    let
      legacy = if pathExists dir then legacyFiles dir else [ ];
      _checkLegacy =
        if legacy == [ ] then
          null
        else
          errors.legacyProfileFile (lib.removeSuffix ".nix" (head legacy).name);

      entries = if pathExists dir then filter (e: e.type == "directory") (fs.listDir dir) else [ ];

      defs = listToAttrs (
        map (entry: {
          name = entry.name;
          value = parse entry;
        }) entries
      );

      resolve =
        name: stack:
        if elem name stack then
          errors.profileCycle (stack ++ [ name ])
        else
          let
            profile = defs.${name} or (errors.unknownProfile name);
            parents = concatMap (parent: resolve parent (stack ++ [ name ])) profile.extends;
            requires = lib.unique (concatMap (p: p.requires) parents ++ profile.requires);
            nixos = lib.unique (
              concatMap (p: p.nixos) parents ++ lib.optional (profile.nixosPath != null) profile.nixosPath
            );
            home = lib.unique (
              concatMap (p: p.home) parents ++ lib.optional (profile.homePath != null) profile.homePath
            );
          in
          if requires == [ ] && nixos == [ ] && home == [ ] then
            errors.invalidMeta profile.metaPath "profile must require a module or provide nixos.nix / home.nix"
              "empty profile"
          else
            {
              inherit
                requires
                nixos
                home
                ;
            };

      resolved = mapAttrs (name: _: resolve name [ ]) defs;
    in
    lib.deepSeq _checkLegacy {
      inherit defs resolved;
      names = attrNames resolved;
    };
}
