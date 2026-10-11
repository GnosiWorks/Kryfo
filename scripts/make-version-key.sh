#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# makes the ed25519 key that signs version.json, the file the app's update
# notice reads. the private half goes to the path given, under a passphrase,
# and never into a git tree. only the public half is printed: it goes into
# kVersionPubKeyB64 in mobile/lib/update_check.dart.
#
#   scripts/make-version-key.sh ~/offline/kryfo-version.pem
#
# KRYFO_VERSION_KEY_PASS in the environment skips the passphrase prompt.
set -euo pipefail
KEY="${1:-}"
if [ -z "$KEY" ] || [ "$KEY" = -h ] || [ "$KEY" = --help ]; then
  echo "usage: $0 <path for the private key, outside any git tree>" >&2
  exit 2
fi
[ -e "$KEY" ] && { echo "$KEY exists already, it is not overwritten" >&2; exit 2; }
DIR=$(dirname "$KEY")
[ -d "$DIR" ] || { echo "no folder $DIR" >&2; exit 2; }
if git -C "$DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "$DIR is inside a git tree: keep the key somewhere else" >&2
  exit 2
fi
command -v openssl >/dev/null || { echo "openssl is not installed" >&2; exit 2; }

if [ -z "${KRYFO_VERSION_KEY_PASS:-}" ]; then
  read -rsp "passphrase for the key: " a; echo >&2
  read -rsp "again: " b; echo >&2
  [ "$a" = "$b" ] || { echo "the two do not match" >&2; exit 2; }
  [ ${#a} -ge 12 ] || { echo "at least 12 characters" >&2; exit 2; }
  KRYFO_VERSION_KEY_PASS=$a
fi
export KRYFO_VERSION_KEY_PASS

umask 077
openssl genpkey -algorithm ed25519 -aes-256-cbc \
  -pass env:KRYFO_VERSION_KEY_PASS -out "$KEY"
echo "private key: $KEY (keep it offline, with a backup)" >&2
"$(dirname "$0")/sign-version.sh" --pubkey "$KEY"
