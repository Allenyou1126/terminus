{ lib, ... }:
{
  options.terminus.nix.substituters.entries = lib.mkOption {
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          url = lib.mkOption {
            type = lib.types.str;
            description = "缓存 base URL；不要带 priority 查询参数。";
          };

          priority = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = 40;
            description = "priority 查询参数；null 表示原样使用 url。";
          };

          trustedPublicKeys = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "该缓存对应的可信公钥；只放公钥。";
          };
        };
      }
    );
    default = [ ];
    description = "要启用的 Nix substituters；可引用 terminus.exports.substituterPresets。";
  };
}
