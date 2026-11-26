# 特殊 Profile：存在时自动应用到每台主机和全局 home。
{
  requires = [
    "_common.agenix-cli"
    "_common.basic-packages"
    "_common.home-bash"
    "_common.home-git"
    "_common.home-packages"
    "_common.locale-timezone"
    "_common.motd"
    "_common.nix-experimental"
    "_common.nix-gc"
    "_common.nix-substituters"
    "_common.nix-trusted-users"
  ];
}
