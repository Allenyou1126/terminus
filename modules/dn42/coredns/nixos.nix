# DN42 CoreDNS 实现：渲染 Corefile 和 zone 文件，并放行 DNS 端口。
{
  config,
  lib,
  ...
}:

let
  cfg = config.terminus.dn42.coredns;

  mkRecord =
    record: "${record.name} ${toString record.ttl} ${record.class} ${record.type} ${record.value}";

  mkSoaRecord =
    soa:
    "@ IN SOA ${soa.mname} ${soa.rname} ${toString soa.serial} ${toString soa.refresh} "
    + "${toString soa.retry} ${toString soa.expire} ${toString soa.minimum}";

  mkZoneText =
    zone:
    lib.concatLines (
      [
        "$ORIGIN ${zone.zone}"
        "$TTL ${toString zone.defaultTtl}"
      ]
      ++ lib.optional (zone.soa != null) (mkSoaRecord zone.soa)
      ++ map mkRecord zone.records
    );

  zoneFiles = builtins.listToAttrs (
    map (zone: {
      name = "coredns/zones/${zone.fileName}";
      value = {
        text = mkZoneText zone;
      };
    }) cfg.zoneFiles
  );

  renderPlugin =
    plugin: "    " + (if lib.isList plugin then lib.concatStringsSep " " plugin else plugin);

  renderServerBlock =
    server:
    lib.concatLines (
      [ "${server.zone}:${toString server.port} {" ]
      ++ lib.optionals (server.plugins != [ ]) (map renderPlugin server.plugins)
      ++ [ "}" ]
    );

  corefile = lib.concatStringsSep "\n\n" (map renderServerBlock cfg.serverBlocks);

  openedPorts = lib.unique (map (server: server.port) cfg.serverBlocks);

  zoneFileNames = map (zone: zone.fileName) cfg.zoneFiles;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.serverBlocks != [ ];
        message = "terminus.dn42.coredns: 启用时至少需要一个 serverBlocks 条目，否则 CoreDNS 没有可服务的配置";
      }
      {
        assertion = lib.length zoneFileNames == lib.length (lib.unique zoneFileNames);
        message = "terminus.dn42.coredns: zoneFiles 的 fileName 必须唯一";
      }
    ];

    services.coredns = {
      enable = true;
      package = cfg.package;
      config = corefile;
      extraArgs = cfg.extraCommandLineOptions;
    };

    environment.etc = zoneFiles;

    networking.firewall = {
      allowedTCPPorts = openedPorts;
      allowedUDPPorts = openedPorts;
    };
  };
}
