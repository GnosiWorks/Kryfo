#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# says no to engines that carry the test censor (censor_on.go). every file
# named must exist; with none named, or one missing, it says no as well.
#
#   engine/censor-scan.sh path/to/libhalo.so ...
set -u
[ $# -gt 0 ] || { echo "censor-scan: no engine to look at" >&2; exit 1; }
for f in "$@"; do
  [ -f "$f" ] || { echo "censor-scan: $f is missing" >&2; exit 1; }
  if grep -aq 'kryfo test censor build' "$f"; then
    echo "censor-scan: $f is a test engine that acts as if tor were blocked" >&2
    exit 1
  fi
done
