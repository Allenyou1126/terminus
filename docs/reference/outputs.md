# Outputs 映射

> 适用版本：`0.1.0`

本页列出 `mkFlake` 生成的完整 output 结构、框架自有 output，以及 Discovery JSON 的字段。
目录约定见[目录结构](../guide/directory-structure.md)，参数见 [`mkFlake`](mk-flake.md)。

## 顶层 outputs

```text
nixosConfigurations.<host>
homeConfigurations.<user>
homeConfigurations."<user>@<host>"
colmenaHive                    # colmena.enable = true 时
packages.<system>.<name>
apps.<system>.<name>
devShells.<system>.<name>
checks.<system>.<name>
formatter.<system>
nixosModules.<module>
homeModules.<module>
overlays.<name>
lib.<name>
```

## 目录到 output

| 目录 / 文件 | output |
| --- | --- |
| `hosts/<name>/default.nix` | `nixosConfigurations.<name>` |
| `hosts/<name>/default.nix` + Colmena | `colmenaHive.nodes.<name>` |
| `homes/<user>/default.nix` | `homeConfigurations.<user>`（`home.standalone = true`） |
| `homes/<user>/<host>.nix` | `homeConfigurations."<user>@<host>"` |
| `modules/<namespace>/<path>/nixos.nix` 等 | `nixosModules."<namespace>.<path>"` |
| `modules/<namespace>/<path>/home.nix` 等 | `homeModules."<namespace>.<path>"` |
| `packages/<name>/default.nix` | `packages.<system>.<name>` |
| `packages/<system>/<name>/default.nix` | 仅该 system 的 `packages.<system>.<name>` |
| `overlays/<name>/default.nix` | `overlays.<name>`，并应用到 `pkgsBySystem` |
| `apps/<name>/default.nix` | `apps.<system>.<name>` |
| `shells/<name>/default.nix` | `devShells.<system>.<name>` |
| `checks/<name>/default.nix` | `checks.<system>.<name>` |
| `formatter/default.nix` | `formatter.<system>` |
| `lib/*.nix` | `lib.<name>`（框架内部映射） |

## 框架自有 output

### packages

每个 system 的 `packages.<system>` 总是包含：

```nix
packages.<system>.colmena = inputs.colmena.packages.<system>.colmena;
```

如果用户包同名，框架的 `colmena` 覆盖用户值。

### apps

每个 system 的 `apps.<system>` 总是包含：

```nix
apps.<system>.colmena = {
  type = "app";
  program = "${inputs.colmena.packages.<system>.colmena}/bin/colmena";
};

apps.<system>.terminus-discovery = {
  type = "app";
  program = <打印 Discovery JSON 的脚本>;
};
```

如果用户 app 同名，框架值覆盖用户值。

### devShells

`devShells.<system>.default` 包含：

```text
colmena  agenix  just  jq  nixfmt  statix  deadnix  treefmt  git
```

用户 `shells/<name>` 与 `default` 合并；同名时框架的 `default` 优先。

### checks

`checks.<system>` 由用户 check 与框架 check 合并，框架同名 check 优先：

| check | 类型 | 验证内容 |
| --- | --- | --- |
| `terminus-discovery` | `writeText` JSON | 发现结果快照。 |
| `terminus-eval-hosts` | `writeText` JSON | 每台主机 `toplevel.drvPath`。 |
| `terminus-secret-paths` | `runCommand` | `terminus.secrets.secret` 的默认路径/owner/mode/store context。 |
| `terminus-deploy-sudo-deny` | `runCommand` | 远程主机 sudo 拒绝规则是最后一条。 |
| `terminus-colmena-consistency` | `runCommand` | 标准配置与 hive 的 `toplevel.outPath` 一致。 |

`terminus-colmena-consistency` 只在 `colmena.enable = true` 且该 system 有主机时生成。

### formatter

有 `formatter/default.nix` 且 `meta.enable` 不为 false 时使用它；否则回退：

```nix
formatter.<system> = pkgs.nixfmt;
```

`meta.systems` 限制自定义 formatter 生效的 system。

### overlays

`overlays.<name>` 是所有 `enable = true` 的发现 overlay；它们同时被应用到每个
`pkgsBySystem`。应用顺序：

```text
发现到的 overlays（按名称）
→ mkFlake 的 nixpkgs.overlays
```

### nixosModules / homeModules

对每个发现的模块：

```nix
nixosModules."<dotted.name>" = {
  imports = [ options.nix default.nix nixos.nix ];  # 只包含存在的文件
};
```

规则：

- 键是点号模块名，例如 `server.frps`、`_common.nix-substituters.cn`；
- 值固定是 `{ imports = ...; }`；
- 只有对应 side 有文件的模块才会出现；
- registry 不经过 Profile 选择或依赖排序；
- `meta.<side>.enable = false` 不会让 registry 项消失。

### lib

`lib.<name>` 是 `lib/*.nix` 的机械映射。每个文件被 `import`；如果是函数，用
`{ lib, inputs, self, terminus }` 中它声明过的参数调用。

注意：本仓库的 `lib/` 是框架源码，`lib` output 不是用户扩展点，也不是稳定 API。部分文件
（如 `discover.nix`）需要额外参数，通过 `lib.<name>` 访问会失败。共享工具请放到模块
`exports.nix`，通过 `terminus.exports` 使用。

## colmenaHive

`colmena.enable = true` 时生成：

```nix
colmenaHive = inputs.colmena.lib.makeHive {
  meta = {
    name = "terminus";
    nixpkgs = pkgsBySystem.<firstSystem>;
    nodeNixpkgs = { <host> = pkgsBySystem.<host.system>; };
    nodeSpecialArgs = { <host> = <host specialArgs>; };
    allowApplyAll = <mkFlake 参数>;
  };

  defaults = { };

  <host> = {
    imports = ctx.modules ++ [ deploy.colmenaModule shim ];
  };
};
```

- `nodes` 包含所有主机，包括没有 `targetHost` 的本机；
- `deployment` 元数据只对 `targetHost != null` 的主机有意义；
- `deploy.colmenaModule` 把 host meta 的 `deployment` 转成 Colmena option；
- shim 对齐 `system.nixos.revision`、`versionSuffix`、`nixpkgs.flake.source`；
- `allowApplyAll = false` 时默认要求显式 `--on`。

`nix flake check` 会警告 `unknown flake output 'colmenaHive'`，这是 flake schema 不认识自定义
output，不影响检查。

## Discovery JSON

`nix run .#terminus-discovery` 输出：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `frameworkVersion` | string | 当前固定为 `"0.1.0"`。 |
| `systems` | list of string | 派生出的 system。 |
| `hosts` | list of string | 主机名。 |
| `users` | list of string | 用户名。 |
| `homes` | list of `{ user, host }` | `host` 为 `null` 表示全局 home。 |
| `modules` | list of string | 所有发现的模块点号名。 |
| `profiles` | list of string | 配置集名（含 `default`，如果存在）。 |
| `profileRequires` | attrset | 配置集名 → `requires` 模块点号名列表。 |
| `profileConfig` | attrset | 配置集名 → `{ nixos = bool; home = bool; }`，表示是否有侧配置文件。 |
| `hostProfiles` | attrset | 主机名 → `meta.profiles` 声明值（不含自动应用的 `default`）。 |
| `hostRequires` | attrset | 主机名 → `meta.requires` 声明值。 |
| `packages` | list of string | 包名。 |
| `overlays` | list of string | overlay 名。 |
| `apps` | list of string | app 名。 |
| `shells` | list of string | shell 名。 |
| `checks` | list of string | 用户 check 名（不含框架 checks）。 |
| `formatter` | string / `null` | 有 formatter 时为 `"formatter"`。 |
| `deploy` | attrset | 远程主机名 → `{ targetHost, targetPort, sshUser, tags }`。 |
| `secretsDir` | string | `toString` 后的 secrets 目录。 |
| `colmenaNodes` | list of string | hive 节点名；未启用 Colmena 时为空。 |

JSON 只描述发现结果，**不包含**某主机最终选中的模块或依赖顺序。模块选择错误在求值主机配置时
报出。

## 惰性与构建

- 发现阶段会读取目录和 `meta.nix`；这是 `mkFlake` 求值的一部分；
- `nixosConfigurations`、`homeConfigurations`、packages、apps、checks 等属性集是惰性的；
- `nix flake show` 不会构建系统配置；
- `nix flake check` 会求值 checks 和模块接口，但不一定构建所有 toplevel；
- 需要精确验证某台主机时，直接构建它的 toplevel 或 check。

## 示例查询

```bash
nix flake show
nix eval --json .#nixosConfigurations --apply builtins.attrNames
nix eval --json .#homeConfigurations --apply builtins.attrNames
nix eval --json .#apps.x86_64-linux --apply builtins.attrNames
nix eval --json .#checks.x86_64-linux --apply builtins.attrNames
nix eval --json .#colmenaHive.nodes --apply builtins.attrNames
nix build .#checks.x86_64-linux.terminus-discovery
```

## 相关

- [目录结构](../guide/directory-structure.md)
- [`mkFlake` 参数](mk-flake.md)
- [包与 outputs](../guide/packages-and-outputs.md)
- [部署](../guide/deployment.md)
