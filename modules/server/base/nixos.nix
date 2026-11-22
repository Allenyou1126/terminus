{ terminus, ... }:
{
  environment.variables.TERMINUS_SERVER = "1";

  # Secrets helper example. Create secrets/demo-token.age and the matching
  # rule in secrets/secrets.nix before uncommenting.
  #
  # age.secrets.demo-token =
  #   terminus.secrets.secret {
  #     name = "demo-token";
  #     owner = "demo";
  #     mode = "0400";
  #   };
}
