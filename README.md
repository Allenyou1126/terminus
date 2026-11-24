# Terminus

Terminus 是一套自包含的、参考 SnowveilOrg/Snowveil 目录约定的 NixOS 配置框架。
目录结构直接映射为 flake outputs，显式区分“发现/元数据”和“NixOS/Home Manager 模块求值”。

当前版本：`0.1.0`，范围是框架 + 首个真实主机 `sha-ali-gaal`；demo 已移除，其余主机尚未迁移。
Nix substituter / binary cache 配置尚未迁移，主机当前使用默认 `cache.nixos.org`。

## 快速开始

```bash
nix flake check path:. --no-build
nix build .#checks.x86_64-linux.terminus-deploy-sudo-deny
nix flake show
nix run .#terminus-discovery
nix fmt
```

> Flake 从 Git 求值时只包含已跟踪/已暂存的文件。新增 host、module、`.age` secret
> 或 `keys/deploy/*.pub` 后，先 `git add` 再构建/部署；本地验证可用
> `nix flake check path:.`。

本机部署（在目标机执行）：

```bash
sudo nixos-rebuild switch --flake .#sha-ali-gaal
```

远程 Colmena 部署：

```bash
nix run .#colmena -- apply test --on sha-ali-gaal          # 先测试激活
nix run .#colmena -- apply --on sha-ali-gaal              # 确认后正式切换
```

## 目录约定

```text
hosts/<name>/              nixosConfigurations.<name> + colmenaHive 节点
  meta.nix                 system / description / roles / profiles / home / deployment
  default.nix              必需；主机模块
  hardware.nix             可选；自动导入
  disk.nix                 可选；自动导入
  network.nix              可选；自动导入
users/<name>/              users.users/groups + Agenix 密码
homes/<user>/default.nix   homeConfigurations.<user>
homes/<user>/<host>.nix    homeConfigurations."<user>@<host>"
modules/<path>/{options,default,nixos,home}.nix
profiles/<name>.nix
packages/<name>/           或 packages/<system>/<name>/
overlays/<name>/           overlays.<name>
apps/<name>/               apps.<system>.<name>
shells/<name>/             devShells.<system>.<name>
checks/<name>/             checks.<system>.<name>
formatter/default.nix      formatter.<system>
lib/*.nix                  lib.<name>
secrets/                   secretsDir（默认）
keys/deploy/*.pub          远程部署用户公钥
```

`modules/` 按角色过滤：`_common` 始终加载，`modules/<role>/` 只加载给声明了该 role 的主机；
`options.nix` / `default.nix` 始终加载。模块目录的 `meta.nix` 支持 `requires` / `after` /
`before` / `wants` / `conflicts`，组合时做稳定拓扑排序。

角色只决定哪些 side 文件被导入，**不会设置模块 option**：无 option 门控、config 无条件的
模块导入即生效；带 `mkIf config.xxx.enable` 的模块仍需显式开启。`hosts/<name>/meta.nix`
的 `modules.<name> = true/false` 可以强制或跳过导入，但同样不会设置 option。

当前拆分：`_common` 下有 `locale-timezone`、`nix-experimental`、`nix-trusted-users`、
`nix-gc`、`agenix-cli`、`basic-packages`、`motd`、`home-packages`、`home-bash`、`home-git`；
`client` 下有 `ssh`；`server` 下有 `ssh`、`node-exporter`。

## 框架结构

- `lib/discover.nix`：纯文件系统扫描；不求值任何 NixOS 配置。
- `lib/metadata.nix`：`meta.nix` 校验与归一化。
- `lib/modules.nix` / `lib/profiles.nix` / `lib/depgraph.nix`：角色、profile、依赖排序。
- `lib/users.nix`：`users/<name>/meta.nix` → `users.users/groups`；框架统一设置
  `users.mutableUsers = false`，支持 `hashedPassword` / `hashedPasswordSecret`（互斥）。
- `lib/secret.nix`：`secretsDir` 路径 helper；统一 `<name>.age`。
- `lib/hosts.nix`：共享 host modules；标准 `nixosConfigurations` 与 Colmena 共用。
- `lib/hive.nix`：`colmenaHive` + toplevel 一致性 shim。
- `lib/deploy.nix`：`deploy` 用户、Colmena deployment 元数据。
- `lib/outputs.nix`：packages/apps/shells/checks/formatter/overlays/lib。

### 为什么标准 `nixosConfigurations` 和 Colmena 能一致

`colmenaHive` 与 `nixosConfigurations` 使用同一份 host modules 和同一个 nixpkgs 实例。
Colmena 侧额外注入一个 shim：

```nix
system.nixos.revision = ...;
system.nixos.versionSuffix = ...;
nixpkgs.flake.source = ...;
```

`checks.<system>.terminus-colmena-consistency` 会比较两边
`config.system.build.toplevel.outPath`；不一致直接失败。本机 `nixos-rebuild`
只走标准 `nixosConfigurations`，不依赖 Colmena 求值。

## Secrets

Secrets 来源是一个目录 `secretsDir`：仓库内目录直接传；外部 flake input 设置
`flake = false` 后也可以直接传。

```nix
mkFlake {
  secretsDir = ./secrets;
  # 或
  # secretsDir = inputs.allenyou-secrets;
}
```

统一文件名为 `<name>.age`，不区分 common/host。收件人由 `secrets/secrets.nix`
的 `publicKeys` 决定。Helper 直接返回完整的 `age.secrets.<name>` 值：

```nix
age.secrets.oss-nix-cache-config =
  terminus.secrets.secret {
    name = "oss-nix-cache-config";
    owner = "allenyou";
    mode = "0400";
  };
```

`users/<name>/meta.nix` 的密码配置二选一：`hashedPasswordSecret = "example-password"`
对应 `secrets/example-password.age`；或直接写 `hashedPassword = "$6$..."`。两者不能同时设置。

`terminus.secrets.secret` 默认用 `"${secretsDir}/<name>.age"` 保留 Nix store
context；不要先用 `toString` 把 `secretsDir` 变成普通字符串，否则 Colmena 不会把
`.age` 文件复制到目标机。

编辑/检查/rekey 在 `secrets/` 下：

```bash
cd secrets
just edit example-token
just check
just rekey
```

外部 `secretsDir` 的编辑/rekey 在外部仓库自己的 Justfile 中完成；本仓库的
`secrets/justfile` 只用于 local 模式。

`just edit` 以当前用户运行 `$EDITOR`，`sudo` 只用于 `agenix -d` / `agenix -e`；
临时明文目录用 agenix 自己的 `mktemp -d` + `cleanup` + `trap "cleanup" 0 2 3 15`
方式清理。编辑器保存什么就原样加密什么，不自动处理尾换行。

默认 Agenix 身份：

```nix
age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
```

WSL 等没有 host key 的机器在 `hosts/<name>/meta.nix` 中覆盖：

```nix
{
  secrets.identityPaths = [ "/home/allenyou/.ssh/id_ed25519" ];
}
```

## 部署

本机：

```bash
sudo nixos-rebuild switch --flake .#<host>
```

远程只使用 Colmena，目标机上的专用 `deploy` 用户使用密钥登录和
`NOPASSWD: ALL` sudo。把公钥放到 `keys/deploy/*.pub`；私钥只留在部署机上。

`deploy` 用户同时加入 `nix.settings.trusted-users`，否则 Colmena 通过 ssh-ng
推送未签名 store path 时会被目标机拒绝。私钥路径属于部署机的本地配置，不要写进仓库；
在部署机的 `~/.ssh/config` 中给目标主机加 `IdentityFile`，例如：

```sshconfig
Host sha-ali-gaal.server.allenyou.wang
    IdentityFile ~/.ssh/terminus_deploy
    IdentitiesOnly yes
```

Colmena 会把 `targetHost`/`User`/`Port` 传给 `ssh`，SSH 配置负责选择私钥。
`deployment.sshOptions` 仍可用于非机器相关的 ssh 参数，但不要把本机私钥路径提交进仓库。

为了阻止受限 sudo 用户通过 `sudo -u deploy bash` 绕过自己的限制，框架在
`security.sudo.extraRules` 的**最后**追加：

```text
ALL ALL=(deploy,#1001) !ALL
```

`#1001` 是 deploy 用户 UID。不要在后面再加允许 `runAs = "deploy"` 的规则；
deploy key 本身等价 root，仍应按 root 凭据管理。

```bash
nix run .#colmena -- apply test --on <host>
nix run .#colmena -- apply --on <host>
nix run .#colmena -- apply --on @<tag>
```

Colmena 没有自动回滚。涉及 SSH、防火墙、bootloader 的变更新先用
`apply test`，必要时用 `apply boot`，并准备控制台。手工回滚：

```bash
ssh <host>
sudo nix-env --profile /nix/var/nix/profiles/system --rollback
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

## 添加主机

1. 创建 `hosts/<name>/meta.nix`，至少声明 `system`；
2. 创建 `hosts/<name>/default.nix`；
3. 按需加 `hardware.nix` / `disk.nix` / `network.nix`；
4. 如需远程部署，在 meta 中写 `deployment.targetHost`，并把 deploy 公钥加入 `keys/deploy/`；
5. 运行 `nix flake check path:. --no-build`。

## 与 Snowveil 的差异（v1）

已实现：目录发现、hosts/users/homes、roles/profiles、模块依赖、packages/overlays/apps/
shells/checks/formatter/lib、HM 嵌入/独立、Agenix、Colmena 桥接、discovery/一致性检查。

暂未实现：images、flake schemas、`outputs.expected`/`outputs.eval`/完整 diagnostics、
模块 groups/capabilities、`mkSystem`/`mkHome` 逃生舱、patches/source helper、
每主机 overlay/package 自动选择、deploy-rs、sops-nix。
