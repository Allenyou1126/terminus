# 用户级 DeepSeek Harness：只作为 Home Manager 模块使用，关闭 NixOS side。
# 系统级、以系统用户运行的版本见 modules/server/deepseek-harness。
{
  nixos.enable = false;
}
