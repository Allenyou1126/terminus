{ lib, ... }:
{
  options.terminus.birdExporter = {
    enable = lib.mkEnableOption "Prometheus BIRD exporter";

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "bird exporter 监听地址。";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9324;
      description = "bird exporter 监听端口。";
    };

    allowedSources = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "106.14.99.198" ];
      description = "允许访问 exporter 的源地址或 CIDR；为空时不添加额外防火墙规则。";
    };
  };
}
