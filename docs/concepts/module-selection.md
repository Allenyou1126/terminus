# 模块选择

> 适用版本：`0.1.0`

发现阶段只建立模块和 Profile 索引；真正决定某台主机导入哪些文件、注入哪些配置的是选择阶段
（`lib/modules.nix` + `lib/depgraph.nix`）。本页给出完整算法和边界情况。

## 输入

对每台主机、每个 side（`nixos` 或 `home`）分别计算：

- `discovery.modulesByName`：所有发现到的模块；
- `host.meta.profiles`：主机声明的 Profile 名称；
- `host.meta.requires`：主机直接要求导入的模块名；
- `discovery.profiles.resolved`：每个 Profile 展开后的：
  - `requires`：要导入的模块名；
  - `nixos`：`nixos.nix` 配置模块路径列表；
  - `home`：`home.nix` 配置模块路径列表；
- 模块自己的 `meta.<side>.enable` 与依赖字段。

Profile 与 Host 都是模块选择来源；Profile 额外提供配置模块。

## 算法

### 1. 求生效 Profile

```nix
profileNames =
  unique (
    optional (hasAttr "default" resolved) "default"
    ++ host.meta.profiles
  );
```

- `profiles/default/` 存在时自动加入；
- Host 可以显式写 `"default"`，去重后只生效一次；
- Profile 的 `extends` 已在发现阶段展开。

### 2. 合并模块候选

```nix
members =
  unique (
    concatMap (profile: profile.requires) selectedProfiles
    ++ host.meta.requires
  );
```

- Profile `requires` 与 Host `requires` 的并集；
- 重复模块只处理一次；
- 未知模块、没有 side 文件的模块会在发现阶段报错。

### 3. 按 side 过滤模块

只保留满足以下条件的模块：

```nix
module.side.<side> != [ ] && module.meta.<side>.enable
```

`side.<side>` 是该侧的 magic 文件列表（`options` + `default` + `nixos`/`home`）。
`meta.<side>.enable = false` 会让整个 side 不参与选择。

Profile 成员是跨 side 的模块名：

- 只有 `nixos.nix` 的模块在 Home Manager side 自动跳过；
- 只有 `home.nix` 的模块在 NixOS side 自动跳过；
- 两侧都有文件的模块在两侧都导入。

### 4. 依赖校验与排序

用该 side 的候选模块建图，用选中集合作为 `enabled`：

```nix
order = depgraph.sort { graph; enabled = selected; };
```

排序会：

- 校验模块 `meta.nix` 的 `requires` / `after` / `before` / `wants` / `conflicts` 引用存在；
- 要求模块依赖 `requires` 的目标已经被 Profile/Host 选中；
- 拒绝同时选中的 `conflicts`；
- 拒绝环；
- 在零入度节点中按模块名字典序选择，得到稳定顺序。

注意：Profile/Host 的 `requires` 是“导入模块”，模块 `meta.nix` 的 `requires` 是“模块依赖”，
二者不是同一层。

### 5. 导入模块并注入 Profile 配置

模块 imports：

```nix
imports = concatMap (name: sideModules.${name}.side.${side}) order;
```

Profile 配置模块：

```nix
profileConfig = unique (concatMap (profile: profile.${side}) selectedProfiles);
```

最终按以下顺序进入主机：

```text
选中模块 imports
  → 生效 Profile 的 nixos.nix / home.nix
  → Host magic 文件 / homes 文件
  → 额外模块
```

Profile 配置是普通 NixOS / Home Manager 模块；作者用 `lib.mkDefault` 表示可被 Host 覆盖。

## 流程图

```text
host.meta.profiles ─┐
                    ├─ 合并（default 自动加入）→ 生效 Profile
profiles/*/meta.nix ┘
                              │
                              ├─ requires ──┐
host.meta.requires ─────────────────────────┤
                              │             ▼
                              │     候选模块并集
                              │             │
                              │             ▼
                              │   该 side 有文件 && meta.<side>.enable
                              │             │
                              │             ▼
                              │      depgraph.sort
                              │             │
                              │             ▼
                              │     模块 imports
                              │
                              └─ nixos.nix / home.nix → 配置模块注入
```

## 例子

```nix
# hosts/lap-fallom/meta.nix
{
  profiles = [ "client" "wsl" "cn" ];
}
```

实际生效：

```text
default + client + wsl + cn
```

- `default` 的 `_common.**` 模块进入两侧对应 side；
- `client.ssh` 的 `home.nix` 进入 Home Manager；
- `wsl.base` 只有 `nixos.nix`，只进入 NixOS；
- `cn` Profile 的 `nixos.nix` 设置 `terminus.nix.substituters.presets.cn = mkDefault true`。

```nix
# hosts/sha-ali-seldon/meta.nix
{
  profiles = [ "server" "cn" ];
  requires = [ "server.certimate-ssh" ];
}
```

- `server` Profile 导入 server 通用模块；
- Host `requires` 额外导入 `server.certimate-ssh`，其他 server 主机没有这个模块的 option；
- `cn` Profile 同时提供 CN preset 配置。

## Home Manager 的差异

- 嵌入式 Home Manager：对每台主机跑一次 `home` side 选择，使用该主机的 `profiles` 与
  `requires`，并注入生效 Profile 的 `home.nix`；
- `homeConfigurations."<user>@<host>"`：使用对应主机的选择结果；
- 全局 `homeConfigurations.<user>`：使用合成主机 `{ profiles = [ ]; requires = [ ]; }`，
  因此只应用 `default` Profile 的 home 模块和 `default/home.nix`。

`homes/<user>/*.nix` 本身不按 Profile 过滤；需要按主机区分的用户设置，用
`lib.mkIf` / `lib.optionalAttrs` 判断 `terminus.host.profiles`，并处理
`terminus.host == null`（全局 home）。

## registry 与选择解耦

`nixosModules` / `homeModules` 是发现级别的导出：

```nix
nixosModules.<module> = { imports = side.nixos; };
```

它不经过 Profile 选择或依赖排序，也不会因为 `meta.<side>.enable = false` 而消失。
手动 import `nixosModules` 会绕过 Terminus 的选择逻辑。

`exports.nix` 同样是发现级别：所有模块的导出都会合并到 `terminus.exports`，不受 Profile
选择影响。导出是 host-independent 的，不能依赖 host/config。

Profile 的 `nixos.nix` / `home.nix` 不会出现在 registry 中；它们是主机配置，不是可复用模块。

## 常见误区

- **Profile 选中模块不等于打开 option**：模块内部仍可能需要 `enable = true`，Profile 可以用
  `nixos.nix` 设置它；
- **Profile `requires` 和模块 `meta.requires` 不同**：前者是导入，后者是依赖；
- **未选中模块的 option 不存在**：不是“默认关闭”，而是完全没有声明；
- **`default` 不写进主机 meta**：只要 `profiles/default/` 存在就自动应用；
- **Profile 配置普通定义会被 Host 冲突**：推荐 `lib.mkDefault`；
- **Host `requires` 只导入模块，不提供配置**：配置仍写在 `default.nix` 或 Profile；
- **registry 不参与选择**：手动 import 只适合逃生场景。

## 相关

- [模块](../guide/modules.md)
- [配置集](../guide/profiles.md)
- [模块依赖](../guide/module-dependencies.md)
- [主机](../guide/hosts.md)
