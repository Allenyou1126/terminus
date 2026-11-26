# 求值模型

> 适用版本：`0.1.0`

`mkFlake` 的职责是：发现目录、计算 system、实例化 nixpkgs、装配主机与 Home Manager、生成
per-system outputs。整个过程不改变 NixOS / Home Manager 的模块求值方式。

## 流程

```text
mkFlake
│
├─ [1] 计算 knownSystems（requested + x86_64-linux + aarch64-linux）
│       knownSystems 只用于旧式 packages/<name>.<system> 后缀识别
│
├─ [2] discovery（lib/discover.nix）
│       纯文件系统扫描 + meta.nix 读取
│       ├── hosts / users / homes
│       ├── modules / profiles
│       ├── packages / overlays / apps / shells / checks / formatter
│       ├── lib/ 文件与 keys/deploy/*.pub
│       └── 重复/未知引用检查（deepSeq）
│
├─ [3] 计算 systems
│       requestedSystems + host systems + package systems
│       + per-system output meta.systems + formatter systems
│       为空时回退 ["x86_64-linux"]
│
├─ [4] 构造 overlays 与 pkgsBySystem
│       每个 system 只 import 一次 nixpkgs
│       overlays = 发现到的 overlays ++ args.nixpkgs.overlays
│
├─ [5] 构造 secrets helper
│       secretsDir、terminus.secrets.secret
│
├─ [6] hostsTools.mk
│       收集模块 exports、按 default + 主机 profiles/requires 选择模块和配置、生成 users 模块、
│       嵌入式 Home Manager、deploy 用户、specialArgs
│
├─ [7] nixosConfigurations
│       nixosSystem { modules = ctx.modules ++ [{ nixpkgs.pkgs = ...; }] }
│
├─ [8] homeConfigurations
│       全局 homeConfigurations.<user> + "<user>@<host>"
│
├─ [9] colmenaHive（可选）
│       同一份 ctx.modules + deploy 元数据 + toplevel shim
│
├─ [10] diagnostics
│       Discovery JSON、eval-hosts、secret-paths、deploy-sudo-deny
│
├─ [11] per-system outputs
│       packages / apps / devShells / checks / formatter
│
├─ [12] registries 与 lib
│       nixosModules / homeModules / lib.<name>
│
└─ [13] 合并 outputs.extra
        lib.recursiveUpdate generated' extra
```

`discovery` 是唯一强调「纯扫描」的阶段：它只读目录和 `meta.nix`，不求值任何 NixOS 配置。
`nixosConfigurations`、`homeConfigurations` 和 per-system outputs 都是惰性属性集，访问哪个
才求值哪个。

## lib/ 文件地图

| 文件 | 职责 |
| --- | --- |
| [`lib/default.nix`](../../lib/default.nix) | `mkFlake` 入口，串联所有阶段并产出 outputs。 |
| [`lib/discover.nix`](../../lib/discover.nix) | 扫描 hosts/users/homes/modules/profiles/packages/...，建立名称索引。 |
| [`lib/fs.nix`](../../lib/fs.nix) | 排序后的目录读取、相对路径、文件遍历。 |
| [`lib/metadata.nix`](../../lib/metadata.nix) | `meta.nix` 读取、类型校验、默认值与归一化。 |
| [`lib/internal/errors.nix`](../../lib/internal/errors.nix) | 统一的 `terminus:` 错误消息。 |
| [`lib/internal/exports.nix`](../../lib/internal/exports.nix) | 收集模块 `exports.nix` 并检测重复 key。 |
| [`lib/modules.nix`](../../lib/modules.nix) | `default` + 主机 Profile/Host `requires` 选择、Profile 配置、依赖排序、registry。 |
| [`lib/profiles.nix`](../../lib/profiles.nix) | Profile 目录加载、`meta.nix` / `nixos.nix` / `home.nix`、继承、循环与空 Profile 检查。 |
| [`lib/depgraph.nix`](../../lib/depgraph.nix) | 依赖边构建、校验、稳定拓扑排序。 |
| [`lib/hosts.nix`](../../lib/hosts.nix) | 主机上下文：选模块、用户、Home Manager、deploy、specialArgs。 |
| [`lib/home.nix`](../../lib/home.nix) | 嵌入式与独立 Home Manager 装配。 |
| [`lib/users.nix`](../../lib/users.nix) | `users/<name>/meta.nix` → `users.users` / `users.groups`。 |
| [`lib/secret.nix`](../../lib/secret.nix) | `secretsDir` helper 与 store context 处理。 |
| [`lib/deploy.nix`](../../lib/deploy.nix) | deploy 用户、sudo 规则、Colmena deployment 元数据。 |
| [`lib/hive.nix`](../../lib/hive.nix) | `colmenaHive`、toplevel shim、一致性检查。 |
| [`lib/outputs.nix`](../../lib/outputs.nix) | packages/apps/shells/checks/formatter/overlays/lib。 |
| [`lib/diagnostics.nix`](../../lib/diagnostics.nix) | Discovery 报告与四个框架 checks 的实现。 |

## 主机模块注入顺序

NixOS 侧的合并顺序（后者可以覆盖前者的 `mkDefault`）：

1. 框架 options（`terminus.users`、`terminus.homeManager.*`）；
2. agenix NixOS 模块；
3. `age.identityPaths` 默认值；
4. 用户模块（`users/<name>/meta.nix` 生成）；
5. 关联用户的 `users/<name>/default.nix`；
6. 远程 deploy 用户模块；
7. 嵌入式 Home Manager 模块；
8. Profile `requires` + Host `requires` 选中的模块（经依赖排序）；
9. 生效 Profile 的 `nixos.nix` 配置模块；
10. 主机 magic 文件（`default → hardware → disk → network`）；
11. `mkFlake` 的 `nixos.modules`；
12. `networking.hostName` 默认值；
13. `nixpkgs.pkgs`。

Home Manager 侧的导入顺序：

1. 框架默认的 `home.username` / `home.homeDirectory`；
2. 主机选中的 home 模块；
3. 生效 Profile 的 `home.nix` 配置模块；
4. `mkFlake` 的 `home.modules`；
5. `homes/<user>/default.nix`；
6. `homes/<user>/<host>.nix`。

## specialArgs

所有 NixOS 模块收到：

```nix
{
  inputs;
  self;
  hostname = <hostname>;
  terminus = {
    version;
    host;          # 归一化后的 meta.nix；全局独立 home 为 null
    secrets;
    deployKeys;
    exports;
  };
}
// nixos.specialArgs
```

嵌入式 Home Manager 使用同一组值加上 `home.specialArgs`，写入
`home-manager.extraSpecialArgs`；独立 home 使用相同结构，但全局 `homeConfigurations.<user>`
的 `hostname` 和 `terminus.host` 为 `null`。

## 标准配置与 Colmena

`colmenaHive` 与 `nixosConfigurations` 使用同一份 `ctx.modules`，但 hive 侧额外注入：

- `lib/deploy.nix` 的 `colmenaModule`（deployment 元数据）；
- `lib/hive.nix` 的 shim：

  ```nix
  system.nixos.revision = ...;
  system.nixos.versionSuffix = ...;
  nixpkgs.flake.source = ...;
  ```

这两个额外模块只影响 Colmena 求值。共享 host 模块不得引用 Colmena 的 `name` / `nodes` /
`deployment` option，否则标准配置与 hive 会分叉。

`terminus-colmena-consistency` 比较两边 `toplevel.outPath`。不一致时，优先检查 shim 和是否
误用了 Colmena 专属 option，而不是修改模块去「凑」路径。

## 求值边界

- `meta.nix` 在发现阶段求值，必须是不依赖 `config` / `pkgs` 的纯属性集；
- `default.nix`、`nixos.nix`、`home.nix` 只在 NixOS / Home Manager 求值时执行；
- `exports.nix` 在 host 装配前求值一次，结果对所有主机共享；
- `profiles/<name>/meta.nix` 在发现阶段加载并解析；`nixos.nix` / `home.nix` 只在主机求值时导入；
  `profiles/default/` 存在时自动加入每台主机的选择；
- `packages`、`apps` 等在对应 system 被访问时才 `callPackage`。

## 相关

- [发现机制](discovery.md)
- [模块选择](module-selection.md)
- [Outputs 映射](../reference/outputs.md)
- [`mkFlake` 参数](../reference/mk-flake.md)
