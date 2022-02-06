# void-install-scripts

Scripts to automate the installing process for void.

# Usage

Download the void ISO image from the
[official download site](https://voidlinux.org/download/).

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
