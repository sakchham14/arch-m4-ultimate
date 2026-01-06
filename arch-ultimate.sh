#!/bin/bash
# arch-m4-final.sh

set -uo pipefail

# --- 1️⃣ Dependency Check ---
if ! command -v pacstrap &> /dev/null; then
    echo "Syncing tools..."
    pacman -Sy --noconfirm gptfdisk arch-install-scripts btrfs-progs
fi

# --- 2️⃣ Configuration ---
echo "--- Arch Linux M4 Setup ---"
lsblk -d -o NAME,SIZE,MODEL
read -p "Target Disk (e.g. /dev/vda): " DISK
read -p "Hostname: " HOSTNAME
read -p "Username: " USERNAME
read -s -p "User Password: " USER_PASS; echo
read -s -p "Root Password: " ROOT_PASS; echo

# --- 3️⃣ Partitioning (Improved Logic) ---
echo "Partitioning $DISK..."
sgdisk --zap-all "$DISK"
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" "$DISK"
sgdisk -n 2:0:0    -t 2:8300 -c 2:"ROOT" "$DISK"

# Handle naming for VirtIO (vda -> vda1) vs NVME (nvme0n1 -> nvme0n1p1)
# This was the cause of your previous 'device 2 does not exist' error
if [[ "$DISK" == *[0-9] ]]; then
    BOOT="${DISK}p1"
    ROOT_PART="${DISK}p2"
else
    BOOT="${DISK}1"
    ROOT_PART="${DISK}2"
fi

# --- 4️⃣ Formatting & Subvolumes ---
mkfs.vfat -F32 "$BOOT"
mkfs.btrfs -f "$ROOT_PART"

mount "$ROOT_PART" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
umount /mnt

# Mounting with M4 optimized flags
OPTS="noatime,compress=zstd:3,ssd,space_cache=v2,subvol="
mount -o "${OPTS}@" "$ROOT_PART" /mnt
mkdir -p /mnt/{boot,home,.snapshots}
mount -o "${OPTS}@home" "$ROOT_PART" /mnt/home
mount -o "${OPTS}@snapshots" "$ROOT_PART" /mnt/.snapshots
mount "$BOOT" /mnt/boot

# --- 5️⃣ Install Base ---
pacstrap /mnt base linux linux-firmware btrfs-progs snapper vim sudo bash qemu-guest-agent git

genfstab -U /mnt >> /mnt/etc/fstab

# --- 6️⃣ Chroot Configuration ---
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

pacman -S --noconfirm grub efibootmgr
grub-install --target=arm64-efi --efi-directory=/boot --bootloader-id=GRUB --removable
grub-mkconfig -o /boot/grub/grub.cfg

# Prepare Snapper
snapper -c root create-config /
rm -rf /.snapshots
mkdir /.snapshots
EOF

# --- 7️⃣ Finalize ---
umount -R /mnt
echo "---------------------------------------------------"
echo "INSTALL COMPLETE! Unmount ISO and reboot."
