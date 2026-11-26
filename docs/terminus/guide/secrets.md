# Secrets

> 适用版本：`0.1.0`

Terminus 使用 [agenix](https://github.com/ryantm/agenix) 管理密钥。框架自动导入 agenix 的
NixOS 模块，并提供 `terminus.secrets.secret` 路径 helper；密钥目录由 `mkFlake` 的
`secretsDir` 统一指定。

## 目录布局

默认 `secretsDir = <repo>/secrets`，该目录必须存在（即使暂时没有 secret），否则
`terminus-secret-paths` 检查会失败。文件按类别放在子目录中，但**相对路径就是规则 key**：

```text
secrets/
├── agenix-rules.nix
├── keys.nix
├── common/
│   ├── aliyun-cli-config.age
│   └── oss-nix-cache-config.age
├── dn42/
│   ├── lax-rn-riose.priv.age
│   └── h503mc_lax-rn-riose.psk.age
├── nexusnet/
│   └── sha-ali-seldon.priv.age
└── services/
    ├── frp-token.age
    ├── grafana/
    │   ├── db-password.age
    │   └── secret-key.age
    └── umami/
        ├── app-secret.age
        └── database-url.age
```

约定：

- `common/`：所有主机共享的配置；
- `dn42/`、`nexusnet/`：网络私钥与 PSK；
- `services/<app>.age`：只有一个 secret 的服务直接用应用名；
- `services/<service>/<name>.age`：多个 secret 的服务建子目录。

规则文件 `secrets/agenix-rules.nix` 的 key 必须与文件相对路径完全一致：

```nix
# secrets/agenix-rules.nix
let
  keys = import ./keys.nix;
in
{
  "common/oss-nix-cache-config.age".publicKeys = builtins.attrValues keys.hostKeys;

  "services/grafana/db-password.age".publicKeys = [
    keys.hostKeys.sha-ali-seldon
  ]
  ++ keys.adminKeys;
}
```

`secrets/keys.nix` 只放**公钥**。私钥永远不会进入仓库。

## secretsDir

本地目录：

```nix
# flake.nix
mkFlake {
  secretsDir = ./secrets;
}
```

外部目录（例如私有 Git 仓库）：

```nix
inputs.allenyou-secrets = {
  url = "git+ssh://git@github.com/Allenyou1126/nixos-secret.git?shallow=1";
  flake = false;
};

mkFlake {
  secretsDir = inputs.allenyou-secrets;
}
```

`secretsDir` 必须是目录路径或字符串，且必须存在；否则报
`terminus: secretsDir must be a directory` 或 `does not exist`。外部 input 必须设置
`flake = false`，这样它才是一个目录而不是 flake。

## 路径 helper

```nix
age.secrets.oss-nix-cache-config =
  terminus.secrets.secret {
    name = "common/oss-nix-cache-config";
    owner = "allenyou";
    mode = "0400";
  };
```

等价于：

```nix
age.secrets.oss-nix-cache-config = {
  owner = "allenyou";
  mode = "0400";
  file = "${secretsDir}/common/oss-nix-cache-config.age";
};
```

`terminus.secrets.secret` 的规则：

| 参数 | 必需 | 说明 |
| --- | --- | --- |
| `name` | 是 | 相对 `secretsDir` 的路径，不带 `.age`，可包含子目录。 |
| `file` | 否 | 覆盖默认文件路径；默认 `"${secretsDir}/<name>.age"`。 |
| 其他 | 否 | 原样传给 `age.secrets.<name>`，例如 `owner`、`mode`、`path`、`symlink`。 |

返回值是**完整的** `age.secrets` 值（包含 `file`），所以直接赋值即可：

```nix
# 正确
age.secrets.example = terminus.secrets.secret {
  name = "common/example";
  owner = "root";
};

# 错误：会丢掉 file 或与 helper 返回值冲突
age.secrets.example = terminus.secrets.secret { name = "common/example"; } // {
  owner = "root";
};
```

不要用 `//` 追加 `owner`/`mode`；把选项直接写进 helper 的参数。

## store context

默认路径必须保留 Nix store context：

```nix
# 正确：路径插值保留 context
file = "${secretsDir}/common/example.age";

# 错误：toString 会丢掉 context
file = "${toString secretsDir}/common/example.age";
```

如果丢掉 context，`nix copy` / Colmena 只会复制 `.age` 文件的路径字符串，不会把实际文件加入
要复制的 closure，目标机上就会缺文件。`terminus.secrets.secret` 内部已经使用
`"${secretsDir}/${name}.age"`，不要在外部再转换成普通字符串。

`terminus.secrets.root` 是供人阅读的 `toString` 路径，`terminus.secrets.storeRoot` 是保留
context 的 store 路径；构造 `file` 时使用 helper 的默认值，不要用 `root` 手工拼接。

## 用户密码

`users/<name>/meta.nix` 的 `hashedPasswordSecret` 使用同一套路径规则：

```nix
{
  hashedPasswordSecret = "common/allenyou-password";
}
```

框架自动声明：

```nix
age.secrets."common/allenyou-password" =
  terminus.secrets.secret { name = "common/allenyou-password"; };

users.users.allenyou.hashedPasswordFile =
  config.age.secrets."common/allenyou-password".path;
```

以 `/` 开头的值按字面文件路径处理，不自动声明 agenix secret。此时需要由其他方式把密码文件
放到该路径。

## 身份路径

默认：

```nix
age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
```

没有 SSH host key 的主机（例如 WSL）在 `hosts/<name>/meta.nix` 覆盖：

```nix
{
  secrets.identityPaths = [ "/home/allenyou/.ssh/id_ed25519" ];
}
```

该值以 `lib.mkDefault` 写入，主机模块仍可覆盖。

## 编辑与检查

```bash
cd secrets
just list
just edit services/example-token
just check
just rekey
```

- `just edit <name>`：name 是相对 `secrets/` 的路径，不带 `.age`；父目录不存在时自动创建。
  编辑器以当前用户运行，`sudo` 只用于 `agenix -d` / `agenix -e`；临时明文目录用
  `mktemp -d` + `cleanup` + `trap` 清理，编辑器保存什么就加密什么，不自动处理尾换行。
- `just list`：列出所有 `.age` 文件的相对路径。
- `just check`：运行 `agenix -c`，校验加密文件的收件人与规则中的 `publicKeys` 一致。
- `just rekey`：按当前规则重新加密所有文件。

外部 `secretsDir` 的编辑/rekey 在外部仓库自己的 Justfile 中完成；本仓库的
`secrets/justfile` 只用于本地目录模式。

## 新增 secret 清单

1. 选定相对路径，例如 `services/example/token`；
2. 在 `secrets/agenix-rules.nix` 添加 `"services/example/token.age".publicKeys`；
3. 运行 `cd secrets && just edit services/example/token`；
4. 在模块或主机中引用：

   ```nix
   age.secrets.example-token = terminus.secrets.secret {
     name = "services/example/token";
     owner = "example";
     mode = "0400";
   };
   ```

5. `git add` 新的 `.age` 文件和规则修改；
6. 运行 `nix flake check path:. --no-build`，再构建目标主机验证 agenix 规则。

## 检查

```bash
nix build .#checks.x86_64-linux.terminus-secret-paths
```

这个 check 用一个虚构的 secret 验证 `terminus.secrets.secret` 的默认路径、`owner`、`mode`
和 store context 行为，不会解密真实密钥。

## 安全规则

- 不提交明文 secret、私钥或 `.age` 解密内容；
- `keys/deploy/*.pub` 是公钥，可以提交；对应私钥只留在部署机；
- deploy key 等价 root 凭据，按 root 级别管理；
- `secretsDir` 指向外部仓库时，确保外部仓库的访问控制至少与主机凭据同级；
- 规则文件的 `publicKeys` 决定哪些主机能解密，新增主机时要同步更新。

## 相关

- [用户](users.md)
- [部署](deployment.md)
- [目录结构](directory-structure.md)
