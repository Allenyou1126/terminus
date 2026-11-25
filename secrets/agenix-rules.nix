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

  # hkg-dog-darell：单 secret 应用直接以应用名命名文件。
  "dn42/hkg-dog-darell.priv.age".publicKeys = [
    keys.hostKeys.hkg-dog-darell
  ]
  ++ keys.adminKeys;

  "services/gotify.age".publicKeys = [
    keys.hostKeys.hkg-dog-darell
  ]
  ++ keys.adminKeys;
  "services/miniflux.age".publicKeys = [
    keys.hostKeys.hkg-dog-darell
  ]
  ++ keys.adminKeys;
  "services/nokoribi.age".publicKeys = [
    keys.hostKeys.hkg-dog-darell
  ]
  ++ keys.adminKeys;
  "services/open-webui.age".publicKeys = [
    keys.hostKeys.hkg-dog-darell
  ]
  ++ keys.adminKeys;
  "services/openviking.age".publicKeys = [
    keys.hostKeys.hkg-dog-darell
  ]
  ++ keys.adminKeys;
  "services/recado.age".publicKeys = [
    keys.hostKeys.hkg-dog-darell
  ]
  ++ keys.adminKeys;
  "services/sub-store.age".publicKeys = [
    keys.hostKeys.hkg-dog-darell
  ]
  ++ keys.adminKeys;
  "services/umami/app-secret.age".publicKeys = [
    keys.hostKeys.hkg-dog-darell
  ]
  ++ keys.adminKeys;
  "services/umami/database-url.age".publicKeys = [
    keys.hostKeys.hkg-dog-darell
  ]
  ++ keys.adminKeys;
  "services/vaultwarden.age".publicKeys = [
    keys.hostKeys.hkg-dog-darell
  ]
  ++ keys.adminKeys;
  "services/wakapi.age".publicKeys = [
    keys.hostKeys.hkg-dog-darell
  ]
  ++ keys.adminKeys;
  "services/waline.age".publicKeys = [
    keys.hostKeys.hkg-dog-darell
  ]
  ++ keys.adminKeys;
  "services/waline-zlight106.age".publicKeys = [
    keys.hostKeys.hkg-dog-darell
  ]
  ++ keys.adminKeys;
  "services/webdav.age".publicKeys = [
    keys.hostKeys.hkg-dog-darell
  ]
  ++ keys.adminKeys;
}
