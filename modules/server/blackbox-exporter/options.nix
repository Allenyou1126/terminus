{ lib, ... }:
{
  options.terminus.blackboxExporter = {
    enable = lib.mkEnableOption "Prometheus Blackbox exporter";

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "blackbox exporter 监听地址。";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9115;
      description = "blackbox exporter 监听端口。";
    };
  };
}
