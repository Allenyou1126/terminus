{
  config,
  lib,
  ...
}:
let
  cfg = config.terminus.postgresql;
in
{
  config = lib.mkIf cfg.enable {
    services.postgresql = {
      enable = true;
      inherit (cfg) package;
      settings = cfg.settings // {
        inherit (cfg) port;
      };
    };
  };
}
