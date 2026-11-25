{ terminus, ... }:
{
  users.users.allenyou.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILFhiR8t5soqwfpcemRLTe9StCSGsD36TyJgE9PGcjJk allenyou@lap-fallom"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKYi3oPee8yUl6/G0WYL6BShQ0fwp/N7uVuXxXRJEPgc allenyou@lap-yenner"
  ];

  age.secrets.oss-nix-cache-config = terminus.secrets.secret {
    name = "common/oss-nix-cache-config";
    path = "/home/allenyou/.aws/config";
    owner = "allenyou";
    mode = "0400";
  };

  age.secrets.aliyun-cli-config = terminus.secrets.secret {
    name = "common/aliyun-cli-config";
    path = "/home/allenyou/.aliyun/config.json";
    owner = "allenyou";
    mode = "0400";
  };
}
