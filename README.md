# Arch Linux M4 (Apple Silicon) UTM Installer

An automated, "no-hassle" Arch Linux ARM64 installer designed specifically for **M4-series Macs** running **UTM**. It uses a modern **Btrfs** layout with subvolumes and snapshot support.

## 🚀 One-Command Install

Once you have booted into the **Archboot** or **Arch ARM64 ISO**, run this command to start the installation:

```bash
pacman -Sy --noconfirm arch-install-scripts gptfdisk && \
curl -L -O [https://raw.githubusercontent.com/sakchham14/arch-m4-ultimate/main/arch-ultimate.sh](https://raw.githubusercontent.com/sakchham14/arch-m4-ultimate/main/arch-ultimate.sh) && \
chmod +x arch-ultimate.sh && \
./arch-ultimate.sh
✨ Key Features
Modern Filesystem: Uses Btrfs with zstd compression (optimized for M4 SSD performance).

Subvolume Layout: shares space dynamically between Root and Home.

System Recovery: Pre-configured with Snapper for instant system rollbacks.

UTM Persistence: Uses the --removable GRUB flag to ensure the VM always finds the bootloader.

Apple Silicon Optimized: Specifically configured for aarch64 architecture.

📂 Partition & Subvolume Scheme
Mount Point	Subvolume	Size	Notes
/boot	N/A	1GB	FAT32 EFI Partition
/	@	Rest	Btrfs root
/home	@home	Shared	Shared Btrfs space
/.snapshots	@snapshots	Shared	For Snapper rollbacks
🛠 UTM Configuration (M4)
For maximum performance, ensure your UTM VM settings are:

System: Apple Virtualization (Virtualization, not Emulation).

Architecture: ARM64 (aarch64).

Display: virtio-ramfb-gl (Apple) (Required for GPU acceleration later).

Drive: VirtIO interface for the main disk.
