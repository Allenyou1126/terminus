{ lib, ... }:
{
  options.terminus.wireguardExporter = {
    enable = lib.mkEnableOption "Prometheus WireGuard exporter";

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "wireguard exporter 监听地址。";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9586;
      description = "wireguard exporter 监听端口。";
    };

    allowedSources = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "106.14.99.198" ];
      description = "允许访问 exporter 的源地址或 CIDR；为空时不添加额外防火墙规则。";
    };

    withRemoteIp = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "是否在指标中暴露 WireGuard 对端的远端 IP。";
    };

    latestHandshakeDelay = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "是否暴露距最近一次 handshake 的秒数指标。";
    };

    verbose = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "是否启用 exporter 的 verbose 日志。";
    };
  };
}
