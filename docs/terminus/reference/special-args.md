# Special Args

> 适用版本：`0.1.0`

Terminus 通过 NixOS / Home Manager 的 `specialArgs` 向模块注入一组额外参数。所有模块都能直接
在函数参数里声明它们。

## NixOS

每个 NixOS 主机收到的 specialArgs：

```nix
{
  inputs;          # 全部 flake inputs
  self;            # 当前 flake
  hostname;        # 主机目录名，例如 "sha-ali-gaal"

  terminus = {
    version;       # { major, minor, patch, string }
    host;          # 归一化后的 hosts/<name>/meta.nix
    secrets;       # secretsDir helper
    deployKeys;    # keys/deploy/*.pub 的内容列表
    exports;       # 所有模块 exports.nix 的合并结果
  };
}
// nixos.specialArgs
```

如果 `mkFlake` 的 `nixos.specialArgs` 与上面同名，后者优先（使用 `//` 合并）。

Profile 的 `nixos.nix` / `home.nix` 是普通 NixOS / Home Manager 模块，也收到同一组
specialArgs；`profiles/<name>/nixos.nix` 同样可以使用 `terminus.host.requires`。

## Home Manager

嵌入式 Home Manager 与主机专属独立 home 使用同一组值：

```nix
{
  inputs;
  self;
  hostname;        # 具体主机名
  terminus = { ... };
}
// home.specialArgs
```

全局 `homeConfigurations.<user>` 没有具体主机：

```nix
{
  inputs;
  self;
  hostname = null;

  terminus = {
    version;
    host = null;
    secrets;
    deployKeys;
    exports;
  };
}
// home.specialArgs
```

嵌入式 Home Manager 把参数写入 `home-manager.extraSpecialArgs`；独立 home 使用
`homeManagerConfiguration.extraSpecialArgs`。两种模式的 `terminus.host` 语义一致：有主机时是
归一化元数据，全局 home 时为 `null`。

## terminus.version

```nix
{ terminus, ... }:
{
  environment.etc."terminus-version".text = terminus.version.string;
}
```

结构：

```nix
{
  major = 0;
  minor = 1;
  patch = 0;
  string = "0.1.0";
}
```

## terminus.host

`terminus.host` 是 `hosts/<name>/meta.nix` 归一化后的属性集：

```nix
{
  system = "x86_64-linux";
  profiles = [ "server" "cn" ];
  requires = [ "server.certimate-ssh" ];
  description = "Test Server";

  home = {
    embed = true;          # 主机 meta 原值；null 表示继承全局，不代表最终生效值
    useGlobalPkgs = true;
  };

  secrets = {
    identityPaths = [ ... ];  # 或 null
  };

  deployment = {
    targetHost = ...;
    targetPort = ...;
    sshUser = ...;
    buildOnRemote = ...;
    tags = [ ... ];
    sshOptions = [ ... ];
    allowLocalDeployment = ...;
    replaceUnknownProfiles = ...;
  };

  raw = { ... };      # 原始 meta.nix
}
```

注意：

- 全局独立 home 中 `terminus.host = null`；
- `profiles` 是主机声明的 Profile 列表，不包含自动应用的 `default`；
- `requires` 是主机直接导入的模块列表；
- `roles` / `modules` 已从 host meta 移除，不再出现在 `terminus.host`；
- 归一化后的 `home.embed` / `home.useGlobalPkgs` 是主机 meta 的原值，`null` 表示继承全局，
  不等于最终生效值；
- `terminus.host.raw` 保留原始字段，可用于读取框架未归一化的自定义元数据。

示例：

```nix
{ lib, terminus, ... }:
{
  config = lib.mkIf (
    terminus.host != null
    && builtins.elem "server" terminus.host.profiles
  ) {
    # server 专属配置
  };
}
```

## terminus.secrets

`terminus.secrets` 是 `lib/secret.nix` 返回的 helper：

```nix
{
  root;        # toString secretsDir
  storeRoot;   # 保留 store context 的路径字符串
  secret;      # { name, file?, ... } -> 完整 age.secrets 值
}
```

最常用的是 `secret`：

```nix
{ terminus, ... }:
{
  age.secrets.example = terminus.secrets.secret {
    name = "services/example/token";
    owner = "example";
    mode = "0400";
  };
}
```

默认 `file = "${secretsDir}/<name>.age"`，保留 store context。不要用 `root` 手工拼接文件路径。

## terminus.exports

所有模块的 `exports.nix` 会被合并成 `terminus.exports`：

```nix
# modules/_common/nix-substituters/exports.nix
{
  substituterPresets = {
    official = {
      url = "https://cache.nixos.org";
      priority = 40;
      trustedPublicKeys = [ ];
    };
  };
}
```

```nix
{ terminus, ... }:
{
  nix.settings.substituters = [
    terminus.exports.substituterPresets.official.url
  ];
}
```

规则：

- exports 是 host-independent 的，不能依赖 host/config；
- key 全局唯一，重复会报错；
- 没有 exports 时 `terminus.exports` 是空 attrset；
- 不要用 `exports.nix` 代替模块 import；它只导出值/函数。

## terminus.deployKeys

`terminus.deployKeys` 是 `keys/deploy/*.pub` 文件内容（trim、去空、去重）的列表：

```nix
{ terminus, ... }:
{
  users.users.deploy.openssh.authorizedKeys.keys = terminus.deployKeys;
}
```

框架的 deploy 用户模块已经使用它；一般不需要在模块里重复设置。

## 自定义 specialArgs

```nix
mkFlake {
  nixos.specialArgs.myOption = "value";
  home.specialArgs.myHomeOption = "value";
}
```

合并规则：

```nix
nixosSpecialArgs = 框架参数 // nixos.specialArgs;
homeSpecialArgs  = 框架参数 // home.specialArgs;
```

自定义值优先。不要覆盖 `inputs`、`self`、`hostname`、`terminus` 这些框架参数，除非明确知道
会影响所有模块。

## 模块中读取

NixOS 模块：

```nix
{
  config,
  pkgs,
  lib,
  inputs,
  self,
  hostname,
  terminus,
  ...
}:
{
  environment.etc."hostname".text = hostname;
  environment.systemPackages = [ terminus.exports.someTool ];
}
```

Home Manager 模块：

```nix
{
  config,
  pkgs,
  lib,
  hostname,
  terminus,
  ...
}:
{
  home.username = config.home.username;
  home.sessionVariables.HOST = hostname;
}
```

标准模块参数（`config`、`pkgs`、`lib`、`options`）仍由 NixOS / Home Manager 提供。

## 相关

- [`mkFlake` 参数](mk-flake.md)
- [Home Manager](../guide/home-manager.md)
- [Secrets](../guide/secrets.md)
- [模块](../guide/modules.md)
