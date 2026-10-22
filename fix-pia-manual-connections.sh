#!/usr/bin/env bash
# fix-pia-manual-connections.sh - reconnect PIA using pia-foss/manual-connections
# (WireGuard), for use as FIX_SCRIPT in /etc/vpn-ipwatch.conf or by hand.
#
# Install:
#   sudo install -m 0755 fix-pia-manual-connections.sh /usr/local/sbin/fix-vpn.sh
#   sudo install -m 0600 /dev/null /etc/pia-credentials
#   sudo vi /etc/pia-credentials        # two lines:  PIA_USER=p1234567
#                                       #             PIA_PASS=your-password
# Then in /etc/vpn-ipwatch.conf:
#   FIX_SCRIPT="/usr/local/sbin/fix-vpn.sh"
#   FIX_TIMEOUT=180
#   KILL_SWITCH_CONTAINERS="qbittorrent"
#
# Run by hand:  sudo /usr/local/sbin/fix-vpn.sh
set -uo pipefail

PIA_DIR="${PIA_DIR:-/opt/manual-connections}"
PIA_CREDENTIALS="${PIA_CREDENTIALS:-/etc/pia-credentials}"
WG_SERVICE="${WG_SERVICE:-wg-quick@pia}"
CONTAINER="${CONTAINER:-qbittorrent}"

[[ $EUID -eq 0 ]] || { echo "Run as root: sudo $0"; exit 1; }

# Credentials live outside the script, readable by root only.
if [[ ! -r "$PIA_CREDENTIALS" ]]; then echo "Missing $PIA_CREDENTIALS (see top of this script)"; exit 1; fi
if [[ -n "$(find "$PIA_CREDENTIALS" -perm /077)" ]]; then
  echo "$PIA_CREDENTIALS must be chmod 600"; exit 1
fi
# shellcheck source=/dev/null
. "$PIA_CREDENTIALS"
[[ -n "${PIA_USER:-}" && -n "${PIA_PASS:-}" ]] || { echo "PIA_USER/PIA_PASS not set in $PIA_CREDENTIALS"; exit 1; }

# When vpn-ipwatch runs this, its kill switch has already paused the container
# and will unpause it once the VPN checks out, so leave Docker alone.
# Run by hand, stop the container first and start it again only if the VPN works.
if [[ -n "${VPN_IPWATCH_STATUS:-}" ]]; then
  manage_docker=0
else
  manage_docker=1
fi

if ((manage_docker)) && docker inspect "$CONTAINER" >/dev/null 2>&1; then
  echo "Stopping $CONTAINER"
  docker stop "$CONTAINER" >/dev/null
fi

echo "Stopping $WG_SERVICE"
systemctl stop "$WG_SERVICE" 2>/dev/null || wg-quick down pia 2>/dev/null || true

echo "Connecting to PIA (WireGuard)"
cd "$PIA_DIR" || { echo "Cannot find $PIA_DIR"; exit 1; }
VPN_PROTOCOL=wireguard DISABLE_IPV6=yes DIP_TOKEN=no AUTOCONNECT=true \
  PIA_PF=false PIA_DNS=true PIA_USER="$PIA_USER" PIA_PASS="$PIA_PASS" \
  ./run_setup.sh
setup_rc=$?

# Confirm the VPN is really up before letting anything back online.
sleep 3
on_vpn=0
if command -v vpn-ipwatch >/dev/null 2>&1; then
  vpn-ipwatch --status && on_vpn=1
else
  ip link show pia >/dev/null 2>&1 && echo "Public IP: $(curl -fsS -4 --max-time 8 https://ipinfo.io/ip)" && on_vpn=1
fi

if ((on_vpn)); then
  echo "VPN is up"
  if ((manage_docker)) && docker inspect "$CONTAINER" >/dev/null 2>&1; then
    echo "Starting $CONTAINER"
    docker start "$CONTAINER" >/dev/null
  fi
  exit 0
fi

echo "VPN is NOT up (run_setup.sh exited $setup_rc); leaving $CONTAINER stopped"
exit 1
