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

      # Store directory used by the default `file` values. Interpolating the
      # path keeps the store context so `nix copy` sends secrets/*.age to the
      # target; `root` stays the human-facing source path.
      storeRoot = "${secretsDir}";

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
          # Interpolate the path itself so Nix keeps the store context. Using
          # the `toString`-derived `root` here drops context and Colmena would
          # not copy secrets/*.age to the target.
          file = args.file or "${secretsDir}/${name}.age";
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
      inherit root storeRoot secret;
    };
}
