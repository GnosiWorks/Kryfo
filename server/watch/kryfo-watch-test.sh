#!/bin/bash
# runs kryfo-watch.sh against stand-ins for curl, df, systemctl, openssl and
# the clock, and checks what it decides: what it marks, what it restarts,
# what it sends.
# nothing here reaches the network or a real unit.
#
#   server/watch/kryfo-watch-test.sh
set -u
unset MIN_FREE_GB HEAL_GAP CERT_DAYS BADGE BADGE_UNIT NTFY_URL NTFY_OPTS
here=$(cd "$(dirname "$0")" && pwd)
REAL_DATE=$(command -v date)
export REAL_DATE
gap=900
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin=$tmp/bin
mkdir -p "$bin"

# answers from $FAKE/routes, one "url-part code body" a line, first match
# wins. code 0 is no answer at all
cat >"$bin/curl" <<'EOF'
#!/bin/bash
url='' wfmt='' out=''
while [ $# -gt 0 ]; do
	case $1 in
	-w) wfmt=$2 && shift ;;
	-o) out=$2 && shift ;;
	-m | -X | -H | -d) shift ;;
	http*) url=$1 ;;
	esac
	shift
done
code=0 body=''
while read -r part c b; do
	case $url in *"$part"*) code=$c body=$b && break ;; esac
done <"$FAKE/routes"
[ "$code" = 0 ] || [ "$out" = /dev/null ] || printf '%s\n' "$body"
[ -n "$wfmt" ] && printf '%b' "${wfmt//'%{http_code}'/$(printf '%03d' "$code")}"
[ "$code" = 0 ] && exit 7
exit 0
EOF

cat >"$bin/df" <<'EOF'
#!/bin/bash
echo "${*: -1}" >>"$FAKE/df.log"
[ -f "$FAKE/avail" ] || exit 1
echo "Filesystem 1-blocks Used Available Capacity Mounted on"
echo "/dev/sda1 100 50 $(cat "$FAKE/avail") 50% /"
EOF

cat >"$bin/systemctl" <<'EOF'
#!/bin/bash
echo "$*" >>"$FAKE/systemctl.log"
[ -f "$FAKE/tick" ] && echo "$(cat "$FAKE/tick") $*" >>"$FAKE/restarts.log"
exit 0
EOF

# the watcher's clock: the case's own when it keeps one, in seconds from
# the case's start
cat >"$bin/date" <<'EOF'
#!/bin/bash
if [ "$*" = +%s ] && [ -f "$FAKE/tick" ]; then
	echo $((1800000000 + $(cat "$FAKE/tick")))
	exit 0
fi
exec "$REAL_DATE" "$@"
EOF

cat >"$bin/openssl" <<'EOF'
#!/bin/bash
cat >/dev/null
[ "$1" = x509 ] && echo "notAfter=Jan  1 00:00:00 2099 GMT"
exit 0
EOF

cat >"$bin/alert" <<'EOF'
#!/bin/bash
echo "$*" >>"$FAKE/alerts.log"
EOF
chmod +x "$bin"/*

failed=0
fail() {
	echo "FAIL $name: $*"
	failed=$((failed + 1))
}

# a fresh state, every service answering, 10 GiB free
fresh() {
	name=$1
	export FAKE=$tmp/$name
	rm -rf "$FAKE"
	mkdir -p "$FAKE/state"
	: >"$FAKE/systemctl.log"
	: >"$FAKE/restarts.log"
	: >"$FAKE/alerts.log"
	echo $((10 << 30)) >"$FAKE/avail"
	routes '{"free":true}' 200 '{"free":true}' 200
}

# what the registry answers from outside and on its own port
routes() {
	cat >"$FAKE/routes" <<EOF
relay.test/handle/check $2 $1
127.0.0.1:3336/handle/check $4 $3
relay.test/ 200 {"software":"khatru"}
127.0.0.1:3334/ 200 {"software":"khatru"}
site.test/ 200 ok
127.0.0.1:8899/pubkey 200 ok
EOF
}

watch() {
	PATH=$bin:$PATH WATCH_ENV=/dev/null STATE=$FAKE/state SITE=http://site.test/ \
		RELAY=http://relay.test/ ALERT_CMD=$bin/alert RELAY_DATA=/srv/relay/data \
		HEAL_GAP=$gap DRY=0 "$here/kryfo-watch.sh" >/dev/null 2>&1
}

status() { grep -qx "$1" "$FAKE/state/status" || fail "status has no \"$1\""; }
restarted() { [ "$(cat "$FAKE/systemctl.log")" = "$1" ] || fail "restarted \"$(cat "$FAKE/systemctl.log")\", wanted \"$1\""; }
alerted() { [ "$(cat "$FAKE/alerts.log")" = "$1" ] || fail "alerts \"$(cat "$FAKE/alerts.log")\", wanted \"$1\""; }
# each restart with the second of the case it came at
restarts() { [ "$(cat "$FAKE/restarts.log")" = "$1" ] || fail "restarts \"$(paste -sd, "$FAKE/restarts.log")\", wanted \"$(paste -sd, <<<"$1")\""; }

tick() { echo "$1" >"$FAKE/tick"; }

# one answer at 120 s, the one in the arguments as routes takes them. then
# no answer at all from 240 s to 2040 s, a run every two minutes, and at
# 2160 s the registry is back, with the name it is asked about taken
answer_then_outage() {
	fresh "$1"
	shift
	tick 0
	watch
	tick 120
	routes "$@"
	watch
	cp "$FAKE/state/status" "$FAKE/after-answer"
	cp "$FAKE/restarts.log" "$FAKE/after-answer-restarts"
	routes '' 0 '' 0
	local s
	for ((s = 240; s <= 2040; s += 120)); do
		tick "$s"
		watch
		grep -qx "handles down" "$FAKE/state/status" || fail "not down at $s s"
	done
	tick 2160
	routes '{"free":false}' 200 '{"free":false}' 200
	watch
	status "handles up"
}

# how the one answer was marked, and what it restarted
after_answer() {
	grep -qx "$1" "$FAKE/after-answer" || fail "after the answer, status has no \"$1\""
	[ "$(cat "$FAKE/after-answer-restarts")" = "$2" ] ||
		fail "after the answer, restarts \"$(paste -sd, "$FAKE/after-answer-restarts")\", wanted \"$2\""
}

all='restart kryfo-handles kryfo-handles-bridge'

fresh busy_registry_is_up
watch
routes 'slow down' 429 'slow down' 429
watch
status "handles up"
restarted ""
alerted ""

fresh registry_that_stops_answering_is_restarted
watch
routes '' 0 '' 0
watch
status "handles down"
restarted "restart kryfo-handles kryfo-handles-bridge"
alerted "handles down"

fresh busy_on_its_own_port_restarts_only_the_bridge
watch
routes '<html>bad gateway</html>' 502 'slow down' 429
watch
status "handles down"
restarted "restart kryfo-handles-bridge"

fresh a_429_without_the_registrys_words_is_no_answer
watch
routes '<html>too many requests</html>' 429 '' 0
watch
status "handles down"
restarted "restart kryfo-handles kryfo-handles-bridge"

fresh down_then_busy_is_back_up
watch
routes '' 0 '' 0
watch
routes 'slow down' 429 'slow down' 429
watch
status "handles up"
alerted "handles down
handles up"

fresh a_200_without_the_registrys_words_is_no_answer
watch
routes '<html>maintenance</html>' 200 '' 0
watch
status "handles down"
restarted "$all"

# the name the probe asks about is free or taken as anyone makes it: both
# are the registry answering. an outage after any answer is one alert, a
# restart at once and one more each HEAL_GAP ($gap s) while it lasts
answer_then_outage taken_name_then_outage '{"free":false}' 200 '{"free":false}' 200
after_answer "handles up" ""
restarts "240 $all
1200 $all"
alerted "handles down
handles up"

answer_then_outage free_name_then_outage '{"free":true}' 200 '{"free":true}' 200
after_answer "handles up" ""
restarts "240 $all
1200 $all"
alerted "handles down
handles up"

answer_then_outage busy_then_outage 'slow down' 429 'slow down' 429
after_answer "handles up" ""
restarts "240 $all
1200 $all"
alerted "handles down
handles up"

answer_then_outage gateway_error_then_outage '<html>502 bad gateway</html>' 502 '<html>500</html>' 500
after_answer "handles down" "120 $all"
restarts "120 $all
1080 $all
2040 $all"
alerted "handles down
handles up"

answer_then_outage no_answer_then_outage '' 0 '' 0
after_answer "handles down" "120 $all"
restarts "120 $all
1080 $all
2040 $all"
alerted "handles down
handles up"

# its own port answers with the name taken, so only the bridge is down
answer_then_outage gateway_error_on_a_running_registry_then_outage \
	'<html>502 bad gateway</html>' 502 '{"free":false}' 200
after_answer "handles down" "120 restart kryfo-handles-bridge"
restarts "120 restart kryfo-handles-bridge
240 $all
1200 $all"
alerted "handles down
handles up"

fresh disk_is_read_where_the_relay_keeps_its_data
watch
[ "$(sort -u "$FAKE/df.log")" = /srv/relay/data ] || fail "df asked about $(sort -u "$FAKE/df.log" | tr '\n' ' ')"
status "disk up"

fresh just_over_a_gib_is_low
echo $(((1 << 30) + (10 << 20))) >"$FAKE/avail"
watch
status "disk low"

fresh under_three_gib_is_low
echo $(((3 << 30) - 1)) >"$FAKE/avail"
watch
status "disk low"

fresh three_gib_is_up
echo $((3 << 30)) >"$FAKE/avail"
watch
status "disk up"

fresh no_answer_from_df_is_unreadable
rm "$FAKE/avail"
watch
status "disk unreadable"

if [ "$failed" -gt 0 ]; then
	echo "$failed failed"
	exit 1
fi
echo "all passed"
