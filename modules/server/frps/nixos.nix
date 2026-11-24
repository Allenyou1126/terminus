# FRP 服务端（frps）实现：把 terminus.frp.server 翻译成
# services.frp.instances.server，并根据监听端口与允许端口范围生成防火墙。
#
# 迁移自 sha-ali-seldon 的 host 级 frps.nix；等效主机配置：
#
#   terminus.frp.server = {
#     enable = true;
#     bindPort = 20000;
#     quicBindPort = 20000;
#     allowedPortRanges = [ { start = 20001; end = 20099; } ];
#     openFirewall = true;
#     environmentFiles = [ config.age.secrets.frp-token.path ];
#     auth.tokenEnvironmentVariable = "FRP_TOKEN";
#     settings = {
#       enablePrometheus = true;
#       maxPortsPerClient = 8;
#       natholeAnalysisDataReserveHours = 168;
#       udpPacketSize = 1500;
#       webServer = { addr = "127.0.0.1"; port = 9500; };
#       log = { level = "info"; disablePrintColor = false; };
#       transport = {
#         maxPoolCount = 2000;
#         tcpMux = true;
#         tcpMuxKeepaliveInterval = 60;
#         tcpKeepalive = 7200;
#         tls.force = false;
#       };
#     };
#   };
{
  config,
  lib,
  ...
}:
let
  cfg = config.terminus.frp.server;

  # 这些键由模块生成，settings 中出现会破坏防火墙/监听端口或认证的一致性。
  reservedSettingKeys = [
    "allowPorts"
    "auth"
    "bindAddr"
    "bindPort"
    "quicBindPort"
  ];

  conflictingKeys = lib.filter (key: cfg.settings ? ${key}) reservedSettingKeys;

  # log.to 固定为 /dev/stdout；settings.log 只允许写其它字段。
  invalidLogSettings =
    cfg.settings ? log && (!(lib.isAttrs cfg.settings.log) || (cfg.settings.log ? to));

  allowPorts = map (range: { inherit (range) start end; }) cfg.allowedPortRanges;

  firewallRanges = map (range: {
    from = range.start;
    to = range.end;
  }) cfg.allowedPortRanges;

  generatedSettings = {
    inherit (cfg) bindAddr bindPort;

    auth = {
      method = "token";
      token = "{{ .Envs.${cfg.auth.tokenEnvironmentVariable} }}";
    };

    log.to = "/dev/stdout";
  };

  # 用 recursiveUpdate 而不是 //：settings.log.level 等字段需要与模块生成的
  # log.to 合并，而不是让整个 log 被覆盖。与模块冲突的键已经由断言禁止。
  effectiveSettings = lib.recursiveUpdate generatedSettings (
    (lib.optionalAttrs (cfg.quicBindPort != null) { inherit (cfg) quicBindPort; })
    // (lib.optionalAttrs (cfg.allowedPortRanges != [ ]) { allowPorts = allowPorts; })
    // cfg.settings
  );
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = conflictingKeys == [ ];
        message = "terminus.frp.server.settings 不能包含以下键：${lib.concatStringsSep ", " conflictingKeys}；请改用 terminus.frp.server 的同名选项（auth 由模块生成，log.to 固定为 /dev/stdout）";
      }
      {
        assertion = !invalidLogSettings;
        message = "terminus.frp.server.settings.log 必须是 attrset，且不能设置 log.to：模块固定 log.to = \"/dev/stdout\"";
      }
      {
        assertion = cfg.bindPort != 0;
        message = "terminus.frp.server.bindPort 不能是 0";
      }
      {
        assertion = cfg.quicBindPort == null || cfg.quicBindPort != 0;
        message = "terminus.frp.server.quicBindPort 为 null 表示关闭 QUIC；设置时不能是 0";
      }
      {
        assertion = lib.all (range: range.start <= range.end) cfg.allowedPortRanges;
        message = "terminus.frp.server.allowedPortRanges 的每一项都必须满足 start <= end";
      }
    ];

    warnings =
      lib.optional (cfg.environmentFiles == [ ])
        "terminus.frp.server.environmentFiles 为空：auth.token 的 {{ .Envs.${cfg.auth.tokenEnvironmentVariable} }} 占位符会展开为空，frps 将以空 token 运行；请通过 agenix 等提供环境变量文件。"
      ++ lib.optional (
        cfg.allowedPortRanges == [ ]
      ) "terminus.frp.server.allowedPortRanges 为空：frps 不限制 frpc 申请端口；公网部署建议设置范围。";

    services.frp = {
      inherit (cfg) package;
      instances.server = {
        enable = true;
        role = "server";
        inherit (cfg) environmentFiles;
        settings = effectiveSettings;
      };
    };

    networking.firewall = {
      allowedTCPPorts = lib.optional cfg.openFirewall cfg.bindPort;
      allowedUDPPorts = lib.optionals (cfg.openFirewall && cfg.quicBindPort != null) [
        cfg.quicBindPort
      ];
      allowedTCPPortRanges = lib.optionals cfg.openFirewall firewallRanges;
      allowedUDPPortRanges = lib.optionals cfg.openFirewall firewallRanges;
    };
  };
}
