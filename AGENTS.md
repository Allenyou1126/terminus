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
- Secrets editing is in `secrets/justfile`; the editor runs as the invoking
  user. The recipe ports agenix's `mktemp -d` + `cleanup` + `trap` pattern and
  passes editor output to `agenix -e` via stdin. Do not add `edit-raw`.
- Remote deployment is Colmena only. The `deploy` user has `NOPASSWD: ALL`;
  deploy public keys live in `keys/deploy/*.pub`.
- `lib/deploy.nix` appends a last sudoers rule denying all users
  `runAs = "deploy,#1001"` (`!ALL`). Do not add a later rule allowing
  `runAs = "deploy"`; that would re-enable `sudo -u deploy bash` and let
  restricted sudo users inherit deploy's NOPASSWD rule.
- Roles only decide which module side files are imported; they never set
  options. Modules with unconditional config apply on import; modules gated by
  `mkIf config.terminus.*.enable` need the option set. `hosts/<name>/meta.nix`
  `modules.<name> = true/false` is only an import override, not an option.
- `lib/users.nix` sets `users.mutableUsers = false` for every host.
  `users/<name>/meta.nix` supports `hashedPassword` or
  `hashedPasswordSecret` (mutually exclusive); do not set both.
- `_common/*/home.nix` modules are imported into every embedded and standalone
  Home Manager config. Keep user identity, SSH host aliases and
  `home.stateVersion` in `homes/<user>/`.
- `server/node-exporter` is server-only. Its `options.nix` is still loaded
  framework-wide by convention, but the exporter config is only imported for
  the server role. Nix substituter/binary cache migration is still pending.
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
