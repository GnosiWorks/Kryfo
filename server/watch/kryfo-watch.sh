#!/bin/bash
# checks every service the way a phone reaches it, through the front proxy,
# and restarts what is down. the registry went dark twice with every unit
# "active": a bridge was down, and only a request from outside shows that.
# run by kryfo-watch.timer. DRY=1 checks and restarts nothing.
set -u

ENV=${WATCH_ENV:-/etc/kryfo-watch.env}
[ -r "$ENV" ] && . "$ENV"
STATE=${STATE:-/var/lib/kryfo-watch}
SITE=${SITE:-https://kryfo.app/}
RELAY=${RELAY:-https://relay.kryfo.app/}
BADGE=${BADGE:-http://127.0.0.1:8899/pubkey}
BADGE_UNIT=${BADGE_UNIT:-}
# the relay stops taking wraps below 2 GiB free where its database lives
# (relay-live/limits.go), so warn above that
MIN_FREE_GB=${MIN_FREE_GB:-3}
RELAY_DATA=${RELAY_DATA:-/opt/halo-relay/data}
CERT_DAYS=${CERT_DAYS:-21}
HEAL_GAP=${HEAL_GAP:-900}
ALERT_CMD=${ALERT_CMD:-}
# an ntfy topic url. the topic is the only secret: make it long and random
NTFY_URL=${NTFY_URL:-}
# extra curl options for ntfy, e.g. -4: ntfy.sh counts a whole ipv6 /64 as
# one sender, and a hosting provider's /64 can be over its limit already
NTFY_OPTS=${NTFY_OPTS:-}
DRY=${DRY:-0}
mkdir -p "$STATE"
now=$(date +%s)
report=()

get() { curl -sS -m 20 -o /dev/null -w '%{http_code}' "$@" 2>/dev/null; }

relay_ok() { curl -sS -m 20 -H 'Accept: application/nostr+json' "$1" 2>/dev/null | grep -q '"software"'; }

# up, busy or down. any answer that is the registry's own is up: free or
# taken alike, since anyone can claim the name asked about. busy is its
# "slow down", when readers have used up the rate they share: it is
# running, and a restart would not help. anything else, a proxy's page
# included, is down
handles_state() {
	local out
	out=$(curl -sS -m 20 -X POST -H 'Content-Type: application/json' \
		-d '{"h":"zzqq_watch_probe"}' -w '\n%{http_code}' "$1" 2>/dev/null)
	case "${out##*$'\n'}" in
	200) grep -Eq '"free":(true|false)' <<<"$out" && echo up && return ;;
	429) grep -q '^slow down' <<<"$out" && echo busy && return ;;
	esac
	echo down
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
	[ "$DRY" = 1 ] && return
	# the service and what happened, nothing else
	# shellcheck disable=SC2086
	[ -n "$NTFY_URL" ] && { curl -fsS -m 15 $NTFY_OPTS -o /dev/null -d "$name $state" "$NTFY_URL" || echo "watch: the alert did not go out"; }
	[ -n "$ALERT_CMD" ] && $ALERT_CMD "$name $state"
	return 0
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
seen=$(handles_state "${RELAY}handle/check")
if [ "$seen" != down ]; then
	mark handles up
	[ "$seen" = busy ] && echo "watch: handles busy"
else
	mark handles down
	if [ "$(handles_state http://127.0.0.1:3336/handle/check)" != down ]; then
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

# room where the relay's database lives, in bytes: df's own units round up
free=$(df -P -B1 "$RELAY_DATA" 2>/dev/null | awk 'NR==2 {print $4}')
if ! [[ "$free" =~ ^[0-9]+$ ]]; then
	mark disk unreadable
elif [ "$free" -ge $((MIN_FREE_GB << 30)) ]; then
	mark disk up
else
	mark disk low
fi

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
