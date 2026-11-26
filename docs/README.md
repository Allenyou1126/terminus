# Terminus 文档

> 适用版本：`0.1.0`

Terminus 是一套自包含的 NixOS 配置框架：`lib/` 负责发现目录、组合模块并生成 flake outputs，
`hosts/`、`homes/`、`users/`、`modules/` 等目录承载真正的系统配置。它参考
[Snowveil](https://github.com/SnowveilOrg/Snowveil) 的目录约定，但框架本身与配置同仓，
不是作为外部 flake input 引入的通用库。

本目录是 Terminus 的完整文档。根目录的 [README](../README.md) 是速查，遇到冲突时以源码和
这里的说明为准。

## 阅读路径

| 目标 | 建议顺序 |
| --- | --- |
| 第一次接触 Terminus | [介绍](guide/introduction.md) → [快速开始](guide/getting-started.md) → [目录结构](guide/directory-structure.md) |
| 添加或维护一台主机 | [主机](guide/hosts.md) → [用户](guide/users.md) → [Home Manager](guide/home-manager.md) → [部署](guide/deployment.md) |
| 编写或调整模块 | [模块](guide/modules.md) → [配置集](guide/profiles.md) → [模块依赖](guide/module-dependencies.md) |
| 管理密钥与服务 | [Secrets](guide/secrets.md) → [包与 outputs](guide/packages-and-outputs.md) |
| 排查求值/部署问题 | [排错](guide/troubleshooting.md) → [求值模型](concepts/architecture.md) |
| 查参数与字段规范 | [mkFlake](reference/mk-flake.md) → [meta.nix](reference/meta.md) → [outputs](reference/outputs.md) → [specialArgs](reference/special-args.md) |

## 入门与上手

- [介绍](guide/introduction.md)：Terminus 的定位、设计原则、与 Snowveil 的差异。
- [快速开始](guide/getting-started.md)：从最小骨架到第一条可构建的 `nixosConfiguration`。
- [目录结构](guide/directory-structure.md)：目录约定、magic 文件与 output 映射。
- [主机](guide/hosts.md)：`hosts/<name>/` 的元数据、模块文件与添加主机流程。
- [用户](guide/users.md)：`users/<name>/`、密码与主机关联。
- [Home Manager](guide/home-manager.md)：嵌入式与独立 home、嵌入策略与 Profile 门控。
- [模块](guide/modules.md)：模块目录、五个 magic 文件、registry 与 `exports.nix`。
- [配置集](guide/profiles.md)：`profiles/<name>/` 的 `requires` 与 `nixos.nix` / `home.nix` 配置。
- [模块依赖](guide/module-dependencies.md)：`requires` / `after` / `before` / `wants` / `conflicts`。
- [Secrets](guide/secrets.md)：`secretsDir`、agenix、`terminus.secrets.secret` 与编辑流程。
- [部署](guide/deployment.md)：本机 `nixos-rebuild`、Colmena、deploy 用户与一致性检查。
- [包与 outputs](guide/packages-and-outputs.md)：`packages/`、overlays、apps、shells、checks、formatter、`lib/`。
- [排错](guide/troubleshooting.md)：常见错误、框架 checks 与调试方法。

## 概念与原理

- [求值模型](concepts/architecture.md)：`mkFlake` 的求值流程、模块注入顺序与 Colmena 同源 shim。
- [发现机制](concepts/discovery.md)：纯文件系统扫描的规则、排序与错误。
- [模块选择](concepts/module-selection.md)：`default`、Profile/Host `requires` 与 Profile 配置如何注入主机。

## 参考规范

- [`mkFlake` 参数](reference/mk-flake.md)：全部入口参数、inputs 要求与 outputs。
- [`meta.nix` 字段](reference/meta.md)：Host / User / Module / Output 元数据。
- [Outputs 映射](reference/outputs.md)：目录到 output、框架自有 checks/apps 与 Discovery JSON。
- [Special Args](reference/special-args.md)：模块可用的 `inputs`、`self`、`hostname` 与 `terminus.*`。

## 文档约定

- 命令默认在仓库根目录执行；本地验证统一使用 `path:.`，引用 output 时使用 `.#`。
- Nix 代码块多数是完整文件或可直接放入模块的属性集；片段会标注上下文。
- 路径、字段名、命令保持英文；正文使用简体中文。
- 文档按 Terminus `0.1.0` 编写。发现实现与文档不一致时，优先阅读对应源码并在
  [排错](guide/troubleshooting.md)中记录已知限制。
