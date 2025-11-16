#!/bin/bash

VERSION=$(cat /boot/firmware/PPPwn/ver 2>/dev/null || echo "unknown")
echo -e "\r\n\033[36mPI-Pwn v$VERSION \033[0m"

if [ ! -d /boot/firmware/PPPwn/payloads ]; then
  sudo mkdir -p /boot/firmware/PPPwn/payloads
fi

echo -e '\r\n\033[33mInstalling system packages...\033[0m'
sudo apt install pppoe dnsmasq iptables nginx php-fpm nmap at net-tools -y

echo -e '\r\n\033[33mConfiguring Dnsmasq...\033[0m'
SYSDNS=$(grep -m 1 "^nameserver" /etc/resolv.conf | awk '{print $2}')
if [ -z "$SYSDNS" ]; then
  SYSDNS="9.9.9.9"
fi

echo '# PPPwn DNS configuration for PS4
listen-address=127.0.0.1
port=5353
bogus-priv
expand-hosts
domain-needed
server='$SYSDNS'
conf-file=/etc/dnsmasq.d/99-pppwn-blocklist.conf' | sudo tee /etc/dnsmasq.d/99-pppwn.conf

echo -e '\r\n\033[33mConfiguring PPPoE server...\033[0m'
echo 'auth
lcp-echo-failure 3
lcp-echo-interval 60
mtu 1482
mru 1482
require-pap
ms-dns 192.168.2.1
netmask 255.255.255.0
defaultroute
noipdefault
usepeerdns' | sudo tee /etc/ppp/pppoe-server-options

echo -e '\r\n\033[33mCreating services...\033[0m'
echo '[Service]
WorkingDirectory=/boot/firmware/PPPwn
ExecStart=/boot/firmware/PPPwn/pppoe.sh
Restart=never
User=root
Group=root
Environment=NODE_ENV=production
[Install]
WantedBy=multi-user.target' | sudo tee /etc/systemd/system/pppoe.service

echo '[Service]
WorkingDirectory=/boot/firmware/PPPwn
ExecStart=/boot/firmware/PPPwn/dtlink.sh
Restart=never
User=root
Group=root
Environment=NODE_ENV=production
[Install]
WantedBy=multi-user.target' | sudo tee /etc/systemd/system/dtlink.service

echo '[Unit]
Description=Run PPPwn devboot.sh once at startup
After=network.target local-fs.target

[Service]
Type=oneshot
WorkingDirectory=/boot/firmware/PPPwn
ExecStart=/boot/firmware/PPPwn/devboot.sh
RemainAfterExit=yes
User=root
Group=root
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target' | sudo tee /etc/systemd/system/devboot.service

echo -e '\r\n\033[33mConfiguring nginx...\033[0m'
PHPVER=$(sudo php -v | head -n 1 | cut -d " " -f 2 | cut -f1-2 -d".")
echo 'server {
  listen 8080;
  listen [::]:8080;
  root /boot/firmware/PPPwn;
  index index.html index.htm index.php;
  server_name _;
  location / {
      try_files $uri $uri/ =404;
  }
  error_page 404 = @mainindex;
  location @mainindex {
      return 302 /;
  }
  location ~ \.php$ {
      include snippets/fastcgi-php.conf;
      fastcgi_pass unix:/var/run/php/php'$PHPVER'-fpm.sock;
  }
}' | sudo tee /etc/nginx/sites-available/pipwn

sudo ln -sf /etc/nginx/sites-available/pipwn /etc/nginx/sites-enabled/pipwn

sudo sed -i "s^www-data	ALL=(ALL) NOPASSWD: ALL^^g" /etc/sudoers
echo 'www-data	ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers

sudo systemctl restart nginx

echo -e '\r\n\033[33mCreating udev rules for USB mounts...\033[0m'
if [ ! -f /etc/udev/rules.d/99-pwnmnt.rules ]; then
  echo 'MountFlags=shared' | sudo tee -a /usr/lib/systemd/system/systemd-udevd.service
  echo 'ACTION=="add", KERNEL=="sd*", SUBSYSTEMS=="usb|scsi", DRIVERS=="sd", SYMLINK+="usbdrive", RUN+="/boot/firmware/PPPwn/pwnmount.sh $kernel"
ACTION=="remove", SUBSYSTEM=="block", RUN+="/boot/firmware/PPPwn/pwnumount.sh $kernel"' | sudo tee /etc/udev/rules.d/99-pwnmnt.rules
  sudo udevadm control --reload
fi

echo -e '\r\n\033[33mCreating media directory for USB drives...\033[0m'
if [ ! -d /media/pwndrives ]; then
  sudo mkdir -p /media/pwndrives
fi

echo -e '\r\n\033[33mDisabling PPPoE service if enabled...\033[0m'
PPSTAT=$(sudo systemctl list-unit-files --state=enabled --type=service | grep pppoe)
if [[ -n "$PPSTAT" ]]; then
  sudo systemctl disable pppoe
fi

while true; do
  read -p "$(printf '\r\n\r\n\033[36mDo you want to use Python (slower) PPPwn? (Y|N): \033[0m')" pypwnopt
  case $pypwnopt in
    [Yy]*)
      sudo apt install python3 python3-scapy -y
      UPYPWN="true"
      echo -e '\r\n\033[32mThe Python version of PPPwn will be used\033[0m'
      break
      ;;
    [Nn]*)
      UPYPWN="false"
      echo -e '\r\n\033[35mThe C++ version of PPPwn will be used\033[0m'
      break
      ;;
    *)
      echo -e '\r\n\033[31mPlease answer Y or N\033[0m'
      ;;
  esac
done

while true; do
  read -p "$(printf '\r\n\r\n\033[36mDo you want to install a FTP server? (Y|N): \033[0m')" ftpq
  case $ftpq in
    [Yy]*)
      sudo apt-get install vsftpd -y
      echo "listen=YES
local_enable=YES
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=077
allow_writeable_chroot=YES
chroot_local_user=YES
user_sub_token=$USER
local_root=/boot/firmware/PPPwn" | sudo tee /etc/vsftpd.conf
      sudo sed -i 's^root^^g' /etc/ftpusers
      echo -e '\r\n\r\n\033[33mTo use FTP, you must set the \033[36mroot\033[33m account password so you can login to the FTP server with full write permissions.\033[0m'
      while true; do
        read -p "$(printf '\r\n\033[36mDo you want to set the root account password now? (Y|N): \033[0m')" rapw
        case $rapw in
          [Yy]*)
            sudo passwd root
            echo -e '\r\n\033[33mYou can log into the FTP server with:\r\nUsername: \033[36mroot\033[33m\r\nPassword: the password you just set\033[0m'
            break
            ;;
          [Nn]*)
            echo -e '\r\n\033[33mYou can log into the FTP server with:\r\nUsername: \033[36mroot\033[33m\r\nPassword: the current root account password\033[0m'
            break
            ;;
          *)
            echo -e '\r\n\033[31mPlease answer Y or N\033[0m'
            ;;
        esac
      done
      echo -e '\r\n\033[32mFTP installed successfully\033[0m'
      break
      ;;
    [Nn]*)
      echo -e '\r\n\033[35mSkipping FTP installation\033[0m'
      break
      ;;
    *)
      echo -e '\r\n\033[31mPlease answer Y or N\033[0m'
      ;;
  esac
done

while true; do
  read -p "$(printf '\r\n\r\n\033[36mDo you want to setup a SAMBA share? (Y|N): \033[0m')" smbq
  case $smbq in
    [Yy]*)
      sudo apt-get install samba samba-common-bin -y
echo '[global]
;   interfaces = 127.0.0.0/8 eth0
;   bind interfaces only = yes
   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file
   panic action = /usr/share/samba/panic-action %d
   server role = standalone server
   obey pam restrictions = yes
   unix password sync = yes
   passwd program = /usr/bin/passwd %u
   passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* .
   pam password change = yes
   map to guest = bad user
;   logon path = \\%N\profiles\%U
;   logon drive = H:
;   logon script = logon.cmd
; add user script = /usr/sbin/useradd --create-home %u
; add machine script  = /usr/sbin/useradd -g machines -c "%u machine account" -d /var/lib/samba -s /bin/false %u
; add group script = /usr/sbin/addgroup --force-badname %g
;   include = /home/samba/etc/smb.conf.%m
;   idmap config * :              backend = tdb
;   idmap config * :              range   = 3000-7999
;   idmap config YOURDOMAINHERE : backend = tdb
;   idmap config YOURDOMAINHERE : range   = 100000-999999
;   template shell = /bin/bash
   usershare allow guests = yes
[homes]
   comment = Home Directories
   browseable = no
   read only = yes
   create mask = 0700
   directory mask = 0700
   valid users = %S
;[netlogon]
;   comment = Network Logon Service
;   path = /home/samba/netlogon
;   guest ok = yes
;   read only = yes
;[profiles]
;   comment = Users profiles
;   path = /home/samba/profiles
;   guest ok = no
;   browseable = no
;   create mask = 0600
;   directory mask = 0700
[printers]
   comment = All Printers
   browseable = no
   path = /var/tmp
   printable = yes
   guest ok = no
   read only = yes
   create mask = 0700
[print$]
   comment = Printer Drivers
   path = /var/lib/samba/printers
   browseable = yes
   read only = yes
   guest ok = no
;   write list = root, @lpadmin
[pppwn]
path = /boot/firmware/PPPwn/
writeable=Yes
create mask=0777
read only = no
directory mask=0777
force create mask = 0777
force directory mask = 0777
force user = root
force group = root
public=yes' | sudo tee /etc/samba/smb.conf
      sudo systemctl unmask smbd
      sudo systemctl enable smbd
      echo -e '\r\n\033[32mSamba installed successfully\033[0m'
      break
      ;;
    [Nn]*)
      echo -e '\r\n\033[35mSkipping Samba installation\033[0m'
      break
      ;;
    *)
      echo -e '\r\n\033[31mPlease answer Y or N\033[0m'
      ;;
  esac
done

while true; do
  read -p "$(printf '\r\n\r\n\033[36mDo you want to change the PPPoE username and password (defaults are: ppp/ppp)? (Y|N): \033[0m')" wapset
  case $wapset in
    [Yy]*)
      while true; do
        read -p "$(printf '\r\n\033[33mEnter Username: \033[0m')" PPPU
        case $PPPU in
          "")
            echo -e '\033[31mCannot be empty!\033[0m'
            ;;
          *)
            if grep -q '^[0-9a-zA-Z_ -]*$' <<<"$PPPU"; then
              if [ ${#PPPU} -le 1 ] || [ ${#PPPU} -ge 33 ]; then
                echo -e '\033[31mUsername must be between 2 and 32 characters long\033[0m'
              else
                break
              fi
            else
              echo -e '\033[31mUsername must only contain alphanumeric characters\033[0m'
            fi
            ;;
        esac
      done
      while true; do
        read -p "$(printf '\r\n\033[33mEnter password: \033[0m')" PPPW
        case $PPPW in
          "")
            echo -e '\033[31mCannot be empty!\033[0m'
            ;;
          *)
            if [ ${#PPPW} -le 1 ] || [ ${#PPPW} -ge 33 ]; then
              echo -e '\033[31mPassword must be between 2 and 32 characters long\033[0m'
            else
              break
            fi
            ;;
        esac
      done
      echo -e '\r\n\033[36mUsing custom settings:\r\n\r\nUsername: \033[33mppp\r\n\033[36mPassword: \033[33m'$PPPW'\r\n\033[0m'
      break
      ;;
    [Nn]*)
      echo -e '\r\n\033[36mUsing default settings:\r\n\r\nUsername: \033[33mppp\r\n\033[36mPassword: \033[33mppp\r\n\033[0m'
      PPPU="ppp"
      PPPW="ppp"
      break
      ;;
    *)
      echo -e '\r\n\033[31mPlease answer Y or N\033[0m'
      ;;
  esac
done

echo '"'$PPPU'"  *  "'$PPPW'"  192.168.2.2' | sudo tee /etc/ppp/pap-secrets

while true; do
  read -p "$(printf '\r\n\r\n\033[36mDo you want to detect console shutdown and restart PPPwn? (Y|N): \033[0m')" dlnk
  case $dlnk in
    [Yy]*)
      DTLNK="true"
      echo -e '\r\n\033[32mConsole shutdown detection enabled\033[0m'
      break
      ;;
    [Nn]*)
      echo -e '\r\n\033[35mConsole shutdown detection disabled\033[0m'
      DTLNK="false"
      break
      ;;
    *)
      echo -e '\r\n\033[31mPlease answer Y or N\033[0m'
      ;;
  esac
done

while true; do
  read -p "$(printf '\r\n\r\n\033[36mDo you want the console to connect to the internet after PPPwn? (Y|N): \033[0m')" pppq
  case $pppq in
    [Yy]*)
      INET="true"
      SHTDN="false"
      echo -e '\r\n\033[32mConsole internet access enabled\033[0m'
      break
      ;;
    [Nn]*)
      echo -e '\r\n\033[35mConsole internet access disabled\033[0m'
      INET="false"
      while true; do
        read -p "$(printf '\r\n\r\n\033[36mDo you want the Pi to shut down after successful exploitation? (Y|N): \033[0m')" pisht
        case $pisht in
          [Yy]*)
            SHTDN="true"
            echo -e '\r\n\033[32mThe Pi will shut down after success\033[0m'
            break
            ;;
          [Nn]*)
            echo -e '\r\n\033[35mThe Pi will not shut down after success\033[0m'
            SHTDN="false"
            break
            ;;
          *)
            echo -e '\r\n\033[31mPlease answer Y or N\033[0m'
            ;;
        esac
      done
      break
      ;;
    *)
      echo -e '\r\n\033[31mPlease answer Y or N\033[0m'
      ;;
  esac
done

while true; do
  read -p "$(printf '\r\n\r\n\033[36mAre you using a USB to Ethernet adapter for the console connection? (Y|N): \033[0m')" usbeth
  case $usbeth in
    [Yy]*)
      USBE="true"
      echo -e '\r\n\033[32mUSB to Ethernet adapter will be used\033[0m'
      break
      ;;
    [Nn]*)
      echo -e '\r\n\033[35mUSB to Ethernet adapter will NOT be used\033[0m'
      USBE="false"
      break
      ;;
    *)
      echo -e '\r\n\033[31mPlease answer Y or N\033[0m'
      ;;
  esac
done

while true; do
  read -p "$(printf '\r\n\r\n\033[36mDo you want to detect if GoldHEN is already running and skip PPPwn if found (useful for rest mode)? (Y|N): \033[0m')" restmd
  case $restmd in
    [Yy]*)
      RESTM="true"
      echo -e '\r\n\033[32mGoldHEN detection enabled\033[0m'
      break
      ;;
    [Nn]*)
      echo -e '\r\n\033[35mGoldHEN detection disabled\033[0m'
      RESTM="false"
      break
      ;;
    *)
      echo -e '\r\n\033[31mPlease answer Y or N\033[0m'
      ;;
  esac
done

while true; do
  read -p "$(printf '\r\n\r\n\033[36mDo you want PPPwn to run in verbose mode? (Y|N): \033[0m')" ppdbg
  case $ppdbg in
    [Yy]*)
      PDBG="true"
      echo -e '\r\n\033[32mPPPwn will run in verbose mode\033[0m'
      break
      ;;
    [Nn]*)
      echo -e '\r\n\033[35mPPPwn will NOT run in verbose mode\033[0m'
      PDBG="false"
      break
      ;;
    *)
      echo -e '\r\n\033[31mPlease answer Y or N\033[0m'
      ;;
  esac
done
while true; do
  read -p "$(printf '\r\n\r\n\033[36mWould you like to change the timeout for PPPwn to restart if it hangs (default is 5 minutes)? (Y|N): \033[0m')" tmout
  case $tmout in
    [Yy]*)
      while true; do
        read -p "$(printf '\r\n\033[33mEnter the timeout value [1 | 2 | 3 | 4 | 5]: \033[0m')" TOUT
        case $TOUT in
          "")
            echo -e '\r\n\033[31mCannot be empty!\033[0m'
            ;;
          *)
            if grep -q '^[1-5]*$' <<<"$TOUT"; then
              if [[ ! "$TOUT" =~ ^("1"|"2"|"3"|"4"|"5")$ ]]; then
                echo -e '\r\n\033[31mThe value must be between 1 and 5\033[0m'
              else
                break
              fi
            else
              echo -e '\r\n\033[31mThe timeout must only contain a number between 1 and 5\033[0m'
            fi
            ;;
        esac
      done
      echo -e '\r\n\033[32mTimeout set to '$TOUT' (minutes)\033[0m'
      break
      ;;
    [Nn]*)
      echo -e '\r\n\033[35mUsing the default setting: 5 (minutes)\033[0m'
      TOUT="5"
      break
      ;;
    *)
      echo -e '\r\n\033[31mPlease answer Y or N\033[0m'
      ;;
  esac
done

while true; do
  read -p "$(printf '\r\n\r\n\033[36mWould you like to change the firmware version being used (default is 11.00)? (Y|N): \033[0m')" fwset
  case $fwset in
    [Yy]*)
      while true; do
        read -p "$(printf '\r\n\033[33mEnter the firmware version [7.00 | 7.01 | 7.02 | 7.50 | 7.51 | 7.55 | 8.00 | 8.01 | 8.03 | 8.50 | 8.52 | 9.00 | 9.03 | 9.04 | 9.50 | 9.51 | 9.60 | 10.00 | 10.01 | 10.50 | 10.70 | 10.71 | 11.00]: \033[0m')" FWV
        case $FWV in
          "")
            echo -e '\r\n\033[31mCannot be empty!\033[0m'
            ;;
          *)
            if grep -q '^[0-9.]*$' <<<"$FWV"; then
              if [[ ! "$FWV" =~ ^("7.00"|"7.01"|"7.02"|"7.50"|"7.51"|"7.55"|"8.00"|"8.01"|"8.03"|"8.50"|"8.52"|"9.00"|"9.03"|"9.04"|"9.50"|"9.51"|"9.60"|"10.00"|"10.01"|"10.50"|"10.70"|"10.71"|"11.00")$ ]]; then
                echo -e '\r\n\033[31mThe version must be [7.00 | 7.01 | 7.02 | 7.50 | 7.51 | 7.55 | 8.00 | 8.01 | 8.03 | 8.50 | 8.52 | 9.00 | 9.03 | 9.04 | 9.50 | 9.51 | 9.60 | 10.00 | 10.01 | 10.50 | 10.70 | 10.71 | 11.00]\033[0m'
              else
                break
              fi
            else
              echo -e '\r\n\033[31mThe version must only contain alphanumeric characters\033[0m'
            fi
            ;;
        esac
      done
      echo -e '\r\n\033[32mYou are using firmware version \033[36m'$FWV'\033[0m'
      break
      ;;
    [Nn]*)
      echo -e '\r\n\033[35mUsing the default firmware version: 11.00\033[0m'
      FWV="11.00"
      break
      ;;
    *)
      echo -e '\r\n\033[31mPlease answer Y or N\033[0m'
      ;;
  esac
done

INUM=0
echo -e '\r\n\r\n\033[44m\033[97mInterfaces List\033[0m\r\n'
readarray -t difcearr < <(sudo ip link | cut -d " " -f-2 | cut -d ":" -f2-2)
for difce in "${difcearr[@]}"; do
  if [ -n "$difce" ]; then
    if [ "$difce" != "lo" ] && [[ "$difce" != *"ppp"* ]] && [[ ! "$difce" == *"wlan"* ]]; then
      if [ -z "$DEFIFCE" ]; then
        DEFIFCE=${difce/ /}
      fi
    fi
    echo -e $INUM': \033[33m'${difce/ /}'\033[0m'
    interfaces+=(${difce/ /})
    ((INUM++))
  fi
done
echo -e '\r\n\033[35mDetected LAN interface: \033[33m'$DEFIFCE'\033[0m'

while true; do
  read -p "$(printf '\r\n\033[36mWould you like to change the Pi LAN interface? (Y|N): \033[0m')" ifset
  case $ifset in
    [Yy]*)
      while true; do
        read -p "$(printf '\r\n\033[33mEnter the interface value: \033[0m')" IFCE
        case $IFCE in
          "")
            echo -e '\r\n\033[31mCannot be empty!\033[0m'
            ;;
          *)
            if [ ${#IFCE} -le 1 ] && [[ $IFCE == ?(-)+([0-9]) ]] && [ -n "${interfaces[IFCE]}" ] && [ $IFCE -lt $INUM ]; then
              IFCE=${interfaces[IFCE]}
              break
            fi
            if grep -q '^[0-9a-zA-Z_ -]*$' <<<"$IFCE"; then
              if [ ${#IFCE} -le 1 ] || [ ${#IFCE} -ge 16 ]; then
                echo -e '\r\n\033[31mThe interface must be between 2 and 15 characters long\033[0m'
              else
                break
              fi
            else
              echo -e '\r\n\033[31mThe interface must only contain alphanumeric characters\033[0m'
            fi
            ;;
        esac
      done
      echo -e '\r\n\033[32mYou are using \033[36m'$IFCE'\033[0m'
      break
      ;;
    [Nn]*)
      echo -e '\r\n\033[35mUsing the detected setting: \033[36m'$DEFIFCE'\033[0m'
      IFCE=$DEFIFCE
      break
      ;;
    *)
      echo -e '\r\n\033[31mPlease answer Y or N\033[0m'
      ;;
  esac
done

while true; do
  read -p "$(printf '\r\n\r\n\033[36mDo you want to use the original IPv6 address from PPPwn? (Y|N): \033[0m')" uoipv
  case $uoipv in
    [Yy]*)
      IPV="true"
      echo -e '\r\n\033[32mThe original IPv6 address will be used\033[0m'
      break
      ;;
    [Nn]*)
      echo -e '\r\n\033[35mThe default IPv6 address will be used\033[0m'
      IPV="false"
      break
      ;;
    *)
      echo -e '\r\n\033[31mPlease answer Y or N\033[0m'
      ;;
  esac
done

PITYP=$(tr -d '\0' </proc/device-tree/model)
if [[ "$PITYP" == *"Raspberry Pi 4"* ]] || [[ "$PITYP" == *"Raspberry Pi 5"* ]]; then
  while true; do
    read -p "$(printf '\r\n\r\n\033[36mDo you want the Pi to act as a USB flash drive for the console? (Y|N): \033[0m')" vusb
    case $vusb in
      [Yy]*)
        echo -e '\r\n\033[32mThe Pi will mount as a USB drive\033[0m'
        echo -e '\033[33mNote: You must plug the Pi into the console USB port using the \033[36mUSB-C\033[33m port of the Pi,\nand the USB drive in the Pi must contain a folder named \033[36mpayloads\033[0m'
        sudo sed -i "s^dtoverlay=dwc2^^g" /boot/firmware/config.txt
        echo 'dtoverlay=dwc2' | sudo tee -a /boot/firmware/config.txt
        VUSB="true"
        break
        ;;
      [Nn]*)
        echo -e '\r\n\033[35mThe Pi will not mount as a USB drive\033[0m'
        sudo sed -i "s^dtoverlay=dwc2^^g" /boot/firmware/config.txt
        VUSB="false"
        break
        ;;
      *)
        echo -e '\r\n\033[31mPlease answer Y or N\033[0m'
        ;;
    esac
  done
else
  VUSB="false"
fi

while true; do
  read -p "$(printf '\r\n\r\n\033[36mWould you like to change the hostname (default is pppwn)? (Y|N): \033[0m')" hstset
  case $hstset in
    [Yy]*)
      while true; do
        read -p "$(printf '\r\n\033[33mEnter the hostname: \033[0m')" HSTN
        case $HSTN in
          "")
            echo -e '\r\n\033[31mCannot be empty!\033[0m'
            ;;
          *)
            if grep -q '^[0-9a-zA-Z_ -]*$' <<<"$HSTN"; then
              if [ ${#HSTN} -le 3 ] || [ ${#HSTN} -ge 21 ]; then
                echo -e '\r\n\033[31mThe interface must be between 4 and 21 characters long\033[0m'
              else
                break
              fi
            else
              echo -e '\r\n\033[31mThe hostname must only contain alphanumeric characters\033[0m'
            fi
            ;;
        esac
      done
      echo -e '\r\n\033[32mYou are using \033[36m'$HSTN'\033[33m, to access the webserver use http://\033[36m'$HSTN'\033[33m.local\033[0m'
      break
      ;;
    [Nn]*)
      echo -e '\r\n\033[35mUsing the default setting: pppwn\033[0m'
      HSTN="pppwn"
      break
      ;;
    *)
      echo -e '\r\n\033[31mPlease answer Y or N\033[0m'
      ;;
  esac
done

echo -e '\r\n\033[33mCreating configuration files...\033[0m'

if [ ! -f /boot/firmware/PPPwn/ports.txt ]; then
  echo '2121,3232,9090,8080,12800,1337' | sudo tee /boot/firmware/PPPwn/ports.txt
fi

echo 'address=/manuals.playstation.net/192.168.2.1
address=/playstation.com/127.0.0.1
address=/playstation.net/127.0.0.1
address=/playstation.org/127.0.0.1
address=/akadns.net/127.0.0.1
address=/akamai.net/127.0.0.1
address=/akamaiedge.net/127.0.0.1
address=/edgekey.net/127.0.0.1
address=/edgesuite.net/127.0.0.1
address=/llnwd.net/127.0.0.1
address=/scea.com/127.0.0.1
address=/sie-rd.com/127.0.0.1
address=/llnwi.net/127.0.0.1
address=/sonyentertainmentnetwork.com/127.0.0.1
address=/ribob01.net/127.0.0.1
address=/cddbp.net/127.0.0.1
address=/nintendo.net/127.0.0.1
address=/ea.com/127.0.0.1
address=/'$HSTN'.local/192.168.2.1' | sudo tee /etc/dnsmasq.d/99-pppwn-blocklist.conf
sudo systemctl reload-or-restart dnsmasq

echo '#!/bin/bash
INTERFACE="'${IFCE/ /}'"
FIRMWAREVERSION="'${FWV/ /}'"
SHUTDOWN='$SHTDN'
USBETHERNET='$USBE'
PPPOECONN='$INET'
VMUSB='$VUSB'
DTLINK='$DTLNK'
RESTMODE='$RESTM'
PPDBG='$PDBG'
TIMEOUT="'${TOUT/ /}'m"
PYPWN='$UPYPWN'
LEDACT="normal"
DDNS=false
OIPV='$IPV'
UGH=true' | sudo tee /boot/firmware/PPPwn/config.sh

echo '#!/bin/bash
XFWAP="1"
XFGD="4"
XFBS="0"
XFSN="0x1000"
XFPN="0x1000"
XFCN="0x1"
XFNWB=false' | sudo tee /boot/firmware/PPPwn/pconfig.sh

echo -e '\r\n\033[33mCreating pipwn service...\033[0m'
sudo rm -f /usr/lib/systemd/system/network-online.target
echo '[Unit]
Description=PiPwn Service
After=network.target devboot.service
Requires=devboot.service

[Service]
WorkingDirectory=/boot/firmware/PPPwn
ExecStart=/boot/firmware/PPPwn/run.sh
Restart=never
User=root
Group=root
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target' | sudo tee /etc/systemd/system/pipwn.service

echo -e '\r\n\033[33mEnabling services...\033[0m'
sudo chmod u+rwx /etc/systemd/system/devboot.service
sudo chmod u+rwx /etc/systemd/system/pipwn.service
sudo chmod u+rwx /etc/systemd/system/pppoe.service
sudo chmod u+rwx /etc/systemd/system/dtlink.service

sudo systemctl enable devboot
sudo systemctl enable pipwn

echo -e '\r\n\033[33mUpdating hostname...\033[0m'
CHSTN=$(hostname | cut -f1 -d' ')
sudo sed -i "s^$CHSTN^$HSTN^g" /etc/hosts
sudo sed -i "s^$CHSTN^$HSTN^g" /etc/hostname

echo -e '\r\n\033[36mInstallation complete.\r\n\033[33mReboot now? (Y|N): \033[0m'
read -p "" reboot
case $reboot in
  [Yy]*)
    echo -e '\r\n\033[32mRebooting...\033[0m'
    sudo reboot
    ;;
  *)
    echo -e '\r\n\033[33mPlease reboot manually to complete installation\033[0m'
    ;;
esac