#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "This script requires root privileges. Restarting with sudo..."
  exec sudo "$0" "$@"
fi

install_pipwn() {
  if [ -d /boot/firmware/PPPwn ]; then
    echo "Cleaning up previous installation..."
    systemctl stop pipwn 2>/dev/null || true
    systemctl stop pppoe 2>/dev/null || true
    systemctl stop dtlink 2>/dev/null || true
    systemctl stop devboot 2>/dev/null || true
    rm -rf /boot/firmware/PPPwn
  fi
  
  apt update
  apt install wget unzip -y
  
  echo "Downloading latest version..."
  cd /tmp
  wget -q https://github.com/mariozelaschi/PI-Pwn/archive/refs/heads/main.zip -O pipwn.zip
  unzip -q pipwn.zip
  mkdir -p /boot/firmware/
  cp -r PI-Pwn-main/PPPwn /boot/firmware/
  rm -rf PI-Pwn-main pipwn.zip
  
  echo "Starting installation..."
  cd /boot/firmware/PPPwn
  chmod +x *.sh pppwn7 pppwn11 pppwn64 2>/dev/null
  bash install.sh
}

uninstall_pipwn() {
  echo "Uninstalling PI-Pwn..."
  
  systemctl stop pipwn 2>/dev/null || true
  systemctl stop pppoe 2>/dev/null || true
  systemctl stop dtlink 2>/dev/null || true
  systemctl stop devboot 2>/dev/null || true
  
  systemctl disable pipwn 2>/dev/null || true
  systemctl disable pppoe 2>/dev/null || true
  systemctl disable dtlink 2>/dev/null || true
  systemctl disable devboot 2>/dev/null || true
  
  rm -f /etc/systemd/system/pipwn.service
  rm -f /etc/systemd/system/pppoe.service
  rm -f /etc/systemd/system/dtlink.service
  rm -f /etc/systemd/system/devboot.service
  systemctl daemon-reload
  
  rm -f /etc/dnsmasq.d/99-pppwn.conf
  rm -f /etc/dnsmasq.d/99-pppwn-blocklist.conf
  rm -f /etc/udev/rules.d/99-pwnmnt.rules
  rm -f /etc/ppp/pap-secrets
  rm -f /etc/ppp/pppoe-server-options
  
  if grep -q "www-data.*NOPASSWD.*ALL" /etc/sudoers 2>/dev/null; then
    sed -i '/^www-data.*NOPASSWD.*ALL$/d' /etc/sudoers
  fi
  
  systemctl reload-or-restart dnsmasq 2>/dev/null || true
  udevadm control --reload 2>/dev/null || true
  
  rm -rf /boot/firmware/PPPwn
  rm -rf /media/pwndrives
  
  if [ -f /usr/lib/systemd/system/systemd-udevd.service ]; then
    sed -i '/^MountFlags=shared$/d' /usr/lib/systemd/system/systemd-udevd.service
  fi
  
  if [ -f /boot/firmware/config.txt ] && grep -q "^dtoverlay=dwc2" /boot/firmware/config.txt 2>/dev/null; then
    sed -i '/^dtoverlay=dwc2$/d' /boot/firmware/config.txt
  fi
  
  rm -f /etc/nginx/sites-enabled/pipwn
  rm -f /etc/nginx/sites-available/pipwn
  systemctl reload nginx 2>/dev/null || true
  
  echo ""
  echo "PI-Pwn has been uninstalled successfully"
  echo ""
  echo "The following packages were installed by PI-Pwn and can be removed manually if not needed:"
  echo "  - pppoe"
  echo "  - dnsmasq (WARNING: DO NOT remove if you have Pi-hole installed!)"
  echo "  - iptables"
  echo "  - nginx"
  echo "  - php-fpm"
  echo "  - nmap"
  echo "  - at"
  echo "  - net-tools"
  echo "  - python3-scapy (if installed)"
  echo "  - vsftpd (if installed)"
  echo "  - samba (if installed)"
  echo ""
}

echo "PI-Pwn Setup Script"
echo "==================="
echo ""
echo "1) Install PI-Pwn"
echo "2) Uninstall PI-Pwn"
echo ""
read -p "Select option (1 or 2): " choice

case $choice in
  1)
    echo ""
    install_pipwn
    ;;
    
  2)
    echo ""
    uninstall_pipwn
    echo ""
    read -p "Reboot now? (Y|N): " reboot
    case $reboot in
      [Yy]*)
        reboot
        ;;
      *)
        echo "Please reboot manually to complete uninstallation"
        ;;
    esac
    ;;
    
  *)
    echo "Invalid option"
    exit 1
    ;;
esac
