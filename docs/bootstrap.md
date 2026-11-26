# 从零开始部署指南

首先，需要在主机上正常安装一个 NixOS。推荐分区方式为：

- UEFI 启动：GPT 分区表
    - `/boot/EFI`: 512M，FAT32，EFI 启动分区
    - 剩余空间：btrfs，用于剩下所有分区，通过 Subvolume 区分。
        - `/`: `root` Subvolume，开启 zstd 压缩。
        - `/nix`: `nix` Subvolume，开启 zstd 压缩，`noatime`。
        - `/home`: `home` Subvolume，开启 zstd 压缩。
        - `/var`: `var` Subvolume，开启 zstd 压缩。
        - `/swap`: `swap` Subvolume，禁用 zstd 压缩，禁用 CoW，用于存放 Swapfile。内有一个 4G 的 Swapfile。
- BIOS 启动：GPT 分区表
    - 1MB，不分区，用于兼容 BIOS 启动。
    - 剩余空间：btrfs，用于剩下所有分区，通过 Subvolume 区分。
        - `/`: `root` Subvolume，开启 zstd 压缩。
        - `/nix`: `nix` Subvolume，开启 zstd 压缩，`noatime`。
        - `/home`: `home` Subvolume，开启 zstd 压缩。
        - `/var`: `var` Subvolume，开启 zstd 压缩。
        - `/swap`: `swap` Subvolume，禁用 zstd 压缩，禁用 CoW，用于存放 Swapfile。内有一个 4G 的 Swapfile。

正常生成 `hardware-configuration.nix`。

安装后，启用 `nix-command` `flakes` Feature，并安装好 git。

随后，执行 `sudo ssh-keygen -A` 生成主机密钥。

在具有管理权限的设备上，向 `secrets/keys.nix` 中添加新的密钥（`/etc/ssh/ssh_host_ed25519_key.pub` 中的内容），并使用 `just rekey` 进行重新加密后，将其推送到 GitHub。

在 `hosts/` 目录下配置相关主机的设置内容后，将其推送到 GitHub，然后在远端服务器上拉取。

拉取完成后，在其下执行 `just switch <主机名>` 应用新配置。
