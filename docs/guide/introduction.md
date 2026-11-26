# 介绍

> 适用版本：`0.1.0`

Terminus 是一套以目录约定驱动的 NixOS 配置框架。它把「发现目录」和「求值 NixOS / Home Manager
模块」分开：`lib/` 只扫描文件、读取 `meta.nix`、选择模块并拼装 outputs；真正的系统配置仍由
NixOS 和 Home Manager 的模块系统求值。

## 它解决什么问题

一份多主机 NixOS 仓库通常会堆积三类重复：

- 每台主机手写一份 `modules = [ ... ]` 列表；
- NixOS 与 Home Manager 各维护一棵平行的模块树；
- 远程部署、密钥、用户和主机元数据散落在不同文件里。

Terminus 用目录约定替代这些样板：

```text
hosts/<name>/        → nixosConfigurations.<name>、colmenaHive.nodes.<name>
homes/<user>/        → homeConfigurations.<user> / "<user>@<host>"
users/<name>/        → 该主机的 users.users / users.groups
modules/<namespace>/... → 按 Profile 选择后注入主机
profiles/<name>/        → requires 模块 + nixos/home 配置
secrets/             → agenix 的唯一密钥目录
```

框架不会改变 NixOS 的 option merge、`mkIf`、`mkDefault` 或模块求值方式。它只负责把正确的
文件送进模块系统。

## 自包含，而不是外部 input

这是 Terminus 与 Snowveil 最重要的区别：

```nix
# Snowveil：框架是外部 flake input
outputs = inputs: inputs.snowveil.lib.mkFlake { inherit inputs; };
```

```nix
# Terminus：框架与配置在同一个仓库
outputs = inputs@{ self, nixpkgs, ... }:
  (import ./lib { lib = nixpkgs.lib; }).mkFlake {
    inherit inputs self;
    root = ./.;
  };
```

因此：

- `lib/` 就是框架源码，修改框架不需要改 flake input 或重新锁定依赖；
- 框架版本与配置版本一起演进；
- flake 的 `lib` output 会把 `lib/*.nix` 机械导出为 `lib.<name>`；本仓库中它是框架内部文件的
  映射，不是用户扩展点，也不是 `mkFlake` 本身（`lib.default` 返回 `{ version, mkFlake }`）；
- 没有 `mkSystem` / `mkHome` 这样的细粒度逃生舱，所有主机统一走 `mkFlake`。

## 设计原则

- **约定优于配置**：目录位置决定 output 和模块归属，不需要维护 import 列表。
- **发现与求值分离**：`lib/discover.nix` 只做文件系统扫描，不触发任何 NixOS 配置求值。
- **单一模块树**：一个功能目录同时容纳 `options.nix`、`default.nix`、`nixos.nix`、`home.nix`，
  避免 NixOS 与 Home Manager 两棵平行树。
- **Profile 选择与配置、模块实现**：Profile 的 `requires` 决定导入哪些模块，`nixos.nix` /
  `home.nix` 提供配置；模块内部仍可实现细粒度 option。
- **标准配置与 Colmena 同源**：`nixosConfigurations` 和 `colmenaHive` 共用同一份 host modules，
  并用检查保证 toplevel 一致。
- **纯 `nixpkgs.lib`**：框架代码不直接依赖 `flake-utils` 或 `flake-parts`。
- **惰性 outputs**：发现结果先建索引，具体主机和 Home Manager 配置在访问时才求值。

## 组合概念

| 概念 | 定义位置 | 作用 | 是否设置 option 值 |
| --- | --- | --- | --- |
| Profile（配置集） | `profiles/<name>/` | `meta.nix` 的 `requires` 导入模块；`nixos.nix` / `home.nix` 提供配置 | 是，作为普通模块 |
| default Profile | `profiles/default/` | 存在时自动应用到每台主机和全局 home | 是 |
| Host requires | `hosts/<name>/meta.nix` 的 `requires` | 直接导入只属于该主机的模块 | 否 |
| Module（模块） | `modules/<namespace>/<path>/` | 提供 options 与具体配置实现 | 是，模块内部自行 `mkIf` |

一句话：**Profile 提供模块和配置，Module 实现功能，Host 可以额外 require 模块。**

没有被 `default`、主机 `profiles` 或 Host `requires` 选中的模块，其 `options.nix` /
`default.nix` 也不会导入；因此 `requires` 同时决定了 option 接口是否可见。Profile 配置是普通
NixOS / Home Manager 模块，推荐用 `lib.mkDefault` 让 Host 可覆盖。

## 与 Snowveil 的差异

Terminus 借鉴了 Snowveil 的目录约定和文档结构，但没有实现 Snowveil 的全部能力：

| 维度 | Snowveil | Terminus |
| --- | --- | --- |
| 框架形态 | 独立 flake，作为 input 引入 | 框架与配置同仓，`lib/` 直接导入 |
| 入口 | `mkFlake` / `mkSystem` / `mkHome` / `mkLib` | 仅 `mkFlake` |
| Secrets | sops-nix | agenix + 单一 `secretsDir` |
| 部署 | 独立 `deploy` output 等 | 内置 `colmenaHive`、deploy 用户、一致性检查 |
| 模块组合 | roles、profiles、modules、模块组、虚拟能力 | profiles、依赖字段；无角色/模块组/能力 |
| 镜像 | `meta.images.formats` | 不支持 |
| 诊断 | discovery JSON、模块图 DOT 等 | discovery / eval / secret / sudo / consistency checks；无模块图 DOT |
| 主机级包/overlay 选择 | `meta.snowveil.packages` / `overlays` | 不支持；overlay 对全局包集生效 |
| 版本基线 | 以 Snowveil 上游文档为准 | `0.1.0` |

迁移时不要假设 Snowveil 的 `snowveil.*` option、`moduleGroups`、`requiresCapabilities`、`images`
或 `deploy` output 在 Terminus 中存在。对应能力需要在本仓库的模块里单独实现。

## 仓库地图

| 路径 | 作用 |
| --- | --- |
| [`flake.nix`](../../flake.nix) | 声明 inputs，并调用 `lib` 的 `mkFlake`。 |
| [`lib/`](../../lib/) | 框架实现：发现、元数据、模块选择、装配、outputs。 |
| [`hosts/`](../../hosts/) | 每台主机的 `meta.nix` 与模块文件。 |
| [`users/`](../../users/) | 用户元数据与用户级补充模块。 |
| [`homes/`](../../homes/) | 每用户的 Home Manager 配置。 |
| [`modules/`](../../modules/) | 按命名空间组织的功能模块。 |
| [`profiles/`](../../profiles/) | 配置集目录；`meta.nix` 的 `requires` + `nixos.nix` / `home.nix` 配置，`default/` 自动应用。 |
| [`packages/`](../../packages/) | 自定义包。 |
| [`secrets/`](../../secrets/) | agenix 规则与加密文件。 |
| [`keys/deploy/`](../../keys/deploy/) | 远程部署用户公钥。 |

框架内部文件的职责见[求值模型](../concepts/architecture.md)，目录与 output 的完整映射见
[Outputs 映射](../reference/outputs.md)。

## 相关

- [快速开始](getting-started.md)
- [目录结构](directory-structure.md)
- [求值模型](../concepts/architecture.md)
- [与 Snowveil 的对照](#与-snowveil-的差异)
