# vpn-ipwatch

Small Bash + systemd tool for Ubuntu/Debian that checks your public IP every minute and **emails you when traffic leaves the VPN** (and again when it comes back).

Each check looks at:

1. **VPN interface**: is `tun0`/`wg0`/etc. present and not DOWN?
2. **Public IP owner**: looks up the public IP's org/ASN at ipinfo.io. A match on your real ISP (e.g. "Comcast") means a leak.
3. **Optional allow-list**: org regex or fixed IPs that count as the VPN.

You get one email when the status changes to OFF-VPN and one when it recovers, so a long outage doesn't fill your inbox.

## Install

```bash
git clone ttps://github.com/<you>/vpn-ipwatch.git](https://github.com/KeepingITEasy/VPN-IPWatch.git
cd vpn-ipwatch
sudo bash install.sh
```

This installs `curl`, `msmtp` and `msmtp-mta`, puts the script in `/usr/local/bin`, and enables a systemd timer that runs every minute.

## Configure

1. **Find your values** with the VPN connected, then disconnected:
   ```bash
   ip -br link              # VPN interface name (tun0, wg0, proton0, nordlynx...)
   curl -s ipinfo.io/org    # e.g. "AS9009 M247 Europe" on VPN, "AS7922 Comcast" off
   ```
2. **Edit `/etc/vpn-ipwatch.conf`**: set `EMAIL_TO`, `VPN_INTERFACE`, and `ISP_ORG_MATCH` (and/or `VPN_ORG_MATCH`).
3. **Edit `/etc/msmtprc`** with your SMTP account. For Gmail, use an App Password. For Microsoft 365, use `smtp.office365.com:587`.
4. **Test:**
   ```bash
   sudo vpn-ipwatch --test-email
   vpn-ipwatch --status
   ```
5. **Simulate a drop**: disconnect the VPN and within about a minute you should get an alert.

## Operate

```bash
systemctl list-timers vpn-ipwatch.timer     # next run
journalctl -t vpn-ipwatch -f                # live log
sudo systemctl disable --now vpn-ipwatch.timer   # stop
```

To check more or less often, change `OnUnitActiveSec` in `/etc/systemd/system/vpn-ipwatch.timer`, then run `sudo systemctl daemon-reload`.

## Notes

- If your VPN has a kill switch, a drop may mean *no* connectivity rather than a leak. The script logs "Could not determine public IP" and doesn't email, because there's no way to send mail with the connection down.
- IPv4 only. If your VPN doesn't tunnel IPv6, disable IPv6 or check it separately.
- ipinfo.io allows about 50k lookups/month free without a token. One check per minute is about 43k.

## Uninstall

```bash
sudo systemctl disable --now vpn-ipwatch.timer
sudo rm /usr/local/bin/vpn-ipwatch /etc/systemd/system/vpn-ipwatch.{service,timer} /etc/vpn-ipwatch.conf
sudo rm -rf /var/lib/vpn-ipwatch
```

## License

MIT
