let
  keys = import ./keys.nix;
  fullKeyList = builtins.attrValues keys.hostKeys;
in
{
  # common：所有主机共享的配置。
  "common/oss-nix-cache-config.age".publicKeys = fullKeyList;
  "common/aliyun-cli-config.age".publicKeys = fullKeyList;

  "dn42/lax-rn-riose.priv.age".publicKeys = [
    keys.hostKeys.lax-rn-riose
  ]
  ++ keys.adminKeys;
  "dn42/h503mc_lax-rn-riose.psk.age".publicKeys = [
    keys.hostKeys.lax-rn-riose
  ]
  ++ keys.adminKeys;

  "nexusnet/sha-ali-seldon.priv.age".publicKeys = [
    keys.hostKeys.sha-ali-seldon
  ]
  ++ keys.adminKeys;
  "nexusnet/lap-fallom_sha-ali-seldon.psk.age".publicKeys = [
    keys.hostKeys.sha-ali-seldon
  ]
  ++ keys.adminKeys;
  "nexusnet/home-hardin_sha-ali-seldon.psk.age".publicKeys = [
    keys.hostKeys.sha-ali-seldon
  ]
  ++ keys.adminKeys;
  "nexusnet/lap-yenner_sha-ali-seldon.psk.age".publicKeys = [
    keys.hostKeys.sha-ali-seldon
  ]
  ++ keys.adminKeys;

  # services：各服务的凭据。
  "services/frp-token.age".publicKeys = [
    keys.hostKeys.sha-ali-seldon
  ]
  ++ keys.adminKeys;

  "services/zitadel/master-key.age".publicKeys = [
    keys.hostKeys.sha-ali-seldon
  ]
  ++ keys.adminKeys;
  "services/zitadel/secret-config.age".publicKeys = [
    keys.hostKeys.sha-ali-seldon
  ]
  ++ keys.adminKeys;

  "services/grafana/db-password.age".publicKeys = [
    keys.hostKeys.sha-ali-seldon
  ]
  ++ keys.adminKeys;
  "services/grafana/secret-key.age".publicKeys = [
    keys.hostKeys.sha-ali-seldon
  ]
  ++ keys.adminKeys;
}
