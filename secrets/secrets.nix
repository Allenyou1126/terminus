let
  keys = import ./keys.nix;
  fullKeyList = builtins.attrValues keys.hostKeys;
in
{
  # Every encrypted file is <name>.age, regardless of which hosts read it.
  "oss-nix-cache-config.age".publicKeys = fullKeyList;
  "aliyun-cli-config.age".publicKeys = fullKeyList;
}
