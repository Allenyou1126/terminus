# 模块

> 适用版本：`0.1.0`

Terminus 用一棵模块树同时服务 NixOS 与 Home Manager。一个功能只建一个目录，通过固定文件名
分拣到两侧；目录路径决定模块的点号名。

## 模块目录

只要目录中包含至少一个 magic 文件，它就会被发现为模块：

```text
modules/
├── _common/
│   └── nix-substituters/
│       ├── options.nix
│       ├── nixos.nix
│       ├── exports.nix
│       ├── meta.nix
│       └── cn/
│           ├── options.nix
│           └── nixos.nix
└── server/
    └── frps/
        ├── options.nix
        ├── nixos.nix
        └── meta.nix
```

模块名是相对 `modules/` 的路径用 `.` 连接：

| 目录 | 模块名 |
| --- | --- |
| `modules/_common/nix-substituters/` | `_common.nix-substituters` |
| `modules/_common/nix-substituters/cn/` | `_common.nix-substituters.cn` |
| `modules/server/frps/` | `server.frps` |
| `modules/`（根目录自身含 magic 文件） | `_root` |

每个含 magic 文件的子目录都是独立模块；父目录不会自动包含子目录的配置。

## 五个模块文件和 meta.nix

| 文件 | 是否作为模块导入 | 进入哪一侧 | 作用 |
| --- | --- | --- | --- |
| `options.nix` | 是 | NixOS 与 Home Manager | 声明两侧共享的 `options.terminus.*`。 |
| `default.nix` | 是 | NixOS 与 Home Manager | 与平台无关的共享实现。 |
| `nixos.nix` | 是 | 仅 NixOS | 系统级配置。 |
| `home.nix` | 是 | 仅 Home Manager | 用户级配置。 |
| `exports.nix` | 否 | 不导入 | host-independent 的值，合并进 `terminus.exports`。 |
| `meta.nix` | 否 | 不导入 | 侧开关与依赖声明，必须是纯属性集。 |

严格说 `meta.nix` 是模块元数据，不属于上面五个模块文件；它只被框架读取，不会被导入。
side 的组成与顺序：

```text
NixOS:        options.nix → default.nix → nixos.nix
Home Manager: options.nix → default.nix → home.nix
```

目录中其他 `.nix` 文件不会被自动导入。需要拆分实现时，由对应的 side 文件显式 `import`。

注意：这些文件只有在模块被生效 Profile/Host `requires` 选中时才会导入。没有被
`profiles/default/`、主机 `meta.profiles` 的 `requires` 或主机 `meta.requires` 选中的模块，
连 option 声明都不会存在。Profile 的 `nixos.nix` / `home.nix` 可以设置 option；模块内部
仍可用 `mkIf config.terminus.*.enable` 之类的开关做细粒度控制。

## 侧开关

`meta.nix` 可以关闭某一侧：

```nix
# modules/server/frps/meta.nix
{
  home.enable = false;
}
```

```nix
# modules/client/deepseek-harness/meta.nix
{
  nixos.enable = false;
}
```

`nixos.enable = false` 表示该模块不会向 NixOS 主机注入任何 side 文件，包括 `options.nix`；
`home.enable = false` 同理。默认两侧都为 `true`。

`exports.nix` 不受侧开关影响，仍会被收集。

## Profile 与模块

`modules/` 下的目录只是命名空间，第一段不再有角色语义，`_` 前缀也没有特殊导入行为。
模块是否导入由 Profile/Host `requires` 决定：

- `profiles/default/` 存在时自动应用到每台主机和全局 home；
- 主机在 `meta.profiles` 中选择 Profile，在 `meta.requires` 中直接导入模块；
- Profile 在 `meta.nix` 的 `requires` 中导入模块；
- 只有被选中的模块才导入 side 文件；未选中模块的 `options.nix` / `default.nix` 也不会全局注入。

Profile 选中模块不等于自动打开模块的 enable option；Profile 可以在 `nixos.nix` / `home.nix`
中设置它，或者由主机设置。模块内部仍用 enable option 做细粒度控制。详见
[配置集](profiles.md)与[模块选择](../concepts/module-selection.md)。

## 示例：一个完整的模块

```nix
# modules/server/example/options.nix
{ lib, ... }:
{
  options.terminus.example = {
    enable = lib.mkEnableOption "example service";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "example 监听端口。";
    };
  };
}
```

```nix
# modules/server/example/nixos.nix
{ config, lib, ... }:
let
  cfg = config.terminus.example;
in
{
  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
```

```nix
# modules/server/example/home.nix
{ config, lib, ... }:
{
  config = lib.mkIf config.terminus.example.enable {
    home.packages = [ ];
  };
}
```

模块被导入不等于功能开启：主机仍需设置 `terminus.example.enable = true`。

## Module registry

框架为每个发现到的模块生成 registry 项：

```nix
nixosModules."server.example" = {
  imports = [ ./modules/server/example/options.nix ./modules/server/example/nixos.nix ];
};

homeModules."server.example" = {
  imports = [ ./modules/server/example/options.nix ./modules/server/example/home.nix ];
};
```

要点：

- 键是模块点号名，不是文件路径；
- 值固定是 `{ imports = [ ... ]; }`，不暴露 magic 文件名；
- registry 是**发现级别**的：即使某模块的 `nixos.enable = false`，只要它有 NixOS side 文件，
  仍会出现在 `nixosModules` 中；
- 没有对应 side 文件的模块不会出现在该侧 registry 中；
- 主机装配不会使用 registry，而是直接使用选择后的 side 文件。

## exports.nix

`exports.nix` 用来放 host-independent 的工具或预设值，框架把它们合并到 `terminus.exports`：

```nix
# modules/_common/nix-substituters/exports.nix
{
  substituterPresets = {
    ustc-mirror = {
      url = "https://mirrors.ustc.edu.cn/nix-channels/store";
      priority = 10;
      trustedPublicKeys = [ ];
    };
  };
}
```

也可以写成函数，函数参数只会收到它声明的 `lib`、`inputs`、`self` 子集：

```nix
# modules/server/prometheus/exports.nix
{ lib, ... }:
{
  prometheus = {
    mkTarget = address: labels: { inherit address labels; };
    mkTargets = targets: map (target: { address = target; labels = { }; }) targets;
  };
}
```

规则：

- 必须返回 attrset，否则报错；
- 不同模块导出的 key 必须全局唯一，重复 key 会报错并指出两个来源；
- exports 不能依赖 host 或 config，所有主机共享同一份结果；
- 在所有 NixOS 与 Home Manager 模块中通过 `terminus.exports.<key>` 读取；
- 导出只用于值，不要用它代替模块 import。

使用示例：

```nix
# modules/_common/nix-substituters/options.nix
{ lib, terminus, ... }:
{
  options.terminus.nix.substituters.entries = lib.mkOption {
    type = lib.types.listOf (lib.types.submodule { ... });
    default = with terminus.exports.substituterPresets; [
      allenyou-cache
      official
    ];
  };
}
```

## 模块写作建议

- `options.nix` 只声明接口，不引用仅某一侧存在的 option；
- `default.nix` 保持平台中性，避免引用 `home-manager.*` 或 NixOS 专属 option；
- 需要 NixOS 专属 option 时放到 `nixos.nix`，需要 Home Manager 专属 option 时放到 `home.nix`；
- 模块内部用 `lib.mkIf config.terminus.*.enable` 做细粒度开关；
- 不在模块里写主机名或用户身份，放在 `hosts/` / `homes/`；
- 依赖其他模块时优先用 `meta.nix` 的 `requires` / `after`，不要依赖 import 顺序。

## 相关

- [配置集](profiles.md)
- [模块依赖](module-dependencies.md)
- [模块选择](../concepts/module-selection.md)
