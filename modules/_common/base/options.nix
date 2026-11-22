{ lib, ... }:
{
  options.terminus.base.enable = lib.mkEnableOption "terminus base module";
}
