# 系统级 DeepSeek Harness：只作为 NixOS 模块使用，关闭 Home Manager side。
# 用户级、每用户独享实例的版本见 modules/client/deepseek-harness。
{
  home.enable = false;
}
