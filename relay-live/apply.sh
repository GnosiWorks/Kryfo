#!/bin/sh
# retention for the relay that is actually in production.
#
# IMPORTANT: ~/halo/relay and ~/halo/dmrelay are NOT what runs. the live relay
# source lives on the box at /opt/halo-relay/main.go and was never committed.
# this script expects you to have copied it into ~/halo/relay-live/ first:
#
#   scp ubuntu@57.129.122.187:/opt/halo-relay/main.go ~/halo/relay-live/
#   scp ubuntu@57.129.122.187:/opt/halo-relay/go.* ~/halo/relay-live/
#
# run from ~/halo/relay-live
set -e
cp retention.go .
python3 - << 'PY'
import io
p = 'main.go'
s = io.open(p, encoding='utf-8').read()
old = "\tfmt.Println(\"halo relay listening on\", addr)"
assert s.count(old) == 1, 'anchor x%d' % s.count(old)
# fourteen days and then it is gone. the sweeper takes the same store the
# relay does, so there is one source of truth about what exists.
s = s.replace(old, "\tstartSweeper(&db)\n\n" + old)
io.open(p, 'w', encoding='utf-8').write(s)
print('sweeper started')
PY
echo "now: go mod tidy && go build ./"
