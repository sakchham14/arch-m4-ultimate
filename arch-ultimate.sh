#!/bin/bash
# arch-m4-ultimate.sh
# Hardened, automated Arch Linux ARM64 for UTM

set -uo pipefail # Better error handling
exec > >(tee -a "/tmp/install.log") 2>&1 # Log everything for debugging

# --- 1️⃣ Configuration & Detection ---
echo "--- Initializing Arch M4 Installer ---"

# Detect Disk
lsblk -d -o NAME,SIZE,MODEL
read -p "Target Disk (e.g. /dev/vda): " DISK

# Detect Host Timezone (If possible via UTM, else prompt)
AUTO_TZ=$(curl -s https://ipapi.co/timezone || echo "UTC")
read -p "Timezone [$AUTO_TZ]: " TIMEZONE
TIMEZONE=${TIMEZONE:-$AUTO_TZ}

# User Info
read -p "Hostname: " HOSTNAME
read -p "Username: " USERNAME
read -s -p "User Password: " USER_PASS; echo
read -s -p "Root Password: " ROOT_PASS; echo

# --- 2️⃣ Partitioning & Filesystem ---
echo "Creating 1GB EFI and Btrfs root..."
sgdisk --zap-all "$DISK"
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" "$DISK"
sgdisk -n 2:0:0    -t 2:8300 -c 2:"ROOT" "$DISK"

PART_PREFIX=""
[[ "$DISK" == *"nvme"* || "$DISK" == *"mmcblk"* ]] && PART_PREFIX="p"
BOOT="${DISK}${PART_PREFIX}1"
ROOT_PART="${DISK}${PART_PREFIX}2"

mkfs.vfat -F32 "$BOOT"
mkfs.btrfs -f "$ROOT_PART"

# Setup Btrfs Subvolumes
mount "$ROOT_PART" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log # Separate log subvol prevents log bloat in snapshots
umount /mnt

# --- 3️⃣ Mounting ---
OPTS="noatime,compress=zstd:3,ssd,space_cache=v2,subvol="
mount -o "${OPTS}@" "$ROOT_PART" /mnt
mkdir -p /mnt/{boot,home,.snapshots,var/log}
mount -o "${OPTS}@home" "$ROOT_PART" /mnt/home
mount -o "${OPTS}@snapshots" "$ROOT_PART" /mnt/.snapshots
mount -o "${OPTS}@var_log" "$ROOT_PART" /mnt/var/log
mount "$BOOT" /mnt/boot

# --- 4️⃣ Base Installation ---
# Added 'git' so you can push the script to GitHub immediately after install
pacstrap /mnt base linux linux-firmware btrfs-progs snapper vim sudo bash qemu-guest-agent git

# --- 5️⃣ Chroot Configuration ---
genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash <<EOF
set -e
# System Clock & Locale
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname

# Users & Sudo
echo "root:$ROOT_PASS" | chpasswd
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$USER_PASS" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Bootloader (Hardened for UTM)
pacman -S --noconfirm grub efibootmgr
grub-install --target=arm64-efi --efi-directory=/boot --bootloader-id=GRUB --removable
grub-mkconfig -o /boot/grub/grub.cfg

# Snapper Setup (Fixed Logic)
# Snapper needs the config created BEFORE the subvolume is mounted to /.snapshots
snapper -c root create-config /
rm -rf /.snapshots
mkdir /.snapshots
# This ensures it mounts correctly on next boot via fstab
EOF

# --- 6️⃣ Finalize ---
umount -R /mnt
echo "SUCCESS: Install complete. Log saved to /tmp/install.log."
