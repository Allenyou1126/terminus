{ ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "25.05";

  # profiles 只选择模块文件；CN preset 的 enable option 仍需显式打开。
  terminus.nix.substituters.presets.cn = true;

  terminus.nodeExporter = {
    enable = true;
    allowedSources = [ "172.24.24.198" ];
  };
}
