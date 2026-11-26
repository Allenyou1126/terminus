# 快速开始

> 适用版本：`0.1.0`

本页从空仓库搭出第一条可构建的 `nixosConfiguration`。完整目录规范见
[目录结构](directory-structure.md)，`mkFlake` 参数见 [`mkFlake` 参考](../reference/mk-flake.md)。

## 前置条件

- 已启用 flakes 的 Nix（`experimental-features = nix-command flakes`）；
- 仓库根目录有 `flake.nix` 与 `lib/`；
- 可选：`just`，用于执行仓库根目录 `justfile` 中的快捷命令。

Terminus 最少需要 `nixpkgs` 和 `agenix` 两个 input。框架的 `packages` / `apps` /
`devShells` 还会引用 `colmena` input，因此实际建议始终提供它；启用远程部署时 `colmena`
必需。存在 `homes/` 配置时还需要 `home-manager`。

## 最小骨架

```text
.
├── flake.nix
├── secrets/
│   └── .gitkeep          # secretsDir 必须存在
└── hosts/
    └── my-host/
        ├── meta.nix
        └── default.nix
```

`hosts/my-host/meta.nix` 必须声明 `system`：

```nix
{
  system = "x86_64-linux";
  description = "My first Terminus host";
}
```

需要导入模块时，创建 `profiles/<name>/meta.nix`：

```nix
# profiles/server/meta.nix
{
  requires = [ "server.ssh" ];
}
```

再在主机 meta 中声明 `profiles = [ "server" ];`。Profile 需要配置时，把普通 NixOS /
Home Manager 模块放到 `profiles/<name>/nixos.nix` / `home.nix`。`profiles/default/` 存在时
会自动应用到每台主机，适合放所有主机共享的基础模块；只属于一台主机的模块也可以直接写进
主机 meta 的 `requires`。

`hosts/my-host/default.nix` 是普通 NixOS 模块：

```nix
{ pkgs, ... }:
{
  # 仅用于演示；真实主机请使用生成的 hardware.nix
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  boot.loader.grub.enable = true;
  boot.loader.grub.devices = [ "/dev/sda" ];

  users.users.root.initialPassword = "changeme"; # 仅演示，请替换

  environment.systemPackages = [ pkgs.git ];
  system.stateVersion = "25.05";
}
```

`flake.nix` 把 `lib` 当成本仓框架导入：

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    agenix = {
      url = "github:ryantm/agenix/0.18.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    colmena = {
      url = "github:nix-community/colmena/v0.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    (import ./lib { lib = nixpkgs.lib; }).mkFlake {
      inherit inputs self;

      root = ./.;
      systems = [ "x86_64-linux" ];

      # 没有远程部署需求时关闭 hive/一致性检查。
      # packages/apps/devShells 仍引用 colmena input，所以保留 input。
      colmena.enable = false;
    };
}
```

`secretsDir` 默认指向 `secrets/`，该目录必须存在；空目录只够让 `terminus-secret-paths`
检查通过，真实 secret 还需要 agenix 规则与 `.age` 文件（见 [Secrets](secrets.md)）。

此时框架会发现 `hosts/my-host/`，生成 `nixosConfigurations.my-host`。

## 第一条命令

```bash
nix flake check path:. --no-build
nix flake show
nix run .#terminus-discovery
nix build .#nixosConfigurations.my-host.config.system.build.toplevel
```

`nix run .#terminus-discovery` 输出 Discovery JSON，列出框架发现的主机、用户、模块、配置集、
包与部署节点。它不构建系统配置，适合确认目录是否被正确识别。

本机切换：

```bash
sudo nixos-rebuild switch --flake .#my-host
```

## 加入用户与 Home Manager

用户在 `users/<name>/meta.nix` 中声明，至少关联一台主机：

```nix
# users/me/meta.nix
{
  hosts = [ "my-host" ];
  uid = 1000;
  group = "users";
  extraGroups = [ "wheel" ];
}
```

Home 配置放在 `homes/<user>/`：

```nix
# homes/me/default.nix
{ ... }:
{
  home.stateVersion = "25.11";
}
```

然后在 `flake.nix` 增加 `home-manager` input：

```nix
home-manager = {
  url = "github:nix-community/home-manager/release-26.05";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

框架会生成：

- `homeConfigurations.me`（独立 home，`home.standalone = true` 时）；
- 该用户在关联主机中的嵌入式 Home Manager 配置；
- `users.users.me` 与 `users.groups.users`。

详见[用户](users.md)与 [Home Manager](home-manager.md)。

## 启用远程部署

删除 `colmena.enable = false`；Colmena input 在最小骨架中已经提供。启用后框架会生成
`colmenaHive` 与 `terminus-colmena-consistency`。

```nix
colmena = {
  url = "github:nix-community/colmena/v0.5.0";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

在 `hosts/<name>/meta.nix` 声明 `deployment.targetHost`，并把部署公钥放进 `keys/deploy/*.pub`：

```nix
{
  deployment = {
    targetHost = "my-host.example.com";
    targetPort = 22;
    sshUser = "deploy";
  };
}
```

首次迁移仍需在目标机本地运行一次 `nixos-rebuild`，之后才能用 Colmena。部署细节见
[部署](deployment.md)。

## 常用命令

仓库根 `justfile` 提供快捷入口：

| 命令 | 等价操作 |
| --- | --- |
| `just check` | `nix flake check path:. --no-build` |
| `just discovery` | `nix run .#terminus-discovery` |
| `just switch my-host` | 在目标机执行 `sudo nixos-rebuild switch --flake .#my-host` |
| `just test my-host` | `nix run .#colmena -- apply test --on my-host` |
| `just apply my-host` | `nix run .#colmena -- apply --on my-host` |
| `just boot my-host` | `nix run .#colmena -- apply boot --on my-host` |
| `just fmt` | `nix fmt` |

## Git 跟踪

从 Git 求值 flake 时只包含已跟踪或已暂存的文件。新增 host、module、`.age` secret 或
`keys/deploy/*.pub` 后，先 `git add`，再执行 `nix build` / `nixos-rebuild` / Colmena。
本地验证可以用 `nix flake check path:.`，它会直接读取工作树，不要求文件已跟踪。

## 下一步

- [目录结构](directory-structure.md)：理解 magic 文件与 output 映射。
- [主机](hosts.md)：完整的主机元数据与添加流程。
- [模块](modules.md)：编写第一个模块。
- [部署](deployment.md)：Colmena 与一致性检查。
