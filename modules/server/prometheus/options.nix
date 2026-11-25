{ lib, ... }:
let
  target = lib.types.submodule {
    options = {
      address = lib.mkOption {
        type = lib.types.str;
        description = "target 地址（host:port）。";
      };

      labels = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "该 target 的标签。";
      };
    };
  };

  staticJob = lib.types.submodule {
    options = {
      metricsPath = lib.mkOption {
        type = lib.types.str;
        default = "/metrics";
        description = "metrics 路径。";
      };

      targets = lib.mkOption {
        type = lib.types.listOf target;
        default = [ ];
        description = "该 job 的静态 target 列表。";
      };
    };
  };

  probe = lib.types.submodule {
    options = {
      target = lib.mkOption {
        type = lib.types.str;
        description = "blackbox 探测目标（URL 或 host:port）。";
      };

      labels = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "该 probe 的标签。";
      };
    };
  };

  blackboxJob = lib.types.submodule {
    options = {
      jobName = lib.mkOption {
        type = lib.types.str;
        description = "Prometheus job_name。";
      };

      module = lib.mkOption {
        type = lib.types.str;
        default = "http_2xx";
        description = "blackbox exporter module 名。";
      };

      exporter = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1:9115";
        description = "blackbox exporter 地址，写入 __address__ relabel。";
      };

      probes = lib.mkOption {
        type = lib.types.listOf probe;
        default = [ ];
        description = "该 job 的探测目标列表。";
      };
    };
  };
in
{
  options.terminus.prometheus = {
    enable = lib.mkEnableOption "Prometheus 监控服务";

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Prometheus 监听地址。";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9333;
      description = "Prometheus 监听端口。";
    };

    scrapeInterval = lib.mkOption {
      type = lib.types.str;
      default = "15s";
      description = "全局 scrape_interval。";
    };

    evaluationInterval = lib.mkOption {
      type = lib.types.str;
      default = "15s";
      description = "全局 evaluation_interval。";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "是否在防火墙放行 Prometheus 的 TCP 端口。";
    };

    staticScrapeJobs = lib.mkOption {
      type = lib.types.attrsOf staticJob;
      default = { };
      description = "普通 static scrape job，属性名即 job_name。";
    };

    blackboxJobs = lib.mkOption {
      type = lib.types.listOf blackboxJob;
      default = [ ];
      description = "blackbox exporter 探测 job 列表。";
    };

    extraScrapeConfigs = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      description = "额外的原始 Prometheus scrape_config，追加在生成配置之后。";
    };
  };
}
