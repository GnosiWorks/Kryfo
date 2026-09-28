#!/bin/bash
# checks every service the way a phone reaches it, through the front proxy,
# and restarts what is down. the registry went dark twice with every unit
# "active": a bridge was down, and only a request from outside shows that.
# run by kryfo-watch.timer. DRY=1 checks and restarts nothing.
set -u

ENV=/etc/kryfo-watch.env
[ -r "$ENV" ] && . "$ENV"
STATE=${STATE:-/var/lib/kryfo-watch}
SITE=${SITE:-https://kryfo.app/}
RELAY=${RELAY:-https://relay.kryfo.app/}
BADGE=${BADGE:-http://127.0.0.1:8899/pubkey}
BADGE_UNIT=${BADGE_UNIT:-}
MIN_FREE_GB=${MIN_FREE_GB:-2}
CERT_DAYS=${CERT_DAYS:-21}
HEAL_GAP=${HEAL_GAP:-900}
ALERT_CMD=${ALERT_CMD:-}
DRY=${DRY:-0}
mkdir -p "$STATE"
now=$(date +%s)
report=()

get() { curl -sS -m 20 -o /dev/null -w '%{http_code}' "$@" 2>/dev/null; }

relay_ok() { curl -sS -m 20 -H 'Accept: application/nostr+json' "$1" 2>/dev/null | grep -q '"software"'; }

handles_ok() {
	curl -sS -m 20 -X POST -H 'Content-Type: application/json' \
		-d '{"h":"zzqq_watch_probe"}' "$1" 2>/dev/null | grep -q '"free":true'
}

# restarts at most once per HEAL_GAP, so a service that cannot start is not
# restarted in a loop
heal() {
	local name=$1
	shift
	local last=0
	[ -f "$STATE/$name.healed" ] && last=$(cat "$STATE/$name.healed")
	if [ $((now - last)) -lt "$HEAL_GAP" ]; then
		echo "watch: $name still down, restarted $(((now - last) / 60)) min ago"
		return
	fi
	echo "watch: $name down, restarting $*"
	[ "$DRY" = 1 ] && return
	echo "$now" >"$STATE/$name.healed"
	systemctl restart "$@"
}

# one line per change, so an alert fires when something goes down and when
# it comes back, not every two minutes
mark() {
	local name=$1 state=$2 was=""
	[ -f "$STATE/$name.state" ] && was=$(cat "$STATE/$name.state")
	report+=("$name $state")
	[ "$was" = "$state" ] && return
	echo "$state" >"$STATE/$name.state"
	[ -z "$was" ] && [ "$state" = up ] && return
	echo "watch: $name is $state"
	[ -n "$ALERT_CMD" ] && [ "$DRY" != 1 ] && $ALERT_CMD "kryfo $name is $state" || true
}

# the site
if [ "$(get "$SITE")" = 200 ]; then mark site up; else mark site down; fi

# the relay: from outside, then its own port to tell the bridge from the relay
if relay_ok "$RELAY"; then
	mark relay up
else
	mark relay down
	if relay_ok http://127.0.0.1:3334/; then
		heal relay-bridge halo-relay-bridge
	else
		heal relay halo-relay halo-relay-bridge
	fi
fi

# the handle registry, the same way
if handles_ok "${RELAY}handle/check"; then
	mark handles up
else
	mark handles down
	if handles_ok http://127.0.0.1:3336/handle/check; then
		heal handles-bridge kryfo-handles-bridge
	else
		heal handles kryfo-handles kryfo-handles-bridge
	fi
fi

# the badge service is only on its onion, so its own port is what can be seen
if [ "$(get "$BADGE")" = 200 ]; then
	mark badge up
else
	mark badge down
	[ -n "$BADGE_UNIT" ] && heal badge "$BADGE_UNIT"
fi

# room on the disk the relay, the registry and the site write to
free=$(df -P --block-size=1G / | awk 'NR==2 {print $4}')
if [ "${free:-0}" -ge "$MIN_FREE_GB" ]; then mark disk up; else mark disk low; fi

# certificates, three weeks ahead
for host in kryfo.app relay.kryfo.app; do
	end=$(echo | timeout 20 openssl s_client -servername "$host" -connect "$host:443" 2>/dev/null |
		openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
	if [ -z "$end" ]; then
		mark "cert-$host" unreadable
		continue
	fi
	days=$((($(date -d "$end" +%s) - now) / 86400))
	if [ "$days" -ge "$CERT_DAYS" ]; then mark "cert-$host" up; else mark "cert-$host" "ending-in-${days}d"; fi
done

{
	date -u +%FT%TZ
	printf '%s\n' "${report[@]}"
} >"$STATE/status.tmp" && mv "$STATE/status.tmp" "$STATE/status"
