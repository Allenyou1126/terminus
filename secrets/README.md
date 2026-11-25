# Secrets

`secretsDir` points at this directory by default. Secret 文件按类别放在子目录中，
但路径只是相对 `secretsDir` 的路径；文件相对路径必须与 `agenix-rules.nix` 的
规则 key 一致。哪些主机能解密由该文件的 `publicKeys` 决定。

## 目录归类

- `common/`：所有主机共享的配置，例如 Nix 缓存和 aliyun CLI 凭据。
- `dn42/`：DN42 主机的 WireGuard 私钥与 PSK，例如 `dn42/lax-rn-riose.priv.age`。
- `nexusnet/`：NexusNet 主机的 WireGuard 私钥与 PSK，例如 `nexusnet/sha-ali-seldon.priv.age`。
- `services/<app>.age`：只有一个 secret 的服务，直接以应用名命名，例如
  `services/miniflux.age`、`services/open-webui.age`。
- `services/<service>/<name>.age`：有多个 secret 的服务才建子目录，例如
  `services/grafana/db-password.age`、`services/umami/app-secret.age`。

新增文件时放在哪个类别都可以，只要 `agenix-rules.nix` 里的规则 key 和
`terminus.secrets.secret.name` 使用同一个相对路径。

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
`/<name>.age`; `name` may include a category subdirectory such as
`nexusnet/sha-ali-seldon.priv`. No extra path configuration is
needed.

When using an external directory, edit/rekey it with that repository's own
Justfile; the `justfile` in this directory is for local mode only.

## Add a host key

On the target host:

```bash
sudo ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key
```

Put the output in `keys.nix` `hostKeys.<host>`, add that key to the relevant
rules in `agenix-rules.nix`, then rekey:

```bash
cd secrets
just rekey
```

## Edit / create

```bash
cd secrets
just edit services/example-token
just list
```

`just list` 输出相对 `secrets/` 的路径；`just edit` 的 name 也使用同样的相对
路径（不带 `.age`）。父目录不存在时会自动创建。

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
the `publicKeys` in `agenix-rules.nix`.

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
