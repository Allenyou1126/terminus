{
  lib,
  terminus,
  ...
}:
let
  # `homes/<user>/default.nix` is imported on every host; role filtering only
  # applies to modules. Treat a standalone home (no host) and a host with
  # roles = null (all roles) as client-capable, matching module selection.
  isClient =
    terminus.host == null || terminus.host.roles == null || builtins.elem "client" terminus.host.roles;
in
lib.optionalAttrs isClient {
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
  };
}
