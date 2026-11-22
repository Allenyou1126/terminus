# Per-system packages/apps/shells/checks/formatter/overlays and user lib.
{
  inputs,
  self,
  lib,
}:
let
  inherit (builtins)
    attrNames
    elem
    filter
    functionArgs
    hasAttr
    intersectAttrs
    isFunction
    length
    listToAttrs
    mapAttrs
    ;

  terminus = {
    version = {
      major = 0;
      minor = 1;
      patch = 0;
      string = "0.1.0";
    };
    inherit inputs self;
  };

  frameworkArgs = {
    inherit inputs self terminus;
  };

  call =
    pkgs: path:
    let
      fn = import path;
    in
    if isFunction fn then
      pkgs.callPackage path (intersectAttrs (functionArgs fn) frameworkArgs)
    else
      fn;

  callLib =
    path:
    let
      fn = import path;
    in
    if isFunction fn then
      fn (
        intersectAttrs (functionArgs fn) {
          inherit
            lib
            inputs
            self
            terminus
            ;
        }
      )
    else
      fn;

  enabled =
    system: definition:
    let
      meta = definition.meta;
      definitionSystem = definition.system or null;
      supported =
        if definitionSystem != null then
          definitionSystem == system
        else if meta.systems != null then
          elem system meta.systems
        else
          true;
    in
    meta.enable && supported;

  uniqueDefinitions =
    kind: definitions:
    let
      names = map (definition: definition.name) definitions;
      duplicates = filter (name: length (filter (n: n == name) names) > 1) (lib.unique names);
    in
    if duplicates != [ ] then
      throw "terminus: duplicate ${kind}: ${lib.concatStringsSep ", " duplicates}"
    else
      definitions;
in
{
  inherit
    call
    callLib
    terminus
    frameworkArgs
    ;

  packages =
    {
      discovery,
      pkgsBySystem,
      systems,
    }:
    lib.genAttrs systems (
      system:
      let
        pkgs = pkgsBySystem.${system};
        defs = uniqueDefinitions "package" (
          filter (definition: enabled system definition) discovery.packages
        );
        userPackages = listToAttrs (
          map (definition: {
            inherit (definition) name;
            value = call pkgs definition.path;
          }) defs
        );
      in
      userPackages
      // {
        colmena = inputs.colmena.packages.${system}.colmena;
      }
    );

  apps =
    {
      discovery,
      pkgsBySystem,
      systems,
    }:
    lib.genAttrs systems (
      system:
      let
        pkgs = pkgsBySystem.${system};
        defs = uniqueDefinitions "app" (filter (definition: enabled system definition) discovery.apps);
      in
      listToAttrs (
        map (definition: {
          inherit (definition) name;
          value =
            let
              value = call pkgs definition.path;
            in
            if builtins.isAttrs value then
              builtins.removeAttrs value [
                "override"
                "overrideDerivation"
              ]
            else
              value;
        }) defs
      )
    );

  shells =
    {
      discovery,
      pkgsBySystem,
      systems,
    }:
    lib.genAttrs systems (
      system:
      let
        pkgs = pkgsBySystem.${system};
        defs = uniqueDefinitions "devShell" (
          filter (definition: enabled system definition) discovery.shells
        );
      in
      listToAttrs (
        map (definition: {
          inherit (definition) name;
          value = call pkgs definition.path;
        }) defs
      )
    );

  checks =
    {
      discovery,
      pkgsBySystem,
      systems,
    }:
    lib.genAttrs systems (
      system:
      let
        pkgs = pkgsBySystem.${system};
        defs = uniqueDefinitions "check" (filter (definition: enabled system definition) discovery.checks);
        reserved = filter (definition: lib.hasPrefix "terminus-" definition.name) discovery.checks;
      in
      if reserved != [ ] then
        throw "terminus: checks/ names starting with 'terminus-' are reserved: ${
          lib.concatStringsSep ", " (map (definition: definition.name) reserved)
        }"
      else
        listToAttrs (
          map (definition: {
            inherit (definition) name;
            value = call pkgs definition.path;
          }) defs
        )
    );

  formatter =
    {
      discovery,
      pkgsBySystem,
      systems,
    }:
    lib.genAttrs systems (
      system:
      let
        pkgs = pkgsBySystem.${system};
        formatter = discovery.formatter;
        supported =
          formatter != null
          && formatter.meta.enable
          && (if formatter.meta.systems == null then true else elem system formatter.meta.systems);
      in
      if supported then call pkgs formatter.path else pkgs.nixfmt
    );

  overlays =
    {
      discovery,
    }:
    let
      loadOverlay =
        path:
        let
          fn = import path;
          args = functionArgs fn;
        in
        if isFunction fn && (hasAttr "inputs" args || hasAttr "self" args || hasAttr "terminus" args) then
          fn (intersectAttrs args frameworkArgs)
        else
          fn;
    in
    listToAttrs (
      map (entry: {
        inherit (entry) name;
        value = loadOverlay entry.path;
      }) (filter (entry: entry.meta.enable) discovery.overlays)
    );

  lib =
    {
      discovery,
    }:
    listToAttrs (
      map (entry: {
        inherit (entry) name;
        value = callLib entry.path;
      }) discovery.libFiles
    );
}
