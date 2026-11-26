{
  lib,
  terminus,
  ...
}:
let
  # `homes/<user>/default.nix` is imported on every host; profile filtering
  # only applies to modules. A standalone home (no host) is treated as
  # client-capable because only the implicit default profile is applied there.
  isClient = terminus.host == null || builtins.elem "client" terminus.host.profiles;
in
lib.optionalAttrs isClient {
  programs.ssh.enable = true;

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
    home-ebeling = {
      hostname = "192.168.100.60";
      port = 2333;
      user = "allenyou";
      identityFile = "~/.ssh/id_ed25519";
    };
    "github.com" = {
      hostname = "ssh.github.com";
      port = 443;
      user = "git";
      identityFile = "~/.ssh/id_ed25519";
    };
    "git.dn42.dev" = {
      hostname = "git.dn42.dev";
      port = 22;
      user = "git";
      identityFile = "~/.ssh/id_ed25519";
    };
  };
}
