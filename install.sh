Install · SH
#!/usr/bin/env bash
# Installs vpn-ipwatch on Ubuntu/Debian. Run with: sudo bash install.sh
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run as root: sudo $0"; exit 1; }
cd "$(dirname "$0")"
 
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl iproute2 msmtp msmtp-mta ca-certificates
 
install -m 0755 vpn-ipwatch /usr/local/bin/vpn-ipwatch
[[ -e /etc/vpn-ipwatch.conf ]] || install -m 0644 vpn-ipwatch.conf /etc/vpn-ipwatch.conf
install -m 0644 systemd/vpn-ipwatch.service systemd/vpn-ipwatch.timer /etc/systemd/system/
 
if [[ ! -e /etc/msmtprc ]]; then
  install -m 0600 msmtprc.example /etc/msmtprc
  echo ">> Edit /etc/msmtprc with your SMTP account (see README)."
fi
 
systemctl daemon-reload
systemctl enable --now vpn-ipwatch.timer
echo ">> Installed. Next: edit /etc/vpn-ipwatch.conf and /etc/msmtprc, then run:"
echo "   sudo vpn-ipwatch --test-email && vpn-ipwatch --status"