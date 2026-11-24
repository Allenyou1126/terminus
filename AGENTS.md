# Terminus agent notes

- Nixpkgs is pinned to `nixos-26.05`; Home Manager to `release-26.05`.
- `lib/` is the framework. `lib/secret.nix` is a secrets helper, **not** the
  agenix rules file; the rules live in `secrets/secrets.nix`.
- `nixosConfigurations` are standard `nixosSystem` values. `colmenaHive` is
  built separately from the same `host.modules` list and adds a shim so both
  toplevels are identical. Never make shared host modules depend on Colmena's
  `name`/`nodes`/`deployment` options.
- The consistency check is `checks.<system>.terminus-colmena-consistency`.
  If it fails, inspect the shim in `lib/hive.nix` before changing modules.
- Secrets are one directory (`secretsDir`) and uniform `<name>.age` files; no
  common/host naming convention. `terminus.secrets.secret` returns the full
  `age.secrets.<name>` value, so do not use `//` to append owner/mode.
- Secret file paths must keep Nix store context
  (`"${secretsDir}/<name>.age"`); do not derive them with `toString`, or
  Colmena will omit `secrets/*.age` when copying the system closure.
- Secrets editing is in `secrets/justfile`; the editor runs as the invoking
  user. The recipe ports agenix's `mktemp -d` + `cleanup` + `trap` pattern and
  passes editor output to `agenix -e` via stdin. Do not add `edit-raw`.
- Remote deployment is Colmena only. The `deploy` user has `NOPASSWD: ALL`;
  deploy public keys live in `keys/deploy/*.pub`. The deploy user is also in
  `nix.settings.trusted-users`; Colmena needs this to push unsigned closures
  over ssh-ng. Keep private-key paths in the deployment machine's
  `~/.ssh/config` (`IdentityFile`/`IdentitiesOnly`); do not commit
  machine-specific `deployment.sshOptions` such as `-i /home/...`.
- `lib/deploy.nix` appends a last sudoers rule denying all users
  `runAs = "deploy,#1001"` (`!ALL`). Do not add a later rule allowing
  `runAs = "deploy"`; that would re-enable `sudo -u deploy bash` and let
  restricted sudo users inherit deploy's NOPASSWD rule.
- Roles only decide which module side files are imported; they never set
  options. Modules with unconditional config apply on import; modules gated by
  `mkIf config.terminus.*.enable` need the option set. `hosts/<name>/meta.nix`
  `modules.<name> = true/false` is only an import override, not an option.
- Modules may add `exports.nix` (plain attrset or `{ lib, inputs, self, ... }:`
  function). The framework merges exports into `terminus.exports`; exports are
  host-independent and duplicate keys are rejected. Do not require hosts to
  import shared value files.
- `nix-substituters` exports `substituterPresets`; hosts select them via
  `terminus.exports.substituterPresets` and `entries`. Only public
  `trustedPublicKeys` belong in the repo.
- `lib/users.nix` sets `users.mutableUsers = false` for every host.
  `users/<name>/meta.nix` supports `hashedPassword` or
  `hashedPasswordSecret` (mutually exclusive); do not set both.
- `_common/*/home.nix` modules are imported into every embedded and standalone
  Home Manager config. Keep user identity, SSH host aliases and
  `home.stateVersion` in `homes/<user>/`.
- Role-specific home modules live under `modules/<role>/.../home.nix`; e.g.
  `client/ssh` only applies to client hosts. Home files themselves are not
  role-filtered, so user-specific role-gated settings in
  `homes/<user>/default.nix` must use `lib.mkIf`/`lib.optionalAttrs` with
  `terminus.host.roles` (and handle `terminus.host == null` for standalone
  homes).
- `homes/<user>/_*.nix` are fragments ignored by discovery; import them from
  `default.nix` or `<host>.nix`. Do not name fragments after hosts.
- `server/node-exporter` is server-only. Its `options.nix` is still loaded
  framework-wide by convention, but the exporter config is only imported for
  the server role.
- Verification:
  - `nix flake check path:. --no-build`
  - `nix build .#checks.x86_64-linux.terminus-colmena-consistency`
  - `nix build .#checks.x86_64-linux.terminus-deploy-sudo-deny`
  - `nix build .#nixosConfigurations.sha-ali-gaal.config.system.build.toplevel`
  - `nix build .#homeConfigurations.allenyou.activationPackage`
  - compare `nixosConfigurations.sha-ali-gaal...toplevel.outPath` with
    `colmenaHive.nodes.sha-ali-gaal...toplevel.outPath`
  - `nix run .#colmena -- eval -E '{ nodes, ... }: nodes.sha-ali-gaal.config.networking.hostName'`
  - `nix fmt`
- Do not commit plaintext secrets or private keys.
