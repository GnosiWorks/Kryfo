# watch

`kryfo-watch.sh` checks the site, the relay and the handle registry the way a
phone reaches them (through the front proxy, bridges included), the badge
service on its own port, free disk and both certificates. A relay or registry
that is down is restarted, the bridge alone when the service itself still
answers, at most once every 15 minutes. Every change of state is one journal
line; `/var/lib/kryfo-watch/status` holds the last run.

It runs every two minutes from `kryfo-watch.timer`, as root (it restarts
units). Settings go in `/etc/kryfo-watch.env`: `BADGE_UNIT` to let it restart
the badge service, `NTFY_URL` (an ntfy topic, long and random) to get one
message per change, saying only which service and what happened ("relay
down", "relay up"), or `ALERT_CMD` for any other command.

    sudo install -D -m 0755 kryfo-watch.sh /opt/kryfo-watch/kryfo-watch.sh
    sudo install -m 0644 kryfo-watch.service kryfo-watch.timer /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo DRY=1 /opt/kryfo-watch/kryfo-watch.sh && cat /var/lib/kryfo-watch/status
    sudo systemctl enable --now kryfo-watch.timer

`DRY=1` checks and restarts nothing.
