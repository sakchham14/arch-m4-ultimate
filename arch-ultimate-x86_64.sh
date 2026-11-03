#!/bin/bash
# arch-ultimate-x86_64.sh — Arch Linux x86_64 installer

set -uo pipefail

# --- 1️⃣ Dependency Check ---
if ! command -v pacstrap &> /dev/null; then
    echo "Syncing tools..."
    pacman -Sy --noconfirm gptfdisk arch-install-scripts btrfs-progs cryptsetup lvm2
fi

# --- 2️⃣ Configuration ---
echo "--- Arch Linux x86_64 Setup ---"
lsblk -d -o NAME,SIZE,MODEL
read -p "Target Disk (e.g. /dev/sda, /dev/vda, /dev/nvme0n1): " DISK
read -p "Hostname: " HOSTNAME
read -p "Username: " USERNAME
read -s -p "User Password: " USER_PASS; echo
read -s -p "Root Password: " ROOT_PASS; echo

echo "--- Partitioning Mode ---"
echo "1) Auto (recommended: EFI + Btrfs root with subvolumes)"
echo "2) Auto + LVM (EFI + LVM PV with logical volumes)"
echo "3) Manual (you partition; provide device paths)"
read -p "Select [1-3]: " PART_MODE

if [[ "$PART_MODE" == "1" ]]; then
    echo "--- Partition Type ---"
    echo "1) GPT (UEFI, recommended)"
    echo "2) MBR (BIOS/legacy)"
    read -p "Select [1-2]: " PART_TYPE
fi

echo "--- Encryption ---"
echo "1) None"
echo "2) LUKS2 (full-disk)"
read -p "Select [1-2]: " ENCRYPT

echo "--- Hypervisor ---"
echo "1) Bare metal / QEMU-KVM"
echo "2) VMware Workstation/Fusion"
echo "3) VirtualBox"
echo "4) Other"
read -p "Select hypervisor [1-4]: " HYPERVISOR

echo "--- Install Profile ---"
echo "1) Minimal (base only)"
echo "2) Server (minimal + server tools)"
echo "3) Desktop (GNOME)"
echo "4) Desktop (KDE Plasma)"
echo "5) Desktop (XFCE)"
echo "6) Window Manager (Hyprland)"
echo "7) Window Manager (Sway)"
echo "8) Window Manager (i3)"
echo "9) Laptop (power management + brightness)"
echo "10) Development (docker, podman, neovim, base-devel)"
echo "11) Gaming (steam, wine, gamemode, lutris)"
read -p "Select profile [1-11]: " PROFILE

# --- 3️⃣ Partitioning ---
if [[ "$PART_MODE" == "3" ]]; then
    echo "Manual mode. Partition your disk now (cfdisk/fdisk), then enter device paths."
    read -p "EFI/boot partition (e.g. /dev/sda1): " BOOT
    read -p "Root partition (e.g. /dev/sda2): " ROOT_PART
    read -p "Is root partition encrypted? [y/N]: " ENC_ROOT
    [[ "$ENC_ROOT" =~ ^[Yy]$ ]] && ENCRYPT="2"
elif [[ "$PART_MODE" == "2" ]]; then
    # LVM auto
    echo "Partitioning $DISK (LVM)..."
    sgdisk --zap-all "$DISK" 2>/dev/null || true
    sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI" "$DISK"
    sgdisk -n 2:0:0     -t 2:8e00 -c 2:"LVM" "$DISK"
    if [[ "$DISK" == *[0-9] ]]; then
        BOOT="${DISK}p1"; LVM_PART="${DISK}p2"
    else
        BOOT="${DISK}1"; LVM_PART="${DISK}2"
    fi
    pvcreate "$LVM_PART"
    vgcreate vg0 "$LVM_PART"
    lvcreate -L 30G -n root vg0
    lvcreate -l 100%FREE -n home vg0
    ROOT_PART="/dev/vg0/root"
    HOME_PART="/dev/vg0/home"
else
    echo "Partitioning $DISK..."
    sgdisk --zap-all "$DISK" 2>/dev/null || true
    if [[ "$PART_TYPE" == "1" ]]; then
        sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI" "$DISK"
        sgdisk -n 2:0:0     -t 2:8300 -c 2:"ROOT" "$DISK"
    else
        sfdisk "$DISK" <<EOF
label: dos
,512M,ef
,,83
EOF
    fi

    if [[ "$DISK" == *[0-9] ]]; then
        BOOT="${DISK}p1"; ROOT_PART="${DISK}p2"
    else
        BOOT="${DISK}1"; ROOT_PART="${DISK}2"
    fi
fi

# --- 4️⃣ Encryption (optional) ---
if [[ "$ENCRYPT" == "2" ]]; then
    read -s -p "LUKS passphrase: " LUKS_PASS; echo
    echo "$LUKS_PASS" | cryptsetup luksFormat "$ROOT_PART" -
    echo "$LUKS_PASS" | cryptsetup open "$ROOT_PART" cryptroot -
    ROOT_PART="/dev/mapper/cryptroot"
fi

# --- 5️⃣ Formatting & Subvolumes ---
mkfs.vfat -F32 "$BOOT"
if [[ "$PART_MODE" == "2" ]]; then
    mkfs.btrfs -f "$ROOT_PART"
    mkfs.btrfs -f "$HOME_PART"
    mount "$ROOT_PART" /mnt
    btrfs subvolume create /mnt/@ 2>/dev/null || true
    btrfs subvolume create /mnt/@snapshots 2>/dev/null || true
    umount /mnt
    mount -o "noatime,compress=zstd:3,ssd,space_cache=v2,subvol=@" "$ROOT_PART" /mnt
    mkdir -p /mnt/home
    mount "$HOME_PART" /mnt/home
else
    mkfs.btrfs -f "$ROOT_PART"
    mount "$ROOT_PART" /mnt
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@snapshots
    umount /mnt
    OPTS="noatime,compress=zstd:3,ssd,space_cache=v2,subvol="
    mount -o "${OPTS}@" "$ROOT_PART" /mnt
    mkdir -p /mnt/{boot,home,.snapshots}
    mount -o "${OPTS}@home" "$ROOT_PART" /mnt/home
    mount -o "${OPTS}@snapshots" "$ROOT_PART" /mnt/.snapshots
fi
mount "$BOOT" /mnt/boot

# --- 6️⃣ Install Base ---
BASE_PKGS="base linux linux-firmware btrfs-progs snapper vim sudo bash git"
case "$HYPERVISOR" in
    1) GUEST_PKGS="qemu-guest-agent" ;;
    2) GUEST_PKGS="open-vm-tools" ;;
    3) GUEST_PKGS="virtualbox-guest-utils" ;;
    *) GUEST_PKGS="" ;;
esac

case "$PROFILE" in
    1) PROFILE_PKGS="" ;;
    2) PROFILE_PKGS="openssh htop tmux" ;;
    3) PROFILE_PKGS="gnome gdm" ;;
    4) PROFILE_PKGS="plasma sddm" ;;
    5) PROFILE_PKGS="xfce4 xfce4-goodies lightdm lightdm-gtk-greeter" ;;
    6) PROFILE_PKGS="hyprland waybar wofi kitty" ;;
    7) PROFILE_PKGS="sway waybar wofi foot" ;;
    8) PROFILE_PKGS="i3-wm i3status i3lock dmenu xorg-server xorg-xinit" ;;
esac

DRIVER_PKGS=""
if lspci 2>/dev/null | grep -qi nvidia; then DRIVER_PKGS="$DRIVER_PKGS nvidia"; fi
if lspci 2>/dev/null | grep -qi "amd.*vga\|radeon"; then DRIVER_PKGS="$DRIVER_PKGS mesa xf86-video-amdgpu"; fi
if lspci 2>/dev/null | grep -qi "intel.*vga\|intel.*graphics"; then DRIVER_PKGS="$DRIVER_PKGS mesa intel-media-driver"; fi
if grep -q "GenuineIntel" /proc/cpuinfo; then DRIVER_PKGS="$DRIVER_PKGS intel-ucode"; fi
if grep -q "AuthenticAMD" /proc/cpuinfo; then DRIVER_PKGS="$DRIVER_PKGS amd-ucode"; fi

pacstrap /mnt $BASE_PKGS $GUEST_PKGS $PROFILE_PKGS $DRIVER_PKGS

genfstab -U /mnt >> /mnt/etc/fstab

# --- 7️⃣ Chroot Configuration ---
arch-chroot /mnt /bin/bash <<EOF
set -e
ln -sf /usr/share/zoneinfo/Asia/Kathmandu /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname

echo "root:$ROOT_PASS" | chpasswd
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$USER_PASS" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

if [[ "$PART_TYPE" == "1" ]]; then
    pacman -S --noconfirm grub efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --removable
else
    pacman -S --noconfirm grub
    grub-install --target=i386-pc "$DISK"
fi
grub-mkconfig -o /boot/grub/grub.cfg

snapper -c root create-config /
rm -rf /.snapshots
mkdir /.snapshots

case "$HYPERVISOR" in
    1) systemctl enable qemu-guest-agent.service ;;
    2) systemctl enable vmtoolsd.service vmware-vmblock-fuse.service ;;
    3) systemctl enable vboxservice.service ;;
esac

case "$PROFILE" in
    3) systemctl enable gdm ;;
    4) systemctl enable sddm ;;
    5) systemctl enable lightdm ;;
esac
EOF

# --- 8️⃣ Finalize ---
umount -R /mnt
[[ "$ENCRYPT" == "2" ]] && cryptsetup close cryptroot
echo "---------------------------------------------------"
echo "INSTALL COMPLETE! Unmount ISO and reboot."
EOF