# mkFlake 参数

> 适用版本：`0.1.0`

`mkFlake` 是 Terminus 的唯一入口。它从 `lib/default.nix` 导出：

```nix
outputs = inputs@{ self, nixpkgs, ... }:
  (import ./lib { lib = nixpkgs.lib; }).mkFlake {
    inherit inputs self;
    root = ./.;
    systems = [ "x86_64-linux" ];
  };
```

## 参数

| 参数 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `inputs` | attrset | 必填 | 全部 flake inputs。 |
| `self` | flake | 必填 | 当前 flake。 |
| `root` | path | `self.outPath` | 扫描根目录；默认 `secretsDir` 也基于它。 |
| `systems` | list of string | `[]` | 额外要求的 system；实际 system 还会从 hosts/packages/outputs/formatter 推导。 |
| `nixpkgs.config` | attrset | `{}` | 传给每个 system 的 nixpkgs config。 |
| `nixpkgs.overlays` | list | `[]` | 追加到发现到的 overlays 之后。 |
| `colmena.enable` | bool | `true` | 是否生成 `colmenaHive` 和一致性检查。 |
| `colmena.allowApplyAll` | bool | `false` | 是否允许 Colmena `apply --all`。 |
| `colmena.deployUser.name` | string | `"deploy"` | 远程部署用户名。 |
| `colmena.deployUser.uid` | int | `50000` | 远程部署用户 UID。 |
| `home.embed` | bool / function / attrset | `true` | 嵌入式 Home Manager 策略。 |
| `home.useGlobalPkgs` | bool / function / attrset | `true` | 嵌入式 Home Manager 是否复用 NixOS 的 `pkgs`。 |
| `home.standalone` | bool | `true` | 是否生成全局 `homeConfigurations.<user>`。 |
| `home.modules` | list | `[]` | 追加到所有 Home Manager 配置（嵌入式与独立）。 |
| `home.specialArgs` | attrset | `{}` | 追加到 Home Manager specialArgs。 |
| `nixos.modules` | list | `[]` | 追加到所有 NixOS 主机的最外层模块。 |
| `nixos.specialArgs` | attrset | `{}` | 追加到 NixOS specialArgs。 |
| `outputs.extra` | attrset | `{}` | 最后合并到 flake outputs。 |
| `secretsDir` | path / string | `root + "/secrets"` | agenix secret 目录；必须存在，否则 `terminus-secret-paths` 检查失败。 |
| `secretsIdentityPaths` | list of string | `[ "/etc/ssh/ssh_host_ed25519_key" ]` | 默认 agenix 身份路径；主机可覆盖。 |

`inputs` 缺失会直接 `throw`；`self` 缺失同样。`root` 默认使用 `self.outPath`，从 Git 求值时
只包含已跟踪文件；本地检查可用 `path:.` 直接读取工作树。

## home 策略

`home.embed` 与 `home.useGlobalPkgs` 支持三种写法：

```nix
home.embed = true;
home.embed = host: host != "lap-fallom";
home.embed = { default = true; hosts.lap-fallom = false; };
```

解析时主机 `meta.nix` 的 `home.embed` 优先；否则使用全局值；全局值是函数时以主机名调用；
是 attrset 时先查 `hosts.<name>`，再查 `default`，都没有则 `true`。

## system 推导

实际 `systems` 由以下来源去重合并：

1. `systems` 参数；
2. 每台主机的 `meta.system`；
3. 每个包的 `system` 或 `meta.systems`；
4. overlays/apps/shells/checks 的 `meta.systems`；
5. formatter 的 `meta.systems`。

结果为空时回退 `[ "x86_64-linux" ]`。`knownSystems`（`requestedSystems` + `x86_64-linux` +
`aarch64-linux`）只用于旧式 `packages/<name>.<system>` 后缀识别，不会直接产生 system。

`pkgsBySystem` 对每个 system 只 `import inputs.nixpkgs` 一次，并把发现到的 overlays 与
`nixpkgs.overlays` 一起应用。

## inputs 要求

| input | 何时必需 |
| --- | --- |
| `nixpkgs` | 总是。 |
| `agenix` | 总是（框架自动导入 agenix NixOS 模块）。 |
| `home-manager` | `discovery.homes != []` 时。 |
| `colmena` | 总是被 `packages` / `apps` / `devShells` 引用；`colmena.enable = true` 时还用于 hive。建议始终提供。 |
| `nixos-wsl` | 由主机模块自行 import；框架不检查，但缺了会在求值时失败。 |

缺失时报：

```text
terminus: missing required flake input '<name>'
add it to flake.nix and pass it through `mkFlake { inherit inputs; }`
```

## outputs

| output | 说明 |
| --- | --- |
| `nixosConfigurations.<host>` | 每台主机的标准 NixOS 配置。 |
| `homeConfigurations.<user>` | 全局独立 Home Manager（`home.standalone = true` 且有 `homes/<user>/default.nix`）。 |
| `homeConfigurations."<user>@<host>"` | 每个 `homes/<user>/<host>.nix`。 |
| `colmenaHive` | `colmena.enable = true` 时的 Colmena hive。 |
| `packages.<system>.<name>` | 发现的包 + 框架的 `colmena`。 |
| `apps.<system>.<name>` | 发现的 app + `colmena` + `terminus-discovery`。 |
| `devShells.<system>.<name>` | 发现的 shell + `default`。 |
| `checks.<system>.<name>` | 发现的 check + 框架 checks。 |
| `formatter.<system>` | 发现的 formatter，回退 `pkgs.nixfmt`。 |
| `nixosModules.<name>` | 每个有 NixOS side 的发现模块，值为 `{ imports = ...; }`。 |
| `homeModules.<name>` | 每个有 Home side 的发现模块。 |
| `overlays.<name>` | 每个 `enable = true` 的 overlay。 |
| `lib.<name>` | `lib/*.nix` 的机械映射，不是稳定 API。 |

框架 checks：

```text
terminus-discovery
terminus-eval-hosts
terminus-secret-paths
terminus-deploy-sudo-deny
terminus-colmena-consistency   # 仅启用 Colmena 且有主机时
```

## outputs.extra

```nix
mkFlake {
  outputs.extra = {
    apps.x86_64-linux.example = {
      type = "app";
      program = "${pkgs.example}/bin/example";
    };
  };
}
```

合并发生在生成结果之后，使用 `lib.recursiveUpdate`：

- 可新增 output；
- 可覆盖同名属性；
- 内部 `libOutput` 在合并前已移除；
- 不建议用 `extra` 伪造 `colmenaHive` 绕过一致性检查。

## 版本

```nix
(import ./lib { lib = nixpkgs.lib; }).version
# { major = 0; minor = 1; patch = 0; string = "0.1.0"; }
```

模块中也可以通过 `terminus.version` 读取同一组版本号。

## 示例

完整入口（与当前 `flake.nix` 一致）：

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

      nixpkgs.config.allowUnfree = true;
      secretsDir = ./secrets;

      colmena = {
        enable = true;
        allowApplyAll = false;
      };
    };
}
```

## 相关

- [Outputs 映射](outputs.md)
- [Special Args](special-args.md)
- [求值模型](../concepts/architecture.md)
