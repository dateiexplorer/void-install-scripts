#!/bin/bash

################################################################################
# CONFIGURATION                                                                #
################################################################################
# Change the Variable below to configure your installation.

# Change the hostname of your computer.
# This will also change the name under which the computer is reachable in your
# local network.
: "${HOSTNAME:=void}"

# Change the root password.
: "${ROOTPASSWD:=root}"

# Setup user settings.
: "${USERNAME:=user}"
: "${USERPASSWD:=user}"
: "${USERGROUPS:=wheel,floppy,lp,audio,video,cdrom,optical,storage,network,\
xbuilder,lpadmin}"

# Setup repository and architecture.
: "${REPO:=https://alpha.de.repo.voidlinux.org/current}"
: "${ARCH:=x86_64}"

# Change timezone.
: "${TIMEZONE:=Europe/Berlin}"

# Change locales.
: "${LOCALES:=de_DE}"

# Change partitions.
: "${DISK:=/dev/sda}"
: "${BOOTPARTITION:=/dev/sda1}"
: "${SWAPPARTITION:=/dev/sda2}"
: "${HOMEPARTITION:=/dev/sda3}"

: "${BOOTPARTITIONSIZE:=+500M}"
: "${SWAPPARTITIONSIZE:=+512M}"

################################################################################
# PARTITIONING                                                                 #
################################################################################
# Partioning filesystem
# /dev/sda1 500M EFI-System
# /dev/sda2 ..   Linux-Swap
# /dev/sda3 ..   Linux-Dateisystem

echo "
g
n


${BOOTPARTITIONSIZE}
t

1
n


${SWAPPARTITIONSIZE}
t

19
n



p
w" | fdisk "${DISK}"

mkfs.vfat -F 32 -n "BOOT" "${BOOTPARTITION}"
mkfs.btrfs -L "ROOT" "${HOMEPARTITION}"

mkswap -L "SWAP" "${SWAPPARTITION}"
swapon "${SWAPPARTITION}"

################################################################################
# INSTALL BASESYSTEM                                                           #
################################################################################
# Create a New Root
mount "${HOMEPARTITION}" /mnt
mkdir -p /mnt/boot/efi
mount "${BOOTPARTITION}" /mnt/boot/efi

# Copy RSA keys from installation medium to the target root directory
mkdir -p /mnt/var/db/xbps/keys
cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/

# Base installation via XBPS
XBPS_ARCH="${ARCH}" xbps-install -Sy -r /mnt -R "${REPO}" base-system

# Mount pseudo-filesystems needed for chroot
mount --rbind /sys /mnt/sys && mount --make-rslave /mnt/sys
mount --rbind /dev /mnt/dev && mount --make-rslave /mnt/dev
mount --rbind /proc /mnt/proc && mount --make-rslave /mnt/proc

# Copy the DNS configuration to still download new packages inside chroot
cp /etc/resolv.conf /mnt/etc/

# Chroot into new installation
cat <<SETUP_EOF | PS1='(chroot) # ' chroot /mnt /bin/bash

################################################################################
# DO CONFIGURATION                                                             #
################################################################################

# Hostname
echo "${HOSTNAME}" > /etc/hostname

# Timezone
ln -sf /usr/share/zoneinfo/"${TIMEZONE}" /etc/localtime

# Generate locales
sed -i "/${LOCALES}.UTF-8/s/^#//g" /etc/default/libc-locales

xbps-reconfigure -f glibc-locales

# Create /etc/fstab
disk_to_uuid() {
    blkid_line="$(blkid "$1")"
    tmp="${blkid_line#*' UUID="'}"
    uuid="${tmp%%\"*}"
    echo "${uuid}"
}

extract_uuid() {
    uuid="$(disk_to_uuid "$1")"
    end_of_line="$2"
    full_line="UUID=${uuid} ${end_of_line}"
    echo "$full_line"
}

extract_uuid "${SWAPPARTITION}" "none swap sw 0 0" >> /etc/fstab
extract_uuid "${HOMEPARTITION}" "/ btrfs defaults 0 1" >> /etc/fstab
extract_uuid "${BOOTPARTITION}" "/boot/efi vfat defaults 0 2" >> /etc/fstab
echo "tmpfs /tmp tmpfs defaults,nosuid,nodev 0 0" >> /etc/fstab

# Configure sudo
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

################################################################################
# GRUB BOOTLOADER                                                              #
################################################################################
# Install grub bootloader
xbps-install -Sy grub-${ARCH}-efi

# Add --no-nvram because of error "EFI variables are not available"
grub-install --no-nvram --target=${ARCH}-efi --efi-directory=/boot/efi

# Finalization
xbps-reconfigure -fa

################################################################################
# INSTALL KDE5                                                                 #
################################################################################
# Configure services
xbps-install -Sy elogind NetworkManager tlp bluez alsa-utils \
    alsa-plugins-pulseaudio pulseaudio sndio cups cups-filters lm_sensors

ln -s /etc/sv/dbus /etc/runit/runsvdir/default/
ln -s /etc/sv/elogind /etc/runit/runsvdir/default/
ln -s /etc/sv/NetworkManager /etc/runit/runsvdir/default/
ln -s /etc/sv/tlp /etc/runit/runsvdir/default/
ln -s /etc/sv/bluetoothd /etc/runit/runsvdir/default/
ln -s /etc/sv/alsa /etc/runit/runsvdir/default/
ln -s /etc/sv/sndiod /etc/runit/runsvdir/default/
ln -s /etc/sv/cupsd /etc/runit/runsvdir/default/
ln -s /etc/sv/fancontrol /etc/runit/runsvdir/default/

# Font configuration
ln -s /usr/share/fontconfig/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d/
xbps-reconfigure -f fontconfig

# Set new root password
echo "root:${ROOTPASSWD}" | chpasswd -c SHA512

# Add user
useradd -m -G "${USERGROUPS}" "${USERNAME}"
echo "${USERNAME}:${USERPASSWD}" | chpasswd -c SHA512

# Install other apps
xbps-install -Sy xorg kde5 kde5-baseapps sddm mugshot spectacle kwalletmanager \
    libappindicator vim

# Configure SDDM service
ln -s /etc/sv/sddm /etc/runit/runsvdir/default/

################################################################################
# Add some programs
# xbps-install -Sy firefox firefox-18n-de keepassxc krdc krita libreoffice \
#     libreoffice-i18n-de musescore nextcloud-client nextcloud-client-dolphin \
#     obs okular openjdk11-bin openvpn python3-pip scrcpy texlive-bin \
#     thunderbird thunderbrid-i18n-de virtualbox-ose vlc vscode wireshark \
#     wireshark-qt yakuake yt-dlp git gimp

exit
SETUP_EOF

shutdown -r now



