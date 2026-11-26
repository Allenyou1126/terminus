# meta.nix parsing and normalization.
{ lib }:
let
  inherit (builtins)
    isAttrs
    isBool
    isInt
    isList
    isString
    typeOf
    ;

  errors = import ./internal/errors.nix { inherit lib; };

  readMeta =
    file:
    let
      value = import file;
    in
    if isAttrs value then value else errors.invalidMeta file "an attribute set" (typeOf value);

  readOptionalMeta = file: if builtins.pathExists file then readMeta file else { };

  stringList =
    file: field: value:
    if isList value && lib.all isString value then
      value
    else
      errors.invalidMeta file "${field} must be a list of strings" (typeOf value);

  boolOr =
    file: field: default: value:
    if value == null then
      default
    else if isBool value then
      value
    else
      errors.invalidMeta file "${field} must be a boolean or null" (typeOf value);

  normalizeModuleMeta =
    file: meta:
    let
      shared = {
        requires = stringList file "requires" (meta.requires or [ ]);
        after = stringList file "after" (meta.after or [ ]);
        before = stringList file "before" (meta.before or [ ]);
        wants = stringList file "wants" (meta.wants or [ ]);
        conflicts = stringList file "conflicts" (meta.conflicts or [ ]);
      };

      side =
        name:
        let
          value = meta.${name} or { };
        in
        if !isAttrs value then
          errors.invalidMeta file "${name} must be an attribute set" (typeOf value)
        else
          {
            enable =
              if isBool (value.enable or true) then
                value.enable or true
              else
                errors.invalidMeta file "${name}.enable must be a boolean" (typeOf value.enable);
            requires = stringList file "${name}.requires" (value.requires or [ ]);
            after = stringList file "${name}.after" (value.after or [ ]);
            before = stringList file "${name}.before" (value.before or [ ]);
            wants = stringList file "${name}.wants" (value.wants or [ ]);
            conflicts = stringList file "${name}.conflicts" (value.conflicts or [ ]);
          };
    in
    {
      inherit shared;
      nixos = side "nixos";
      home = side "home";
    };

  normalizeHostMeta =
    file: meta:
    let
      system = meta.system or (errors.missingHostSystem (toString file));

      profiles = if meta ? profiles then stringList file "profiles" meta.profiles else [ ];

      requires = if meta ? requires then stringList file "requires" meta.requires else [ ];

      removedField =
        if meta ? roles then
          "roles"
        else if meta ? role then
          "role"
        else if meta ? modules then
          "modules"
        else
          null;

      description =
        if meta ? description then
          if meta.description == null || isString meta.description then
            meta.description
          else
            errors.invalidMeta file "description must be a string or null" (typeOf meta.description)
        else
          null;

      home =
        let
          value = meta.home or { };
        in
        if !isAttrs value then
          errors.invalidMeta file "home must be an attribute set" (typeOf value)
        else
          {
            embed = if value ? embed then boolOr file "home.embed" null value.embed else null;
            useGlobalPkgs =
              if value ? useGlobalPkgs then boolOr file "home.useGlobalPkgs" null value.useGlobalPkgs else null;
          };

      secrets =
        let
          value = meta.secrets or { };
        in
        if !isAttrs value then
          errors.invalidMeta file "secrets must be an attribute set" (typeOf value)
        else
          {
            identityPaths =
              if value ? identityPaths then stringList file "secrets.identityPaths" value.identityPaths else null;
          };

      deployment =
        let
          value = meta.deployment or { };
        in
        if !isAttrs value then
          errors.invalidMeta file "deployment must be an attribute set" (typeOf value)
        else
          {
            targetHost =
              if value ? targetHost then
                if value.targetHost == null || isString value.targetHost then
                  value.targetHost
                else
                  errors.invalidMeta file "deployment.targetHost must be a string or null" (typeOf value.targetHost)
              else
                null;
            targetPort =
              if value ? targetPort then
                if value.targetPort == null || isInt value.targetPort then
                  value.targetPort
                else
                  errors.invalidMeta file "deployment.targetPort must be an integer or null" (typeOf value.targetPort)
              else
                22;
            sshUser =
              if value ? sshUser then
                if value.sshUser == null || isString value.sshUser then
                  value.sshUser
                else
                  errors.invalidMeta file "deployment.sshUser must be a string or null" (typeOf value.sshUser)
              else
                null;
            buildOnRemote = boolOr file "deployment.buildOnRemote" false (value.buildOnRemote or null);
            tags = if value ? tags then stringList file "deployment.tags" value.tags else [ ];
            sshOptions =
              if value ? sshOptions then stringList file "deployment.sshOptions" value.sshOptions else [ ];
            allowLocalDeployment =
              if value ? allowLocalDeployment then
                boolOr file "deployment.allowLocalDeployment" null value.allowLocalDeployment
              else
                null;
            replaceUnknownProfiles =
              if value ? replaceUnknownProfiles then
                boolOr file "deployment.replaceUnknownProfiles" null value.replaceUnknownProfiles
              else
                null;
          };
    in
    if removedField == "roles" || removedField == "role" then
      errors.removedHostField file removedField (
        "declare module groups in `profiles` instead, e.g. profiles = [ \"server\" ];"
      )
    else if removedField == "modules" then
      errors.removedHostField file "modules" (
        "host-level module overrides were removed; use `requires = [ ... ]` for direct imports or select a profile"
      )
    else
      {
        inherit
          system
          profiles
          requires
          description
          home
          secrets
          deployment
          ;
        raw = meta;
      };

  normalizeProfileMeta =
    file: meta:
    let
      requires = stringList file "requires" (meta.requires or [ ]);
      extends = stringList file "extends" (meta.extends or [ ]);
      misplaced = lib.filter (field: lib.hasAttr field meta) [
        "modules"
        "common"
        "nixos"
        "home"
      ];
      hint =
        if lib.hasAttr "modules" meta then
          "rename `modules` to `requires`; profile config belongs in nixos.nix / home.nix"
        else
          "profile config belongs in nixos.nix / home.nix";
    in
    if misplaced != [ ] then
      errors.unsupportedProfileField file (lib.concatStringsSep ", " misplaced) hint
    else
      {
        inherit requires extends;
        raw = meta;
      };

  normalizeUserMeta =
    file: meta:
    let
      hosts = if meta ? hosts then stringList file "hosts" meta.hosts else [ ];

      hashedPassword =
        if meta ? hashedPassword then
          if meta.hashedPassword == null || isString meta.hashedPassword then
            meta.hashedPassword
          else
            errors.invalidMeta file "hashedPassword must be a string or null" (typeOf meta.hashedPassword)
        else
          null;

      hashedPasswordSecret =
        if meta ? hashedPasswordSecret then
          if meta.hashedPasswordSecret == null || isString meta.hashedPasswordSecret then
            meta.hashedPasswordSecret
          else
            errors.invalidMeta file "hashedPasswordSecret must be a string or null" (
              typeOf meta.hashedPasswordSecret
            )
        else
          null;
    in
    if hashedPassword != null && hashedPasswordSecret != null then
      errors.invalidMeta file "only one of hashedPassword and hashedPasswordSecret may be set" "both set"
    else
      {
        inherit hosts hashedPassword hashedPasswordSecret;
        uid =
          if meta ? uid then
            if meta.uid == null || isInt meta.uid then
              meta.uid
            else
              errors.invalidMeta file "uid must be an integer or null" (typeOf meta.uid)
          else
            null;
        gid =
          if meta ? gid then
            if meta.gid == null || isInt meta.gid then
              meta.gid
            else
              errors.invalidMeta file "gid must be an integer or null" (typeOf meta.gid)
          else
            null;
        group =
          if meta ? group then
            if meta.group == null || isString meta.group then
              meta.group
            else
              errors.invalidMeta file "group must be a string or null" (typeOf meta.group)
          else
            null;
        extraGroups = if meta ? extraGroups then stringList file "extraGroups" meta.extraGroups else [ ];
        description =
          if meta ? description then
            if meta.description == null || isString meta.description then
              meta.description
            else
              errors.invalidMeta file "description must be a string or null" (typeOf meta.description)
          else
            null;
        home =
          if meta ? home then
            if meta.home == null || isString meta.home then
              meta.home
            else
              errors.invalidMeta file "home must be a string or null" (typeOf meta.home)
          else
            null;
        createHome = boolOr file "createHome" true (meta.createHome or null);
        isNormalUser = boolOr file "isNormalUser" true (meta.isNormalUser or null);
        raw = meta;
      };

  normalizeOutputMeta = file: meta: {
    enable =
      if meta ? enable then
        if isBool meta.enable then
          meta.enable
        else
          errors.invalidMeta file "enable must be a boolean" (typeOf meta.enable)
      else
        true;
    systems =
      if meta ? systems then
        if meta.systems == null then null else stringList file "systems" meta.systems
      else
        null;
    description = if meta ? description && isString meta.description then meta.description else null;
  };
in
{
  inherit
    readMeta
    readOptionalMeta
    stringList
    normalizeModuleMeta
    normalizeHostMeta
    normalizeProfileMeta
    normalizeUserMeta
    normalizeOutputMeta
    ;
}
