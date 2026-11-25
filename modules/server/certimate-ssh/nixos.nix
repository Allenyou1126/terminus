{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.terminus.certimate-ssh;
in
{
  config = lib.mkIf cfg.enable {
    users.groups.${cfg.group} = lib.mkIf (cfg.group == "certimate") { };

    users.users.${cfg.user} = {
      openssh.authorizedKeys.keys = cfg.keys;
      shell = pkgs.bashInteractive;
      isSystemUser = true;
      group = cfg.group;
    };

    security.sudo.extraRules = [
      {
        users = [
          cfg.user
        ];
        commands = map (command: {
          command = command;
          options = [
            "NOPASSWD"
          ];
        }) cfg.allowedCommands;
      }
    ];
  };
}
