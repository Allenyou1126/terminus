# DN42 CoreDNS 选项。
#
# 模块只负责把声明式的 zone / server block 渲染成 Corefile 和 zone 文件，
# 并放行对应端口；DN42 的域名和反向解析记录都通过这里的选项管理。
{
  lib,
  pkgs,
  ...
}:
let
  types = {
    server = lib.types.submodule {
      options = {
        port = lib.mkOption {
          type = lib.types.port;
          default = 53;
          description = "该 server block 监听的端口。";
        };
        zone = lib.mkOption {
          type = lib.types.str;
          example = "allenyou.dn42";
          description = "该 server block 服务的 DNS 区域（Corefile 里的 zone 部分）。";
        };
        plugins = lib.mkOption {
          type = lib.types.listOf (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
          default = [ ];
          example = [
            "log"
            [
              "file"
              "/etc/coredns/zones/allenyou.dn42.zone"
            ]
            [
              "bind"
              "172.21.89.225"
            ]
          ];
          description = ''
            server block 里启用的 CoreDNS 插件。字符串会原样写入一行；
            字符串列表会用空格连接后再写入（用于带参数的插件）。
          '';
        };
      };
    };

    zoneFile = lib.types.submodule {
      options = {
        fileName = lib.mkOption {
          type = lib.types.str;
          example = "allenyou.dn42.zone";
          description = "zone 文件名，最终路径为 `/etc/coredns/zones/<fileName>`。";
        };
        zone = lib.mkOption {
          type = lib.types.str;
          example = "allenyou.dn42.";
          description = "zone 文件里的 `$ORIGIN`，通常以点结尾。";
        };
        defaultTtl = lib.mkOption {
          type = lib.types.int;
          default = 300;
          description = "zone 文件里的 `$TTL`，也是记录的默认 TTL。";
        };
        records = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                name = lib.mkOption {
                  type = lib.types.str;
                  example = "ns1";
                  description = "记录名；`@` 表示 zone 本身。";
                };
                class = lib.mkOption {
                  type = lib.types.str;
                  default = "IN";
                  description = "记录 class，通常保持 `IN`。";
                };
                type = lib.mkOption {
                  type = lib.types.str;
                  example = "A";
                  description = "记录类型，例如 `A`、`AAAA`、`CNAME`、`PTR`、`NS`。";
                };
                value = lib.mkOption {
                  type = lib.types.str;
                  example = "172.21.89.225";
                  description = "记录值。";
                };
                ttl = lib.mkOption {
                  type = lib.types.int;
                  default = 300;
                  description = "该记录的 TTL（秒）。";
                };
              };
            }
          );
          default = [ ];
          description = "zone 文件中的静态记录。";
        };
        soa = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.submodule {
              options = {
                mname = lib.mkOption {
                  type = lib.types.str;
                  example = "ns1.allenyou.dn42.";
                  description = "zone 的主名称服务器（SOA MNAME）。";
                };
                rname = lib.mkOption {
                  type = lib.types.str;
                  example = "i.allenyou.wang.";
                  description = "zone 负责人邮箱（SOA RNAME，点代替 @）。";
                };
                serial = lib.mkOption {
                  type = lib.types.int;
                  default = 0;
                  description = "zone 序列号；修改记录时需要递增。";
                };
                refresh = lib.mkOption {
                  type = lib.types.int;
                  default = 28800;
                  description = "从服务器刷新间隔（秒）。";
                };
                retry = lib.mkOption {
                  type = lib.types.int;
                  default = 7200;
                  description = "刷新失败后的重试间隔（秒）。";
                };
                expire = lib.mkOption {
                  type = lib.types.int;
                  default = 604800;
                  description = "从服务器数据过期时间（秒）。";
                };
                minimum = lib.mkOption {
                  type = lib.types.int;
                  default = 60;
                  description = "否定回答的缓存时间（秒）。";
                };
              };
            }
          );
          default = null;
          description = "可选的 SOA 记录；为 null 时 zone 文件里不写 SOA。";
        };
      };
    };
  };
in
{
  options.terminus.dn42.coredns = {
    enable = lib.mkEnableOption "DN42 CoreDNS 权威 DNS";

    package = lib.mkPackageOption pkgs "coredns" { };

    serverBlocks = lib.mkOption {
      type = lib.types.listOf types.server;
      default = [ ];
      description = ''
        Corefile 中的 server block 列表，每个条目对应一个 zone 和一组插件。
        启用时必须至少有一个条目，否则 CoreDNS 没有可服务的配置。
      '';
    };

    zoneFiles = lib.mkOption {
      type = lib.types.listOf types.zoneFile;
      default = [ ];
      description = ''
        要写入 `/etc/coredns/zones/` 的 zone 文件。文件名必须唯一；
        server block 的 `file` 插件通过绝对路径引用它们。
      '';
    };

    extraCommandLineOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "-dns.port=53" ];
      description = "追加到 CoreDNS 命令行的参数（对应 `services.coredns.extraArgs`）。";
    };
  };
}
