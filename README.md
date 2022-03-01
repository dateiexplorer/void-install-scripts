# void-install-scripts

Scripts to automate the installing process for void.

## void-install-kde.sh

The script installs a basic void system with the kde plasma desktop
environment.

# Usage

Download the void ISO image from the
[official download site](https://voidlinux.org/download/).

To install the ISO image on a bootable USB stick, you can use the `dd` command
line tool with root permissions.

```
dd if=/path/to/iso of=/path/to/usb/device bs=4M conv=sync status=progress
```

First select the UEFI-Boot entry from the install ISO image.
Perform a login and download the files from GitHub, then set execute
permissions for the script and finally run it.
Make sure that you have root permissions to do that.

```sh
# Install tool to download files from command line
xbps-install -S wget

# Download file from this Repository
wget https://raw.githubusercontent.com/dateiexplorer/void-install-scripts/main/void-install-kde.sh

# Make script executable
chmod 744 void-install-kde.sh

# Execute script
./void-install-kde.sh
```

If you need to specify the user settings, passwords or even
partitioning change the corresponding variable in the script.
