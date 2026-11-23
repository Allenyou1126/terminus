# DN42 BIRD2 BGP 路由选项。
#
# 这里只描述网络拓扑（自己通告的网段、对等体、RPKI 服务器）；配置渲染、
# ROA 表刷新和 systemd 加固见同目录的 nixos.nix。
{
  lib,
  pkgs,
  ...
}:
let
  types = {
    networkConfig = lib.types.submodule {
      options = {
        ip = lib.mkOption {
          type = lib.types.str;
          example = "172.21.89.225";
          description = "本机在该地址族下的 DN42 地址。";
        };
        cidr = lib.mkOption {
          type = lib.types.str;
          example = "172.21.89.224/27";
          description = "本网络在该地址族下通告的 CIDR 前缀。";
        };
      };
    };

    ownNetwork = lib.types.submodule {
      options = {
        asn = lib.mkOption {
          type = lib.types.int;
          example = 4242421056;
          description = "本网络的 DN42 ASN。";
        };
        ipv4 = lib.mkOption {
          type = types.networkConfig;
          description = "本网络的 IPv4 地址和前缀。";
        };
        ipv6 = lib.mkOption {
          type = types.networkConfig;
          description = "本网络的 IPv6 地址和前缀。";
        };
      };
    };

    peeringSession = lib.types.submodule {
      options = {
        neighborAS = lib.mkOption {
          type = lib.types.int;
          example = 4242422547;
          description = "对端网络的 ASN。";
        };
        networkInterface = lib.mkOption {
          type = lib.types.str;
          example = "dn42-lantian";
          description = "承载该 BGP 会话的网络接口，通常是 WireGuard 接口名。";
        };
        neighborV4 = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "172.22.76.185";
          description = "对端的 IPv4 地址。为 null 时不为该对端建立 IPv4 会话。";
        };
        neighborV6 = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "fe80::2547";
          description = "对端的 IPv6 地址（通常是对端接口的 link-local 地址）。为 null 时不为该对端建立 IPv6 会话。";
        };
        multiProtocolV4 = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            是否在 IPv4 会话上启用 MP-BGP 以同时承载 IPv6 路由。
            为 false 时显式关闭该会话的 IPv6 通道。
          '';
        };
        multiProtocolV6 = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            是否在 IPv6 会话上启用 MP-BGP 以同时承载 IPv4 路由。
            为 false 时显式关闭该会话的 IPv4 通道。
          '';
        };
      };
    };

    staticSession = lib.types.submodule {
      options = {
        networkInterface = lib.mkOption {
          type = lib.types.str;
          example = "hkg-dog-darell";
          description = "承载该静态会话的网络接口，通常是同一网络内另一节点的 WireGuard 接口名。";
        };
        neighborV4 = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "172.21.89.226/32";
          description = "对端的 IPv4 地址（带前缀长度，通常写成 /32）。为 null 时不生成 IPv4 静态路由。";
        };
        neighborV6 = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "fdbf:b830:8a32::2/128";
          description = "对端的 IPv6 地址（带前缀长度，通常写成 /128）。为 null 时不生成 IPv6 静态路由。";
        };
      };
    };

    rpkiServer = lib.types.submodule {
      options = {
        address = lib.mkOption {
          type = lib.types.str;
          example = "rpki.akae.re";
          description = "RPKI 服务器地址（域名或 IP），通过 RTR 协议获取 ROA。";
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = 8282;
          description = "RPKI 服务器的 RTR 端口。";
        };
        retry = lib.mkOption {
          type = lib.types.int;
          default = 90;
          description = "连接失败后的重试间隔（秒）。";
        };
        refresh = lib.mkOption {
          type = lib.types.int;
          default = 900;
          description = "ROA 数据的刷新间隔（秒）。";
        };
        expire = lib.mkOption {
          type = lib.types.int;
          default = 172800;
          description = "ROA 数据的过期时间（秒）。";
        };
      };
    };
  };
in
{
  options.terminus.dn42.bird2 = {
    enable = lib.mkEnableOption "DN42 BIRD2 BGP 路由";

    package = lib.mkPackageOption pkgs "bird2" { };

    ownNetwork = lib.mkOption {
      type = types.ownNetwork;
      description = "本网络的 ASN、IPv4/IPv6 地址和前缀；决定 BIRD 的 router id 和本网络路由的过滤规则。";
    };

    enableRoa = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        是否启用 RPKI ROA 校验。启用后从 dn42.burble.com 下载 DN42 的 ROA 表，
        在 import filter 中拒绝 ROA 校验失败的路由，并由 cron 每小时刷新一次。
      '';
    };

    rpkiServers = lib.mkOption {
      type = lib.types.attrsOf types.rpkiServer;
      default = { };
      description = ''
        通过 RTR 协议提供 ROA 的服务器。留空表示只使用
        {option}`terminus.dn42.bird2.enableRoa` 下载的静态 ROA 文件。
        属性名只用于生成 BIRD 协议名，可以随意取。
      '';
    };

    staticSessions = lib.mkOption {
      type = lib.types.attrsOf types.staticSession;
      default = { };
      description = ''
        静态路由会话，通常用于和同一网络内的其他节点（例如自己的另一台机器）
        建立 BGP 会话。属性名会成为 BIRD 协议名的一部分。
      '';
    };

    peeringSessions = lib.mkOption {
      type = lib.types.attrsOf types.peeringSession;
      default = { };
      description = ''
        与 DN42 其他网络建立的 BGP 对等会话。属性名会成为 BIRD 协议名的一部分，
        建议与对端使用的 WireGuard 接口名保持一致。
      '';
    };
  };
}
