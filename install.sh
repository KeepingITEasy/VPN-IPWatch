#!/usr/bin/env bash
# Installs vpn-ipwatch on Ubuntu/Debian. Run with: sudo bash install.sh
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run as root: sudo bash $0"; exit 1; }
cd "$(dirname "$0")"
 
echo ">> Installing packages (curl, msmtp)..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl iproute2 msmtp msmtp-mta ca-certificates
 
echo ">> Installing script to /usr/local/bin/vpn-ipwatch"
install -m 0755 vpn-ipwatch /usr/local/bin/vpn-ipwatch
 
if [[ -e /etc/vpn-ipwatch.conf ]]; then
  echo ">> Keeping existing /etc/vpn-ipwatch.conf"
else
  install -m 0644 vpn-ipwatch.conf /etc/vpn-ipwatch.conf
  echo ">> Created /etc/vpn-ipwatch.conf"
fi
 
if [[ -e /etc/msmtprc ]]; then
  echo ">> Keeping existing /etc/msmtprc"
else
  install -m 0600 msmtprc.example /etc/msmtprc
  echo ">> Created /etc/msmtprc"
fi
 
echo ">> Installing systemd timer (runs every minute)"
for unit in vpn-ipwatch.service vpn-ipwatch.timer; do
  if   [[ -f $unit ]];         then src=$unit
  elif [[ -f systemd/$unit ]]; then src=systemd/$unit
  else echo "ERROR: cannot find $unit next to install.sh"; exit 1; fi
  install -m 0644 "$src" "/etc/systemd/system/$unit"
done
systemctl daemon-reload
systemctl enable --now vpn-ipwatch.timer
 
cat <<'EOF'
 
>> Installed. Finish setup:
   1. sudo vi /etc/msmtprc           (email account that sends alerts)
   2. sudo vi /etc/vpn-ipwatch.conf  (EMAIL_TO, VPN_INTERFACE, ISP_ORG_MATCH)
   3. sudo vpn-ipwatch --test-email
   4. vpn-ipwatch --status
EOF