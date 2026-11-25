{ lib, ... }:
let
  peer = lib.types.submodule {
    options = {
      publicKey = lib.mkOption {
        type = lib.types.str;
        description = "对端的 WireGuard 公钥（base64）。";
      };

      allowedIPs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "该 peer 允许进入隧道的地址/CIDR。";
      };

      preSharedKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "可选的预共享密钥文件路径，通常由 agenix 提供。";
      };

      endpoint = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "可选的 peer endpoint（host:port）；不填则等待对端连接。";
      };

      persistentKeepalive = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "可选的 persistent keepalive 秒数。";
      };
    };
  };
in
{
  options.terminus.nexusnet = {
    enable = lib.mkEnableOption "NexusNet WireGuard 网络";

    interface = lib.mkOption {
      type = lib.types.str;
      default = "nexusnet";
      description = "WireGuard 接口名；Linux 最多 15 个字符。";
    };

    addresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "192.168.103.1/24" ];
      description = "本机接口地址列表；启用时至少需要一个地址。";
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 51820;
      description = "本机 WireGuard 监听端口。";
    };

    mtu = lib.mkOption {
      type = lib.types.int;
      default = 1280;
      description = "接口 MTU。";
    };

    privateKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "本机 WireGuard 私钥文件路径，通常由 agenix 注入。";
    };

    nat = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "是否为本网络做 NAT 和 FORWARD 放行。";
      };

      externalInterface = lib.mkOption {
        type = lib.types.str;
        default = "eth0";
        description = "NAT 出接口名。";
      };

      source = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "192.168.103.0/24";
        description = "NAT 源网段；nat.enable = true 时必填。";
      };
    };

    peers = lib.mkOption {
      type = lib.types.attrsOf peer;
      default = { };
      description = "以属性名为标识的 WireGuard peer 集合。";
    };
  };
}
