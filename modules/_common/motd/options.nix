{ lib, terminus, ... }:
{
  options.terminus.motd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "是否启用登录 MOTD。默认保持旧 common.nix 的常开行为。";
    };

    banner = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = ''
          ______                    _                 
         /_  __/__  _________ ___  (_)___  __  _______
          / / / _ \/ ___/ __ `__ \/ / __ \/ / / / ___/
         / / /  __/ /  / / / / / / / / / / /_/ (__  ) 
        /_/  \___/_/  /_/ /_/ /_/_/_/ /_/\__,_/____/                  
      '';
      description = "MOTD 前显示的 ASCII banner；设为 null 可关闭。";
    };

    description = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = if terminus.host != null then terminus.host.description else null;
      defaultText = "hosts/<name>/meta.nix 的 description";
      description = "MOTD 的 Role 行；默认取 hosts/<name>/meta.nix 的 description。";
    };
  };
}
