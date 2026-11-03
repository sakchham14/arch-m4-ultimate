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
- **Partitioning modes** — Auto (Btrfs), Auto + LVM, or Manual
- **LUKS2 encryption** — optional full-disk encryption
- **GPT or MBR** — UEFI or legacy BIOS
- **Btrfs** with zstd compression and subvolumes (`@`, `@home`, `@snapshots`)
- **Snapper** pre-configured for instant system rollbacks
- **UEFI + GRUB** with `--removable` flag for VM compatibility
- **Auto driver detection** — GPU (NVIDIA/AMD/Intel), CPU microcode, audio
- **Install profiles** — 11 presets from minimal to gaming

## Partitioning Modes

| Mode | Description |
|---|---|
| Auto | EFI + single Btrfs root with subvolumes (recommended) |
| Auto + LVM | EFI + LVM PV with separate root/home logical volumes |
| Manual | You partition; provide device paths |

## Partition Scheme (Auto)

| Mount Point | Subvolume | Size | Notes |
|---|---|---|---|
| `/boot` | — | 512MB | FAT32 EFI partition |
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

## Install Profiles

| # | Profile | Packages |
|---|---|---|
| 1 | Minimal | base only |
| 2 | Server | openssh, htop, tmux |
| 3 | Desktop (GNOME) | gnome, gdm |
| 4 | Desktop (KDE Plasma) | plasma, sddm |
| 5 | Desktop (XFCE) | xfce4, lightdm |
| 6 | WM (Hyprland) | hyprland, waybar, wofi, kitty |
| 7 | WM (Sway) | sway, waybar, wofi, foot |
| 8 | WM (i3) | i3-wm, i3status, i3lock, dmenu |
| 9 | Laptop | power-profiles-daemon, brightnessctl |
| 10 | Development | docker, podman, neovim, base-devel |
| 11 | Gaming | steam, wine, gamemode, lutris |

## Auto-Detected Drivers

- **GPU:** NVIDIA, AMD (mesa + xf86-video-amdgpu), Intel (mesa + intel-media-driver)
- **CPU microcode:** intel-ucode or amd-ucode
- **Audio:** pipewire, pipewire-pulse, wireplumber
- **Network:** networkmanager

## UTM Configuration (Apple Silicon)

For best performance on M4 Macs:
- **System:** Apple Virtualization (not Emulation)
- **Architecture:** ARM64 (aarch64)
- **Display:** virtio-ramfb-gl (Apple)
- **Drive:** VirtIO interface
