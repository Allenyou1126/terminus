# Secrets

`secretsDir` points at this directory by default. Every secret is exactly
`<name>.age`; there is no common/host naming distinction. Which hosts can
decrypt a file is decided solely by `secrets.nix` `publicKeys`.

## Local directory

```nix
# flake.nix
mkFlake {
  secretsDir = ./secrets;
}
```

## External directory (e.g. private Git repo)

```nix
# flake.nix
inputs.allenyou-secrets = {
  url = "git+ssh://git@github.com/Allenyou1126/nixos-secret.git?shallow=1";
  flake = false;
};

mkFlake {
  secretsDir = inputs.allenyou-secrets;
}
```

Because `flake = false`, the input is already a directory. The helper appends
`/<name>.age`; no extra path configuration is needed.

When using an external directory, edit/rekey it with that repository's own
Justfile; the `justfile` in this directory is for local mode only.

## Add a host key

On the target host:

```bash
sudo ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key
```

Put the output in `keys.nix` `hostKeys.<host>`, add that key to the relevant
rules in `secrets.nix`, then rekey:

```bash
cd secrets
just rekey
```

## Edit / create

```bash
cd secrets
just edit demo-token
```

The editor runs as the current user. `sudo` is only used for `agenix -d` and
`agenix -e`. The temporary cleartext directory is created with `mktemp -d`
and removed by the same `cleanup` / `trap` pattern agenix uses internally.

`just edit` passes whatever the editor saved to `agenix -e` via stdin; it
does not add or remove trailing newlines.

## Check

```bash
cd secrets
just check
```

This runs `agenix -c` and verifies that each encrypted file's recipients match
the `publicKeys` in `secrets.nix`.

## Host identity

The framework sets, by default:

```nix
age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
```

Override per host when there is no SSH host key (for example WSL):

```nix
# hosts/<name>/meta.nix
{
  secrets.identityPaths = [ "/home/allenyou/.ssh/id_ed25519" ];
}
```
