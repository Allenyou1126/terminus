{ lib, ... }:
{
  options.terminus.workstation.git.enable = lib.mkEnableOption "git";
}
