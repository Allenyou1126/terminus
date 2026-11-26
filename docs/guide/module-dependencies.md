# 模块依赖

> 适用版本：`0.1.0`

模块目录可以在 `meta.nix` 中声明依赖、顺序与冲突。框架为 NixOS 与 Home Manager 分别建立
依赖图，在 Profile/Host `requires` 选出模块后做稳定拓扑排序。

## 字段

```nix
# modules/server/example/meta.nix
{
  requires = [ "server.base" ];
  after = [ "server.database" ];
  before = [ "server.frontend" ];
  wants = [ "server.metrics" ];
  conflicts = [ "server.legacy" ];
}
```

| 字段 | 语义 | 目标未启用时 |
| --- | --- | --- |
| `requires` | 硬依赖，目标必须启用，且目标先导入。 | 报错 `requires ... but ... is not enabled`。 |
| `after` | 软顺序，目标启用时排在其后。 | 忽略。 |
| `before` | 软顺序，目标启用时排在其前。 | 忽略。 |
| `wants` | 软依赖，目标启用时排在其后；不会自动启用目标。 | 忽略。 |
| `conflicts` | 双方同时启用时组合失败。 | 忽略。 |

所有字段都是模块点号名列表，不支持路径通配符。

## 分侧声明

顶层字段对 NixOS 与 Home Manager 同时生效；`nixos` / `home` 下的同名字段只对对应 side 生效：

```nix
{
  requires = [ "server.base" ];

  nixos = {
    enable = true;
    requires = [ "server.base" ];
    after = [ "server.database" ];
    conflicts = [ "server.legacy" ];
  };

  home = {
    enable = true;
    requires = [ "client.base" ];
    after = [ "client.shell" ];
  };
}
```

有效值是「顶层字段 + 当前 side 字段」的拼接：

```text
NixOS 侧有效 requires = 顶层 requires ++ nixos.requires
Home 侧有效 requires  = 顶层 requires ++ home.requires
```

因此 NixOS-only 的引用不会污染 Home Manager 图。`meta.nix` 的 `nixos.enable = false` 会让
整个 NixOS side 不参与选择，依赖字段也随之失效。

## 边的方向

- `requires = [ "a" ]`：边 `a → 本模块`，即 `a` 必须先导入；
- `after = [ "a" ]`：边 `a → 本模块`；
- `before = [ "a" ]`：边 `本模块 → a`；
- `wants = [ "a" ]`：边 `a → 本模块`，但 `a` 未启用不报错；
- `conflicts = [ "a" ]`：不建边，双方都在启用集合中时报错。

排序结果中，同一时刻有多个零入度节点时，按模块名字典序选择最小的一个，因此结果是稳定的。
NixOS 与 Home Manager 各自排序，互不影响。

## 校验

对每个已启用模块，框架会检查：

- `requires` / `after` / `before` / `wants` / `conflicts` 引用的模块必须存在；
- `requires` 的目标必须在已启用集合中；
- `conflicts` 的目标不能同时在已启用集合中；
- 图中不能有环。

错误信息会以 `terminus:` 开头，例如：

```text
terminus: unknown module 'module reference 'requires'' 'server.missing'
terminus: module 'server.app' requires 'server.db', but 'server.db' is not enabled
terminus: modules 'server.app' and 'server.legacy' conflict
terminus: module dependency cycle: server.a, server.b
```

## 示例

```nix
# modules/server/postgresql/meta.nix
{
  # 仅作为 NixOS 模块使用
  home.enable = false;
}
```

```nix
# modules/server/umami/meta.nix
{
  requires = [ "server.postgresql" ];
  after = [ "server.postgresql" ];
}
```

如果选中集合只有 `server.umami` 而没有 `server.postgresql`，求值会报缺依赖；把
`server.postgresql` 加入同一个 Profile 的 `requires`、`default`，或 Host `requires` 后，
PostgreSQL 会排在 Umami 之前导入。

## 与 Profile/Host requires 的关系

选择顺序是：

1. 生效 Profile = `default` + 主机 `profiles`；
2. 候选模块 = Profile `requires` + Host `requires`，去重；
3. 按 side 过滤掉没有对应文件或 `meta.<side>.enable = false` 的模块；
4. 对选中集合做依赖校验与稳定拓扑排序；
5. 按排序结果导入完整 side 文件，并注入 Profile 配置。

因此：

- 模块 `meta.requires` 不会自动加入目标模块；必须让目标也出现在 Profile/Host `requires` 中；
- `wants` 不会自动加入目标模块；
- 依赖字段只影响导入顺序与校验，不设置任何 option；
- 没有出现在 Profile/Host `requires` 中的模块不会参与导入，但它的名字仍会用于 `requires`
  等字段的引用校验。

注意：Profile/Host 的 `requires` 是“导入模块”，模块 `meta.requires` 是“模块依赖”，两者
不是同一层。前者增加候选，后者只要求目标已经在候选中。

## 与 Snowveil 的差异

Terminus `0.1.0` 没有模块组（`moduleGroups`）、虚拟能力（`provides` /
`requiresCapabilities`）或模块图 DOT 输出。需要分组时，用配置集；需要能力选择时，在模块里
显式实现。可用的检查只有 Discovery、eval、secret、sudo 与 Colmena 一致性检查。

## 相关

- [模块](modules.md)
- [配置集](profiles.md)
- [模块选择](../concepts/module-selection.md)
