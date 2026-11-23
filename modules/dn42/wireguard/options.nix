# DN42 WireGuard 隧道选项。
#
# 每个属性对应一条隧道：`dn42PeeringSessions` 用于和其他 DN42 网络互联，
# `staticSessions` 用于和同一网络内的节点（例如自己的另一台机器）互联。
# 实现见同目录的 nixos.nix。
{
  lib,
  ...
}:
let
  types = {
    localConfig = lib.types.submodule {
      options = {
        addressV4 = lib.mkOption {
          type = lib.types.str;
          example = "172.21.89.225/27";
          description = "本机的 IPv4 地址（带前缀长度）。";
        };
        addressV6 = lib.mkOption {
          type = lib.types.str;
          example = "fdbf:b830:8a32::1/64";
          description = "本机的 IPv6 地址（带前缀长度）。";
        };
        localLinkAddressV6 = lib.mkOption {
          type = lib.types.str;
          example = "fe80::1056/64";
          description = "本机接口的 IPv6 link-local 地址（带前缀长度）。";
        };
        privateKeyFile = lib.mkOption {
          type = lib.types.path;
          example = "/run/agenix/dn42-wireguard";
          description = ''
            WireGuard 私钥文件路径。通常由 agenix 注入，例如
            `config.age.secrets.dn42-wireguard.path`；私钥不要写进 Nix store。
          '';
        };
      };
    };

    peeringSession = lib.types.submodule {
      options = {
        addressV4 = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "172.22.76.185";
          description = "对端的 IPv4 地址。为 null 时该隧道不配置 IPv4 对端地址。";
        };
        addressV6 = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "fdbc:f9dc:67ad:3::1";
          description = "对端的 IPv6 地址。为 null 时该隧道不配置 IPv6 对端地址。";
        };
        localLinkAddressV6 = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "fe80::2547";
          description = "对端接口的 IPv6 link-local 地址，BGP 会话通常用它做邻居地址。";
        };
        endpoint = lib.mkOption {
          type = lib.types.str;
          example = "bwg-lax.lantian.pub:21056";
          description = "对端端点（`host:port`），可以是域名或 IP。";
        };
        publicKey = lib.mkOption {
          type = lib.types.str;
          example = "DipkJyCAKPpGTEs66PuBfWYb6JcnHDaurDJW0ofTSWo=";
          description = "对端的 WireGuard 公钥（base64）。";
        };
        preSharedKeyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            可选的预共享密钥文件路径。对端要求 PSK 时通过 agenix 提供；
            不要写进 Nix store。
          '';
        };
        listenPort = lib.mkOption {
          type = lib.types.port;
          example = 22547;
          description = "本端监听端口。DN42 对等通常使用 2xxxx 段。";
        };
      };
    };

    staticSession = lib.types.submodule {
      options = {
        addressV4 = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "172.21.89.226/32";
          description = "对端的 IPv4 地址。为 null 时该隧道不配置 IPv4 对端地址。";
        };
        addressV6 = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "fdbf:b830:8a32::2/128";
          description = "对端的 IPv6 地址。为 null 时该隧道不配置 IPv6 对端地址。";
        };
        isGateway = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            对端是否充当网关。为 true 时把对端地址作为下一跳，为 DN42 网段
            添加静态路由；否则只把本机地址配置到接口上。
          '';
        };
        endpoint = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "hkg-dog-darell.server.allenyou.wang:50226";
          description = ''
            对端端点（`host:port`）。为 null 时只等待对端主动连接，
            适合位于 NAT 后面、没有固定公网地址的节点。
          '';
        };
        publicKey = lib.mkOption {
          type = lib.types.str;
          example = "ioHavV7Rvc+t6EarVxjaVX4l+EP59CDUYTSEewVxyG0=";
          description = "对端的 WireGuard 公钥（base64）。";
        };
        preSharedKeyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "可选的预共享密钥文件路径；对端要求 PSK 时通过 agenix 提供。";
        };
        listenPort = lib.mkOption {
          type = lib.types.nullOr lib.types.port;
          default = null;
          example = 50226;
          description = "本端监听端口。为 null 时只主动连接对端，不监听端口。";
        };
      };
    };
  };
in
{
  options.terminus.dn42.wireguard = {
    enable = lib.mkEnableOption "DN42 WireGuard 隧道";

    local = lib.mkOption {
      type = types.localConfig;
      description = "本机的 DN42 地址和 WireGuard 私钥；每个会话共用同一把私钥。";
    };

    dn42PeeringSessions = lib.mkOption {
      type = lib.types.attrsOf types.peeringSession;
      default = { };
      description = ''
        与其他 DN42 网络建立的 WireGuard 隧道。属性名会变成接口名
        `dn42-<name>`，建议和 BIRD 对等会话的属性名保持一致。
      '';
    };

    staticSessions = lib.mkOption {
      type = lib.types.attrsOf types.staticSession;
      default = { };
      description = ''
        与同一网络内其他节点建立的 WireGuard 隧道。属性名直接作为接口名，
        建议和 BIRD 静态会话的属性名保持一致。
      '';
    };
  };
}
