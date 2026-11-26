# Home Manager

> 适用版本：`0.1.0`

Terminus 同时支持两种 Home Manager 形态：

- **嵌入式**：Home Manager 作为 NixOS 模块运行，用户配置随主机一起切换；
- **独立式**：生成 `homeConfigurations.<user>` 或 `homeConfigurations."<user>@<host>"`，
  用 `home-manager switch` 单独切换。

两种形态共享同一份 `homes/<user>/` 文件，但模块来源和 specialArgs 略有不同。

## homes/ 目录

```text
homes/
└── <user>/
    ├── default.nix       # 共享 home，生成 homeConfigurations.<user>
    ├── <host>.nix        # 主机专属 home，生成 "<user>@<host>"
    └── _*.nix            # 片段，被 discovery 忽略
```

| 文件 | 作用 |
| --- | --- |
| `default.nix` | 该用户的共享配置；存在时，在 `home.embed` 未关闭的关联主机上启用嵌入式 Home Manager。 |
| `<host>.nix` | 只对指定主机生效；文件名必须是已存在的主机名。 |
| `_*.nix` | 不作为入口发现；由 `default.nix` 或 `<host>.nix` 显式 `import`。 |
| `meta.nix` | 当前不读取，写了也会被忽略。 |

```nix
# homes/allenyou/default.nix
{ ... }:
{
  imports = [
    ./_client.nix
    ./_git.nix
    ./_ssh.nix
  ];

  home.stateVersion = "25.11";
}
```

```nix
# homes/allenyou/lap-fallom.nix
{ ... }:
{
  home.shellAliases.gpg = "/mnt/c/Program\\ Files/Git/usr/bin/gpg.exe";
}
```

## 策略解析

`mkFlake` 的 `home.embed` 与 `home.useGlobalPkgs` 可以是 bool、函数或 attrset：

```nix
home.embed = true;

# 或者按主机名：
home.embed = host: host != "lap-fallom";

# 或者：
home.embed = {
  default = true;
  hosts.lap-fallom = false;
};
```

解析优先级：

```text
hosts/<name>/meta.nix 的 home.*  >  mkFlake 的 home.*  >  默认值
```

默认值：

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `home.embed` | `true` | 是否启用嵌入式 Home Manager。 |
| `home.useGlobalPkgs` | `true` | 嵌入式 Home Manager 是否复用 NixOS 的 `pkgs`。 |
| `home.standalone` | `true` | 是否生成全局 `homeConfigurations.<user>`。 |

`home.standalone = false` 只影响全局 home；`homeConfigurations."<user>@<host>"` 仍会为每个
`<host>.nix` 生成。`home.embed = false` 只关闭某个主机的嵌入式配置，独立 home 不受影响。

## 生成哪些配置

假设 `users/me/meta.nix` 关联 `host-a`，并且有：

```text
homes/me/default.nix
homes/me/host-a.nix
```

则生成：

| output | 来源 |
| --- | --- |
| `homeConfigurations.me` | `default.nix`；仅当 `home.standalone = true`。 |
| `homeConfigurations."me@host-a"` | `default.nix` + `host-a.nix`。 |
| `nixosConfigurations.host-a` 中的 `home-manager.users.me` | `default.nix` + `host-a.nix` + 主机选中的 home 模块。 |

如果只有 `homes/me/host-a.nix` 而没有 `default.nix`：

- `homeConfigurations."me@host-a"` 仍会生成；
- 只有 `host-a` 会启用嵌入式 Home Manager；
- 不会生成全局 `homeConfigurations.me`。

## 嵌入式模式

当主机 `home.embed` 为真，且该用户在这台主机上有 `default.nix` 或 `<host>.nix` 时，框架注入：

```nix
{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager.useGlobalPkgs = lib.mkDefault <host 策略>;
  home-manager.useUserPackages = lib.mkDefault true;
  home-manager.extraSpecialArgs = <specialArgs>;

  home-manager.users.<user> = {
    imports = [
      # 框架默认值：home.username / home.homeDirectory
      # 主机选中的 home 模块
      # homes/<user>/default.nix
      # homes/<user>/<host>.nix
    ];
  };
}
```

`home-manager.users.<user>` 的导入顺序是：

1. 框架默认的 `home.username`、`home.homeDirectory`；
2. Profile/Host `requires` 选中的 home 模块（依赖排序后）；
3. 生效 Profile 的 `home.nix` 配置模块；
4. `mkFlake` 的 `home.modules`；
5. `homes/<user>/default.nix`；
6. `homes/<user>/<host>.nix`。

因此用户文件可以覆盖模块里的 `mkDefault` 值。`home.username` 和 `home.homeDirectory` 是
`mkDefault`，默认分别为用户名和 `users/<name>/meta.nix` 的 `home`（没有则 `/home/<name>`）。

## 独立模式

```nix
inputs.home-manager.lib.homeManagerConfiguration {
  pkgs = <对应 system 的 pkgs>;
  extraSpecialArgs = <specialArgs>;
  modules = [
    # 默认值
    # 主机选中的 home 模块 + Profile home.nix + home.modules
    # homes/<user>/default.nix
    # homes/<user>/<host>.nix
  ];
}
```

- 全局 `homeConfigurations.<user>` 使用**第一个派生 system** 的 `pkgs`（通常是第一台主机的
  架构），`hostname = null`、`terminus.host = null`；
- `homeConfigurations."<user>@<host>"` 使用该主机的 system 和 specialArgs；
- 全局 home 使用一个合成主机（`profiles = []`、`requires = []`），因此只应用
  `profiles/default/`（存在时）的 home 模块与 `default/home.nix`；主机专属 Profile 的 home
  模块和配置不会进入全局 home；
- 独立模式始终使用传入的 `pkgs`，`home.useGlobalPkgs` 只影响嵌入式模式。

## specialArgs

NixOS 与 Home Manager 模块都能收到：

- `inputs`、`self`；
- `hostname`：主机名，全局独立 home 为 `null`；
- `terminus.version`、`terminus.host`、`terminus.secrets`、`terminus.deployKeys`、
  `terminus.exports`；
- `mkFlake` 中对应的 `nixos.specialArgs` / `home.specialArgs`。

嵌入式 Home Manager 把这些写入 `home-manager.extraSpecialArgs`，与独立模式保持一致。
`terminus.host` 是归一化后的主机元数据；全局独立 home 中为 `null`。

## 按 Profile 区分的 home 配置

模块 home 文件只会被生效 Profile 导入，但 `homes/<user>/*.nix` **本身不做 Profile 过滤**。
如果某个用户设置只应对 client 主机生效，需要自己判断：

```nix
# homes/allenyou/_client.nix
{ lib, terminus, ... }:
{
  config = lib.mkIf (
    terminus.host != null
    && builtins.elem "client" terminus.host.profiles
  ) {
    programs.ssh.startAgent = true;
  };
}
```

必须处理 `terminus.host == null`：全局 `homeConfigurations.<user>` 没有具体主机。

`profiles/default/meta.nix` 列出的 `_common/*/home.nix` 会进入所有嵌入式与独立 home；如果
`profiles/default/home.nix` 存在，也会进入所有 home。因此不要在 default Profile 中写只在某台
主机成立的假设。

## 已知限制

`terminus.homeManager.backupFileExtension` 与 `terminus.homeManager.embed` 在 `0.1.0` 中只是
声明了 option，尚未自动接线。需要备份后缀时，直接在嵌入式 Home Manager 配置里设置
`home-manager.backupFileExtension`，或在引入 `home-manager.nixosModules.home-manager` 后自行设置。

## 相关

- [用户](users.md)
- [模块](modules.md)
- [Special Args](../reference/special-args.md)
- [Secrets](secrets.md)
