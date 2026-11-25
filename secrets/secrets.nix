let
  keys = import ./keys.nix;
  fullKeyList = builtins.attrValues keys.hostKeys;
  laxHostKeys = [
    keys.hostKeys.lax-rn-riose
    keys.hostKeys.lap-fallom
    keys.hostKeys.lap-yenner
  ];
  laptopKeys = [
    keys.hostKeys.lap-fallom
    keys.hostKeys.lap-yenner
  ];
  seldonKeys = [ keys.hostKeys.sha-ali-seldon ] ++ laptopKeys;
  frpTokenKeys = [
    keys.hostKeys.sha-ali-seldon
    keys.hostKeys.home-ebeling
  ]
  ++ laptopKeys;
in
{
  "oss-nix-cache-config.age".publicKeys = fullKeyList;
  "aliyun-cli-config.age".publicKeys = fullKeyList;
  "wg-private-key.lax-rn-riose.age".publicKeys = laxHostKeys;
  "wg-psk-dn42-h503mc.lax-rn-riose.age".publicKeys = laxHostKeys;

  "wg-private-key.sha-ali-seldon.age".publicKeys = seldonKeys;
  "wg-psk-lap-fallom.sha-ali-seldon.age".publicKeys = seldonKeys;
  "wg-psk-home-hardin.sha-ali-seldon.age".publicKeys = seldonKeys;
  "wg-psk-lap-yenner.sha-ali-seldon.age".publicKeys = seldonKeys;
  "frp-token.sha-ali-seldon.age".publicKeys = frpTokenKeys;
  "zitadel-master-key.sha-ali-gaal.age".publicKeys = seldonKeys;
  "zitadel-secret-config.sha-ali-gaal.age".publicKeys = seldonKeys;
  "grafana-db-password.sha-ali-gaal.age".publicKeys = seldonKeys;
  "grafana-secret-key.sha-ali-gaal.age".publicKeys = seldonKeys;
}
