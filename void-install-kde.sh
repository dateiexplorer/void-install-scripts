#!/bin/bash
#-
# This script is an additional script to the void-installer from
# https://github.com/dateiexplorer/void-mklive.
#
# It installs the KDE Plasma desktop environment and set up all
# necessary services to run Plasma flawless.
#-

# Check if running script with root permissions.
if [ "$(id -u)" -ne 0 ]; then
    error "script must run as root"
    return 1
fi


#
# main()
#
# Print welcome banner
DIALOG --title "${BOLD}${RED} Install KDE Plasma ... ${RESET}" --msgbox "\n
Welcome to the KDE Plasma installation for Void Linux. This script installs \
the basic KDE Plasma desktop environment. You can choose some additional
software packages to install.\n\n
If you are find issues or in trouble visit please visit the GitHub repository.\n\n
${BOLD}https://github.com/dateiexplorer/void-install-scripts${RESET}\n\n" 16 80

DIALOG --yesno "Do you want to procceed installing KDE plasma?" ${YESNOSIZE}
if [ $? -ne 0 ]; then
    return
fi


TITLE="Check $LOG for details ..."

# Copy the DNS configuration to still download new packages inside chroot
cp /etc/resolv.conf $TARGETDIR/etc/

INFOBOX "Update packages ..." 4 60
chroot $TARGETDIR xbps-install -Suy >$LOG 2>&1

# Install KDE Plasma itself
INFOBOX "Install KDE Plasma ..." 4 60
cat <<KDE_EOF | chroot $TARGETDIR /bin/bash >$LOG 2>&1
xbps-install -Sy xorg kde5 kde5-baseapps sddm mugshot spectacle \
    kwalletmanager libappindicator vim
KDE_EOF

# Font configuration
INFOBOX "Configure fonts ..." 4 60
chroot $TARGETDIR ln -s /usr/share/fontconfig/conf.avail/70-no-bitmaps.conf \
    /etc/fonts/conf.d/ >$LOG 2>&1
chroot $TARGETDIR xbps-reconfigure -f fontconfig >$LOG 2>&1

# Configure services
INFOBOX "Configure services ..." 4 60
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

# Configure SDDM service
ln -s /etc/sv/sddm /etc/runit/runsvdir/default/
SERVICES_EOF


