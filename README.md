# vpn-ipwatch

Emails you when your Ubuntu machine's public IP leaves the VPN, and again when it's back on. Bash + systemd, checks every minute.

Each check decides you're **off the VPN** if any of these is true:

- The VPN adapter (e.g. `pia`, `tun0`, `wg0`) is down or missing.
- Your public IP belongs to your real ISP (looked up at ipinfo.io).
- Optional: your public IP's owner doesn't match a VPN pattern you set.

You get one email per drop and one on recovery, never a flood.

Optional extras (v3):

- **Auto-fix:** runs a shell script of your choice the moment you're off the VPN, then re-checks.
- **Kill switch:** pauses the Docker containers you list while you're off the VPN or offline, and unpauses them once you're back.

When a drop is found, the order is: pause containers → run the fix script → re-check → email.

## Install

```bash
git clone https://github.com/KeepingITEasy/vpn-ipwatch.git
cd vpn-ipwatch
sudo bash install.sh
```

**Upgrading from v2:** run `git pull` and `sudo bash install.sh` again. Your `/etc/vpn-ipwatch.conf` is kept. The new auto-fix and kill switch settings are added at the end, turned off until you fill them in.

## Setup

Steps 1 and 2 collect values you'll enter in steps 3 and 4.

### Step 1: Find your VPN adapter name

Connect the VPN, then run:

```bash
ip -br link
```

Look for the VPN adapter: `pia` or `wgpia0` (PIA app), `tun0` (OpenVPN) or `wg0` (WireGuard). Ignore `lo`, `ens…`/`eth…`, `docker0`, `br-…` and `veth…`.

If no VPN adapter appears, the VPN runs on your router. Use `""` in step 4.

### Step 2: Find your ISP's name

Disconnect the VPN, then run:

```bash
curl -s ipinfo.io/org
```

You'll see something like `AS7922 Comcast Cable Communications`. Note one distinctive word, such as `Comcast`. Reconnect the VPN afterwards.

### Step 3: Set up the email account

```bash
sudo vi /etc/msmtprc
```

Change these lines to the account that **sends** the alerts:

```
host           smtp.gmail.com
from           you@gmail.com
user           you@gmail.com
password       your-16-char-app-password
```

- **Gmail:** use an App Password (Google Account → Security → 2-Step Verification → App passwords).
- **Microsoft 365:** use `host smtp.office365.com`.

Save and exit with `:wq`. Keep your real password only in `/etc/msmtprc`, never in the repo.

### Step 4: Set up the watcher

```bash
sudo vi /etc/vpn-ipwatch.conf
```

Change these three lines:

```
EMAIL_TO="you@example.com"   # where alerts go
VPN_INTERFACE="pia"          # name from step 1 (or "")
ISP_ORG_MATCH="Comcast"      # word from step 2
```

Save and exit with `:wq`.

### Step 5: Send a test email

```bash
sudo vpn-ipwatch --test-email
```

It should print `Sent.` and an email should arrive within a minute. If not, recheck step 3. Errors are logged in `/var/log/msmtp.log`.

### Step 6: Test VPN detection

With the VPN **connected**:

```bash
vpn-ipwatch --status
```

You should see `ON VPN: ...`. **Disconnect** the VPN and run it again. You should see `OFF VPN: ...`, and an alert email arrives within about a minute. Reconnect and you'll get a "back on the VPN" email.

### Step 7 (optional): Auto-fix script

Copy the example, keep the option that matches your VPN (PIA, WireGuard, OpenVPN or a systemd service), and delete the rest:

```bash
sudo cp /usr/local/share/vpn-ipwatch/fix-vpn.example.sh /usr/local/sbin/fix-vpn.sh
sudo chmod 755 /usr/local/sbin/fix-vpn.sh
sudo vi /usr/local/sbin/fix-vpn.sh
```

**PIA with manual-connections (WireGuard):** use `fix-pia-manual-connections.sh` instead. It reads your PIA login from `/etc/pia-credentials` (chmod 600), reconnects, and confirms the VPN is up. Setup steps are at the top of the file. Set `FIX_TIMEOUT=180`, since the PIA setup can take a minute.

Point the config at it (the script can live anywhere):

```
FIX_SCRIPT="/usr/local/sbin/fix-vpn.sh"
```

Test it:

```bash
sudo vpn-ipwatch --test-fix
```

How it runs:

- Runs as root, so vpn-ipwatch refuses a script that isn't executable or that other users can edit.
- Runs on the first check that finds you off the VPN, then at most every `FIX_RETRY_INTERVAL` seconds (default 300) until you're back.
- Stopped after `FIX_TIMEOUT` seconds (default 120). vpn-ipwatch waits `FIX_WAIT` seconds (default 15), then checks again.
- Gets `VPN_IPWATCH_REASON` and `VPN_IPWATCH_IP` as environment variables. Its output goes to the log.
- If the fix works within that check, you get one email: "dropped off the VPN; auto-fix restored it".
- When there's no internet at all but the VPN adapter looks up, it doesn't run unless you set `FIX_WHEN_OFFLINE=1`.

### Step 8 (optional): Kill switch for Docker containers

List the containers to pause, space-separated:

```bash
docker ps --format '{{.Names}}'
```

```
KILL_SWITCH_CONTAINERS="qbittorrent sonarr radarr"
```

- Paused (`docker pause`) while you're off the VPN **or** offline, and unpaused when you're back on the VPN.
- Paused containers keep their memory and open files and pick up where they left off. They aren't stopped or restarted.
- Only containers vpn-ipwatch paused are unpaused. If you paused one yourself, it's left alone.
- A listed container that starts during an outage is paused at the next check.
- The list of what it paused is kept in `/var/lib/vpn-ipwatch/paused-containers`, so it survives reboots.
- To unpause by hand: `sudo vpn-ipwatch --resume`. If you're still off the VPN, the next check pauses them again.

## Day-to-day commands

```bash
systemctl list-timers vpn-ipwatch.timer          # when the next check runs
journalctl -t vpn-ipwatch -f                     # live log
sudo systemctl disable --now vpn-ipwatch.timer   # stop monitoring
```

To check more or less often, edit `OnUnitActiveSec` in `/etc/systemd/system/vpn-ipwatch.timer`, then run `sudo systemctl daemon-reload`.

## Notes

- **PIA (Private Internet Access):** leave `VPN_ORG_MATCH` empty. PIA rents servers from many hosting companies, so matching on them causes false alerts. The adapter and ISP checks are enough.
- **VPN app kill switch:** if your VPN blocks all traffic when it drops, no email can be sent until the connection returns. The drop is still logged, the fix script still runs and containers are still paused (no internet with the adapter down counts as off the VPN).
- **Up to a minute of exposure:** the timer checks once a minute, so a container can leak for up to a minute before it's paused. To check more often, lower `OnUnitActiveSec`. Pair this with your VPN app's own kill switch.
- **IPv4 only.** If your VPN doesn't tunnel IPv6, disable IPv6 or check it separately.
- **Lookup limit:** ipinfo.io allows about 50,000 free lookups a month. One check a minute uses about 43,000.

## Uninstall

```bash
sudo systemctl disable --now vpn-ipwatch.timer
sudo vpn-ipwatch --resume   # unpause any containers it paused
sudo rm /usr/local/bin/vpn-ipwatch /etc/systemd/system/vpn-ipwatch.{service,timer} /etc/vpn-ipwatch.conf
sudo rm -rf /usr/local/share/vpn-ipwatch
sudo rm -rf /var/lib/vpn-ipwatch
```

## License

MIT, see [LICENSE](LICENSE).
