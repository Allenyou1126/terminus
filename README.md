# Terminus

Terminus 是一套自包含的、参考 SnowveilOrg/Snowveil 目录约定的 NixOS 配置框架。
目录结构直接映射为 flake outputs，显式区分“发现/元数据”和“NixOS/Home Manager 模块求值”。

当前版本：`0.1.0`，已迁移 `sha-ali-gaal`、`sha-ali-seldon`、`home-ebeling`、`lax-rn-riose`、`lap-fallom` 与 `hkg-dog-darell`；demo 已移除，其余主机尚未迁移。

> 完整框架文档见 [docs/](docs/README.md)。

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
nix run .#colmena -- apply test --on sha-ali-gaal          # 测试激活
nix run .#colmena -- apply --on sha-ali-gaal              # 正式切换
```

## 目录约定

```text
hosts/<name>/              nixosConfigurations.<name> + colmenaHive 节点
  meta.nix                 system / description / profiles / requires / home / deployment
  default.nix              必需；主机模块
  hardware.nix             可选；自动导入
  disk.nix                 可选；自动导入
  network.nix              可选；自动导入
  <other>.nix              非 magic 文件不会被自动导入；需要时由 default.nix import
users/<name>/              users.users/groups、其他用户特定定义
homes/<user>/
  default.nix              homeConfigurations.<user>
  <host>.nix               homeConfigurations."<user>@<host>"
  _*.nix                   被 discovery 忽略；由 default/host 文件 imports
modules/<namespace>/<path>/
  options.nix              公共的 Nix Options 定义。
  default.nix              NixOS / Home Manager 共享的模块实现
  nixos.nix                NixOS 模块实现
  home.nix                 Home Manager 模块实现
  exports.nix              导出的工具等
  <other>.nix              非 magic 文件不会被自动导入
profiles/<name>/
  meta.nix                 requires / extends
  nixos.nix                可选；NixOS 配置模块
  home.nix                 可选；Home Manager 配置模块
profiles/default/          特殊 Profile：存在时自动应用到每台主机和全局 home
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

`modules/` 的目录名只是命名空间，不再按角色或前缀过滤；一个模块是否导入由 Profile 和 Host
决定。每台主机自动应用 `profiles/default/`（存在时）和自己的 `meta.profiles`；最终导入
`default` + Profile `requires` + Host `requires` 的并集。只有被选中的模块才会导入 side 文件；
未选中模块的 `options.nix` / `default.nix` 不会全局注入。

Profile 是“`requires` + 配置”的组合：`meta.nix` 声明要导入的模块，`nixos.nix` / `home.nix`
是普通 NixOS / Home Manager 模块。Profile 配置推荐用 `lib.mkDefault`，Host 可以覆盖。
Host 也可以在 `meta.requires` 中直接导入只属于该主机的模块。

`hosts/<name>/meta.nix` 的 `roles` / `role` / `modules` 字段已移除，出现会报错；需要直接导入
模块时用 `requires = [ ... ]`，或把模块写进 Profile。

### Module exports

模块目录可以放 `exports.nix`，它不会被当作 NixOS/Home Manager 模块导入，而是由框架收集并
合并到所有模块都能访问的 `terminus.exports`：

```nix
# modules/_common/example/exports.nix
{
  examplePresets = {
    foo = { ... };
  };
}
```

`exports.nix` 也可以写成 `{ lib, inputs, self, ... }:` 形式。导出必须是 attrset，且各模块
导出的 key 必须全局唯一；重复 key 会报错。导出是 host-independent 的，不能依赖 host/config。

### Nix substituters

`modules/_common/nix-substituters` 通过 `exports.nix` 导出 `substituterPresets`，主机直接选用：

```nix
terminus.nix.substituters.entries = [
  terminus.exports.substituterPresets.ustc-mirror
  terminus.exports.substituterPresets.allenyou-cache
  terminus.exports.substituterPresets.official-cloudflare-mirror
];
```

`entries` 是 list of attrset：`url`、`priority`、`trustedPublicKeys`。默认 `priority = 40`，
`priority = null` 表示原样使用 URL；默认 `cache.nixos.org` 和它的 key 仍由 NixOS 保留。
私有签名 key 只留在主机，不进入仓库。

`profiles = [ "cn" ]` / `[ "global" ]` 通过 `profiles/cn/` / `profiles/global/` 导入对应
preset 模块；它们的 `nixos.nix` 还会用 `lib.mkDefault true` 打开
`terminus.nix.substituters.presets.cn`（或 `.global`）。需要关闭的主机在 `default.nix` 里写
普通定义 `= false` 即可覆盖；没有选中这些 Profile 的主机则不存在对应 preset option。

`homes/<user>/default.nix` 可以用 `imports = [ ./_git.nix ./_ssh.nix ];` 拆分；
`_*.nix` 不会被 discovery 当作 host 专用 home，`<host>.nix` 仍保留给 host 专用文件。

## 框架结构

- `lib/discover.nix`：纯文件系统扫描；不求值任何 NixOS 配置。
- `lib/metadata.nix`：`meta.nix` 校验与归一化。
- `lib/modules.nix` / `lib/profiles.nix` / `lib/depgraph.nix`：Profile 目录、requires 合并、
  配置注入与依赖排序。
- `lib/users.nix`：`users/<name>/meta.nix` → `users.users/groups`；框架统一设置
  `users.mutableUsers = false`，支持 `hashedPassword` / `hashedPasswordSecret`（互斥）。
- `lib/secret.nix`：`secretsDir` 路径 helper；支持 `<category>/<name>.age` 相对路径。
- `lib/internal/exports.nix`：收集模块 `exports.nix`，合并注入 `terminus.exports`。
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

Secret 文件用子目录归类（例如 `common/`、`dn42/`、`nexusnet/`），服务凭据放在
`services/` 下：只有一个 secret 的服务直接用应用名命名（如 `services/miniflux.age`），
有多个 secret 的服务才建子目录（如 `services/umami/app-secret.age`）。文件相对路径
必须与 `secrets/agenix-rules.nix` 的规则 key 一致。收件人由该文件的 `publicKeys` 决定。
Helper 直接返回完整的 `age.secrets.<name>` 值：

```nix
age.secrets.oss-nix-cache-config =
  terminus.secrets.secret {
    name = "common/oss-nix-cache-config";
    owner = "allenyou";
    mode = "0400";
  };
```

`users/<name>/meta.nix` 的密码配置二选一：`hashedPasswordSecret = "common/example-password"`
对应 `secrets/common/example-password.age`；或直接写 `hashedPassword = "$6$..."`。两者不能同时设置。

`terminus.secrets.secret` 默认用 `"${secretsDir}/<name>.age"` 保留 Nix store
context；`name` 可以包含子目录。不要先用 `toString` 把 `secretsDir` 变成普通字符串，
否则 Colmena 不会把 `.age` 文件复制到目标机。

编辑/检查/rekey 在 `secrets/` 下：

```bash
cd secrets
just edit services/example-token
just list
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
Host sha-ali-gaal
    IdentityFile ~/.ssh/terminus_deploy
    IdentitiesOnly yes
```

首次迁移时目标机上还没有 `deploy` 用户，需要先在目标机本地运行
`sudo nixos-rebuild switch --flake .#<Host Name>`，之后才能用 Colmena。

Colmena 会把 `targetHost`/`User`/`Port` 传给 `ssh`，SSH 配置负责选择私钥。
`deployment.sshOptions` 仍可用于非机器相关的 ssh 参数，但不要把本机私钥路径提交进仓库。

为了阻止受限 sudo 用户通过 `sudo -u deploy bash` 绕过自己的限制，框架在
`security.sudo.extraRules` 的**最后**追加：

```text
ALL ALL=(deploy,#50000) !ALL
```

`#50000` 是 deploy 用户 UID。不要在后面再加允许 `runAs = "deploy"` 的规则；
deploy key 本身等价 root，仍应按 root 凭据管理。

```bash
nix run .#colmena -- apply test --on <host>
nix run .#colmena -- apply --on <host>
nix run .#colmena -- apply --on @<tag>
```

Colmena 没有自动回滚。涉及 SSH、防火墙、bootloader 的变更新先用
`apply test`，必要时用 `apply boot`，并准备控制台。

## 添加主机

1. 创建 `hosts/<name>/meta.nix`，至少声明 `system`，并按需声明 `profiles` / `requires`；
2. 创建 `hosts/<name>/default.nix`；
3. 按需加 `hardware.nix` / `disk.nix` / `network.nix`；
4. 如需远程部署，在 meta 中写 `deployment.targetHost`，并把 deploy 公钥加入 `keys/deploy/`；
5. 运行 `nix flake check path:. --no-build`。

WSL 主机在 meta 中声明 `profiles = [ "wsl" ]`（按需再加 `"client"`）；`wsl.base` 模块会导入
`inputs.nixos-wsl.nixosModules.wsl` 并设置 `wsl.enable = true`。主机 `default.nix` 只需设置
`wsl.defaultUser`。flake 已提供 `nixos-wsl`（`release-26.05`）input，WSL 主机不需要
`hardware.nix`。
