{ ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      ClientAliveInterval = 30;
      ClientAliveCountMax = 3;
    };
    ports = [ 2333 ];
    openFirewall = true;
    sftpServerExecutable = "internal-sftp";
  };

  programs.ssh.startAgent = true;
}
