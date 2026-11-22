# profiles/<name>.nix loading, inheritance and validation.
{ lib }:
let
  inherit (builtins)
    attrNames
    concatMap
    elem
    isAttrs
    isList
    isString
    listToAttrs
    mapAttrs
    typeOf
    ;

  errors = import ./internal/errors.nix { inherit lib; };
  fs = import ./fs.nix { inherit lib; };

  normalize =
    file: value:
    let
      attrs =
        if isList value then
          { common = value; }
        else if isAttrs value then
          value
        else
          errors.invalidMeta file "profile must be a list or attribute set" (typeOf value);

      listField =
        name:
        let
          v = attrs.${name} or [ ];
        in
        if isList v && lib.all isString v then
          v
        else
          errors.invalidMeta file "profiles field '${name}' must be a list of strings" (typeOf v);
    in
    {
      extends = listField "extends";
      common = listField "common";
      nixos = listField "nixos";
      home = listField "home";
    };
in
{
  load =
    { dir }:
    let
      files = if builtins.pathExists dir then fs.nixFiles dir else [ ];

      defs = listToAttrs (
        map (e: {
          name = lib.removeSuffix ".nix" e.name;
          value = normalize e.path (import e.path);
        }) files
      );

      resolve =
        name: stack:
        if elem name stack then
          errors.profileCycle (stack ++ [ name ])
        else
          let
            profile = defs.${name} or (errors.unknownProfile name);
            parents = concatMap (parent: resolve parent (stack ++ [ name ])) profile.extends;
            collect = field: lib.unique (concatMap (p: p.${field}) parents ++ profile.${field});
            result = {
              common = collect "common";
              nixos = collect "nixos";
              home = collect "home";
            };
          in
          if result.common == [ ] && result.nixos == [ ] && result.home == [ ] then
            errors.invalidMeta (dir + "/${name}.nix") "profile must enable at least one module" "empty profile"
          else
            result;

      resolved = mapAttrs (name: _: resolve name [ ]) defs;
    in
    {
      inherit defs resolved;
      names = attrNames resolved;
    };
}
