{
  lib,
  pkgs,
  terminus,
  ...
}:
let
  isClientHost = terminus.host != null && builtins.elem "client" terminus.host.profiles;
in
lib.optionalAttrs isClientHost {
  home.packages = with pkgs; [
    nixfmt-rfc-style
    nil
    just-lsp
  ];

  home.sessionVariables.GPG_TTY = "$(tty)";
}
