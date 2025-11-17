#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo -e "\033[33mThis script requires root privileges. Restarting with sudo...\033[0m"
  exec sudo "$0" "$@"
fi

install_pipwn() {
  if [ -d /boot/firmware/PPPwn ]; then
    echo -e "\033[33mCleaning up previous installation...\033[0m"
    systemctl stop pipwn 2>/dev/null || true
    systemctl stop pppoe 2>/dev/null || true
    systemctl stop dtlink 2>/dev/null || true
    systemctl stop devboot 2>/dev/null || true
    rm -rf /boot/firmware/PPPwn
  fi
  
  apt update
  if apt list --upgradable 2>/dev/null | grep -q upgradable; then
    echo ""
    read -p "$(printf '\033[36mUpgradeable packages found. Upgrade now? (Y|N): \033[0m')" upgrade
    case $upgrade in
      [Yy]*)
        apt upgrade -y
        echo -e "\033[32mPackages upgraded. Restarting setup script...\033[0m"
        sleep 2
        exec bash "$0" "$@"
        ;;
      *)
        echo -e "\033[33mContinuing with installation...\033[0m"
        ;;
    esac
  fi
  apt install wget unzip -y
  
  echo -e "\033[33mDownloading latest version...\033[0m"
  cd /tmp
  wget -q https://github.com/mariozelaschi/PI-Pwn/archive/refs/heads/main.zip -O pipwn.zip
  unzip -q pipwn.zip
  mkdir -p /boot/firmware/
  cp -r PI-Pwn-main/PPPwn /boot/firmware/
  rm -rf PI-Pwn-main pipwn.zip
  
  echo -e "\033[33mStarting installation...\033[0m"
  cd /boot/firmware/PPPwn
  chmod +x *.sh pppwn7 pppwn11 pppwn64 2>/dev/null
  bash install.sh
}

uninstall_pipwn() {
  echo -e "\033[33mUninstalling PI-Pwn...\033[0m"
  
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
  if [ -f /etc/nginx/sites-available/default.disabled ]; then
    sudo mv /etc/nginx/sites-available/default.disabled /etc/nginx/sites-enabled/default 2>/dev/null || true
  fi
  systemctl reload nginx 2>/dev/null || true
  
  echo ""
  echo -e "\033[32mPI-Pwn has been uninstalled successfully\033[0m"
  echo ""
  echo -e "\033[33mThe following packages were installed by PI-Pwn and can be removed manually if not needed (WARNING: some of these packages may be in use by other active services, such as dnsmasq or nginx):\033[0m"
  echo -e "  - pppoe\n  - dnsmasq\n  - iptables\n  - nginx\n  - php-fpm\n  - nmap\n  - at\n  - net-tools\n  - python3-scapy (if installed)\n  - vsftpd (if installed)\n  - samba (if installed)"
  echo ""
}

echo ""
echo -e "\033[36mPI-Pwn Setup Script\033[0m"
echo -e "\033[36m===================\033[0m"
echo ""
echo -e "\033[33m1) Install PI-Pwn\033[0m"
echo -e "\033[33m2) Uninstall PI-Pwn\033[0m"
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
        echo -e "\033[33mPlease reboot manually to complete uninstallation\033[0m"
        ;;
    esac
  ;;
    
  *)
    echo -e "\033[31mInvalid option\033[0m"
    exit 1
    ;;
esac
