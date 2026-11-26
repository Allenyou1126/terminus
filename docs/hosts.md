# 主机列表

这里列出了我的设备，包括由本仓库管理的 NixOS 设备和其他设备。

## 目前主机列表

| 主机名                                   | 类型          | 服务商   | 地域                  | 系统                   | 描述                                  |
| ---------------------------------------- | ------------- | -------- | --------------------- | ---------------------- | ------------------------------------- |
| [hkg-dog-darell](/hosts/hkg-dog-darell/) | 云服务器      | 狗云     | 香港                  | NixOS                  | 主力服务器，大部分应用                |
| [sha-ali-gaal](/hosts/sha-ali-gaal/)     | 云服务器      | 阿里云   | 上海                  | NixOS                  | 99 计划机子，测试用                   |
| [sha-ali-seldon](/hosts/sha-ali-seldon/) | 云服务器      | 阿里云   | 上海                  | NixOS                  | 内网穿透 + 个人主页 + 监控 + SSO      |
| [lax-rn-riose](/hosts/lax-rn-riose/)     | 云服务器      | RackNerd | 洛杉矶                | NixOS                  | DN42 BGP                              |
| home-demerzel                            | 家里云-实体机 | -        | 家里                  | Proxmox VE             | 虚拟化                                |
| home-arkady                              | 家里云-虚拟机 | -        | 家里 on home-demerzel | Windows 11             | 远程桌面                              |
| [home-ebeling](/hosts/home-ebeling/)     | 家里云-虚拟机 | -        | 家里 on home-demerzel | NixOS                  | 内网服务器                            |
| home-preem                               | 家里云-虚拟机 | -        | 家里 on home-demerzel | OpenWRT                | 旁路由                                |
| home-hardin                              | 家里云-实体机 | -        | 家里                  | Proxmox VE             | 软路由虚拟化                          |
| home-compor                              | 家里云-虚拟机 | -        | 家里 on home-hardin   | RouterOS               | 主软路由                              |
| [lap-fallom](/hosts/lap-fallom/)         | 个人设备      | -        | -                     | Windows 11 + NixOS WSL | 拯救者 R9000P 2023 锐龙版，娱乐用设备 |
| lap-yenner                               | 个人设备      | -        | -                     | Arch Linux with Nix    | 机械革命无界 15X，开发用机            |

## 命名规则

代号优先从阿西莫夫《基地》系列中选取。

### 远程服务器

```text
[三位机场码]-[服务商]-[代号]
```

目前的服务商代号列表：

- `ali`: 阿里云
- `rn`: RackNerd
- `dog`: 狗云

### 家里云

```
home-[代号]
```

### 个人设备

```
lap-[代号]
desk-[代号]
```
