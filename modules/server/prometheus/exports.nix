{ lib, ... }:
{
  prometheus = {
    mkTarget = address: labels: { inherit address labels; };

    mkTargets =
      targets:
      map (
        target:
        if builtins.isString target then
          {
            address = target;
            labels = { };
          }
        else
          target
      ) targets;

    mkStaticJob =
      {
        targets,
        metricsPath ? "/metrics",
      }:
      {
        inherit targets metricsPath;
      };

    mkStaticJobs =
      jobs:
      lib.mapAttrs (_name: targets: {
        inherit targets;
      }) jobs;

    mkProbe = target: labels: { inherit target labels; };

    mkBlackboxJob =
      {
        jobName,
        module ? "http_2xx",
        exporter ? "127.0.0.1:9115",
        probes,
      }:
      {
        inherit
          jobName
          module
          exporter
          probes
          ;
      };
  };
}
