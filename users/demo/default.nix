{ ... }:
{
  users.users.demo = {
    shell = "/run/current-system/sw/bin/bash";
    openssh.authorizedKeys.keys = [ ];
  };
}
