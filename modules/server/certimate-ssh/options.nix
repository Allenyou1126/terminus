{ lib, ... }:
{
  options.terminus.certimate-ssh = {
    enable = lib.mkEnableOption "Certimate ssh users for deploy";
    user = lib.mkOption {
      type = lib.types.str;
      default = "certimate";
      description = ''
        远程登录使用的用户名。
      '';
    };
    group = lib.mkOption {
      type = lib.types.str;
      default = "certimate";
      description = ''
        远程登录使用的用户所属组。(若修改，则需要手动创建)
      '';
    };
    keys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        远程登录使用的 SSH Key。
      '';
    };
    allowedCommands = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        远程登录允许使用 sudo 免密执行的命令。
      '';
    };
  };
}
