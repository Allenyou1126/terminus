# bird-lg-proxy：通过 BIRD 控制 socket 查询路由，供 bird-lg 前端调用。
{
  lib,
  pkgs,
  ...
}:
{
  options.terminus.dn42.bird-lg-proxy = {
    enable = lib.mkEnableOption "DN42 bird-lg-proxy（需要同时启用 terminus.dn42.bird2）";

    package = lib.mkPackageOption pkgs "bird-lg" { };

    address = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      example = "172.21.89.225";
      description = ''
        监听地址。默认监听所有地址；DN42 中通常绑定到自己的 DN42 地址，
        只让 DN42 内部访问。IPv6 地址可以带方括号，例如 `[fd00::1]`。
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "监听端口；启用时会在防火墙放行对应的 TCP 端口。";
    };
  };
}
