{
  config,
  terminus,
  ...
}:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "25.11";

  # profiles 只决定模块文件是否导入，不会打开模块的 enable option；
  # _common 模块常驻导入，所以 CN 镜像仍要在这里显式启用。
  terminus.nix.substituters.presets.cn = true;

  terminus.nodeExporter = {
    enable = true;
    listenAddress = "0.0.0.0";
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
