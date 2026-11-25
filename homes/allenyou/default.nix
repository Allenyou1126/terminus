{ ... }:
{
  imports = [
    ./_client.nix
    ./_git.nix
    ./_ssh.nix
  ];

  home.stateVersion = "25.11";
}
