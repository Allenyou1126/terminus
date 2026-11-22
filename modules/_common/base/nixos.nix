{ config, lib, ... }:
{
  config = lib.mkIf config.terminus.base.enable {
    time.timeZone = "Asia/Shanghai";

    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    users.mutableUsers = false;

    environment.variables.TERMINUS_BASE = "1";
  };
}
