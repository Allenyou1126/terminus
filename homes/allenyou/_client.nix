{
  lib,
  pkgs,
  terminus,
  ...
}:
let
  isClientHost =
    terminus.host != null
    && (terminus.host.roles == null || builtins.elem "client" terminus.host.roles);
in
lib.optionalAttrs isClientHost {
  home.packages = with pkgs; [
    nixfmt-rfc-style
    nil
    just-lsp
  ];

  home.sessionVariables.GPG_TTY = "$(tty)";
}
