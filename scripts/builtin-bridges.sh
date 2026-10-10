#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# release step: refreshes engine/builtin.json from moat's builtin call,
# over meek through the engine's own client, and shows the diff. read it
# before committing. a line with a host that is not in reviewedHosts
# (engine/builtin.go) stops the run until the host is reviewed and added.
#
#   scripts/builtin-bridges.sh
set -euo pipefail
cd "$(dirname "$0")/../engine"
ulimit -n "$(ulimit -Hn)"
new="$(mktemp)"
trap 'rm -f "$new"' EXIT
GOFLAGS=-mod=vendor GOPROXY=off BUILTIN_OUT="$new" \
	go test -tags moatlive -count=1 -run '^TestBuiltinRelease$' -v . |
	grep -E '^(--- |ok|FAIL)|_test\.go:[0-9]+:'
[ -s "$new" ] || { echo "no new set written"; exit 1; }
# the same checks the bundled set gets, a line per transport included
GOFLAGS=-mod=vendor GOPROXY=off BUILTIN_FILE="$new" \
	go test -count=1 -run '^TestBundledBuiltins$' . >/dev/null ||
	{ echo "the new set fails the bundled-builtins check"; exit 1; }
rc=0
diff -u builtin.json "$new" || rc=$?
case $rc in
0) echo "builtin.json is current" ;;
1)
	cp "$new" builtin.json
	echo "builtin.json updated, review the diff above"
	;;
*)
	echo "diff failed"
	exit 1
	;;
esac
