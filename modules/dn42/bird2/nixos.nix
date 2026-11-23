# DN42 BIRD2 实现：渲染 BIRD 配置、维护 ROA 表并加固 systemd 单元。
#
# ROA 文件放在 /tmp/dn42/ 而不是 /run：`services.bird.checkConfig` 在构建沙箱
# 里执行，沙箱内只有 /tmp 可写，用 /run 会让构建期的配置检查失败。该目录由
# systemd-tmpfiles 以 bird 用户创建（0750），其他本地用户无法写入或替换文件。
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.terminus.dn42.bird2;

  roaDir = "/tmp/dn42";
  roaV4File = "${roaDir}/roa_v4.conf";
  roaV6File = "${roaDir}/roa_v6.conf";

  roaUrls = {
    ipv4 = "https://dn42.burble.com/roa/dn42_roa_bird2_4.conf";
    ipv6 = "https://dn42.burble.com/roa/dn42_roa_bird2_6.conf";
  };

  # 先下载到同目录的临时文件，全部成功后再 rename 覆盖，避免 BIRD 读到
  # 下载到一半的 ROA 表；rename 也不会跟随 /tmp 里可能存在的符号链接。
  roaUpdater = pkgs.writeShellApplication {
    name = "dn42-roa-update";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.wget
    ];
    text = ''
      dir=${lib.escapeShellArg roaDir}

      mkdir -p "$dir"

      tmp=$(mktemp -d "$dir/update.XXXXXX")
      trap 'rm -rf "$tmp"' EXIT

      wget -4 -q -O "$tmp/v4.conf" ${lib.escapeShellArg roaUrls.ipv4}
      wget -4 -q -O "$tmp/v6.conf" ${lib.escapeShellArg roaUrls.ipv6}

      # cron 以 root 运行本脚本，而 BIRD 以 bird 用户读取 ROA 表；统一成
      # 0644（目录本身是 0750，其他用户无法进入）保证两种身份都能读取。
      chmod 0644 "$tmp/v4.conf" "$tmp/v6.conf"

      mv -f "$tmp/v4.conf" "$dir/roa_v4.conf"
      mv -f "$tmp/v6.conf" "$dir/roa_v6.conf"
    '';
  };

  ownV4 = cfg.ownNetwork.ipv4;
  ownV6 = cfg.ownNetwork.ipv6;

  # 协议名只允许字母、数字和下划线，所以属性名里的连字符要换掉。
  protocolName = name: builtins.replaceStrings [ "-" ] [ "_" ] name;

  commonConfig = ''
    define OWNAS       = ${toString cfg.ownNetwork.asn};
    define OWNIPv4     = ${ownV4.ip};
    define OWNNETv4    = ${ownV4.cidr};
    define OWNNETSETv4 = [ ${ownV4.cidr}+ ];
    define OWNIPv6     = ${ownV6.ip};
    define OWNNETv6    = ${ownV6.cidr};
    define OWNNETSETv6 = [ ${ownV6.cidr}+ ];

    router id OWNIPv4;

    function is_self_net_v4() -> bool {
        return net ~ OWNNETSETv4;
    }

    function is_self_net_v6() -> bool {
        return net ~ OWNNETSETv6;
    }

    protocol device {
        scan time 10;
    }

    function is_valid_network_v4() -> bool {
        return net ~ [
            172.20.0.0/14{21,29}, # dn42
            172.20.0.0/24{28,32}, # dn42 Anycast
            172.21.0.0/24{28,32}, # dn42 Anycast
            172.22.0.0/24{28,32}, # dn42 Anycast
            172.23.0.0/24{28,32}, # dn42 Anycast
            172.31.0.0/16+,       # ChaosVPN
            10.100.0.0/14+,       # ChaosVPN
            10.127.0.0/16{16,32}, # neonetwork
            10.0.0.0/8{15,24}     # Freifunk.net
        ];
    }

    function is_valid_network_v6() -> bool {
        return net ~ [
            fd00::/8{44,64} # ULA address space as per RFC 4193
        ];
    }

    protocol kernel {
        scan time 20;

        ipv4 {
            import none;
            export filter {
                if source = RTS_STATIC then reject;
                krt_prefsrc = OWNIPv4;
                accept;
            };
        };
    }

    protocol kernel {
        scan time 20;

        ipv6 {
            import none;
            export filter {
                if source = RTS_STATIC then reject;
                krt_prefsrc = OWNIPv6;
                accept;
            };
        };
    }
  '';

  roaConfig = lib.optionalString cfg.enableRoa ''
    roa4 table dn42_roa_v4_table;
    roa6 table dn42_roa_v6_table;

    protocol static dn42_roa_v4 {
        roa4 { table dn42_roa_v4_table; };
        include "${roaV4File}";
    };

    protocol static dn42_roa_v6 {
        roa6 { table dn42_roa_v6_table; };
        include "${roaV6File}";
    };
  '';

  mkRpkiSession = name: server: ''
    protocol rpki rpki_${protocolName name} {
        roa4 { table dn42_roa_v4_table; };
        roa6 { table dn42_roa_v6_table; };
        remote "${server.address}" port ${toString server.port};
        retry keep ${toString server.retry};
        refresh keep ${toString server.refresh};
        expire keep ${toString server.expire};
    };
  '';

  rpkiConfig = lib.optionalString cfg.enableRoa (
    lib.concatStrings (lib.attrValues (lib.mapAttrs mkRpkiSession cfg.rpkiServers))
  );

  roaRejectV4 = lib.optionalString cfg.enableRoa ''
    if (roa_check(dn42_roa_v4_table, net, bgp_path.last) != ROA_VALID) then {
        print "[dn42] ROA check failed for ", net, " ASN ", bgp_path.last;
        reject;
    }
  '';

  roaRejectV6 = lib.optionalString cfg.enableRoa ''
    if (roa_check(dn42_roa_v6_table, net, bgp_path.last) != ROA_VALID) then {
        print "[dn42] ROA check failed for ", net, " ASN ", bgp_path.last;
        reject;
    }
  '';

  templateConfig = ''
    template bgp dn42peers {
        local as OWNAS;
        path metric 1;
        ipv4 {
            import filter {
                if is_valid_network_v4() && !is_self_net_v4() then {
                    ${roaRejectV4}
                    accept;
                }
                reject;
            };

            export filter {
                if is_valid_network_v4() && source ~ [RTS_STATIC, RTS_BGP] then accept;
                reject;
            };
            import limit 1000 action block;
            extended next hop yes;
        };
        ipv6 {
            import filter {
                if is_valid_network_v6() && !is_self_net_v6() then {
                    ${roaRejectV6}
                    accept;
                }
                reject;
            };

            export filter {
                if is_valid_network_v6() && source ~ [RTS_STATIC, RTS_BGP] then accept;
                reject;
            };
            import limit 1000 action block;
            extended next hop yes;
        };
    }
  '';

  # 每个地址族单独渲染：neighborV4/V6 为 null 时不生成对应会话。
  # multiProtocol* 为 false 时，显式关闭该会话里另一地址族的通道。
  mkPeeringSession =
    name: peer:
    let
      protocol = protocolName name;
      mkSession =
        suffix: neighbor: disabledChannel: multiProtocol:
        lib.concatStringsSep "\n" (
          [
            "protocol bgp dn42_${protocol}_${suffix} from dn42peers {"
            "    neighbor ${neighbor} % '${peer.networkInterface}' as ${toString peer.neighborAS};"
            "    direct;"
          ]
          ++ lib.optionals (!multiProtocol) [
            "    ${disabledChannel} {"
            "        import none;"
            "        export none;"
            "    };"
          ]
          ++ [
            "};"
            ""
          ]
        );
    in
    lib.optionalString (peer.neighborV4 != null) (
      mkSession "v4" peer.neighborV4 "ipv6" peer.multiProtocolV4
    )
    + lib.optionalString (peer.neighborV6 != null) (
      mkSession "v6" peer.neighborV6 "ipv4" peer.multiProtocolV6
    );

  peeringConfig = lib.concatStrings (
    lib.attrValues (lib.mapAttrs mkPeeringSession cfg.peeringSessions)
  );

  # 静态会话同样按地址族分别渲染；两个地址都为空时不会产生空协议块。
  mkStaticSession =
    name: session:
    let
      protocol = protocolName name;
      mkProtocol = suffix: channel: neighbor: ownNet: ''
        protocol static static_${protocol}_${suffix} {
            route ${neighbor} via "${session.networkInterface}";
            route ${ownNet} reject;

            ${channel} {
                import all;
                export none;
            };
        }
      '';
    in
    lib.optionalString (session.neighborV4 != null) (
      mkProtocol "v4" "ipv4" session.neighborV4 "OWNNETv4"
    )
    + lib.optionalString (session.neighborV6 != null) (
      mkProtocol "v6" "ipv6" session.neighborV6 "OWNNETv6"
    );

  staticConfig = lib.concatStrings (lib.attrValues (lib.mapAttrs mkStaticSession cfg.staticSessions));

  birdConfig = lib.concatStrings [
    commonConfig
    roaConfig
    rpkiConfig
    templateConfig
    peeringConfig
    staticConfig
  ];
in
{
  config = lib.mkIf cfg.enable {
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.default.forwarding" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
      "net.ipv4.conf.default.rp_filter" = 0;
      "net.ipv4.conf.all.rp_filter" = 0;
      "net.ipv6.conf.default.rp_filter" = 0;
      "net.ipv6.conf.all.rp_filter" = 0;
    };

    services.bird = {
      enable = true;
      package = cfg.package;
      # BIRD 在构建期检查配置；先创建 include 的 ROA 文件，否则检查会失败。
      preCheckConfig = lib.optionalString cfg.enableRoa ''
        mkdir -p ${roaDir}
        touch ${roaV4File} ${roaV6File}
      '';
      config = birdConfig;
    };

    systemd.tmpfiles.rules = lib.optionals cfg.enableRoa [
      "d ${roaDir} 0750 bird bird -"
      "f ${roaV4File} 0640 bird bird -"
      "f ${roaV6File} 0640 bird bird -"
    ];

    systemd.services.bird.serviceConfig = lib.mkForce (
      {
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateMounts = true;
        # ROA 表在 /tmp 下，必须和主机共享 /tmp。
        PrivateTmp = false;
        ProcSubset = "pid";
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        # ProtectSystem=strict 会把 /tmp 也变成只读，ROA 目录需要单独放行，
        # 否则 ExecStartPre 无法更新 ROA 表。
        ReadWritePaths = lib.optionals cfg.enableRoa [ roaDir ];
        RemoveIPC = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallErrorNumber = "EPERM";
        PrivateDevices = false;
        ProtectClock = false;
        ProtectControlGroups = false;
        AmbientCapabilities = [
          "CAP_NET_ADMIN"
          "CAP_NET_BIND_SERVICE"
          "CAP_NET_RAW"
        ];
        CapabilityBoundingSet = [
          "CAP_NET_ADMIN"
          "CAP_NET_BIND_SERVICE"
          "CAP_NET_RAW"
        ];
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
        ];
        SystemCallFilter = [ ];
        ExecStart = "${lib.getExe' cfg.package "bird"} -f -c /etc/bird/bird.conf";
        ExecReload = "${lib.getExe' cfg.package "birdc"} configure";

        CPUQuota = "10%";
        Restart = "always";

        User = "bird";
        Group = "bird";
        RuntimeDirectory = "bird";
      }
      // lib.optionalAttrs cfg.enableRoa {
        # 下载失败不阻塞 BIRD 启动：tmpfiles 已创建空 ROA 表，cron 稍后会重试
        # 并在成功后 reload。前缀 `-` 表示 systemd 忽略该步骤的失败。
        ExecStartPre = [ "-${roaUpdater}/bin/dn42-roa-update" ];
      }
    );

    services.cron.enable = lib.mkIf cfg.enableRoa true;
    services.cron.systemCronJobs = lib.optional cfg.enableRoa (
      "0 * * * * root ${roaUpdater}/bin/dn42-roa-update && ${config.systemd.package}/bin/systemctl reload bird.service"
    );
  };
}
