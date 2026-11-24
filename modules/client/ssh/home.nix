{ ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*" = {
      serverAliveInterval = 120;
      serverAliveCountMax = 30;
    };
  };
}
