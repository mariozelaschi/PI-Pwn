#!/bin/bash

if [ -f /boot/firmware/PPPwn/config.sh ]; then
  source /boot/firmware/PPPwn/config.sh
fi
if [ -z "$INTERFACE" ]; then INTERFACE="eth0"; fi
if [ -z "$DTLINK" ]; then DTLINK=false; fi

if [ "$DTLINK" = true ]; then
  echo -e "\033[32mMonitoring link\033[0m\n" | sudo tee /dev/tty1
  coproc read -t 60 && wait "$!" || true
  while [[ $(ifconfig "$INTERFACE") == *"RUNNING"* ]]; do
    coproc read -t 10 && wait "$!" || true
  done
  sudo systemctl stop pppoe
  sudo killall pppoe-server
  sudo ip link set "$INTERFACE" down

  sudo iptables -t nat -S PREROUTING 2>/dev/null | grep '192\.168\.2\.' | sed 's/^-A/-D/' | while read rule; do sudo iptables -t nat $rule 2>/dev/null; done
  sudo iptables -t nat -S POSTROUTING 2>/dev/null | grep '192\.168\.2\.' | sed 's/^-A/-D/' | while read rule; do sudo iptables -t nat $rule 2>/dev/null; done
  sudo iptables -t nat -F PPPWN 2>/dev/null
  sudo iptables -t nat -X PPPWN 2>/dev/null

  sudo sysctl net.ipv4.ip_forward=0
  sudo sysctl net.ipv4.conf.all.route_localnet=0
  echo -e "\033[32mRestarting PPPwn\033[0m\n" | sudo tee /dev/tty1
  sudo systemctl restart pipwn
fi