{ ... }:
{
  home.stateVersion = "25.11";

  programs.git.settings = {
    user.name = "Allen You";
    user.email = "i@allenyou.wang";
  };

  programs.ssh.settings = {
    hkg-dog-darell = {
      hostname = "hkg-dog-darell.server.allenyou.wang";
      port = 2333;
      user = "allenyou";
      identityFile = "~/.ssh/id_ed25519";
    };
    sha-ali-seldon = {
      hostname = "sha-ali-seldon.server.allenyou.wang";
      port = 2333;
      user = "allenyou";
      identityFile = "~/.ssh/id_ed25519";
    };
    sha-ali-gaal = {
      hostname = "sha-ali-gaal.server.allenyou.wang";
      port = 2333;
      user = "allenyou";
      identityFile = "~/.ssh/id_ed25519";
    };
    lax-rn-riose = {
      hostname = "lax-rn-riose.server.allenyou.wang";
      port = 2333;
      user = "allenyou";
      identityFile = "~/.ssh/id_ed25519";
    };
  };
}
