# Terminus agent notes

- Nixpkgs is pinned to `nixos-26.05`; Home Manager to `release-26.05`.
- `nixos-wsl` is pinned to `release-26.05`; WSL hosts import
  `inputs.nixos-wsl.nixosModules.wsl` (see `hosts/lap-fallom`).
- `lib/` is the framework. `lib/secret.nix` is a secrets helper, **not** the
  agenix rules file; the rules live in `secrets/agenix-rules.nix`.
- `nixosConfigurations` are standard `nixosSystem` values. `colmenaHive` is
  built separately from the same `host.modules` list and adds a shim so both
  toplevels are identical. Never make shared host modules depend on Colmena's
  `name`/`nodes`/`deployment` options.
- The consistency check is `checks.<system>.terminus-colmena-consistency`.
  If it fails, inspect the shim in `lib/hive.nix` before changing modules.
- Secrets are one directory (`secretsDir`), categorized with subdirectories
  such as `common/`, `dn42/`, `nexusnet/`, and `services/<service>/`; the file
  path relative to `secretsDir` must match the rule key in
  `secrets/agenix-rules.nix`.
  `terminus.secrets.secret` returns the full `age.secrets.<name>` value, so do
  not use `//` to append owner/mode.
- Secret file paths must keep Nix store context
  (`"${secretsDir}/<category>/<name>.age"`); do not derive them with
  `toString`, or Colmena will omit `.age` files when copying the system
  closure.
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
  `runAs = "deploy,#50000"` (`!ALL`). Do not add a later rule allowing
  `runAs = "deploy"`; that would re-enable `sudo -u deploy bash` and let
  restricted sudo users inherit deploy's NOPASSWD rule.
- Profiles are directories: `profiles/<name>/meta.nix` (required, pure attrset) with
  `requires` / `extends`, plus optional `nixos.nix` / `home.nix` which are ordinary
  NixOS / Home Manager modules. `requires` imports modules; the side files provide
  configuration. Use `lib.mkDefault` for values a host may override.
- Every host implicitly applies `profiles/default/` (when present) plus
  `meta.profiles`. Imported modules are the union of every selected profile's
  `requires` and the host's `meta.requires`. Unselected modules' `options.nix` /
  `default.nix` are not global.
- `hosts/<name>/meta.nix` accepts `requires` for direct module imports. `roles` /
  `role` / `modules` are rejected; module directories are namespaces, not roles.
  A leading `_` has no special import meaning.
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
- `profiles/default/meta.nix` lists the `_common/*` home modules, so they are imported
  into every embedded and standalone Home Manager config. `profiles/default/home.nix`
  (if present) is also applied to every home. Keep user identity, SSH host aliases and
  `home.stateVersion` in `homes/<user>/`.
- Home modules are imported only when a host profile selects them; e.g.
  `client.ssh` is imported by the `client` profile. `homes/<user>/*.nix` is not
  profile-filtered, so profile-gated user settings in
  `homes/<user>/default.nix` must use `lib.mkIf`/`lib.optionalAttrs` with
  `terminus.host.profiles` (and handle `terminus.host == null` for standalone
  homes).
- `homes/<user>/_*.nix` are fragments ignored by discovery; import them from
  `default.nix` or `<host>.nix`. Do not name fragments after hosts.
- `server/node-exporter`, `server/bird-exporter`, `server/wireguard-exporter`,
  `server/blackbox-exporter`, and `server/nginx-exporter` are imported only by the
  `server` profile. `server.certimate-ssh` is imported via `sha-ali-seldon`'s host
  `requires`. Their options are not global; hosts that set them must select the
  profile or require the module directly.
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
