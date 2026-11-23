# DN42 WireGuard 实现：把会话选项翻译成 networking.wg-quick 接口。
#
# postUp 里的 ip / sysctl 使用绝对路径，避免依赖 wg-quick 服务的 PATH。
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.terminus.dn42.wireguard;

  # DN42 聚合网段和常用的私有地址段；对等体只允许这些网段进入隧道。
  allowedIPs = [
    "10.0.0.0/8"
    "172.20.0.0/14"
    "172.31.0.0/16"
    "fd00::/8"
    "fe80::/64"
  ];

  ip = args: "${lib.getExe' pkgs.iproute2 "ip"} ${lib.escapeShellArgs args}";

  sysctl = args: "${lib.getExe' pkgs.procps "sysctl"} ${lib.escapeShellArgs args}";

  # iproute2 的 `via` 只接受裸地址；对端地址选项通常带 /32 或 /128。
  stripPrefixLength = address: lib.head (lib.splitString "/" address);

  mkPeer = session: {
    endpoint = session.endpoint;
    publicKey = session.publicKey;
    inherit allowedIPs;
    presharedKeyFile =
      if session.preSharedKeyFile == null then null else toString session.preSharedKeyFile;
  };

  mkInterface = name: postUp: session: {
    inherit name;
    value = {
      autostart = true;
      table = "off";
      listenPort = session.listenPort;
      privateKeyFile = toString cfg.local.privateKeyFile;
      inherit postUp;
      peers = [ (mkPeer session) ];
    };
  };

  # 对等会话：两端的地址通过 `ip addr add ... peer ...` 直接写在接口上。
  mkPeeringInterface =
    name: session:
    let
      interfaceName = "dn42-${name}";
      commands =
        lib.optionals (session.addressV4 != null) [
          (ip [
            "addr"
            "add"
            cfg.local.addressV4
            "peer"
            session.addressV4
            "dev"
            interfaceName
          ])
        ]
        ++ lib.optionals (session.addressV6 != null) [
          (ip [
            "addr"
            "add"
            cfg.local.addressV6
            "peer"
            session.addressV6
            "dev"
            interfaceName
          ])
        ]
        ++ lib.optionals (session.localLinkAddressV6 != null) [
          (ip [
            "addr"
            "add"
            cfg.local.localLinkAddressV6
            "peer"
            session.localLinkAddressV6
            "dev"
            interfaceName
          ])
        ]
        ++ [
          (sysctl [
            "-w"
            "net.ipv6.conf.${interfaceName}.autoconf=0"
          ])
        ];
    in
    mkInterface interfaceName (lib.concatStringsSep "\n" commands) session;

  # 静态会话：本机地址直接加到接口；网关模式再补 DN42 网段的静态路由。
  mkStaticInterface =
    name: session:
    let
      commands = [
        (sysctl [
          "-w"
          "net.ipv6.conf.${name}.autoconf=0"
        ])
      ]
      ++ lib.optionals (session.addressV4 != null) [
        (ip [
          "addr"
          "add"
          cfg.local.addressV4
          "dev"
          name
        ])
      ]
      ++ lib.optionals (session.addressV6 != null) [
        (ip [
          "addr"
          "add"
          cfg.local.addressV6
          "dev"
          name
        ])
      ]
      ++ lib.optionals (session.isGateway && session.addressV4 != null) [
        (ip [
          "route"
          "add"
          "172.20.0.0/14"
          "via"
          (stripPrefixLength session.addressV4)
          "dev"
          name
        ])
        (ip [
          "route"
          "add"
          "172.31.0.0/16"
          "via"
          (stripPrefixLength session.addressV4)
          "dev"
          name
        ])
      ]
      ++ lib.optionals (session.isGateway && session.addressV6 != null) [
        (ip [
          "route"
          "add"
          "fd00::/8"
          "via"
          (stripPrefixLength session.addressV6)
          "dev"
          name
        ])
      ];
    in
    mkInterface name (lib.concatStringsSep "\n" commands) session;

  interfaces =
    lib.mapAttrsToList mkPeeringInterface cfg.dn42PeeringSessions
    ++ lib.mapAttrsToList mkStaticInterface cfg.staticSessions;

  interfaceNames = map (interface: interface.name) interfaces;

  listenPorts = lib.unique (
    lib.filter (port: port != null) (
      map (session: session.listenPort) (lib.attrValues cfg.dn42PeeringSessions)
      ++ map (session: session.listenPort) (lib.attrValues cfg.staticSessions)
    )
  );
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.length interfaceNames == lib.length (lib.unique interfaceNames);
        message = "terminus.dn42.wireguard: 会话属性名生成的接口名重复（对等会话会加上 dn42- 前缀，静态会话直接使用属性名）";
      }
      {
        assertion = lib.all (name: lib.stringLength name <= 15) interfaceNames;
        message = "terminus.dn42.wireguard: Linux 接口名最长 15 个字符，请缩短会话属性名";
      }
    ];

    networking.wg-quick.interfaces = builtins.listToAttrs interfaces;

    networking.firewall.allowedUDPPorts = listenPorts;
  };
}
