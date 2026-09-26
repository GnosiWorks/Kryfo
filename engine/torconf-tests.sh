#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# the tests that need a real tor and the real network. each one runs in its
# own process: under one -run regex they share one tor, and a test that
# inherits someone else's tor measures that one instead of its own.
#
#   cd engine && ./torconf-tests.sh            # the lot, about 30 minutes
#   cd engine && ./torconf-tests.sh TestReconnect
set -u
cd "$(dirname "$0")"
ulimit -n "$(ulimit -Hn)"
tests=(
	TestSleepWakeThenModeSwitch
	TestReconnect
	TestRegistryOverTor
	TestClaimAfterNetworkBounce
	TestOneShotsSurviveBounce
	TestControlPortNeverAnswers
	TestReconnectOutcomeDoesNotNest
	TestOutcomeSaysRunningWhileRunning
)
[ $# -gt 0 ] && tests=("$@")
failed=()
for t in "${tests[@]}"; do
	echo "== $t"
	go test -tags torconf -count=1 -timeout 25m -run "^${t}\$" -v . 2>&1 |
		grep -E '^(=== |--- |ok|FAIL|panic)|_test\.go:[0-9]+:'
	[ "${PIPESTATUS[0]}" -eq 0 ] || failed+=("$t")
done
if [ ${#failed[@]} -gt 0 ]; then
	echo "FAILED: ${failed[*]}"
	exit 1
fi
echo "all ${#tests[@]} passed"
