let
  keys = import ./keys.nix;
  fullKeyList = builtins.attrValues keys.hostKeys;
in
{
  "oss-nix-cache-config.age".publicKeys = fullKeyList;
  "aliyun-cli-config.age".publicKeys = fullKeyList;
}
