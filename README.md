# vpn-ipwatch

Emails you when your Ubuntu machine's public IP leaves the VPN, and again when it's back on. Bash + systemd, checks every minute.

Each check decides you're **off the VPN** if any of these is true:

- The VPN adapter (e.g. `pia`, `tun0`, `wg0`) is down or missing.
- Your public IP belongs to your real ISP (looked up at ipinfo.io).
- Optional: your public IP's owner doesn't match a VPN pattern you set.

You get one email per drop and one on recovery, never a flood.

## Install

```bash
git clone https://github.com/YOUR-USERNAME/vpn-ipwatch.git
cd vpn-ipwatch
sudo bash install.sh
```

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

## Day-to-day commands

```bash
systemctl list-timers vpn-ipwatch.timer          # when the next check runs
journalctl -t vpn-ipwatch -f                     # live log
sudo systemctl disable --now vpn-ipwatch.timer   # stop monitoring
```

To check more or less often, edit `OnUnitActiveSec` in `/etc/systemd/system/vpn-ipwatch.timer`, then run `sudo systemctl daemon-reload`.

## Notes

- **PIA (Private Internet Access):** leave `VPN_ORG_MATCH` empty. PIA rents servers from many hosting companies, so matching on them causes false alerts. The adapter and ISP checks are enough.
- **Kill switch:** if your VPN blocks all traffic when it drops, no email can be sent until the connection returns. The drop is still logged.
- **IPv4 only.** If your VPN doesn't tunnel IPv6, disable IPv6 or check it separately.
- **Lookup limit:** ipinfo.io allows about 50,000 free lookups a month. One check a minute uses about 43,000.

## Uninstall

```bash
sudo systemctl disable --now vpn-ipwatch.timer
sudo rm /usr/local/bin/vpn-ipwatch /etc/systemd/system/vpn-ipwatch.{service,timer} /etc/vpn-ipwatch.conf
sudo rm -rf /var/lib/vpn-ipwatch
```

## License

MIT, see [LICENSE](LICENSE).
