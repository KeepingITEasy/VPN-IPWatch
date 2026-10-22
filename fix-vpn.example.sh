#!/usr/bin/env bash
# Example fix script for vpn-ipwatch. Copy it, keep ONE option, and point
# FIX_SCRIPT in /etc/vpn-ipwatch.conf at the copy:
#   sudo cp /usr/local/share/vpn-ipwatch/fix-vpn.example.sh /usr/local/sbin/fix-vpn.sh
#   sudo chmod 755 /usr/local/sbin/fix-vpn.sh
#
# vpn-ipwatch runs it as root and passes:
#   VPN_IPWATCH_REASON  why it thinks the VPN is off
#   VPN_IPWATCH_IP      the current public IP (blank if offline)
# Anything it prints goes to the log (journalctl -t vpn-ipwatch).
set -uo pipefail
echo "Reason: ${VPN_IPWATCH_REASON:-unknown}"

# --- Option 1: PIA app (piactl) ---
# Needs the PIA daemon running in the background:  piactl background enable
piactl disconnect
sleep 3
piactl connect
for _ in $(seq 1 30); do
  [[ "$(piactl get connectionstate)" == "Connected" ]] && { echo "PIA connected"; exit 0; }
  sleep 2
done
echo "PIA did not reconnect within 60s"
exit 1

# --- Option 2: WireGuard (wg-quick) ---
# systemctl restart wg-quick@wg0

# --- Option 3: OpenVPN client service ---
# systemctl restart openvpn-client@myvpn

# --- Option 4: Proton VPN / other app with a systemd service ---
# systemctl restart <service-name>
