{ pkgs, lib, ... }:
let
  config = pkgs.writeText "treefmt.toml" (builtins.readFile ../treefmt.toml);
in
pkgs.writeShellScriptBin "fmt" ''
  export PATH="${lib.makeBinPath [ pkgs.nixfmt ]}:$PATH"
  exec ${pkgs.treefmt}/bin/treefmt --config-file ${config} "$@"
''
