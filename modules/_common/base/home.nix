{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.terminus.base.enable {
    home.packages = [ pkgs.ripgrep ];
    home.sessionVariables.TERMINUS_BASE = "1";
  };
}
