# 选择 cn Profile 的主机默认启用 CN preset；主机可以用普通定义覆盖为 false。
{ lib, ... }:
{
  terminus.nix.substituters.presets.cn = lib.mkDefault true;
}
