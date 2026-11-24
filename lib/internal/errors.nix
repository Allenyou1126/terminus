# Consistent, actionable error messages for the framework.
{ lib }:
{
  invalidMeta =
    file: expected: got:
    throw ''
      terminus: invalid meta.nix
        file:     ${toString file}
        expected: ${expected}
        got:      ${got}
    '';

  missingFile = file: throw "terminus: missing required file: ${toString file}";

  missingHostSystem =
    host:
    throw ''
      terminus: hosts/${host}/meta.nix must declare a system
      example:
        { system = "x86_64-linux"; }
    '';

  unknownHost =
    host:
    throw ''
      terminus: unknown host '${host}'
      create hosts/${host}/ with meta.nix and default.nix first
    '';

  unknownUser = user: throw "terminus: unknown user '${user}'";

  duplicate = kind: name: throw "terminus: duplicate ${kind} '${name}'";

  invalidModuleExport =
    module: got:
    throw ''
      terminus: module '${module}' exports.nix must return an attribute set
        got: ${got}
    '';

  duplicateExport =
    key: first: second:
    throw ''
      terminus: duplicate module export '${key}'
        defined by: ${first}
        also by:    ${second}
    '';

  unknownModule = kind: name: throw "terminus: unknown ${kind} '${name}'";

  unknownProfile = profile: throw "terminus: unknown profile '${profile}'";

  profileCycle =
    chain: throw "terminus: profile inheritance cycle: ${lib.concatStringsSep " -> " chain}";

  moduleCycle = names: throw "terminus: module dependency cycle: ${lib.concatStringsSep ", " names}";

  missingDependency =
    name: dep: throw "terminus: module '${name}' requires '${dep}', but '${dep}' is not enabled";

  moduleConflict = name: other: throw "terminus: modules '${name}' and '${other}' conflict";

  missingInput =
    name:
    throw ''
      terminus: missing required flake input '${name}'
      add it to flake.nix and pass it through `mkFlake { inherit inputs; }`
    '';

  badSecretsDir =
    dir:
    throw ''
      terminus: secretsDir must be a directory (path or string).
        got: ${builtins.typeOf dir}
        if it comes from a flake input, set `flake = false`.
    '';

  missingSecretsDir =
    dir:
    throw ''
      terminus: secretsDir does not exist: ${toString dir}
      create it locally or pass an external directory.
    '';
}
