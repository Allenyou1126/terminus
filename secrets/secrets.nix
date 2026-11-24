let
  keys = import ./keys.nix;
  fullKeyList = builtins.attrValues keys.hostKeys;
in
{
  # Every encrypted file is <name>.age, regardless of which hosts read it.
  "oss-nix-cache-config.age".publicKeys = fullKeyList;
  "aliyun-cli-config.age".publicKeys = fullKeyList;
  # 旧 nixos-secret 中的 deepseek-harness-secret.home-ebeling.age 按统一命名迁移；
  # 解密范围保持为 home-ebeling 主机 + 管理员笔记本。
  "deepseek-harness-secret.age".publicKeys = [ keys.home-ebeling ] ++ keys.adminKeys;
}
