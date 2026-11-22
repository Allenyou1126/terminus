# secretsDir helper. The directory is the only source of paths: it can be a
# local directory or a flake input with `flake = false`.
{ lib }:
let
  errors = import ./internal/errors.nix { inherit lib; };
  inherit (builtins) isPath isString removeAttrs;
in
{
  mk =
    { secretsDir }:
    let
      root = toString secretsDir;

      checkDir =
        if !(isPath secretsDir || isString secretsDir) then
          errors.badSecretsDir secretsDir
        else if !(builtins.pathExists root) then
          errors.missingSecretsDir root
        else
          true;

      secret =
        args:
        let
          name = args.name or (throw "terminus.secrets.secret: missing name");
          file = args.file or "${root}/${name}.age";
          options = removeAttrs args [
            "name"
            "file"
          ];
        in
        assert checkDir;
        assert isString name;
        options
        // {
          inherit file;
        };
    in
    {
      inherit root secret;
    };
}
