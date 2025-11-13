#!/bin/bash

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
    echo "Starting PI-Pwn installation..."
    echo ""
    
    sudo apt update
    sudo apt install wget unzip -y
    sudo systemctl stop pipwn 2>/dev/null
    sudo rm -rf /boot/firmware/PPPwn
    sudo mkdir -p /boot/firmware/
    cd /tmp
    wget -q https://github.com/mariozelaschi/PI-Pwn/archive/refs/heads/main.zip -O pipwn.zip
    unzip -q pipwn.zip
    sudo cp -r PI-Pwn-main/PPPwn /boot/firmware/
    rm -rf PI-Pwn-main pipwn.zip
    cd /boot/firmware/PPPwn
    sudo chmod +x *.sh pppwn7 pppwn11 pppwn64 2>/dev/null
    sudo bash install.sh
    ;;
    
  2)
    echo ""
    echo "Starting PI-Pwn uninstallation..."
    echo ""
    
    sudo systemctl stop pipwn 2>/dev/null
    sudo systemctl stop pppoe 2>/dev/null
    sudo systemctl stop dtlink 2>/dev/null
    sudo systemctl stop devboot 2>/dev/null
    
    sudo systemctl disable pipwn 2>/dev/null
    sudo systemctl disable pppoe 2>/dev/null
    sudo systemctl disable dtlink 2>/dev/null
    sudo systemctl disable devboot 2>/dev/null
    
    sudo rm -f /etc/systemd/system/pipwn.service
    sudo rm -f /etc/systemd/system/pppoe.service
    sudo rm -f /etc/systemd/system/dtlink.service
    sudo rm -f /etc/systemd/system/devboot.service
    
    sudo systemctl daemon-reload
    
    sudo rm -f /etc/dnsmasq.d/99-pppwn.conf
    sudo rm -f /etc/dnsmasq.more.conf
    sudo rm -f /etc/udev/rules.d/99-pwnmnt.rules
    sudo rm -f /etc/ppp/pap-secrets
    
    sudo systemctl reload-or-restart dnsmasq 2>/dev/null
    sudo udevadm control --reload 2>/dev/null
    
    sudo rm -rf /boot/firmware/PPPwn
    sudo rm -rf /media/pwndrives
    
    sudo sed -i '/www-data.*NOPASSWD.*ALL/d' /etc/sudoers
    sudo sed -i 's/^dtoverlay=dwc2$//g' /boot/firmware/config.txt
    sudo sed -i '/^$/d' /boot/firmware/config.txt
    
    OLDHOST=$(grep "192.168.2.1" /etc/dnsmasq.more.conf 2>/dev/null | grep "address=/" | cut -d'/' -f2 | cut -d'.' -f1)
    if [ -n "$OLDHOST" ] && [ "$OLDHOST" != "manuals" ]; then
      CURHOST=$(hostname)
      if [ "$CURHOST" = "$OLDHOST" ]; then
        sudo sed -i "s/$OLDHOST/raspberrypi/g" /etc/hosts
        sudo sed -i "s/$OLDHOST/raspberrypi/g" /etc/hostname
      fi
    fi
    
    echo ""
    echo "PI-Pwn uninstalled successfully"
    echo ""
    read -p "Reboot now? (Y|N): " reboot
    case $reboot in
      [Yy]*)
        sudo reboot
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
