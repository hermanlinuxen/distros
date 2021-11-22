#!/bin/bash
# Not meant to be ran as script. Only for storing commands.
#########################
## Arch Linux           #
#########################
## Full-Disk Encryption #
## AppArmor & Firejail  #
## KDE PLasma & SDDM    #
#########################

loadkeys no

ls /sys/firmware/efi/efivars

timedatectl set-timezone Europe/Oslo
hwclock --systohc && hwclock --show
timedatectl set-ntp true

ping -c 3 -4 archlinux.org

parted /dev/sda -s -- mklabel gpt
parted /dev/sda -s -- unit mb
parted /dev/sda -s -- mkpart ESP fat32 1 551
parted /dev/sda -s -- mkpart primary ext4 551 -1
parted /dev/sda -s -- name 1 boot
parted /dev/sda -s -- name 2 root
parted /dev/sda -s -- set 1 ESP on
parted /dev/sda -s -- set 2 lvm on
parted /dev/sda -s -- print
parted /dev/sda -s -- quit

cryptsetup --verbose --cipher aes-xts-plain64 --key-size 512 --hash sha512 --use-urandom -y luksFormat /dev/sda2
cryptsetup luksOpen /dev/sda2 cryptroot

pvcreate /dev/mapper/cryptroot
vgcreate arch /dev/mapper/cryptroot
lvcreate -L 8G -n swap arch
lvcreate -l 100%FREE -n root arch

mkfs.vfat -F32 /dev/sda1
mkfs.ext4 /dev/mapper/arch-root
mkswap /dev/mapper/arch-swap

mount -t ext4 /dev/mapper/arch-root /mnt
mkdir -p /mnt/boot
mount -t vfat /dev/sda1 /mnt/boot
swapon /dev/mapper/arch-swap

pacstrap -i /mnt base base-devel linux linux-firmware linux-headers nano
nano -w /mnt/etc/pacman.conf # uncomment '#Color', #[multilib] and #Include=

genfstab -U -p /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash

localectl set-keymap no

ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc --utc

pacman -Sy noto-fonts-emoji
nano -w /etc/locale.gen # uncomment '#en_US.UTF-8 UTF-8' and 'en_US ISO-8859-1'
locale-gen

echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo 'LANGUAGE=en_US:en' >> /etc/locale.conf

echo 'KEYMAP=no' > /etc/vconsole.conf
echo 'FONT=eurlatgr' >> /etc/vconsole.conf

echo "arch" > /etc/hostname

echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1 localhost" >> /etc/hosts
echo "127.0.1.1 localhost.localdomain arch" >> /etc/hosts


pacman -S amd-ucode # replace 'amd' with 'intel' if intel CPU
nano -w /etc/mkinitcpio.conf # HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)
mkinitcpio -p linux

pacman -S grub efibootmgr efivar dosfstools
blkid | grep 'crypto_LUKS'
nano -w /etc/default/grub
#GRUB_CMDLINE_LINUX="cryptdevice=UUID=aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee:cryptroot root=/dev/mapper/arch-root"
#GRUB_CMDLINE_LINUX_DEFAULT="apparmor=1 security=apparmor"
#GRUB_ENABLE_CRYPTODISK=y
#GRUB_PRELOAD_MODULES="part_msdos part_gpt luks lvm"
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=LOOONIX
grub-mkconfig -o /boot/grub/grub.cfg

# Wayland:
pacman -S xorg-wayland xorg-server xorg-apps plasma-wayland-session

# x11:
pacman -S xorg-server xorg-apps

# AMDGPU:
sudo pacman -S mesa lib32-mesa xf86-video-amdgpu
# If PRO is needed: https://wiki.archlinux.org/title/AMDGPU_PRO

# Nvidia:
nvidia nvidia-settings nvidia-utils lib32-nvidia-utils

# All: 
pacman -S plasma-desktop kmenuedit konsole dolphin sddm sddm-kcm networkmanager plasma-nm wpa_supplicant wireless_tools iw file-roller unzip unrar gedit gimp vlc firefox git wget apparmor firejail bleachbit screenfetch bash-completion tor terminator

systemctl enable sddm.service
systemctl enable NetworkManager.service
systemctl enable tor.service
systemctl enable apparmor.service

nano -w /etc/X11/xorg.conf.d/00-keyboard.conf
# File must contain following for Norwegian key layout
Selection "ImputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "no"
        Option "XkbModel" "pc105"
        Option "XkbVariant" ",dvorak"
        Option "XkbOptions" "grp:win_space_toggle"
EndSection
# EOF


useradd -m -d /home/user -G users,wheel,audio -s /bin/bash herman
passwd herman
passwd root

EDITOR=nano visudo
# Change following: "%wheel ALL=(ALL) NOPASSWD: ALL"

exit
umount -R /mnt
reboot
