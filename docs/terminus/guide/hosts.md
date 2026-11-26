# 主机

> 适用版本：`0.1.0`

一台主机由 `hosts/<name>/` 目录声明。目录名就是主机名，直接决定
`nixosConfigurations.<name>` 和 `colmenaHive.nodes.<name>`。

## 文件

| 文件 | 必需 | 作用 |
| --- | --- | --- |
| `meta.nix` | 是 | 发现阶段读取的元数据：`system`、配置集、部署信息等。必须是纯属性集，不能是函数。 |
| `default.nix` | 是 | 主机核心 NixOS 模块，交给 NixOS module system 求值。 |
| `hardware.nix` | 否 | 存在则自动导入。 |
| `disk.nix` | 否 | 存在则自动导入。 |
| `network.nix` | 否 | 存在则自动导入。 |
| 其他 `.nix` | 否 | 不会自动导入；需要由 `default.nix` 显式 `import`。 |

主机 magic 文件的导入顺序固定为：

```text
default.nix → hardware.nix → disk.nix → network.nix
```

后三者只有存在时才加入。若需要控制顺序，把逻辑放进 `default.nix` 或模块，不要依赖文件名排序。

## meta.nix

```nix
# hosts/sha-ali-gaal/meta.nix
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
    tags = [ "server" "sha-ali-gaal" ];
  };
}
```

字段说明：

| 字段 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `system` | string | 必填 | 主机架构，例如 `x86_64-linux`。缺失会在发现阶段报错。 |
| `profiles` | list of string | `[]` | 要应用的配置集名称，对应 `profiles/<name>/`；`default` 存在时自动应用。 |
| `requires` | list of string | `[]` | 该主机直接导入的模块点号名，与 Profile 的 `requires` 合并。 |
| `description` | string 或 `null` | `null` | 人类可读描述；`motd` 等模块可通过 `terminus.host.description` 读取。 |
| `home.embed` | bool 或 `null` | `null` | 是否把关联用户的 Home Manager 嵌入 NixOS；`null` 表示继承 `mkFlake` 的 `home.embed`。 |
| `home.useGlobalPkgs` | bool 或 `null` | `null` | 嵌入式 Home Manager 是否复用 NixOS 的 `pkgs`；`null` 表示继承全局值。 |
| `secrets.identityPaths` | list of string 或 `null` | `null` | 覆盖默认的 agenix 身份路径。 |
| `deployment.targetHost` | string 或 `null` | `null` | Colmena 目标地址；非 `null` 时才会创建远程 deploy 用户。 |
| `deployment.targetPort` | int 或 `null` | `22` | SSH 端口。 |
| `deployment.sshUser` | string 或 `null` | `null` | 远程 SSH 用户；`null` 时使用 deploy 用户名。 |
| `deployment.buildOnRemote` | bool | `false` | 是否在目标机构建（Colmena `buildOnTarget`）。 |
| `deployment.tags` | list of string | `[]` | Colmena 标签，可用 `@tag` 批量操作。 |
| `deployment.sshOptions` | list of string | `[]` | 传给 Colmena / SSH 的额外参数；不要写机器相关私钥路径。 |
| `deployment.allowLocalDeployment` | bool 或 `null` | `null` | 是否允许部署到本机；`null` 时 Colmena 取 `targetHost == null`。 |
| `deployment.replaceUnknownProfiles` | bool 或 `null` | `null` | 透传给 Colmena；`null` 时取 `true`。 |

`roles`、`role`、`modules` 已移除；在 host meta 中出现会在发现阶段报错。需要直接导入模块时写
`requires = [ ... ]`，或者把模块放进 Profile。

`requires` 与 Profile 的关系见 [配置集](profiles.md)；例如只属于一台主机的模块：

```nix
# hosts/sha-ali-seldon/meta.nix
{
  profiles = [ "server" "cn" ];
  requires = [ "server.certimate-ssh" ];
}
```

`meta.nix` 不支持 `config`、`pkgs`、`lib` 等模块参数。需要这些值时，把逻辑写进
`default.nix`：

```nix
# hosts/sha-ali-gaal/default.nix
{ config, pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.git
    config.terminus.exports.someTool
  ];
}
```

## 主机模块注入顺序

框架按以下顺序合并 NixOS 模块，后者可以覆盖前者的 `mkDefault` 值：

1. 框架 options：`terminus.users`、`terminus.homeManager.*`；
2. agenix NixOS 模块；
3. `age.identityPaths` 默认值；
4. `users/<name>/meta.nix` 生成的用户模块；
5. 关联用户的 `users/<name>/default.nix`；
6. 远程主机的 deploy 用户模块（含 sudo 规则）；
7. 嵌入式 Home Manager 模块；
8. Profile `requires` + Host `requires` 选中的模块（经依赖排序）；
9. 生效 Profile 的 `nixos.nix` 配置模块；
10. 主机 magic 文件：`default.nix` → `hardware.nix` → `disk.nix` → `network.nix`；
11. `mkFlake` 的 `nixos.modules`；
12. `networking.hostName = lib.mkDefault <name>`；
13. `nixosConfigurations` 追加 `{ nixpkgs.pkgs = pkgsBySystem.<system>; }`。

这意味着：

- 模块里的 `mkDefault` 可以被 `default.nix` 覆盖；
- 模块里的普通定义仍然遵循 NixOS 的冲突规则；
- 主机名默认等于目录名，可在 `default.nix` 中用 `networking.hostName` 覆盖。

## 添加一台主机

1. 创建 `hosts/<name>/meta.nix`，至少声明 `system`；
2. 创建 `hosts/<name>/default.nix`，写核心 NixOS 配置；
3. 按需添加 `hardware.nix`、`disk.nix`、`network.nix`；
4. 在 `users/<name>/meta.nix` 的 `hosts` 中加入该主机，或在 `homes/<user>/<name>.nix` 中
   建立关联；
5. 如需远程部署，在 `deployment` 中写 `targetHost`，并把公钥放入 `keys/deploy/`；
6. 运行 `nix flake check path:. --no-build`，再用
   `nix build .#nixosConfigurations.<name>.config.system.build.toplevel` 验证。

新文件必须先 `git add`，否则从 Git 求值的 `nix build .#...` 看不到它们；本地检查可用
`path:.` 绕过这个限制。

## WSL 主机

WSL 主机通过 `profiles = [ "client" "wsl" ]` 导入 `modules/wsl/base`，该模块负责导入
`inputs.nixos-wsl.nixosModules.wsl` 并设置 `wsl.enable = true`：

```nix
# hosts/lap-fallom/meta.nix
{
  system = "x86_64-linux";
  profiles = [ "client" "wsl" "cn" ];

  secrets.identityPaths = [ "/home/allenyou/.ssh/id_ed25519" ];
  deployment.allowLocalDeployment = false;
}
```

```nix
# hosts/lap-fallom/default.nix
{
  wsl.defaultUser = "allenyou";
  system.stateVersion = "25.05";
}
```

WSL 通常没有 `/etc/ssh/ssh_host_ed25519_key`，需要用 `secrets.identityPaths` 指向可用的
SSH 私钥，否则 agenix 解密会失败。

## 相关

- [目录结构](directory-structure.md)
- [`meta.nix` 字段](../reference/meta.md)
- [模块选择](../concepts/module-selection.md)
- [部署](deployment.md)
- [用户](users.md)
