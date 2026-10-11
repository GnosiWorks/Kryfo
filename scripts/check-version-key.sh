#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# prints the version key the app pins (kVersionPubKeyB64 in
# mobile/lib/update_check.dart) and fails while it is the placeholder or not
# 32 bytes of base64. release.sh and sign-version.sh both ask it.
#
#   scripts/check-version-key.sh [update_check.dart, or - for stdin]
set -euo pipefail
SRC="${1:-$(dirname "$0")/../mobile/lib/update_check.dart}"
if [ "$SRC" = - ]; then TEXT=$(cat); else TEXT=$(cat "$SRC"); fi
PIN=$(printf '%s' "$TEXT" | tr -d '\n' |
  sed -n "s/.*const kVersionPubKeyB64 *= *'\([A-Za-z0-9+\/=]*\)'.*/\1/p")
if [ -z "$PIN" ]; then
  echo "the app pins no version key (the placeholder?): see RELEASING.md, update notice" >&2
  exit 2
fi
if [ "$(printf '%s' "$PIN" | openssl base64 -d -A 2>/dev/null | wc -c)" -ne 32 ]; then
  echo "the pinned version key is not 32 bytes: $PIN" >&2
  exit 2
fi
echo "$PIN"
