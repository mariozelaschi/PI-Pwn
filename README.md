# Pi-Pwn

- [Features](#features)
- [Supported Firmware](#supported-firmware)
- [Tested Hardware](#tested-hardware)
  - [Raspberry Pi Models](#raspberry-pi-models)
  - [Other Compatible Boards](#other-compatible-boards)
- [Installation](#installation)
  - [Prerequisites](#prerequisites)
  - [Setup Instructions](#setup-instructions)
  - [Configuration](#configuration)
- [PS4 Configuration](#ps4-configuration)
  - [GoldHEN Setup](#goldhen-setup)
- [Usage](#usage)
  - [How It Works](#how-it-works)
  - [Web Interface](#web-interface)
- [Advanced Features](#advanced-features)
  - [Console FTP and Binloader Access](#console-ftp-and-binloader-access)
  - [USB Passthrough Drive](#usb-passthrough-drive)
  - [Rest Mode Support](#rest-mode-support)
  - [Pi File Access](#pi-file-access)
    - [FTP Access](#ftp-access)
    - [Samba Access](#samba-access)
- [Updating Pi-Pwn](#updating-pi-pwn)
- [Configuration Options](#configuration-options)
- [Credits](#credits)

This is a fork of the original [stooged/PI-Pwn](https://github.com/stooged/PI-Pwn), which has not been updated for some time. This version adds compatibility with the latest Raspberry Pi OS Debian 13 (Trixie) and includes updated GoldHEN and stage2 payloads.

Pi-Pwn is an automated setup script for [PPPwn](https://github.com/TheOfficialFloW/PPPwn) and [PPPwn_cpp](https://github.com/xfangfang/PPPwn_cpp) on Raspberry Pi and compatible single-board computers. It provides automated PS4 exploitation with internet connectivity support, USB passthrough capabilities, and a web-based control interface.

## Features

- Automated exploit execution with continuous retry until successful
- Support for [GoldHEN](https://github.com/GoldHEN/GoldHEN) payloads
- Optional internet access for the console after exploitation
- Web interface for configuration and control
- USB drive passthrough to console
- Built-in DNS blocker to prevent system updates
- FTP, klog, and binloader server access forwarding
- Rest mode support with GoldHEN detection
- LED indicators for exploit progress (model-dependent)

## Supported Firmware

- 9.00
- 9.60
- 10.00, 10.01
- 10.50, 10.70, 10.71
- 11.00

## Tested Hardware

Pi-Pwn has been tested on the following models, but is not limited to them:

### Raspberry Pi Models

- [Raspberry Pi 5](https://www.raspberrypi.com/products/raspberry-pi-5/)
- [Raspberry Pi 4 Model B](https://www.raspberrypi.com/products/raspberry-pi-4-model-b/)
- [Raspberry Pi 400](https://www.raspberrypi.com/products/raspberry-pi-400/)
- [Raspberry Pi 3B+](https://www.raspberrypi.com/products/raspberry-pi-3-model-b-plus/)
- [Raspberry Pi 2 Model B](https://www.raspberrypi.com/products/raspberry-pi-2-model-b/)
- [Raspberry Pi Zero 2 W](https://www.raspberrypi.com/products/raspberry-pi-zero-2-w/) (requires USB to Ethernet adapter)
- [Raspberry Pi Zero W](https://www.raspberrypi.com/products/raspberry-pi-zero-w/) (requires USB to Ethernet adapter)

### Other Compatible Boards

- [ROCK Pi 4C Plus](https://wiki.radxa.com/Rock4/4cplus) with [Armbian](https://imola.armbian.com/archive/rockpi-4cplus/archive/Armbian_23.11.1_Rockpi-4cplus_bookworm_current_6.1.63.img.xz)
- [BIGTREETECH BTT Pi V1.2](https://biqu.equipment/products/bigtreetech-btt-pi-v1-2) with [Armbian minimal](https://www.armbian.com/bigtreetech-cb1/)
- [pcDuino3b](https://www.linksprite.com/linksprite-pcduino3/) with [Armbian](https://imola.armbian.com/archive/pcduino3nano/archive/Armbian_5.38_Pcduino3nano_Debian_jessie_next_4.14.14.7z)

## Installation

### Prerequisites

- Raspberry Pi or compatible board
- MicroSD card (8GB or larger recommended)
- [Raspberry Pi OS Lite](https://www.raspberrypi.com/software/operating-systems/) or [Armbian CLI/Minimal](https://www.armbian.com/)
- Ethernet cable to connect Pi to PS4
- Internet connection for initial setup

### Setup Instructions

1. Flash Raspberry Pi OS Lite or Armbian CLI/Minimal to your SD card
2. Insert the SD card into your Raspberry Pi and boot it
3. Connect the Pi to the internet (via Ethernet or WiFi)
4. Run the following commands:



```bash
sudo apt update
sudo apt install git -y
sudo rm -f -r PI-Pwn
sudo systemctl stop pipwn
git clone https://github.com/mariozelaschi/PI-Pwn
sudo mkdir -p /boot/firmware/
cd PI-Pwn
sudo cp -r PPPwn /boot/firmware/
cd /boot/firmware/PPPwn
sudo chmod 777 *
sudo bash install.sh
```

### Configuration

During installation, you'll be prompted to configure several options:

- **Python PPPwn Support**: Option to install Python3 and Scapy for using the original Python version of PPPwn (slower but may work better on some setups)
- **FTP Server**: Optional FTP server installation for easy file access to the PPPwn folder
  - Requires setting the root account password for login
  - Uses standard ports 21 (command) and 20 (data)
- **Samba Share**: Optional network share setup for accessing PPPwn files
  - No authentication required
  - Accessible at `\\pppwn.local\pppwn` (Windows) or `smb://pppwn.local/pppwn` (macOS/Linux)
- **USB Ethernet Adapter**: Select "yes" if using a USB to Ethernet adapter for the console connection
  - If your Pi has a built-in Ethernet port and you're using a USB adapter, the interface will typically be `eth1`
  - For boards like Pi Zero 2, the interface will be `eth0`
- **PPPoE Credentials**: Configure username and password for console connection (default: `ppp`/`ppp`)
  - Must match on both Pi-Pwn and PS4 if enabling internet access
- **Console Internet Access**: Enable internet connectivity for the PS4 after exploitation
- **Firmware Version**: Select your PS4's firmware version (9.00 through 11.00)
- **Timeout Setting**: Time in minutes (1-5) before restarting PPPwn if it hangs
- **Network Interface**: The LAN interface connected to the console (auto-detected, usually `eth0` or `eth1`)
- **Original IPv6 Address**: Option to use the original PPPwn IPv6 (`fe80::4141:4141:4141:4141`)
- **USB Drive Passthrough**: Enable USB drive mounting to console (Pi 4/400/5 only)
- **Hostname**: Set a custom hostname for the Pi (default: `pppwn`) - affects web interface URL
- **Additional Options**:
  - GoldHEN detection for rest mode support
  - Console shutdown detection and auto-restart
  - Verbose logging for debugging
  - Automatic Pi shutdown after successful exploit
  - DNS blocker configuration

After installation completes, the Pi will reboot and PPPwn will start automatically.

## PS4 Configuration

Configure your PS4 to connect via PPPoE:

1. Navigate to **Settings** → **Network** → **Set Up Internet Connection**
2. Select **Use a LAN Cable**
3. Choose **Custom** setup
4. Select **PPPoE** for **IP Address Settings**
5. Enter PPPoE credentials:
   - **User ID**: `ppp` (or the username you configured during installation)
   - **Password**: `ppp` (or the password you configured during installation)
   - **Note**: If internet access is enabled, these credentials must match those set during Pi-Pwn setup
6. Choose **Automatic** for **DNS Settings**
7. Choose **Automatic** for **MTU Settings**
8. Choose **Do Not Use** for **Proxy Server**

### GoldHEN Setup

For GoldHEN payloads:

1. Download the latest `goldhen.bin` from the official source: [https://ko-fi.com/sistro](https://ko-fi.com/sistro)
2. Place the `goldhen.bin` file on the root of a USB drive
3. Insert the USB drive into your PS4
4. Run the exploit
5. GoldHEN will be copied to the console's internal HDD after the first successful load
6. The USB drive is no longer required for subsequent boots
7. To update GoldHEN, repeat the process with the new version

**Note**: Always download GoldHEN from SiSTR0's official Ko-fi page to ensure you have the authentic, latest version.

## Usage

### How It Works

Once everything is configured and the Ethernet cable connects the Pi to the console:

1. Power on both the PS4 and Raspberry Pi
2. Wait on the PS4 home screen
3. The Pi will automatically attempt to exploit the console
4. The exploit may fail multiple times - this is normal behavior
5. The Pi will continuously retry until successful
6. After successful exploitation, the Pi will shut down (unless internet access is enabled)

No user interaction is required - the Pi handles the entire process automatically.

### Web Interface

Access the web control panel from:

- Your PS4 browser (when connected): `http://pppwn.local:8080` or `http://192.168.2.1:8080`
- Your PC browser (when Pi has internet access enabled): `http://pppwn.local:8080` or `http://{pi-ip-address}:8080`

**Note**: The default hostname is `pppwn` but can be customized during installation. If you changed the hostname, access the interface at `http://{your-hostname}.local:8080`. The `.local` domain resolution requires mDNS/Avahi to be running on your device.

From the web interface you can:

- Change configuration settings
- Select different firmware versions
- Send custom payloads
- Update Pi-Pwn
- Monitor exploit status
- Configure PPPoE credentials
- Set up WiFi connection

## Advanced Features

### Console FTP and Binloader Access

When internet access is enabled:

1. Connect the Pi to your home network via WiFi or a second Ethernet connection
2. Connect to the Pi's IP address from your PC
3. All requests will be automatically forwarded to the console's FTP, klog, and binloader servers
4. **Important**: Set your FTP client to **Active** mode (not passive)

### USB Passthrough Drive

Raspberry Pi 4, 400, and 5 models support USB drive passthrough:

1. Create a folder named `payloads` on the root of a USB flash drive
2. Insert the drive into the Raspberry Pi
3. Connect the Pi to the PS4 USB port using the USB-C connection
4. Enable "USB drive to console" in the Pi-Pwn configuration
5. The drive will be accessible from the PS4

**Power Note**: Most configurations work with a single USB-C cable. If experiencing power issues, use a USB Y cable to inject additional power.

### Rest Mode Support

To enable rest mode functionality:

1. Enable "Detect if GoldHEN is running" in Pi-Pwn options
2. If powering the Pi from the PS4 USB port, disable "Supply Power to USB Ports" in the console's rest mode settings
3. Ensure the PS4's PPPoE credentials match your Pi-Pwn configuration (default: `ppp`/`ppp`)

Pi-Pwn will check if GoldHEN is already loaded and skip the exploit process if it's running.

### Pi File Access

#### FTP Access

If you installed the FTP server during setup:

- **Server**: Pi's IP address
- **Ports**: 21 (command), 20 (data)
- **Credentials**: Root username and password (set during installation)
- **Path**: `/boot/firmware/PPPwn`
- **Note**: Can be installed later by re-running the installation script

#### Samba Access

If you configured the Samba share during setup:

- **Windows**: `\\pppwn.local\pppwn`
- **macOS/Linux**: `smb://pppwn.local/pppwn`
- **Credentials**: None (no authentication required)
- **Note**: Can be installed later by re-running the installation script


## Updating Pi-Pwn

There are three methods to update Pi-Pwn:

1. **Web Interface**: Click the update button in the web UI
2. **Reinstall Script**: Run the installation commands again to update to the latest version and reconfigure settings
3. **Manual Edit**: Remove the SD card, insert it into your computer, and edit files in the `PPPwn` folder at `/boot/firmware/PPPwn`

## Configuration Options

Access these options through the web interface or during installation:

- **Interface**: LAN interface on the Pi connected to the console (e.g., `eth0`, `eth1`)
- **Firmware Version**: PS4 firmware version to target
- **Time to Restart PPPwn if it Hangs**: Timeout in minutes (1-5) before restarting if the exploit hangs
- **LED Activity**: Enable LED indicators based on exploit progress (supported models only)
- **Use Python Version**: Force use of the original Python PPPwn by [TheOfficialFloW](https://github.com/TheOfficialFloW/PPPwn)
- **Use Original Source IPv6**: Use the original IPv6 address `fe80::4141:4141:4141:4141` (may increase exploit speed on some consoles)
- **Use USB Ethernet Adapter**: Enable if using a USB to Ethernet adapter for console connection
- **Detect if GoldHEN is Running**: Check if GoldHEN is already loaded and skip exploit if running (useful for rest mode)
- **Detect Console Shutdown**: Restart PPPwn if the connection to the console is lost
- **Enable Verbose PPPwn**: Show debug output to monitor exploit progress
- **Enable Console Internet Access**: Allow console internet connectivity after successful exploitation
- **Disable DNS Blocker**: Turn off DNS blocking for update and telemetry servers
- **Shutdown Pi After PWN**: Automatically shut down the Pi after successful exploitation
- **Enable USB Drive to Console**: Enable USB passthrough (supported models only)
- **Ports**: Comma-separated list of ports forwarded from Pi to console (supports single ports and ranges like `1000-1100`). Default: `2121,3232,9090,8080,12800,1337`
- **PPPoE Credentials**: Configure username and password for console connection (can be changed via web interface)
- **WiFi Settings**: Configure WiFi SSID and password for Pi internet connectivity (can be changed via web interface)

## Credits

Special thanks to [stooged](https://github.com/stooged) for the original [PI-Pwn](https://github.com/stooged/PI-Pwn) project that made this fork possible.

This project builds upon the exceptional work of:

- [TheOfficialFloW](https://github.com/TheOfficialFloW) - Original PPPwn exploit
- [xfangfang](https://github.com/xfangfang) - PPPwn C++ implementation
- [SiSTR0](https://github.com/SiSTR0) - GoldHEN development
- [Vortex](https://github.com/xvortex) - Community contributions
- [nn9dev](https://github.com/nn9dev) - Testing and support

And many other contributors who have made this project possible.
 