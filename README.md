# Arch Linux Universal Installer

Automated, "no-hassle" Arch Linux installer for **ARM64 (aarch64)** and **x86_64** systems — bare metal or virtualized (UTM, VMware, VirtualBox, QEMU/KVM, Parallels). Uses a modern **Btrfs** layout with subvolumes and snapshot support.

## One-Command Install

Boot into an Arch Linux ISO (matching your architecture), then run:

```bash
pacman -Sy --noconfirm arch-install-scripts gptfdisk && \
curl -L -O https://raw.githubusercontent.com/sakchham14/arch-m4-ultimate/main/arch-ultimate.sh && \
chmod +x arch-ultimate.sh && ./arch-ultimate.sh
```

The script auto-detects your architecture (`uname -m`) and pulls the correct installer.

## Features

- **Auto architecture detection** — aarch64 or x86_64
- **Bare metal or VM** — prompts for hypervisor to install the right guest tools
- **Btrfs** with zstd compression and subvolumes (`@`, `@home`, `@snapshots`)
- **Snapper** pre-configured for instant system rollbacks
- **UEFI + GRUB** with `--removable` flag for VM compatibility

## Partition Scheme

| Mount Point | Subvolume | Size | Notes |
|---|---|---|---|
| `/boot` | — | 1GB | FAT32 EFI partition |
| `/` | `@` | Rest | Btrfs root |
| `/home` | `@home` | Shared | Shared Btrfs space |
| `/.snapshots` | `@snapshots` | Shared | For Snapper rollbacks |

## Hypervisor Support

| Option | Guest package | Service enabled |
|---|---|---|
| UTM / QEMU | `qemu-guest-agent` | `qemu-guest-agent.service` |
| VMware Fusion/Workstation | `open-vm-tools` | `vmtoolsd`, `vmware-vmblock-fuse` |
| VirtualBox | `virtualbox-guest-utils` | `vboxservice` |
| Bare metal / other | none | — |

## UTM Configuration (Apple Silicon)

For best performance on M4 Macs:
- **System:** Apple Virtualization (not Emulation)
- **Architecture:** ARM64 (aarch64)
- **Display:** virtio-ramfb-gl (Apple)
- **Drive:** VirtIO interface