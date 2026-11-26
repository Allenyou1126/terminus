# 选择 global Profile 的主机默认启用 Global preset；主机可以覆盖为 false。
{ lib, ... }:
{
  terminus.nix.substituters.presets.global = lib.mkDefault true;
}
