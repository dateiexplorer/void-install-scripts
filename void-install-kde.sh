#!/bin/bash
#-
# Copyright (c) 2022 Justus Röderer <justus.roederer@firebeard.de>.
#               2012-2015 Juan Romero Pardines <xtraeme@gmail.com>.
#               2012 Dave Elusive <davehome@redthumb.info.tm>.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#-
#
# This code reuses some functionalities from the void-mklive repository hosted
# on GitHub: https://github.com/void-linux/void-mklive.

###############################################################################
# CONFIGURATION
###############################################################################
# Change the Variable below to configure your installation.

# Change the hostname of your computer.
# This will also change the name under which the computer is reachable in your
# local network.
: "${HOST:=void}"

# Change the root password.
: "${ROOTPASSWD:=root}"

# Add a new user with the information below.
: "${USERNAME:=Void User}"
: "${USERLOGIN:=user}"
: "${USERPASSWD:=user}"
: "${USERGROUPS:=wheel,floppy,lp,audio,video,cdrom,optical,storage,network,
xbuilder,lpadmin}"

# Setup repository and architecture.
: "${REPO:=https://alpha.de.repo.voidlinux.org/current}"
: "${ARCH:=x86_64}"

# Change timezone.
: "${TIMEZONE:=Europe/Berlin}"

# Change locales.
: "${LOCALE:=de_DE.UTF-8}"

# Setup partitions
: "${DISK:=/dev/sda}"
: "${BOOTPARTITION:=/dev/sda1}"
: "${SWAPPARTITION:=/dev/sda2}"
: "${ROOTPARTITION:=/dev/sda3}"

: "${BOOTPARTITIONSIZE:=+500M}"
: "${SWAPPARTITIONSIZE:=+512M}"

###############################################################################
# INTERNAL VARIABLES
###############################################################################

# Directory where the new root system should be installed.
TARGETDIR=/mnt
# File where the installation log should be write. 
LOG=/dev/tty8
# Location of the fstab for the new installation.
TARGET_FSTAB=$TARGETDIR/etc/fstab

# Colors for bash shell
RESET="\033[m"
WHITE="\033[1m"
GREEN="\033[32m"
RED="\033[33m"

###############################################################################
# HELPER FUNCTIONS
###############################################################################

# Print an information message.
info() {
    printf "$WHITE$@\n$RESET"
}

# Print a success message.
success() {
    printf "$GREEN$@\n$RESET"
}

# Print an error message.
error() {
    printf "$RED$@\n$RESET"
}

# Print a fatal message and exit the script.
fatal() {
    error "FATAL: $@"
    exit 1
}

# Test if the network is reachable.
# Returns 1 if network is reachable, otherwise the script will be terminated.
test_network() {
    # Pick a peace of data to download to ensure that a network connection is
    # available.
    local _file="http://alpha.de.repo.voidlinux.org/live/xtraeme.asc"
    
    # Download with XBPS, remove it directly afterwards
    xbps-uhelper fetch "$file" >$LOG 2>&1 || rm -f xtraeme.asc

    # If next error `$?` is 0, no error detected. Network is reachable.
    if [ $? -eq 0 ]; then
        return 1
    fi
    fatal "Network is unreachable, please set it up proberly."
}

# Return the UUID of a specific disk or partition.
get_uuid() {
    echo "$(blkid -o value -s UUID "$1")"
}

###############################################################################
# RUN SCRIPT...
###############################################################################
# Check if running script with root permissions.

if [ "$(id -u)" -ne 0 ]; then
    fatal "Must be run with root permissions. Exiting..."
fi

# Check if network is reachable.
test_network

# Print welcome banner.
cat <<WELCOME_EOF
###############################################################################
Current configuration:
  Hostname: ${HOST}
  Root password: ${ROOTPASSWD}
  
  Repository: ${REPO}
  Architecture: ${ARCH}

  User:
    Name: ${USERNAME}
    Login name: ${USERLOGIN}
    Password: ${USERPASSWD}
    Groups: ${USERGROUPS}

  Timezone: ${TIMEZONE}
  Locale: ${LOCALE}

  Partitioning on disk ${DISK}:
    ${BOOTPARTITION} BOOT vfat ${BOOTPARTITIONSIZE} EFI-Bootloader
    ${SWAPPARTITION} SWAP swap ${SWAPPARTITIONSIZE} Swap-Partition
    ${ROOTPARTITION} ROOT btrfs Linux-Filesystem

If you want to change the configuration open the script and change the
corresponding variables.
###############################################################################
WELCOME_EOF

read -p "Want you proceed with this configuration? [y/N] " answer
if ! [[ $answer == [yY]* ]]; then
    echo "Aborted"
    exit
fi

cat <<INFO_EOF
Okay, I will install your system now. This will take a while.
Don't turn off your computer or disconnect it from the internet.
INFO_EOF

###############################################################################
# PARTITIONING
###############################################################################
# Partioning filesystem, e.g.
# /dev/sda1 500M EFI-System
# /dev/sda2 ..   Linux-Swap
# /dev/sda3 ..   Linux-Dateisystem
info "Partitioning disks..."
cat <<PARTITIONING_EOF | fdisk "${DISK}" >$LOG 2>&1
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
w
PARTITIONING_EOF

###############################################################################
# FILESYSTEM
###############################################################################
info "Configure filesystem..."
mkfs.vfat -F 32 -n "BOOT" "${BOOTPARTITION}" >$LOG 2>&1
mkfs.btrfs -L "ROOT" "${ROOTPARTITION}" >$LOG 2>&1

mkswap -L "SWAP" "${SWAPPARTITION}" >$LOG 2>&1
swapon "${SWAPPARTITION}" >$LOG 2>&1

###############################################################################
# INSTALL BASESYSTEM
###############################################################################
info "Install basesystem..."

# Create a new root
mount "${ROOTPARTITION}" $TARGETDIR >$LOG 2>&1
mkdir -p $TARGETDIR/boot/efi
mount "${BOOTPARTITION}" $TARGETDIR/boot/efi >$LOG 2>&1

# Copy RSA keys from installation medium to the target root directory
mkdir -p $TARGETDIR/var/db/xbps/keys
cp /var/db/xbps/keys/* $TARGETDIR/var/db/xbps/keys/

# Base installation via XBPS
XBPS_ARCH="${ARCH}" xbps-install -Sy -r $TARGETDIR -R "${REPO}" \
    base-system >$LOG 2>&1

# Mount pseudo-filesystems needed for chroot
mount --rbind /sys $TARGETDIR/sys && mount --make-rslave $TARGETDIR/sys
mount --rbind /dev $TARGETDIR/dev && mount --make-rslave $TARGETDIR/dev
mount --rbind /proc $TARGETDIR/proc && mount --make-rslave $TARGETDIR/proc

# Copy the DNS configuration to still download new packages inside chroot
cp /etc/resolv.conf $TARGETDIR/etc/

###############################################################################
# DO CONFIGURATION
###############################################################################

# Hostname
info "Set hostname..."
chroot $TARGETDIR hostname "${HOST}"
echo "${HOST}" > $TARGETDIR/etc/hostname

# Timezone
info "Set timezone..."
chroot $TARGETDIR ln -sf /usr/share/zoneinfo/"${TIMEZONE}" /etc/localtime \
    >$LOG 2>&1

# Generate locales
info "Generate locales..."
sed -i "/${LOCALE}/s/^#//g" $TARGETDIR/etc/default/libc-locales
chroot $TARGETDIR xbps-reconfigure -f glibc-locales >$LOG 2>&1

# Generate fstab
info "Generate fstab..."
echo "UUID=$(get_uuid ${SWAPPARTITION}) none swap sw 0 0" >>$TARGET_FSTAB
echo "UUID=$(get_uuid ${ROOTPARTITION}) / btrfs defaults 0 1" >>$TARGET_FSTAB
echo "UUID=$(get_uuid ${BOOTPARTITION}) /boot/efi vfat defaults 0 2" \
    >>$TARGET_FSTAB

###############################################################################
# CONFIGURE SERVICES
###############################################################################
info "Configure services..."
cat <<SERVICES_EOF | chroot $TARGETDIR /bin/bash >$LOG 2>&1
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
SERVICES_EOF

# Configure sudo
info "Configure sudo..."
echo "%wheel ALL=(ALL) ALL" > $TARGETDIR/etc/sudoers.d/wheel
chmod 440 $TARGETDIR/etc/sudoers.d/wheel

# Font configuration
info "Configure fonts..."
chroot $TARGETDIR ln -s /usr/share/fontconfig/conf.avail/70-no-bitmaps.conf \
    /etc/fonts/conf.d/ >$LOG 2>&1
chroot $TARGETDIR xbps-reconfigure -f fontconfig >$LOG 2>&1

# Set new root password
info "Set root password..."
echo "root:${ROOTPASSWD}" | chpasswd -R $TARGETDIR -c SHA512

# Add user
info "Add user..."
useradd -R $TARGETDIR -m -G "${USERGROUPS}" -c "${USERNAME}" "${USERLOGIN}" \
    >$LOG 2>&1
echo "${USERLOGIN}:${USERPASSWD}" | chpasswd -R $TARGETDIR -c SHA512

###############################################################################
# GRUB BOOTLOADER
###############################################################################
# Install grub bootloader
info "Install GRUB bootloader..."
chroot $TARGETDIR xbps-install -Sy grub-${ARCH}-efi >$LOG 2>&1

# Add --no-nvram because of error "EFI variables are not available"
chroot $TARGETDIR grub-install --no-nvram --target=${ARCH}-efi \
    --efi-directory=/boot/efi >$LOG 2>&1

# Finilazation
chroot $TARGETDIR xbps-reconfigure -fa >$LOG 2>&1

###############################################################################
# KDE5 PLASMA
###############################################################################
info "Install kde5 plasma..."
cat <<KDE_EOF | chroot $TARGETDIR /bin/bash >$LOG 2>&1
xbps-install -Sy xorg kde5 kde5-baseapps sddm mugshot spectacle \
    kwalletmanager libappindicator vim

# Configure SDDM service
ln -s /etc/sv/sddm /etc/runit/runsvdir/default/

# Add some programs
# xbps-install -Sy firefox firefox-18n-de keepassxc krdc krita libreoffice \
#     libreoffice-i18n-de musescore nextcloud-client nextcloud-client-dolphin \
#     obs okular openjdk11-bin openvpn python3-pip scrcpy texlive-bin \
#     thunderbird thunderbrid-i18n-de virtualbox-ose vlc vscode wireshark \
#     wireshark-qt yakuake yt-dlp git gimp

exit
KDE_EOF

###############################################################################
# COMPLETE SETUP
###############################################################################
success "Installation completed."
cat <<MESSAGE_EOF
###############################################################################
You're now logged in as root in your new system and can do further
configurations. To reboot the system type "exit".
###############################################################################
MESSAGE_EOF

# Change into installation to do further configuration.
PS1='# ' chroot $TARGETDIR /bin/bash

# If exit from the chroot environment restart the system.
shutdown -r now



