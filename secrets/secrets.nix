let
  keys = import ./keys.nix;
  fullKeyList = builtins.attrValues keys.hostKeys;
  laxHostKeys = [
    keys.hostKeys.lax-rn-riose
    keys.hostKeys.lap-fallom
    keys.hostKeys.lap-yenner
  ];
in
{
  "oss-nix-cache-config.age".publicKeys = fullKeyList;
  "aliyun-cli-config.age".publicKeys = fullKeyList;
  "wg-private-key.lax-rn-riose.age".publicKeys = laxHostKeys;
  "wg-psk-dn42-h503mc.lax-rn-riose.age".publicKeys = laxHostKeys;
}
