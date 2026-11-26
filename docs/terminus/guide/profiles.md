# 配置集

> 适用版本：`0.1.0`

配置集（profile）是 `profiles/<name>/` 目录：`meta.nix` 声明它需要哪些模块，可选的
`nixos.nix` / `home.nix` 则是普通 NixOS / Home Manager 模块。Profile 同时承担两件事：

- 通过 `requires` 导入一组模块；
- 通过 `nixos.nix` / `home.nix` 提供一组配置。

Host 也可以在 `meta.nix` 中用 `requires` 直接导入模块。Profile 和 Host 都是模块选择来源，
但只有 Profile 携带配置；Host 自身配置仍写在 `default.nix` 等文件。

## 目录结构

```text
profiles/
└── <name>/
    ├── meta.nix     # 必需；纯属性集
    ├── nixos.nix    # 可选；NixOS 模块
    └── home.nix     # 可选；Home Manager 模块
```

- `meta.nix` 必须是纯属性集，不能依赖 `config` / `pkgs`；发现阶段只读取它。
- `nixos.nix` / `home.nix` 不是元数据，而是普通模块，可以使用 `config`、`pkgs`、`lib`、
  `inputs`、`self`、`terminus` 等参数。
- 目录中的其他 `.nix` 文件不会被自动导入；需要时由 `nixos.nix` / `home.nix` 显式 `import`。
- 旧形式 `profiles/<name>.nix` 单文件已移除，会在发现阶段报迁移错误。

## meta.nix

```nix
# profiles/server/meta.nix
{
  requires = [
    "server.ssh"
    "server.node-exporter"
    "server.prometheus"
  ];
}
```

| 字段 | 类型 | 默认 | 作用 |
| --- | --- | --- | --- |
| `requires` | list of string | `[]` | 要导入的模块点号名。 |
| `extends` | list of string | `[]` | 父 Profile；先展开父级。 |

- `requires` / `extends` 必须是字符串列表。
- `extends` 会合并父级的 `requires`、`nixos.nix`、`home.nix`，然后追加自身内容；重复模块名
  和重复配置路径会去重。
- 继承环、未知父 Profile 报错。
- 空 Profile（没有 `requires`，也没有 `nixos.nix` / `home.nix`）报错。
- `meta.nix` 中写 `modules` 会提示改名为 `requires`；写 `common` / `nixos` / `home` 会提示
  配置应放到 `nixos.nix` / `home.nix`。

## nixos.nix / home.nix

配置文件是普通模块，可以直接写 option，也可以写成函数：

```nix
# profiles/cn/nixos.nix
{ lib, ... }:
{
  terminus.nix.substituters.presets.cn = lib.mkDefault true;
}
```

```nix
# profiles/desktop/home.nix
{ lib, pkgs, ... }:
{
  home.packages = [ pkgs.hello ];
}
```

- `nixos.nix` 只注入 NixOS 配置；`home.nix` 只注入 Home Manager 配置。
- 配置模块与普通 NixOS / Home Manager 模块完全一致，可以 `imports`、`mkIf`、`mkDefault`、
  `mkForce`。
- Profile 配置默认是普通优先级。推荐对“主机可能覆盖”的值使用 `lib.mkDefault`：

  ```nix
  terminus.example.enable = lib.mkDefault true;
  ```

  这样 Host `default.nix` 里的普通定义可以覆盖它；如果 Profile 写普通定义，Host 也必须用
  `lib.mkForce` 才能覆盖。
- Profile 配置引用的 option 必须由该 Profile 的 `requires`（或 `default` / Host `requires`）
  导入，否则主机求值会报 option 不存在。

## requires 的两层含义

Profile / Host 的 `requires` 和模块 `meta.nix` 的 `requires` 不是同一层：

| 位置 | 含义 |
| --- | --- |
| `profiles/<name>/meta.nix` 的 `requires` | 该 Profile 要导入的模块。 |
| `hosts/<name>/meta.nix` 的 `requires` | 该 Host 直接导入的模块。 |
| `modules/<path>/meta.nix` 的 `requires` | 模块依赖：目标模块必须已经被导入，只影响校验和顺序。 |

Profile / Host 的 `requires` 是“选择模块”；模块的 `requires` 是“模块之间的依赖”。前者增加
候选，后者不会自动增加候选。

## Host 使用

```nix
# hosts/sha-ali-seldon/meta.nix
{
  profiles = [ "server" "cn" ];
  requires = [ "server.certimate-ssh" ];
}
```

- `profiles` 选择配置集；`requires` 直接导入额外模块，适合只属于这台主机的模块。
- 最终导入的模块是 `default` + 所有选中 Profile 的 `requires` + Host `requires` 的并集。
- Host `requires` 与 Profile `requires` 重复时只导入一次。
- 模块的 side 文件仍由模块自己的 `meta.nix` 决定；没有 NixOS/Home Manager side 文件的模块
  不会出现在对应 side。

## 特殊 Profile：default

`profiles/default/` 是特殊配置集：

- 只要目录存在，就自动应用到每台主机和全局 `homeConfigurations.<user>`；
- Host `profiles` 不需要写 `"default"`；
- 它的 `meta.nix` 通常放所有主机共享模块的 `requires`；
- 它的 `nixos.nix` / `home.nix` 会自动进入所有主机 / home 的配置；
- 缺失不报错，方便最小仓库先跑起来。

本仓库的 `profiles/default/meta.nix`：

```nix
{
  requires = [
    "_common.agenix-cli"
    "_common.basic-packages"
    "_common.home-bash"
    "_common.home-git"
    "_common.home-packages"
    "_common.locale-timezone"
    "_common.motd"
    "_common.nix-experimental"
    "_common.nix-gc"
    "_common.nix-substituters"
    "_common.nix-trusted-users"
  ];
}
```

## 当前仓库的 Profile

| Profile | requires | 配置 |
| --- | --- | --- |
| `default` | 所有主机共享的 `_common` 基础模块 | 无 |
| `server` | `server.*` 通用模块（不含 `certimate-ssh`） | 无 |
| `client` | `client.ssh`、`client.deepseek-harness` | 无 |
| `dn42` | `dn42.bird2`、`bird-lg-proxy`、`coredns`、`wireguard` | 无 |
| `wsl` | `wsl.base` | 无 |
| `cn` | `_common.nix-substituters.cn` | `nixos.nix` 默认启用 `presets.cn` |
| `global` | `_common.nix-substituters.global` | `nixos.nix` 默认启用 `presets.global` |

`server.certimate-ssh` 只被 `sha-ali-seldon` 使用，因此放在该主机的 `requires` 中，而不是
`server` Profile。

## 选择与注入

对每台主机、每个 side：

1. 生效 Profile = `default`（若存在）+ `meta.profiles`；
2. 候选模块 = 各 Profile `requires` + `meta.requires`，去重；
3. 只保留该 side 有文件且 `meta.<side>.enable` 不为 false 的模块；
4. 按模块依赖排序，导入完整 side 文件；
5. 把生效 Profile 的 `nixos.nix` / `home.nix` 作为配置模块注入对应 side。

Profile 配置在模块 imports 之后、Host magic 文件之前注入；Host `default.nix` 和
`homes/<user>/*.nix` 在更后面，因此配合 `lib.mkDefault` 可以实现 Host 覆盖。

## 校验与错误

| 情况 | 错误 |
| --- | --- |
| 旧单文件 Profile | `legacy profile file 'profiles/<name>.nix' is no longer supported` |
| Profile 目录缺 `meta.nix` | `missing required file` |
| Profile 的 `requires` 引用未知模块 | `unknown profile requires '<name>'` |
| Host 的 `requires` 引用未知模块 | `unknown host requires '<name>'` |
| requires 的模块没有 side 文件 | `module '<name>' has no NixOS or Home Manager side files` |
| 空 Profile、继承环、未知父级 | `invalid meta.nix` / `profile inheritance cycle` |
| 旧 `modules` 字段 | `unsupported profile meta field 'modules'`，提示改 `requires` |

## 从旧模型迁移

旧版本 Profile 是单文件，只列模块名：

```nix
# profiles/cn.nix（旧）
{
  nixos = [ "_common.nix-substituters.cn" ];
}
```

新结构：

```text
profiles/cn/meta.nix
profiles/cn/nixos.nix
```

```nix
# profiles/cn/meta.nix
{ requires = [ "_common.nix-substituters.cn" ]; }
```

```nix
# profiles/cn/nixos.nix
{ lib, ... }:
{
  terminus.nix.substituters.presets.cn = lib.mkDefault true;
}
```

- `modules = [...]` 改为 `requires = [...]`；
- `common` / `nixos` / `home` 的模块名列表改为 `requires`，side 由模块自己的 `meta.nix`
  决定；
- Profile 配置写进 `nixos.nix` / `home.nix`；
- Host 级导入覆盖 `modules` 已移除；需要时用 Host `meta.requires`。

## 相关

- [模块](modules.md)
- [模块依赖](module-dependencies.md)
- [模块选择](../concepts/module-selection.md)
- [主机](hosts.md)
