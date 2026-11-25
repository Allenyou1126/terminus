{
  config,
  lib,
  ...
}:
let
  cfg = config.terminus.prometheus;

  staticScrapeConfigs = lib.mapAttrsToList (name: job: {
    job_name = name;
    metrics_path = job.metricsPath;
    static_configs = map (target: {
      targets = [ target.address ];
      inherit (target) labels;
    }) job.targets;
  }) cfg.staticScrapeJobs;

  blackboxScrapeConfigs = map (job: {
    job_name = job.jobName;
    metrics_path = "/probe";
    params.module = [ job.module ];
    relabel_configs = [
      {
        source_labels = [ "__address__" ];
        target_label = "__param_target";
      }
      {
        source_labels = [ "__param_target" ];
        target_label = "url";
      }
      {
        target_label = "__address__";
        replacement = job.exporter;
      }
    ];
    static_configs = map (probe: {
      targets = [ probe.target ];
      inherit (probe) labels;
    }) job.probes;
  }) cfg.blackboxJobs;

  scrapeConfigs = staticScrapeConfigs ++ blackboxScrapeConfigs ++ cfg.extraScrapeConfigs;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.port != 0;
        message = "terminus.prometheus.port 不能是 0";
      }
      {
        assertion = cfg.scrapeInterval != "";
        message = "terminus.prometheus.scrapeInterval 不能为空";
      }
      {
        assertion = cfg.evaluationInterval != "";
        message = "terminus.prometheus.evaluationInterval 不能为空";
      }
    ];

    services.prometheus = {
      enable = true;
      inherit (cfg) listenAddress port;
      globalConfig = {
        scrape_interval = cfg.scrapeInterval;
        evaluation_interval = cfg.evaluationInterval;
      };
      inherit scrapeConfigs;
    };

    networking.firewall.allowedTCPPorts = lib.optional cfg.openFirewall cfg.port;
  };
}
