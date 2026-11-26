# meta.nix 字段

> 适用版本：`0.1.0`

`meta.nix` 是发现阶段的接口，必须直接返回属性集，不能是 NixOS / Home Manager 模块，也不能
依赖 `config`、`pkgs`、`lib`。框架只读取下表中的已知字段；Host 和 User 的未知字段会被忽略但
保留在 `raw` 中（已移除的 `roles` / `role` / `modules` 会直接报错），Module 的 `meta.nix`
没有 `raw` 字段。

## Host：hosts/<name>/meta.nix

```nix
{
  system = "x86_64-linux";
  description = "Test Server";
  profiles = [ "server" "cn" ];

  home = {
    embed = true;
    useGlobalPkgs = true;
  };

  secrets.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  deployment = {
    targetHost = "sha-ali-gaal";
    targetPort = 2333;
    sshUser = "deploy";
    buildOnRemote = false;
    tags = [ "server" ];
    sshOptions = [ ];
    allowLocalDeployment = false;
    replaceUnknownProfiles = true;
  };
}
```

| 字段 | 类型 | 默认 | 校验 / 说明 |
| --- | --- | --- | --- |
| `system` | string | 必填 | 缺失报 `must declare a system`。 |
| `profiles` | list of string | `[]` | 必须是字符串列表；`default` 存在时自动应用。 |
| `requires` | list of string | `[]` | 该主机直接导入的模块点号名。 |
| `description` | string / `null` | `null` | 供模块/文档读取。 |
| `home.embed` | bool / `null` | `null` | `null` 表示继承 `mkFlake` 的 `home.embed`。 |
| `home.useGlobalPkgs` | bool / `null` | `null` | `null` 表示继承全局值。 |
| `secrets.identityPaths` | list of string / `null` | `null` | 覆盖默认 agenix 身份路径。 |
| `deployment.targetHost` | string / `null` | `null` | 非 `null` 时创建远程 deploy 用户。 |
| `deployment.targetPort` | int / `null` | `22` | 必须是整数或 `null`。 |
| `deployment.sshUser` | string / `null` | `null` | `null` 时使用 deploy 用户名。 |
| `deployment.buildOnRemote` | bool | `false` | 对应 Colmena `buildOnTarget`。 |
| `deployment.tags` | list of string | `[]` | Colmena 标签。 |
| `deployment.sshOptions` | list of string | `[]` | 额外 SSH 参数；不要写本机私钥路径。 |
| `deployment.allowLocalDeployment` | bool / `null` | `null` | `null` 时取 `targetHost == null`。 |
| `deployment.replaceUnknownProfiles` | bool / `null` | `null` | `null` 时取 `true`。 |
| `raw` | attrset | 原始值 | 归一化时自动加入，只读使用。 |

`roles`、`role`、`modules` 已移除；在 host meta 中出现会报 `unsupported host meta field`。
需要直接导入模块时写 `requires = [ "module.name" ]`，或把模块写进 Profile。

```nix
# hosts/sha-ali-seldon/meta.nix
{
  profiles = [ "server" "cn" ];
  requires = [ "server.certimate-ssh" ];
}
```

## User：users/<name>/meta.nix

```nix
{
  hosts = [ "sha-ali-gaal" ];
  uid = 1000;
  group = "users";
  extraGroups = [ "wheel" ];
  description = "Allenyou";
  hashedPasswordSecret = "common/allenyou-password";
}
```

| 字段 | 类型 | 默认 | 校验 / 说明 |
| --- | --- | --- | --- |
| `hosts` | list of string | `[]` | 与 `homes/<user>/<host>.nix` 的主机取并集；最终不能为空。 |
| `uid` | int / `null` | `null` | 同时作为默认 GID。 |
| `gid` | int / `null` | `null` | 主组 GID；未设置时使用 `uid`。 |
| `group` | string / `null` | `null` | 未设置时使用用户名。 |
| `extraGroups` | list of string | `[]` | 附加组。 |
| `description` | string / `null` | `null` | GECOS 描述。 |
| `home` | string / `null` | `null` | 家目录。 |
| `createHome` | bool | `true` | 是否创建家目录。 |
| `isNormalUser` | bool | `true` | 是否普通用户。 |
| `hashedPassword` | string / `null` | `null` | 与 `hashedPasswordSecret` 互斥。 |
| `hashedPasswordSecret` | string / `null` | `null` | 相对 agenix 名或 `/` 开头的绝对路径。 |
| `raw` | attrset | 原始值 | 只读。 |

同时设置 `hashedPassword` 与 `hashedPasswordSecret` 报：

```text
terminus: invalid meta.nix
  expected: only one of hashedPassword and hashedPasswordSecret may be set
```

## Module：modules/<namespace>/<path>/meta.nix

```nix
{
  requires = [ "server.base" ];
  after = [ "server.database" ];
  before = [ "server.frontend" ];
  wants = [ "server.metrics" ];
  conflicts = [ "server.legacy" ];

  nixos = {
    enable = true;
    requires = [ "server.base" ];
  };

  home = {
    enable = false;
  };
}
```

| 字段 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `requires` | list of string | `[]` | 硬依赖，双方共享。 |
| `after` | list of string | `[]` | 软顺序。 |
| `before` | list of string | `[]` | 软顺序。 |
| `wants` | list of string | `[]` | 软依赖。 |
| `conflicts` | list of string | `[]` | 冲突。 |
| `nixos.enable` | bool | `true` | 关闭整个 NixOS side。 |
| `nixos.requires` / `after` / `before` / `wants` / `conflicts` | list of string | `[]` | 追加到共享字段。 |
| `home.enable` | bool | `true` | 关闭整个 Home Manager side。 |
| `home.requires` / `after` / `before` / `wants` / `conflicts` | list of string | `[]` | 追加到共享字段。 |

`meta.nix` 缺失时使用全部默认值。`meta.nix` 不是模块，不会被导入；它必须是纯属性集。

## Output：packages/overlays/apps/shells/checks/formatter

```nix
# packages/<name>/meta.nix
{
  enable = true;
  systems = [ "x86_64-linux" ];
}
```

| 字段 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `enable` | bool | `true` | 为 false 时不生成该 output。 |
| `systems` | list of string / `null` | `null` | 限制 system；`null` 表示所有派生 system。 |
| `description` | string / `null` | `null` | 被读取但当前不参与 output 生成。 |

注意：

- packages 的 `systems` 还会影响旧式 `packages/<name>.<system>` 后缀是否拆分；显式声明
  `systems` 时保留完整目录名作为包名；
- overlays 的 `systems` 参与 system 推导，但 enabled overlay 仍会应用到所有派生 system；
- formatter 的 `systems` 决定哪些 system 使用自定义 formatter，其余回退 `pkgs.nixfmt`；
- checks 名称以 `terminus-` 开头会报保留名错误。

## Profile：profiles/<name>/

配置集是目录，不是 `meta.nix` 本身：

```text
profiles/<name>/
  meta.nix     # 必需；纯属性集
  nixos.nix    # 可选；NixOS 模块
  home.nix     # 可选；Home Manager 模块
```

`meta.nix`：

```nix
{
  extends = [ "base" ];
  requires = [ "server.prometheus" ];
}
```

| 字段 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `extends` | list of string | `[]` | 父配置集。 |
| `requires` | list of string | `[]` | 要导入的模块点号名。 |
| `raw` | attrset | 原始值 | 归一化时自动加入，只读使用。 |

规则：

- `meta.nix` 必需；`requires` / `extends` 必须是字符串列表；
- 展开后 `requires`、`nixos.nix`、`home.nix` 全空时报错；
- 未知父配置集、继承环、未知 requires 成员、模块没有 side 文件都会报错；
- `meta.nix` 中写 `modules` 会提示改名为 `requires`；写 `common` / `nixos` / `home` 会提示
  配置应放到 `nixos.nix` / `home.nix`；
- `profiles/default/` 是特殊 Profile：存在时自动应用到每台主机和全局 home；
- 旧的单文件 `profiles/<name>.nix` 会报迁移错误。

`nixos.nix` / `home.nix` 是普通 NixOS / Home Manager 模块，不是元数据；它们会在主机求值时
注入对应 side。推荐用 `lib.mkDefault` 让 Host 覆盖 Profile 的默认配置。

Profile 的 `requires` 只负责导入模块；Profile 配置和 Host `default.nix` 才是设置 option 值的
地方。未被任何生效 Profile/Host `requires` 选中的模块，其 `options.nix` / `default.nix`
也不会导入。

## 错误格式

所有字段校验失败都会走 `lib/internal/errors.nix`，例如：

```text
terminus: invalid meta.nix
  file:     /path/hosts/foo/meta.nix
  expected: profiles must be a list of strings
  got:      string
```

`system` 缺失是单独的错误：

```text
terminus: hosts/<name>/meta.nix must declare a system
example:
  { system = "x86_64-linux"; }
```

## 相关

- [主机](../guide/hosts.md)
- [用户](../guide/users.md)
- [模块](../guide/modules.md)
- [发现机制](../concepts/discovery.md)
