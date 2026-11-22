let
  keys = import ./keys.nix;
in
{
  # Every encrypted file is <name>.age, regardless of which hosts read it.
  # "demo-token.age".publicKeys =
  #   builtins.attrValues keys.hostKeys ++ keys.adminKeys;
}
