# 仅作为 NixOS 模块使用：关闭 Home Manager side，避免 options.nix 被导入
# server 主机的 home 配置。
{
  home.enable = false;
}
