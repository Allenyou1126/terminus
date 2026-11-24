# FRP 服务端（frps）的 NixOS 模块选项。
#
# 本模块只实现 server role 的 frps，与未来 frpc 模块共享 `terminus.frp`
# 命名空间：这里声明 `terminus.frp.server`，客户端模块可声明
# `terminus.frp.client`；frp 实例名也固定为 `server`，未来客户端用
# `client`，因此两边不会互相覆盖选项或 systemd 服务。
#
# auth 与 log.to 由模块独占：auth 固定 token 模式，token 用环境变量占位符
# 从 environmentFiles 读取；log.to 固定 /dev/stdout，交给 systemd journal。
# 因此 settings 中不能出现 auth 或 log.to（会触发断言）。
#
# 迁移自 sha-ali-seldon 的 host 级 frps.nix；完整等效配置示例见 nixos.nix。
{
  lib,
  pkgs,
  ...
}:
let
  portRange = lib.types.submodule {
    options = {
      start = lib.mkOption {
        type = lib.types.ints.between 1 65535;
        example = 20001;
        description = "允许端口范围的起始端口（含）。单个端口时与 end 相同。";
      };

      end = lib.mkOption {
        type = lib.types.ints.between 1 65535;
        example = 20099;
        description = "允许端口范围的结束端口（含）。必须不小于 start。";
      };
    };
  };
in
{
  options.terminus.frp.server = {
    enable = lib.mkEnableOption "FRP 服务端（frps）";

    package = lib.mkPackageOption pkgs "frp" { };

    bindAddr = lib.mkOption {
      type = lib.types.nonEmptyStr;
      default = "0.0.0.0";
      example = "127.0.0.1";
      description = ''
        frps 控制面监听地址，写入 `bindAddr`。

        默认监听所有地址；需要只绑定具体网卡时改这里。IPv6 地址直接写
        `::`，不要加方括号。
      '';
    };

    bindPort = lib.mkOption {
      type = lib.types.port;
      default = 7000;
      example = 20000;
      description = ''
        frps 控制面 TCP 端口，写入 `bindPort`，不能为 0。

        {option}`terminus.frp.server.openFirewall` 开启时会在防火墙放行该
        TCP 端口。
      '';
    };

    quicBindPort = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      example = 7000;
      description = ''
        QUIC（UDP）监听端口，写入 `quicBindPort`。为 null 时不写该键，
        frp 默认关闭 QUIC；需要 QUIC 时通常设为与
        {option}`terminus.frp.server.bindPort` 相同。

        {option}`terminus.frp.server.openFirewall` 开启时会在防火墙放行该
        UDP 端口。
      '';
    };

    allowedPortRanges = lib.mkOption {
      type = lib.types.listOf portRange;
      default = [ ];
      example = [
        {
          start = 20001;
          end = 20099;
        }
      ];
      description = ''
        frps 允许 frpc 申请的端口范围，写入 `allowPorts`。

        每一项都是闭区间；单个端口用 `start = end = N` 表示。为空时不写
        `allowPorts`，此时 frp 默认不限制客户端申请端口（模块会给出告警）。

        {option}`terminus.frp.server.openFirewall` 开启时会同时放行这些范围
        的 TCP 与 UDP 端口。
      '';
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.externalPath;
      default = [ ];
      example = [ "/run/agenix/frp-token" ];
      description = ''
        systemd `EnvironmentFile=` 列表，每项是 `KEY=VALUE` 格式的文件路径。

        模块生成的 `auth.token = "{{ .Envs.<变量名> }}"` 从这里读取实际
        token；通常由 agenix 注入，例如
        `config.age.secrets.frp-token.path`。变量名由
        {option}`terminus.frp.server.auth.tokenEnvironmentVariable` 控制。

        类型是 `externalPath`：Nix store 路径会被拒绝，避免把密钥复制进
        全局可读的 store。值为空时模块只告警，不阻止求值。
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        是否放行 frps 的入站端口：TCP `bindPort`、UDP `quicBindPort`，以及
        `allowedPortRanges` 的 TCP/UDP 范围。

        不包含 `webServer` / `metricsServer` 的端口；dashboard 通常只监听
        127.0.0.1，需要对外访问时请另行放行或走反向代理。
      '';
    };

    auth.tokenEnvironmentVariable = lib.mkOption {
      type = lib.types.strMatching "[A-Za-z_][A-Za-z0-9_]*";
      default = "FRP_TOKEN";
      example = "FRP_TOKEN";
      description = ''
        模块生成 `auth.token = "{{ .Envs.<变量名> }}"` 时使用的环境变量名。

        本模块固定 `auth.method = "token"`，并在 settings 中禁止 `auth`，
        避免把 token 写进 Nix store，也避免未来 frpc 模块的认证选项与这里
        互相覆盖。变量的实际值由
        {option}`terminus.frp.server.environmentFiles` 提供。
      '';
    };

    settings = lib.mkOption {
      type = (pkgs.formats.toml { }).type;
      default = { };
      example = lib.literalExpression ''
        {
          enablePrometheus = true;
          webServer = { addr = "127.0.0.1"; port = 9500; };
          log = { level = "info"; disablePrintColor = false; };
          transport = { tcpMux = true; tls.force = false; };
        }
      '';
      description = ''
        其余 frps TOML 配置，写入
        `services.frp.instances.server.settings`。

        模块独占以下键，写在 settings 里会触发断言：

        - `auth`：由模块生成 token 认证；
        - `log.to`：固定为 `/dev/stdout`，交给 systemd journal；
        - `bindAddr` / `bindPort` / `quicBindPort` / `allowPorts`：请使用
          上面的同名选项，保证防火墙与实际监听端口一致。

        `log.level`、`log.disablePrintColor` 等其它字段可以正常写。密钥不要
        放进这里：Nix store 全局可读；token 走
        {option}`terminus.frp.server.environmentFiles`。
      '';
    };
  };
}
