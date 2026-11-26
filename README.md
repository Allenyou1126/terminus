# Terminus

[![NixOS 26.05](https://img.shields.io/badge/NixOS-26.05-5277C3?logo=nixos&logoColor=white)](https://nixos.org)
[![Terminus 0.1.0](https://img.shields.io/badge/Terminus-0.1.0-informational)](docs/README.md)

Terminus 是一套自包含的、参考 [Snowveil](https://github.com/SnowveilOrg/Snowveil) 目录约定的
NixOS 配置框架，框架与配置同仓。当前版本 `0.1.0`，使用 NixOS `nixos-26.05`、Home Manager
`release-26.05`、[Colmena](https://github.com/nix-community/colmena) 与
[agenix](https://github.com/ryantm/agenix)。

本仓库目前管理 6 台 `x86_64-linux` 主机：

| 主机 | 用途 |
| --- | --- |
| `sha-ali-gaal` | 测试服务器 |
| `sha-ali-seldon` | 网络网关服务器 |
| `hkg-dog-darell` | 应用服务器 |
| `home-ebeling` | Homelab 服务器 |
| `lax-rn-riose` | DN42 服务器 |
| `lap-fallom` | WSL 客户端笔记本 |

> [!IMPORTANT]
> 这是个人配置仓库，包含针对特定硬件的配置与加密的 secrets。请勿直接部署到其他机器；
> 可将其作为目录约定与模块实现的参考。

## 文档

完整框架文档见 **[docs/README.md](docs/README.md)**，包含目录结构、模块与 Profile、模块依赖、
Secrets、部署流程和 `mkFlake` 参考规范。

## 快速开始

```bash
nix flake check path:. --no-build   # 求值检查
nix flake show                      # 查看 flake outputs
nix run .#terminus-discovery        # 输出发现结果 JSON
nix fmt                             # 格式化
```

> Flake 从 Git 求值时只包含已跟踪/已暂存的文件。新增 host、module、`.age` secret 或
> `keys/deploy/*.pub` 后先 `git add`；本地验证可用 `path:.` 读取工作树。

仓库根目录的 `justfile` 封装了常用操作（`just check`、`just discovery`、`just switch <host>`、
`just test <host>`、`just apply <host>`、`just fmt`），`just --list` 可查看全部。

## 部署

本机（在目标机执行）：

```bash
# 不使用 just
sudo nixos-rebuild switch --flake .#<host>

# 使用 just
just switch <host>
```

远程（Colmena）：

```bash
# 不使用 just
nix run .#colmena -- apply test --on <host>   # 灰度激活，保留旧 boot 默认项
nix run .#colmena -- apply boot --on <host>   # 设为 boot 默认，不立即激活
nix run .#colmena -- apply --on <host>        # 正式切换

# 使用 just
just test <host>
just boot <host>
just apply <host>

# 批量部署到某个 TAG 的所有主机上
just apply-tag <TAG>
nix run .#colmena -- apply --on @<TAG>
```

首次远程部署前，如果目标机上还没有 `deploy` 用户，需要先在目标机本地部署一次。deploy 用户、
SSH 配置、一致性检查与回滚注意事项见 [部署文档](docs/guide/deployment.md)。

## Secrets

加密文件与规则位于 [`secrets/`](secrets/)；仓库内不保存私钥或明文 secrets。编辑、检查与
rekey 的流程见 [Secrets 文档](docs/guide/secrets.md)。

## 参考

- [Snowveil](https://github.com/SnowveilOrg/Snowveil)：目录约定与文档结构的主要来源。
