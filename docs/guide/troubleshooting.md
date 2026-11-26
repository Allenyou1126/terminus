# 排错

> 适用版本：`0.1.0`

Terminus 的错误尽量以 `terminus:` 开头，并指出具体文件或模块。本页按「发现 → 选择 → 求值 →
部署」的顺序列出常见问题。

## 先跑最小检查

```bash
nix flake check path:. --no-build
nix run .#terminus-discovery | jq .
nix flake show
```

`path:.` 会直接读取工作树，适合检查尚未 `git add` 的新文件。需要定位求值错误时加
`--show-trace`：

```bash
nix build path:.#nixosConfigurations.<host>.config.system.build.toplevel --show-trace
```

## 常见错误

| 错误 | 原因 | 处理 |
| --- | --- | --- |
| `missing required file: .../meta.nix` | host/profile/user 目录缺 `meta.nix`。 | 补 `meta.nix`；host 还需要 `default.nix`，profile 还需要可选的 `nixos.nix` / `home.nix`。 |
| `hosts/<host>/meta.nix must declare a system` | host 元数据没有 `system`。 | 加 `system = "x86_64-linux";`。 |
| `invalid meta.nix ... expected: an attribute set` | `meta.nix` 写成了函数或非 attrset。 | `meta.nix` 必须是直接返回属性集的文件。 |
| `unsupported host meta field 'roles'` | 主机仍在用已移除的 `roles`。 | 改成 `profiles = [ ... ];`。 |
| `unsupported host meta field 'modules'` | 主机仍在用已移除的主机级导入覆盖。 | 用 Host `requires = [ ... ]` 直接导入，或把模块写进 Profile。 |
| `unknown host '<name>'` | `users/*/meta.nix` 或 `homes/<user>/<host>.nix` 引用了不存在的主机。 | 先创建 `hosts/<name>/`，或修正名称。 |
| `unknown user '<name>'` | `homes/<user>/` 没有对应的 `users/<user>/`。 | 补 `users/<name>/meta.nix`。 |
| `does not associate the user with any host` | 用户既没有 `hosts`，也没有 host 级 home 文件。 | 在 `users/<name>/meta.nix` 的 `hosts` 中至少写一台主机。 |
| `duplicate module '<name>'` | 两个目录映射到同一模块点号名（通常是重命名/大小写问题）。 | 改目录名，保证相对路径唯一。 |
| `duplicate package '<system>:<name>'` | 两个包布局产生同名包。 | 删除重复目录或改用 `meta.systems` 区分。 |
| `legacy profile file 'profiles/<name>.nix' is no longer supported` | 仍在用旧单文件 Profile。 | 创建 `profiles/<name>/meta.nix` 和可选的 `nixos.nix` / `home.nix`。 |
| `unsupported profile meta field 'modules'` | Profile 的 `meta.nix` 仍在用旧字段。 | `modules` 改名为 `requires`；配置移到 `nixos.nix` / `home.nix`。 |
| `unsupported profile meta field 'nixos' / 'home' / 'common'` | 把 Profile 配置写进了 `meta.nix`。 | 移到同目录的 `nixos.nix` / `home.nix`。 |
| `unknown profile requires '<name>'` | Profile 的 `requires` 引用了不存在的模块。 | 检查模块点号名。 |
| `unknown host requires '<name>'` | Host 的 `requires` 引用了不存在的模块。 | 检查模块点号名。 |
| `module '<name>' has no NixOS or Home Manager side files` | requires 的模块只有 `exports.nix` / `meta.nix`，没有可导入的 side 文件。 | 给模块加 side 文件，或从 requires 移除。 |
| `unknown profile '<name>'` | `hosts/<name>/meta.nix` 的 `profiles` 写了未定义的配置集。 | 创建 `profiles/<name>/meta.nix` 或修正引用。 |
| `profile inheritance cycle` | 配置集 `extends` 形成环。 | 去掉环。 |
| `invalid meta.nix ... empty profile` | Profile 既没有 `requires`，也没有 `nixos.nix` / `home.nix`。 | 至少加一个 requires 或一个 side 配置，或删除该 Profile。 |
| `module dependency cycle` | 模块 `meta.nix` 的 `requires` / `after` / `before` / `wants` 形成环。 | 检查模块依赖边。 |
| `requires ... but ... is not enabled` | 模块依赖目标没有被任何生效 Profile/Host `requires` 选中。 | 把目标加入 Profile 或 Host `requires`，或去掉模块依赖。 |
| `modules ... conflict` | 两个模块同时启用且声明了 `conflicts`。 | 关闭其中一个。 |
| `missing required flake input '<name>'` | `flake.nix` 缺少 nixpkgs/agenix/home-manager/colmena。 | 补 input 并 `inherit inputs`。 |
| `secretsDir does not exist` | `secretsDir` 路径不存在。 | 创建目录，或修正 `mkFlake` 参数。 |
| `secretsDir must be a directory` | 外部 input 没有设置 `flake = false`。 | 设 `flake = false`，让它成为目录。 |
| `duplicate module export '<key>'` | 两个 `exports.nix` 导出同名 key。 | 改 key 名，保证全局唯一。 |
| `module '...' exports.nix must return an attribute set` | `exports.nix` 返回了非 attrset。 | 返回属性集。 |

## 框架 checks

| check | 验证内容 |
| --- | --- |
| `terminus-discovery` | 生成 Discovery JSON，列出 hosts/users/modules/profiles/packages 等。 |
| `terminus-eval-hosts` | 对每台主机生成 `toplevel.drvPath` JSON，确认主机可求值。 |
| `terminus-secret-paths` | 验证 `terminus.secrets.secret` 的默认路径、owner、mode 与 store context。 |
| `terminus-deploy-sudo-deny` | 验证远程主机的 sudo 拒绝规则是最后一条。 |
| `terminus-colmena-consistency` | 比较标准配置与 `colmenaHive` 的 toplevel `outPath`。 |

```bash
nix build .#checks.x86_64-linux.terminus-discovery
nix build .#checks.x86_64-linux.terminus-eval-hosts
nix build .#checks.x86_64-linux.terminus-secret-paths
nix build .#checks.x86_64-linux.terminus-deploy-sudo-deny
nix build .#checks.x86_64-linux.terminus-colmena-consistency
```

`terminus-colmena-consistency` 不一致时，先看 `lib/hive.nix` 的 shim，不要直接改共享 host
模块来「凑」出相同路径。共享模块不应依赖 Colmena 的 `name` / `nodes` / `deployment`。

## 模块被导入但配置没生效

Profile 只影响 **import**，不设置 option 的值。只有被 `default` 或主机 `profiles` 选中的模块
才会导入 `options.nix`；但“模块被导入”和“option 被设为 `true`”仍是两件事：

```nix
# 模块已经导入，但 enable 仍是默认 false
{ config, lib, ... }:
{
  config = lib.mkIf config.terminus.example.enable {
    # ...
  };
}
```

需要主机显式：

```nix
{
  terminus.example.enable = true;
}
```

排查步骤：

1. 用 `nix run .#terminus-discovery` 确认模块被发现，并查看 `profileRequires` /
   `profileConfig` / `hostRequires` / `hostProfiles`；
2. 检查主机 `meta.nix` 的 `profiles` / `requires`，以及 `profiles/default/meta.nix` 是否
   包含该模块；
3. 检查模块 `meta.nix` 的 `nixos.enable` / `home.enable`；
4. 检查模块里的 `mkIf` 条件对应的 option 是否被设置；
5. 用 `nix eval` 直接读 option：

   ```bash
   nix eval path:.#nixosConfigurations.<host>.config.terminus.example.enable
   ```

## Profile 配置与 option 值

- Profile 的 `nixos.nix` / `home.nix` 是普通模块，可以设置 option；
- `profiles = [ "cn" ]` 会导入 cn 模块，并由 `profiles/cn/nixos.nix` 用
  `lib.mkDefault true` 设置 `terminus.nix.substituters.presets.cn`；
- 主机可以在 `default.nix` 里用普通定义覆盖为 `false`；如果 Profile 用的是普通定义而不是
  `mkDefault`，主机需要用 `lib.mkForce`；
- 没有选中 `cn` / `global` 的主机根本不存在对应 preset option，设置它会报 option 不存在；
- Profile `requires` 成员必须是 `modules/` 下的点号名，例如 `_common.nix-substituters.cn`；
- 如果模块的 `meta.<side>.enable = false`，该 side 不会参与选择；
- Profile 配置引用未导入模块的 option，会在主机求值时报 option 不存在。

## Home Manager 问题

- `homeConfigurations.<user>` 不存在：检查是否有 `homes/<user>/default.nix`，以及
  `home.standalone` 是否为 `true`；
- 主机没有嵌入 Home Manager：检查用户是否有关联 home 文件，以及
  `hosts/<name>/meta.nix` 的 `home.embed` 是否为 `false`；
- 全局 home 中访问 `terminus.host.profiles` 报错：全局 home 的 `terminus.host = null`，需要先判空；
- 用户文件被忽略：`homes/<user>/_*.nix` 和 `meta.nix` 不会被 discovery 当作入口，必须由
  `default.nix` 或 `<host>.nix` 显式 `import`；
- `<host>.nix` 报 `unknown host`：文件名必须与 `hosts/` 下的目录名完全一致。

## Secrets 问题

- 目标机缺 `.age` 文件：检查 `file` 是否保留了 store context，不要用 `toString secretsDir`
  手工拼接；
- 规则不匹配：`secrets/agenix-rules.nix` 的 key 必须与相对 `secretsDir` 的路径完全一致，
  包括 `.age` 后缀；
- `age.secrets.<name>` 属性冲突：`terminus.secrets.secret` 已返回完整值，不要再 `//` 追加
  `owner` / `mode`；
- 用户密码解密失败：确认 `hosts/<name>/meta.nix` 的 `secrets.identityPaths` 指向存在的私钥；
- 新增 `.age` 后 Colmena 看不到：先 `git add`，并确认 secrets 文件路径带 store context。

## 部署问题

- `apply` 报权限/连接错误：确认目标机已存在 deploy 用户、公钥在 `keys/deploy/*.pub`、部署机
  `~/.ssh/config` 指向正确私钥；
- deploy 用户不存在：首次迁移需要先在目标机本地 `nixos-rebuild switch`；
- `trusted-users` 不匹配：`modules/_common/nix-trusted-users/nixos.nix` 当前硬编码
  `"deploy"`，改 `colmena.deployUser.name` 时需同步修改；
- `terminus-deploy-sudo-deny` 失败：检查 `security.sudo.extraRules` 最后一条，不要在它后面追加
  允许 `runAs = "deploy"` 的规则；
- `terminus-colmena-consistency` 失败：检查 `lib/hive.nix` 的 shim 与共享模块是否引用了
  Colmena 专属 option；
- `nix flake check` 的 `unknown flake output 'colmenaHive'` 警告是预期的，不影响结果。

## 已知限制（0.1.0）

- `terminus.homeManager.backupFileExtension` / `terminus.homeManager.embed` 只声明了 option，
  没有自动接线；
- 没有模块图 DOT、images、独立 `deploy` output、`mkSystem` / `mkHome`；
- 没有模块组和虚拟能力；
- `lib` output 是框架内部文件的机械映射，部分条目需要额外参数，不能当作稳定 API；
- 自定义 deploy 用户名需要手动同步 `_common/nix-trusted-users` 与默认 SSH 用户名；
- 独立全局 home 使用第一个派生 system。

## 相关

- [发现机制](../concepts/discovery.md)
- [模块选择](../concepts/module-selection.md)
- [部署](deployment.md)
- [Secrets](secrets.md)
