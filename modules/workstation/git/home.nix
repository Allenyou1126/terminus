{ config, lib, ... }:
{
  config = lib.mkIf config.terminus.workstation.git.enable {
    programs.git.enable = true;
  };
}
