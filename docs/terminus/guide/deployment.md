# 部署

> 适用版本：`0.1.0`

Terminus 支持两种激活方式：

- **本机**：目标机上的 `nixos-rebuild`，使用标准 `nixosConfigurations`；
- **远程**：只使用 Colmena，通过专用 `deploy` 用户推送并激活配置。

两者使用同一份 host modules 和同一个 nixpkgs 实例，`terminus-colmena-consistency` 会检查
两边的 toplevel 是否一致。

## 本机部署

```bash
sudo nixos-rebuild switch --flake .#<host>
```

或使用 `just`：

```bash
just switch <host>
```

本机路径不依赖 Colmena 求值。即使 `colmena.enable = false`，`nixosConfigurations` 仍可正常
构建和切换。

## 远程部署

Terminus 的远程部署只支持 Colmena：

```bash
nix run .#colmena -- apply test --on <host>   # 激活但保留旧 boot 默认项
nix run .#colmena -- apply boot --on <host>   # 设为 boot 默认，不立即激活
nix run .#colmena -- apply --on <host>        # 正式切换
nix run .#colmena -- build --on <host>        # 只构建
nix run .#colmena -- apply --on @<tag>        # 按标签批量操作
```

对应的 `just` 命令：

```bash
just test <host>
just boot <host>
just apply <host>
just build <host>
just apply-tag <tag>
```

Colmena 版本固定在 `v0.5.0`，通过 `nix run .#colmena` 使用仓库锁定的 CLI，不依赖系统里
是否安装了同版本的 `colmena`。

## deploy 用户

当主机满足以下条件时，框架会生成 deploy 用户：

- `deployment.targetHost != null`；
- `deployment.sshUser` 为空，或等于 deploy 用户名。

生成的用户：

```nix
users.users.deploy = {
  isNormalUser = true;
  createHome = true;
  hashedPassword = "!";
  uid = 50000;
  openssh.authorizedKeys.keys = <keys/deploy/*.pub>;
};

security.sudo.extraRules = [
  # deploy 的 NOPASSWD: ALL
  # ...
  # 最后一条：禁止其他用户 sudo 成 deploy
  { users = [ "ALL" ]; runAs = "deploy,#50000"; commands = [ { command = "!ALL"; } ]; }
];
```

`keys/deploy/*.pub` 中的文件内容会被 trim、去重，作为 deploy 用户的授权公钥。没有任何公钥时
会生成一个警告：远程部署会失败，直到你加入公钥。

`deploy` 用户同时通过 `_common/nix-trusted-users` 加入
`nix.settings.trusted-users`。Colmena 通过 ssh-ng 推送未签名 closure 时需要这个权限，否则
目标机的 Nix 会拒绝。

## SSH 配置

Colmena 会把 `targetHost`、`targetPort`、`sshUser` 传给 `ssh`，私钥选择交给部署机的
`~/.ssh/config`：

```sshconfig
Host sha-ali-gaal
    HostName sha-ali-gaal.example.com
    Port 2333
    IdentityFile ~/.ssh/terminus_deploy
    IdentitiesOnly yes
```

- 私钥路径属于部署机的本地配置，**不要**提交到仓库；
- 不要写机器相关的 `deployment.sshOptions`（例如 `-i /home/...`）；
- 没有公网 DNS 的主机（例如 `home-ebeling`）需要部署机能路由到其内网地址，并为该地址配置
  同一把 deploy 私钥。

首次迁移时目标机上还没有 deploy 用户，需要先在目标机本地运行一次：

```bash
sudo nixos-rebuild switch --flake .#<host>
```

之后才能用 Colmena 远程部署。

## deployment 字段

```nix
# hosts/<name>/meta.nix
{
  deployment = {
    targetHost = "sha-ali-gaal";
    targetPort = 2333;
    sshUser = "deploy";
    buildOnRemote = false;
    tags = [ "server" "sha-ali-gaal" ];
    sshOptions = [ ];
    allowLocalDeployment = false;
    replaceUnknownProfiles = true;
  };
}
```

| 字段 | 默认 | 传到 Colmena |
| --- | --- | --- |
| `targetHost` | `null` | `deployment.targetHost` |
| `targetPort` | `22` | `deployment.targetPort` |
| `sshUser` | `null` → `deploy` | `deployment.targetUser` |
| `buildOnRemote` | `false` | `deployment.buildOnTarget` |
| `tags` | `[]` | `deployment.tags` |
| `sshOptions` | `[]` | `deployment.sshOptions` |
| `allowLocalDeployment` | `null` → `targetHost == null` | `deployment.allowLocalDeployment` |
| `replaceUnknownProfiles` | `null` → `true` | `deployment.replaceUnknownProfiles` |

`colmenaHive.nodes` 包含所有主机，包括没有 `targetHost` 的本机；`deploy` 元数据只包含
`targetHost != null` 的远程主机。

`deployment.sshUser` 指向其他用户时，框架不会创建 deploy 用户；该用户必须已经存在并具备
sudo 权限，Colmena 才能完成激活。

## Colmena 全局配置

```nix
# flake.nix
mkFlake {
  colmena = {
    enable = true;
    allowApplyAll = false;

    deployUser = {
      name = "deploy";
      uid = 50000;
    };
  };
}
```

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `enable` | `true` | 是否生成 `colmenaHive` 和一致性检查。 |
| `allowApplyAll` | `false` | 是否允许 `colmena apply --all`；默认要求显式 `--on`。 |
| `deployUser.name` | `"deploy"` | 远程部署用户名。 |
| `deployUser.uid` | `50000` | 远程部署用户 UID。 |

修改 `deployUser.name` 时要同步检查 `modules/_common/nix-trusted-users/nixos.nix` 中硬编码的
`"deploy"`，以及 `lib/deploy.nix` 的默认 SSH 用户名。当前 `0.1.0` 的默认假设是 `deploy`。

## 一致性检查

```bash
nix build .#checks.x86_64-linux.terminus-colmena-consistency
```

该检查比较：

```text
nixosConfigurations.<host>.config.system.build.toplevel.outPath
colmenaHive.nodes.<host>.config.system.build.toplevel.outPath
```

不一致时构建失败，并打印两边路径。`colmenaHive` 额外注入了一个 shim：

```nix
system.nixos.revision = ...;
system.nixos.versionSuffix = ...;
nixpkgs.flake.source = ...;
```

这些值用于让 Colmena 侧的 toplevel 与标准配置完全一致。**不要**让共享 host 模块依赖
Colmena 的 `name`、`nodes` 或 `deployment` option；这些 option 只在 hive 侧存在，会导致两边
求值分叉。

## deploy sudo 检查

```bash
nix build .#checks.x86_64-linux.terminus-deploy-sudo-deny
```

该检查面向所有远程主机，确认 `security.sudo.extraRules` 的最后一条是：

```text
users = [ "ALL" ];
runAs = "deploy,#50000";
commands = [ { command = "!ALL"; } ];
```

这条规则阻止受限 sudo 用户通过 `sudo -u deploy bash` 继承 deploy 的 `NOPASSWD: ALL`。

**不要**在它之后追加允许 `runAs = "deploy"` 的规则。deploy key 本身等价 root 凭据，仍应按
root 级别管理。

## 安全与回滚

- Colmena 没有自动回滚。涉及 SSH、防火墙、bootloader 的变更先用 `apply test`，必要时用
  `apply boot`，并准备控制台。
- `apply test` 激活新配置但保留旧 boot 默认项；重启后可能回到旧系统，适合验证。
- `apply boot` 只设置 boot 默认项，不立即激活；适合需要重启生效的变更。
- 确认无误后再 `apply` 正式切换。
- 生产主机建议保留至少一个可用的旧 generation。

## 常见警告

`nix flake check` 可能输出：

```text
warning: unknown flake output 'colmenaHive'
```

这是 `flake check` 不认识自定义 output 导致的提示，不影响检查结果；`colmenaHive` 仍可通过
`nix eval .#colmenaHive.nodes` 访问。

## 相关

- [Secrets](secrets.md)
- [主机](hosts.md)
- [求值模型](../concepts/architecture.md)
- [排错](troubleshooting.md)
