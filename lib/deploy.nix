# Colmena deployment metadata and the dedicated deploy user.
{ lib }:
let
  inherit (builtins) mapAttrs;
in
{
  isRemote = host: host.meta.deployment.targetHost != null;

  userModule =
    {
      host,
      deployUser,
      deployKeys,
    }:
    { lib, ... }:
    {
      services.openssh.enable = lib.mkDefault true;

      users.users.${deployUser.name} = {
        isNormalUser = lib.mkDefault true;
        createHome = lib.mkDefault true;
        hashedPassword = "!";
        uid = lib.mkDefault deployUser.uid;
        openssh.authorizedKeys.keys = deployKeys;
      };

      # The deploy user needs passwordless root for Colmena. Other users must
      # not be able to become deploy via sudo: a restricted sudo user could
      # otherwise run `sudo -u deploy bash` and inherit deploy's NOPASSWD rule.
      # `mkAfter` makes the deny rule the last match, which sudoers uses.
      security.sudo.extraRules = lib.mkMerge [
        (lib.mkBefore [
          {
            users = [ deployUser.name ];
            commands = [
              {
                command = "ALL";
                options = [ "NOPASSWD" ];
              }
            ];
          }
        ])
        (lib.mkAfter [
          {
            users = [ "ALL" ];
            runAs = "${deployUser.name},#${toString deployUser.uid}";
            commands = [ { command = "!ALL"; } ];
          }
        ])
      ];

      warnings = lib.optional (deployKeys == [ ]) ''
        terminus: no deploy public keys in keys/deploy/*.pub
        remote deployment as '${deployUser.name}' will fail until a key is added.
      '';
    };

  colmenaModule =
    {
      host,
      deployUser,
    }:
    let
      deployment = host.meta.deployment;
      targetUser = if deployment.sshUser != null then deployment.sshUser else deployUser.name;
    in
    {
      deployment = {
        targetHost = deployment.targetHost;
        targetPort = deployment.targetPort;
        targetUser = targetUser;
        buildOnTarget = deployment.buildOnRemote;
        tags = deployment.tags;
        sshOptions = deployment.sshOptions;
        allowLocalDeployment =
          if deployment.allowLocalDeployment != null then
            deployment.allowLocalDeployment
          else
            deployment.targetHost == null;
        replaceUnknownProfiles =
          if deployment.replaceUnknownProfiles != null then deployment.replaceUnknownProfiles else true;
      };
    };

  nodes =
    hosts:
    mapAttrs (name: host: {
      inherit name;
      targetHost = host.meta.deployment.targetHost;
      targetPort = host.meta.deployment.targetPort;
      sshUser = if host.meta.deployment.sshUser != null then host.meta.deployment.sshUser else "deploy";
      tags = host.meta.deployment.tags;
    }) (lib.filterAttrs (_name: host: host.meta.deployment.targetHost != null) hosts);
}
