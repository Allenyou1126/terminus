# 包与 outputs

> 适用版本：`0.1.0`

除了 `nixosConfigurations` 和 `homeConfigurations`，Terminus 还会发现并生成 per-system 的
packages、overlays、apps、devShells、checks、formatter，以及 `lib` 映射。本页说明这些目录的
写法；完整 output 列表见 [Outputs 映射](../reference/outputs.md)。

## packages/

```text
packages/
├── certimate/
│   ├── default.nix
│   └── meta.nix
└── x86_64-linux/
    └── foo/
        └── default.nix
```

| 布局 | output |
| --- | --- |
| `packages/<name>/default.nix` | `packages.<system>.<name>`，对所有派生 system 可用。 |
| `packages/<name>/meta.nix` 的 `systems` | 限制到指定 system。 |
| `packages/<system>/<name>/default.nix` | 仅该 system 的 `packages.<system>.<name>`。 |
| `packages/<name>.<system>/default.nix` | 旧式单架构布局，继续兼容。 |

旧式后缀布局只在 `meta.nix` 没有显式 `systems` 时生效：

```nix
# packages/foo.x86_64-linux/default.nix → packages.x86_64-linux.foo
```

如果 `meta.nix` 声明了 `systems`，完整目录名会被保留为包名，不再按 `.x86_64-linux` 拆分。

`meta.nix`：

```nix
{
  enable = true;
  systems = [ "x86_64-linux" ];
}
```

| 字段 | 默认 | 作用 |
| --- | --- | --- |
| `enable` | `true` | 为 `false` 时不生成该包。 |
| `systems` | `null` | 限制生成该包的 system；`null` 表示所有派生 system。 |

包文件本身是 `callPackage` 可调用的函数：

```nix
{
  lib,
  fetchFromGitHub,
  buildGoModule,
  inputs,
  self,
  terminus,
  ...
}:
buildGoModule {
  # ...
}
```

`callPackage` 能解析普通 nixpkgs 参数；此外框架还提供：

- `inputs`：全部 flake inputs；
- `self`：当前 flake；
- `terminus`：`{ version, inputs, self }`。

重复的包名会在求值时报错：发现阶段检查同一 `system:name`，outputs 阶段再检查按 system 过滤后的同名包。框架还会在 `packages.<system>` 中加入
`colmena`；如果用户包与它同名，框架的 `colmena` 优先。

## overlays/

```text
overlays/
└── example/
    └── default.nix
```

标准 overlay：

```nix
# overlays/example/default.nix
final: prev: {
  example = prev.hello;
}
```

需要框架参数时，写成先接收参数、再返回 overlay 的函数：

```nix
# overlays/example/default.nix
{ inputs, ... }:
final: prev: {
  example = inputs.some-flake.packages.${prev.system}.default;
}
```

框架识别函数参数中是否有 `inputs` / `self` / `terminus`：有则先传入这些参数，再把返回值当作
overlay；没有则原样作为 overlay 使用。

`overlays/<name>/meta.nix` 支持：

```nix
{
  enable = true;
  systems = [ "x86_64-linux" ];
}
```

`enable = false` 时不会导出，也不会应用。所有启用的 overlay 会按名称顺序应用到每个
`pkgsBySystem`，然后才应用 `mkFlake` 的 `nixpkgs.overlays`。注意 `systems` 当前参与 system
推导，但 overlay 本身仍会应用到所有派生 system，不做逐 system 过滤。

## apps / shells / checks

```text
apps/<name>/default.nix      → apps.<system>.<name>
shells/<name>/default.nix    → devShells.<system>.<name>
checks/<name>/default.nix    → checks.<system>.<name>
```

三者都使用与 packages 相同的 `callPackage` 机制，并支持 `meta.nix` 的 `enable` / `systems`。

`apps` 的返回值如果是 attrset，会去掉 `override` 和 `overrideDerivation` 后再放入 output；
这避免 app 值被误当成包。`checks/` 中名称以 `terminus-` 开头的 check 是框架保留名，会直接
报错：

```text
terminus: checks/ names starting with 'terminus-' are reserved: ...
```

框架自有 checks 会覆盖同名用户 check：

```text
terminus-discovery
terminus-eval-hosts
terminus-secret-paths
terminus-deploy-sudo-deny
terminus-colmena-consistency   # 启用 Colmena 时
```

## formatter/

```nix
# formatter/default.nix
{ pkgs, lib, ... }:
let
  config = pkgs.writeText "treefmt.toml" (builtins.readFile ../treefmt.toml);
in
pkgs.writeShellScriptBin "fmt" ''
  export PATH="${lib.makeBinPath [ pkgs.nixfmt ]}:$PATH"
  exec ${pkgs.treefmt}/bin/treefmt --config-file ${config} "$@"
''
```

- 存在 `formatter/default.nix` 时生成 `formatter.<system>`；
- 不存在或 `meta.enable = false` 时回退到 `pkgs.nixfmt`；
- `meta.systems` 限制生效的 system；
- 本仓库通过 `just fmt` / `nix fmt` 调用 treefmt。

## lib 映射

`lib/*.nix` 会被机械导出为 `lib.<name>`：

```text
lib/
├── default.nix     → lib.default
├── discover.nix    → lib.discover
├── fs.nix          → lib.fs
└── ...
```

每个文件被 `import`；如果是函数，则用 `{ lib, inputs, self, terminus }` 中它声明过的参数调用；
否则直接作为值。

需要特别注意：

- 本仓库的 `lib/` 就是**框架源码**，不是用户扩展目录；
- `lib.default` 是 `{ version, mkFlake }`，不是 `mkFlake` 函数本身；
- 部分框架文件需要额外参数（例如 `lib/discover.nix` 需要 `root` 和 `knownSystems`），通过
  `lib.discover` 访问会因缺少参数而失败；
- 因此 `lib` output 是内部文件的机械映射，不是稳定 API，不建议在主机配置里依赖它。

如需共享工具函数，优先放在模块的 `exports.nix` 中，通过 `terminus.exports` 使用：

```nix
# modules/server/example/exports.nix
{ lib, ... }:
{
  example = {
    mkListen = port: "0.0.0.0:${toString port}";
  };
}
```

## outputs.extra

`mkFlake` 的 `outputs.extra` 会在所有生成结果之后做 `lib.recursiveUpdate`：

```nix
mkFlake {
  outputs.extra = {
    apps.x86_64-linux.my-tool = {
      type = "app";
      program = "${pkgs.my-tool}/bin/my-tool";
    };
  };
}
```

可以新增 output，也可以覆盖已有的同名属性。注意：

- `extra` 的合并发生在框架生成结果之后，所以它会覆盖同名框架 output；
- `libOutput` 这个内部属性在合并前已移除；
- `colmenaHive` 的生成取决于 `colmena.enable`，不要用 `extra` 伪造它来绕过一致性检查。

## 常用检查

```bash
nix flake show
nix eval --json .#packages.x86_64-linux --apply builtins.attrNames
nix eval --json .#apps.x86_64-linux --apply builtins.attrNames
nix build .#packages.x86_64-linux.<name>
```

## 相关

- [目录结构](directory-structure.md)
- [Outputs 映射](../reference/outputs.md)
- [`mkFlake` 参数](../reference/mk-flake.md)
- [模块](modules.md)
