#!/bin/bash

if [ -f /boot/firmware/PPPwn/upd.log ]; then
  sudo rm -f /boot/firmware/PPPwn/upd.log
fi

echo "Checking for updates..." | sudo tee /dev/tty1 | sudo tee /dev/pts/* | sudo tee -a /boot/firmware/PPPwn/upd.log
sudo mkdir -p /home/www-data
cd /home/www-data
sudo rm -f -r PI-Pwn

echo "Downloading files..." | sudo tee /dev/tty1 | sudo tee /dev/pts/* | sudo tee -a /boot/firmware/PPPwn/upd.log
git clone https://github.com/mariozelaschi/PI-Pwn

currentver=$(</boot/firmware/PPPwn/ver)
newver=$(<PI-Pwn/PPPwn/ver)

if [ "$newver" -gt "$currentver" ]; then
  cd PI-Pwn
  echo "Starting update..." | sudo tee /dev/tty1 | sudo tee /dev/pts/* | sudo tee -a /boot/firmware/PPPwn/upd.log

  sudo systemctl stop pipwn
  echo "Installing files..." | sudo tee /dev/tty1 | sudo tee /dev/pts/* | sudo tee -a /boot/firmware/PPPwn/upd.log
  sudo cp -r PPPwn /boot/firmware/

  cd /boot/firmware/PPPwn
  sudo chmod +x *.sh pppwn7 pppwn11 pppwn64 2>/dev/null
  sudo bash install.sh update
  
  cd /home/www-data
  sudo rm -rf PI-Pwn

else
  sudo rm -f -r PI-Pwn
  echo "No updates found." | sudo tee /dev/tty1 | sudo tee /dev/pts/* | sudo tee -a /boot/firmware/PPPwn/upd.log

fi