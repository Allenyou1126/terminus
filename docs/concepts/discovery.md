# 发现机制

> 适用版本：`0.1.0`

发现（discovery）是 Terminus 把目录树转成 flake outputs 的第一步。它是**纯文件系统扫描**：
只读取目录结构和 `meta.nix`，不求值任何 NixOS / Home Manager 配置。

## 扫描范围

| 目录 | 发现对象 | 索引 |
| --- | --- | --- |
| `hosts/` | 每台主机的 `meta.nix`、`default.nix`、magic 文件 | `hosts`、`hostsByName` |
| `homes/` | 每个用户的 `default.nix`、`<host>.nix` | `homes`、`homesByUser` |
| `users/` | 每个用户的 `meta.nix`、可选 `default.nix` | `users`、`usersByName`、`usersByHost` |
| `modules/` | 每个含 magic 文件的目录（递归） | `localModules`、`modulesByName` |
| `profiles/` | 每个子目录是一个配置集 | `profiles.defs`、`profiles.resolved` |
| `packages/` | 包目录 | `packages` |
| `overlays/`、`apps/`、`shells/`、`checks/` | 含 `default.nix` 的目录 | 同名列表 |
| `formatter/` | `formatter/default.nix` | `formatter` |
| `lib/` | `lib/*.nix` | `libFiles` |
| `keys/deploy/` | `*.pub` 文件内容 | `deployKeys` |

所有目录读取都按名称排序（`lib/fs.nix`），因此发现结果稳定、可复现。

## 文件系统边界

- `fs.listDir` 使用 `builtins.readDir`，只区分 `directory`、`regular` 等类型；
- 符号链接不会出现在目录或普通文件列表中；不要用符号链接组织 hosts/modules；
- 隐藏文件（以 `.` 开头）会参与 `readDir`，但不会匹配 magic 文件名；
- 只有普通文件才会被 `nixFiles` 选为模块/host 文件。

## hosts/

对 `hosts/` 下每个目录：

1. 读取 `meta.nix`；缺失则报错；
2. 用 `normalizeHostMeta` 校验并归一化；`system` 缺失直接报错；
3. 要求 `default.nix` 存在；
4. 记录 `default.nix`、`hardware.nix`、`disk.nix`、`network.nix` 中存在的 magic 文件；
5. 记录其他 `.nix` 文件，但不自动导入。

主机名就是目录名。`meta.profiles` / `meta.requires`、`deployment` 等字段只做归一化，不在发现
阶段求值 NixOS 配置。

## homes/

对 `homes/<user>/` 下每个 `.nix` 文件：

- `default.nix` → host 为 `null`；
- `<name>.nix` → host 为 `<name>`，且必须是已存在的主机；
- `meta.nix` 和 `_` 开头的文件被忽略。

因此 `homes/<user>/foo.nix` 中的 `foo` 必须是 `hosts/foo/`。如果只是想拆分片段，命名为
`_foo.nix` 并从 `default.nix` / `<host>.nix` 显式导入。

## users/

每个 `users/<name>/` 必须有 `meta.nix`。用户的主机列表是：

```text
users/<name>/meta.nix 的 hosts
∪ homes/<name>/<host>.nix 中出现的主机名
```

结果去重后逐个校验主机存在。如果为空，报错：

```text
terminus: users/<name>/meta.nix does not associate the user with any host
```

同时检查每个 home 用户都有对应的 `users/<user>/`，否则报 `unknown user`。

`users/<name>/default.nix` 可选；它只记录路径，不在此阶段求值。

## modules/

`modules/` 递归扫描。一个目录只有在包含以下任一文件时才成为模块：

```text
options.nix  default.nix  nixos.nix  home.nix  exports.nix
```

模块名是相对 `modules/` 的路径，用 `.` 连接；根目录自身的模块名是 `_root`。目录中的
`meta.nix` 可选，缺失时使用默认值（两侧 enable、无依赖）。

记录内容：

- `files`：文件名到路径的映射；
- `side.nixos`：`options.nix`、`default.nix`、`nixos.nix`；
- `side.home`：`options.nix`、`default.nix`、`home.nix`；
- `meta`：归一化后的侧开关与依赖字段。

重复模块名会在发现阶段直接报错。

## profiles/

`profiles/` 下每个子目录是一个配置集：

```text
profiles/<name>/
  meta.nix     # 必需；requires / extends
  nixos.nix    # 可选；NixOS 配置模块
  home.nix     # 可选；Home Manager 配置模块
```

- `meta.nix` 缺失报 `missing required file`；
- `meta.nix` 读取 `requires` / `extends`，两者都必须是字符串列表；
- `meta.nix` 中写 `modules` / `common` / `nixos` / `home` 会报迁移错误；
- 对每个配置集递归解析 `extends`，检测循环；
- 展开后 `requires`、`nixos.nix`、`home.nix` 全空时报错；
- 未知父配置集报错；
- 所有 Profile 的 `requires` 与 Host `requires` 成员必须存在于 `modulesByName`，且至少有一个
  side 文件；
- `profiles/default/` 是特殊 Profile：存在时自动应用到每台主机和全局 home；
- `profiles/<name>.nix` 单文件会报迁移错误。

`nixos.nix` / `home.nix` 不在发现阶段求值，只记录路径；它们作为普通模块在主机配置中导入。

## packages/

对 `packages/` 下每个目录：

- 如果目录自身有 `default.nix`，它是一个包；
  - 若 `meta.nix` 未声明 `systems`，且目录名以已知 system 结尾（如 `.x86_64-linux`），
    去掉后缀作为包名，后缀作为 `system`；
  - 否则完整目录名就是包名；
- 否则把子目录当作 `<system>/<name>/default.nix` 布局；
- 两种布局都读取可选的 `meta.nix`。

重复的 `system:name` 组合会在发现阶段报错。

## 其他 outputs

`overlays/`、`apps/`、`shells/`、`checks/` 只发现**目录**且目录内必须有 `default.nix`；
每个目录读取可选 `meta.nix`。`checks/` 的 `terminus-` 前缀在 outputs 阶段检查。

`formatter/` 只在 `formatter/default.nix` 存在时记录。`lib/*.nix` 记录为 `libFiles`；
`keys/deploy/*.pub` 读取内容、trim、去空、去重。

## meta.nix 读取

`meta.nix` 的读取规则：

```nix
value = import file;
if isAttrs value then value else error
```

因此：

- 必须直接返回属性集；
- 不能写成 `{ config, ... }:` 形式的函数；
- 不能引用 `pkgs`、`config` 等模块参数；
- 校验失败会报 `terminus: invalid meta.nix`，并给出文件、期望类型和实际类型。

各目录的字段校验见 [`meta.nix` 字段](../reference/meta.md)。

## Discovery 报告

`nix run .#terminus-discovery` 输出 JSON（`lib/diagnostics.nix` 生成）：

```json
{
  "frameworkVersion": "0.1.0",
  "systems": [ "x86_64-linux" ],
  "hosts": [ "sha-ali-gaal" ],
  "users": [ "allenyou" ],
  "homes": [ { "user": "allenyou", "host": null } ],
  "modules": [ "_common.motd", "server.frps" ],
  "profiles": [ "cn", "default", "global", "server" ],
  "profileRequires": {
    "default": [ "_common.motd" ],
    "server": [ "server.frps" ]
  },
  "profileConfig": {
    "cn": { "nixos": true, "home": false },
    "server": { "nixos": false, "home": false }
  },
  "hostProfiles": {
    "sha-ali-gaal": [ "server", "cn" ]
  },
  "hostRequires": {
    "sha-ali-gaal": []
  },
  "packages": [ "certimate" ],
  "overlays": [],
  "apps": [],
  "shells": [],
  "checks": [],
  "formatter": "formatter",
  "deploy": {
    "sha-ali-gaal": {
      "targetHost": "sha-ali-gaal",
      "targetPort": 2333,
      "sshUser": "deploy",
      "tags": [ "server" ]
    }
  },
  "secretsDir": "/path/to/secrets",
  "colmenaNodes": [ "sha-ali-gaal" ]
}
```

说明：

- `modules`、`profiles`、`profileRequires`、`profileConfig` 等只是**发现结果**，不代表某台主机
  最终导入它们；
- `hostProfiles` / `hostRequires` 是主机 `meta.profiles` / `meta.requires` 的声明值；
  `default` 不写入这里，但会自动生效；
- `deploy` 只包含 `targetHost != null` 的远程主机；
- `colmenaNodes` 是 `colmenaHive.nodes` 的全部节点，包含本机；
- `secretsDir` 是 `toString` 后的路径，可能被 Nix 复制到 store；
- 报告不包含模块依赖图或逐主机选择结果。

`checks.<system>.terminus-discovery` 把同一份 JSON 写入 store 文件，供 CI 或调试使用。

## 相关

- [目录结构](../guide/directory-structure.md)
- [模块选择](module-selection.md)
- [Outputs 映射](../reference/outputs.md)
- [`meta.nix` 字段](../reference/meta.md)
