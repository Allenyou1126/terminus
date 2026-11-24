{
  config,
  terminus,
  ...
}:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "25.11";

  terminus.nodeExporter = {
    enable = true;
    allowedSources = [
      "192.168.100.0/24"
      "192.168.103.0/24"
    ];
  };

  age.secrets.deepseek-harness-secret = terminus.secrets.secret {
    name = "deepseek-harness-secret";
  };

  terminus.deepseekHarness.server = {
    enable = true;
    host = "192.168.100.60";
    publicUrl = "https://dsh.allenyou.top/";
    trustedHosts = [ "dsh.allenyou.top" ];
    openFirewall = true;
    environmentFile = config.age.secrets.deepseek-harness-secret.path;
  };
}
