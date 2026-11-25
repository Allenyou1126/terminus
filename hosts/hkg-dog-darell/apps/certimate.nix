{ pkgs, ... }:

{
  terminus.certimate = {
    enable = true;
    stateDirectory = "/var/certimate";
    port = 8090;
    environment.CERTIMATE_WORKFLOW_MULTIPROC = "0";
    extraPackages = [ pkgs.sudo ];
  };

  # 源主机允许 certimate 通过本地部署节点重载 nginx。
  security.sudo.extraRules = [
    {
      users = [ "certimate" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/systemctl reload nginx";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
