# users/<name>/meta.nix -> users.users/groups and Agenix password hashes.
{ lib }:
let
  inherit (builtins) elem filter listToAttrs;
  isAbsolute = value: lib.hasPrefix "/" value;
in
{
  mk =
    {
      discovery,
      secrets,
      host,
    }:
    let
      usersForHost = filter (user: elem host.name user.hosts) discovery.users;

      userNames = map (user: user.name) usersForHost;

      groups = listToAttrs (
        map (
          user:
          let
            meta = user.meta;
            group = if meta.group != null then meta.group else user.name;
            gid = if meta.gid != null then meta.gid else meta.uid;
          in
          {
            name = group;
            value = lib.optionalAttrs (gid != null) {
              gid = lib.mkDefault gid;
            };
          }
        ) usersForHost
      );

      secretUsers = filter (
        user:
        let
          secret = user.meta.hashedPasswordSecret;
        in
        secret != null && !(isAbsolute secret)
      ) usersForHost;
    in
    {
      inherit usersForHost;

      module =
        { config, ... }:
        {
          config = {
            terminus.users = userNames;

            users = {
              inherit groups;
              users = listToAttrs (
                map (
                  user:
                  let
                    meta = user.meta;
                    group = if meta.group != null then meta.group else user.name;
                    secretName = meta.hashedPasswordSecret;
                    useSecret = secretName != null && !(isAbsolute secretName);
                  in
                  {
                    name = user.name;
                    value = {
                      isNormalUser = lib.mkDefault meta.isNormalUser;
                      createHome = lib.mkDefault meta.createHome;
                      group = group;
                      extraGroups = lib.mkDefault meta.extraGroups;
                      uid = lib.mkDefault meta.uid;
                    }
                    // lib.optionalAttrs (meta.home != null) {
                      home = lib.mkDefault meta.home;
                    }
                    // lib.optionalAttrs (meta.description != null) {
                      description = lib.mkDefault meta.description;
                    }
                    // lib.optionalAttrs (secretName != null) {
                      hashedPasswordFile = lib.mkDefault (
                        if useSecret then config.age.secrets.${secretName}.path else secretName
                      );
                    };
                  }
                ) usersForHost
              );
            };

            age.secrets = listToAttrs (
              map (user: {
                name = user.meta.hashedPasswordSecret;
                value = secrets.secret {
                  name = user.meta.hashedPasswordSecret;
                };
              }) secretUsers
            );
          };
        };
    };
}
