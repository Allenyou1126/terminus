{
  lib,
  pkgs,
  ...
}:
{
  options.terminus.postgresql = {
    enable = lib.mkEnableOption "PostgreSQL server";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.postgresql_17;
      defaultText = lib.literalExpression "pkgs.postgresql_17";
      description = "PostgreSQL 包；默认与源 seldon 配置一致，使用 17。";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5432;
      description = "PostgreSQL 监听端口，写入 services.postgresql.settings.port。";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "额外 PostgreSQL 配置；port 由上面的选项统一覆盖。";
    };
  };
}
