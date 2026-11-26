# 用户

> 适用版本：`0.1.0`

用户由 `users/<name>/` 目录声明。框架根据 `users/<name>/meta.nix` 生成关联主机的
`users.users.<name>` 与 `users.groups.<group>`，并把用户与 `homes/<user>/` 的 Home Manager
配置关联起来。

## 文件

| 文件 | 必需 | 作用 |
| --- | --- | --- |
| `meta.nix` | 是 | 用户属性与主机列表。 |
| `default.nix` | 否 | 用户级补充 NixOS 模块，在该用户的每个关联主机上导入。 |

## meta.nix

```nix
# users/allenyou/meta.nix
{
  hosts = [
    "sha-ali-gaal"
    "lap-fallom"
  ];

  uid = 1000;
  group = "users";
  extraGroups = [ "wheel" ];
  description = "Allenyou";

  hashedPassword = "$6$...";
}
```

| 字段 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `hosts` | list of string | `[]` | 用户关联的主机。与 `homes/<user>/<host>.nix` 的主机名取并集。 |
| `uid` | int 或 `null` | `null` | 用户 UID；同时作为默认 GID。 |
| `gid` | int 或 `null` | `null` | 用户主组的 GID；未设置时使用 `uid`。 |
| `group` | string 或 `null` | `null` | 主组名；未设置时使用用户名。 |
| `extraGroups` | list of string | `[]` | 附加组。 |
| `description` | string 或 `null` | `null` | GECOS 描述。 |
| `home` | string 或 `null` | `null` | 家目录；未设置时使用 NixOS 默认值，Home Manager 使用 `/home/<name>`。 |
| `createHome` | bool | `true` | 是否创建家目录。 |
| `isNormalUser` | bool | `true` | 是否为普通用户。 |
| `hashedPassword` | string 或 `null` | `null` | 直接写入 `users.users.<name>.hashedPassword`。 |
| `hashedPasswordSecret` | string 或 `null` | `null` | agenix secret 名或绝对文件路径。 |
| `raw` | attrset | 原始 `meta.nix` | 归一化时保留的原始值。 |

`hashedPassword` 与 `hashedPasswordSecret` **互斥**，同时设置会在发现阶段报错。

## 密码

### 直接写哈希

```nix
{
  hashedPassword = "$6$...";
}
```

适合公开仓库中不敏感的测试密码。生产密码不建议直接提交。

### 使用 agenix secret

```nix
{
  hashedPasswordSecret = "common/allenyou-password";
}
```

这要求 `secrets/common/allenyou-password.age` 存在，且 `secrets/agenix-rules.nix` 中有对应
规则。框架会自动声明：

```nix
age.secrets."common/allenyou-password" =
  terminus.secrets.secret { name = "common/allenyou-password"; };

users.users.allenyou.hashedPasswordFile =
  config.age.secrets."common/allenyou-password".path;
```

`hashedPasswordSecret` 以 `/` 开头时按**字面文件路径**处理，不会自动声明 agenix secret：

```nix
{
  hashedPasswordSecret = "/run/secrets/allenyou-password";
}
```

## 生成结果

对每个关联用户，框架生成：

```nix
{
  users.mutableUsers = false;

  # 仅当 gid 或 uid 非 null 时生成 gid
  users.groups.<group> = lib.optionalAttrs (<gid 或 uid> != null) {
    gid = lib.mkDefault (<gid 或 uid>);
  };

  users.users.<name> = {
    isNormalUser = lib.mkDefault true;
    createHome = lib.mkDefault true;
    group = <group>;
    extraGroups = lib.mkDefault [ ... ];
    uid = lib.mkDefault <uid>;
    hashedPassword = lib.mkDefault <hash>;        # 如果设置
    home = lib.mkDefault <home>;                  # 如果设置
    description = lib.mkDefault <description>;    # 如果设置
    hashedPasswordFile = lib.mkDefault <path>;     # 如果设置 secret
  };
}
```

注意：

- `users.mutableUsers = false` 是框架级固定值，不要按主机覆盖；用户必须通过配置声明，
  不能在目标机上用 `useradd` / `passwd` 修改。
- `isNormalUser`、`createHome`、`extraGroups`、`uid`、`home`、`description`、密码字段都包了
  `mkDefault`，可以被 `users/<name>/default.nix` 覆盖。
- `group` 是直接赋值，不是 `mkDefault`；需要换主组时用 `lib.mkForce` 或修改 `meta.nix`。

## 用户级补充模块

`users/<name>/default.nix` 会在该用户的每个关联主机上导入，位置在框架生成的用户模块之后：

```nix
# users/allenyou/default.nix
{ terminus, ... }:
{
  users.users.allenyou.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAA... allenyou@lap-fallom"
  ];

  age.secrets.oss-nix-cache-config = terminus.secrets.secret {
    name = "common/oss-nix-cache-config";
    path = "/home/allenyou/.aws/config";
    owner = "allenyou";
    mode = "0400";
  };
}
```

适合放 SSH 公钥、用户级 secret、额外的 `users.users.<name>` 属性。用户身份、SSH host alias 和
`home.stateVersion` 应放在 `homes/<user>/`，不要写在这里。

## 主机关联

用户与主机的关联来源有两个，取并集：

1. `users/<name>/meta.nix` 的 `hosts`；
2. `homes/<name>/<host>.nix` 出现的主机名。

因此：

```nix
# users/me/meta.nix
{ hosts = [ "sha-ali-gaal" ]; }
```

和：

```nix
# homes/me/sha-ali-gaal.nix
{ ... }: { ... }
```

都会把 `me` 关联到 `sha-ali-gaal`。

约束：

- 每个用户必须至少关联一台主机，否则发现阶段报错
  `does not associate the user with any host`；
- 关联的主机必须存在，否则报 `unknown host`；
- `users/<name>/` 必须存在 `meta.nix`；
- `homes/<user>/` 中出现的用户必须在 `users/<user>/` 中有目录，否则报 `unknown user`。

即使只需要独立的全局 `homeConfigurations.<user>`，也必须声明至少一台关联主机。

## 在模块中读取用户

框架设置 `terminus.users`，值为当前主机关联的用户名列表：

```nix
{ config, ... }:
{
  environment.etc."terminus-users".text =
    builtins.concatStringsSep "\n" config.terminus.users;
}
```

## 相关

- [Home Manager](home-manager.md)
- [主机](hosts.md)
- [Secrets](secrets.md)
- [`meta.nix` 字段](../reference/meta.md)
