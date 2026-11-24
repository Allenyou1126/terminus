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
        _   _                       _   _      _   
        | \ | |                     | \ | |    | |  
        |  \| | _____  ___   _ ___  |  \| | ___| |_ 
        | . ` |/ _ \ \/ / | | / __| | . ` |/ _ \ __|
        | |\  |  __/>  <| |_| \__ \ | |\  |  __/ |_ 
        |_| \_|\___/_/\_\\__,_|___/ |_| \_|\___|\__|                   
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
