# 目录结构

> 适用版本：`0.1.0`

Terminus 把目录位置直接映射为 flake outputs。本页给出完整目录树和 magic 文件规则；发现阶段的
实现细节见[发现机制](../concepts/discovery.md)，output 的完整列表见
[Outputs 映射](../reference/outputs.md)。

## 目录树

```text
.
├── flake.nix                       # inputs + (import ./lib).mkFlake
├── lib/                            # 框架实现，不是用户库
│   ├── default.nix                 # mkFlake
│   ├── discover.nix                # 纯文件系统扫描
│   ├── metadata.nix                # meta.nix 校验与归一化
│   ├── modules.nix                 # Profile 选择与依赖排序
│   ├── profiles.nix                # profiles/<name>/ 加载与继承
│   ├── depgraph.nix                # 稳定拓扑排序
│   ├── hosts.nix                   # 主机模块装配
│   ├── home.nix                    # 嵌入式与独立 Home Manager
│   ├── users.nix                   # users.<name>/groups 生成
│   ├── secret.nix                  # secretsDir helper
│   ├── deploy.nix                  # deploy 用户与 Colmena 元数据
│   ├── hive.nix                    # colmenaHive + toplevel 一致性 shim
│   ├── outputs.nix                 # packages/apps/shells/checks/overlays/lib
│   ├── diagnostics.nix             # 框架 checks 与 discovery 报告
│   └── internal/                   # errors、exports 收集
├── hosts/
│   └── <name>/
│       ├── meta.nix                # 必需：system、profiles、requires、deployment 等
│       ├── default.nix             # 必需：主机核心 NixOS 模块
│       ├── hardware.nix            # 可选：存在则自动导入
│       ├── disk.nix                # 可选：存在则自动导入
│       └── network.nix             # 可选：存在则自动导入
├── users/
│   └── <name>/
│       ├── meta.nix                # 必需：hosts、uid、密码等
│       └── default.nix             # 可选：users.users.<name> 补充模块
├── homes/
│   └── <user>/
│       ├── default.nix             # homeConfigurations.<user>
│       ├── <host>.nix              # homeConfigurations."<user>@<host>"
│       └── _*.nix                  # 被 discovery 忽略，由上面文件 imports
├── modules/
│   └── <namespace>/<path>/
│       ├── options.nix             # NixOS + Home Manager 共享 options
│       ├── default.nix             # 两侧共享实现
│       ├── nixos.nix               # NixOS 侧实现
│       ├── home.nix                # Home Manager 侧实现
│       ├── exports.nix             # 合并到 terminus.exports
│       └── meta.nix                # 侧开关与依赖声明
├── profiles/
│   ├── default/                    # 特殊：存在时自动应用到所有主机
│   │   ├── meta.nix                # 必需：requires / extends
│   │   └── nixos.nix / home.nix    # 可选：配置模块
│   └── <name>/
│       ├── meta.nix                # 必需：requires / extends
│       ├── nixos.nix               # 可选：NixOS 配置
│       └── home.nix                # 可选：Home Manager 配置
├── packages/
│   ├── <name>/default.nix          # packages.<system>.<name>
│   ├── <name>/meta.nix             # 可选：enable / systems
│   └── <system>/<name>/default.nix # 仅对应架构的包
├── overlays/<name>/default.nix     # overlays.<name>，并应用到统一包集
├── apps/<name>/default.nix         # apps.<system>.<name>
├── shells/<name>/default.nix       # devShells.<system>.<name>
├── checks/<name>/default.nix       # checks.<system>.<name>；terminus- 前缀保留
├── formatter/default.nix           # formatter.<system>
├── secrets/                        # 默认 secretsDir
│   ├── agenix-rules.nix
│   ├── keys.nix
│   └── <category>/<name>.age
└── keys/deploy/*.pub               # 远程 deploy 用户公钥
```

## 目录到 output

| 路径 | 生成的 output / 作用 |
| --- | --- |
| `hosts/<name>/default.nix` | `nixosConfigurations.<name>`，同时进入 `colmenaHive.nodes.<name>`。 |
| `hosts/<name>/meta.nix` | 发现阶段的主机元数据；`system` 必需，决定该主机使用的 nixpkgs 架构。 |
| `hosts/<name>/{hardware,disk,network}.nix` | 存在则作为主机 magic 文件自动导入。 |
| `users/<name>/meta.nix` | 生成关联主机的 `users.users.<name>` 与 `users.groups.<group>`。 |
| `users/<name>/default.nix` | 可选补充模块，可覆盖用户默认值、添加 SSH key 等。 |
| `homes/<user>/default.nix` | `homeConfigurations.<user>`（`home.standalone = true` 时），并嵌入关联主机。 |
| `homes/<user>/<host>.nix` | `homeConfigurations."<user>@<host>"`，并嵌入该主机的 Home Manager。 |
| `modules/<namespace>/<path>/{options,default,nixos,home}.nix` | 被 Profile 选中后注入 NixOS / Home Manager；同时导出 `nixosModules` / `homeModules`。 |
| `modules/<namespace>/<path>/exports.nix` | 合并到 `terminus.exports`，不直接作为模块导入。 |
| `profiles/default/` | 不单独生成 output；存在时自动应用到每台主机和全局 home。 |
| `profiles/<name>/` | 不单独生成 output；被主机的 `meta.profiles` 引用。`meta.nix` 的 `requires` 导入模块，`nixos.nix` / `home.nix` 注入配置。 |
| `packages/<name>/default.nix` | `packages.<system>.<name>`。 |
| `packages/<system>/<name>/default.nix` | 仅该架构的 `packages.<system>.<name>`。 |
| `overlays/<name>/default.nix` | `overlays.<name>`，并应用到所有 per-system 包集。 |
| `apps/<name>/default.nix` | `apps.<system>.<name>`。 |
| `shells/<name>/default.nix` | `devShells.<system>.<name>`。 |
| `checks/<name>/default.nix` | `checks.<system>.<name>`。 |
| `formatter/default.nix` | `formatter.<system>`；不存在时回退到 `pkgs.nixfmt`。 |
| `lib/*.nix` | 机械导出为 `lib.<name>`；本仓库中即框架内部文件，不是用户扩展点。 |
| `secrets/` | 不直接生成 output；通过 `terminus.secrets` 和 agenix 规则消费。 |
| `keys/deploy/*.pub` | 内容被读取为远程 deploy 用户的 `openssh.authorizedKeys.keys`。 |

## Magic 文件

只有固定文件名会被自动识别，其他文件不会被框架扫描或导入。

| 目录 | 自动识别 | 说明 |
| --- | --- | --- |
| `hosts/<name>/` | `meta.nix`、`default.nix`、`hardware.nix`、`disk.nix`、`network.nix` | `meta.nix` 与 `default.nix` 必需；其余三个存在才导入，顺序固定为 `default → hardware → disk → network`。 |
| `users/<name>/` | `meta.nix`、`default.nix` | `meta.nix` 必需；`default.nix` 可选。 |
| `homes/<user>/` | `default.nix`、`<host>.nix` | `_*.nix` 与 `meta.nix` 被忽略；`<host>.nix` 的文件名必须是已存在的主机。 |
| `modules/<namespace>/<path>/` | `options.nix`、`default.nix`、`nixos.nix`、`home.nix`、`exports.nix`、`meta.nix` | 目录中至少有一个 magic 文件才会被当作模块；其余 `.nix` 文件不会自动导入。 |
| `packages/`、`overlays/`、`apps/`、`shells/`、`checks/` | `default.nix`、`meta.nix` | 必须存在 `default.nix` 才会被发现。 |
| `profiles/` | 每个子目录是一个配置集 | 目录内 `meta.nix` 必需，`nixos.nix` / `home.nix` 可选；`profiles/default/` 自动应用。旧的 `profiles/<name>.nix` 会报迁移错误。 |
| `formatter/` | `default.nix`、`meta.nix` | 仅一个 formatter。 |
| `keys/deploy/` | 任意 `*.pub` | 文件内容被 trim 后去重，作为 deploy 公钥列表。 |

## 不会被自动处理的内容

- `hosts/<name>/` 下除 magic 文件外的 `.nix` 文件：需要由 `default.nix` 显式 `import`。
- `modules/<namespace>/<path>/` 下除 magic 文件外的 `.nix` 文件：需要由同目录的 side 文件显式
  `import`。
- `profiles/<name>/` 下除 `meta.nix` / `nixos.nix` / `home.nix` 外的 `.nix` 文件：需要由
  `nixos.nix` / `home.nix` 显式 `import`。
- `homes/<user>/_*.nix`：用于拆分片段，必须由 `default.nix` 或 `<host>.nix` 显式导入。
- `homes/<user>/meta.nix`：Home 目录当前不读取元数据。
- 符号链接：发现列表会忽略符号链接，不会把它当作目录或普通文件；不要用符号链接组织
  hosts/modules。

## 命名与排序

- 模块键由相对 `modules/` 的路径用 `.` 连接：`modules/server/frps/` → `server.frps`；
  嵌套目录各自成为独立模块，例如 `modules/_common/nix-substituters/cn/` →
  `_common.nix-substituters.cn`。
- 模块根目录本身若包含 magic 文件，键为 `_root`。
- 发现按文件名排序，因此列表与重复检查结果是稳定的。
- 主机 magic 文件按 `default → hardware → disk → network` 导入，与文件名排序无关。
- 模块 side 文件按 `options → default → nixos`（或 `options → default → home`）导入。

## 相关

- [发现机制](../concepts/discovery.md)
- [模块选择](../concepts/module-selection.md)
- [Outputs 映射](../reference/outputs.md)
- [主机](hosts.md)
