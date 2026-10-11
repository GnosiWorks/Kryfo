#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# signs version.json, the file the app's update notice reads from
# kryfo.app. writes version.json and version.json.sig (base64 of the raw
# ed25519 signature) into the site's static/ folder, which site/build.py
# copies to the root of public/. the version has to be the one in
# site/l10n/release.json.
#
#   scripts/sign-version.sh 0.5.1 ~/offline/kryfo-version.pem [site folder]
#   scripts/sign-version.sh --pubkey ~/offline/kryfo-version.pem
#
# the site folder defaults to site/ in this checkout. --pubkey prints the
# public half the app must pin. KRYFO_VERSION_KEY_PASS in the environment
# skips the passphrase prompt.
set -euo pipefail
command -v openssl >/dev/null || { echo "openssl is not installed" >&2; exit 2; }

usage() { sed -n '9,10p' "$0" | sed 's/^#   /usage: /' >&2; exit 2; }

# asks once for the passphrase of an encrypted key, for every openssl call
passphrase() {
  if grep -q ENCRYPTED "$1" && [ -z "${KRYFO_VERSION_KEY_PASS:-}" ]; then
    read -rsp "passphrase for $1: " KRYFO_VERSION_KEY_PASS; echo >&2
  fi
  export KRYFO_VERSION_KEY_PASS="${KRYFO_VERSION_KEY_PASS:-}"
}

# the raw 32 bytes of the public key, base64, as the app pins it
pubkey() {
  openssl pkey -in "$1" -passin env:KRYFO_VERSION_KEY_PASS -pubout -outform DER |
    tail -c 32 | openssl base64 -A
  echo
}

if [ "${1:-}" = --pubkey ]; then
  KEY="${2:-}"
  [ -f "$KEY" ] || usage
  passphrase "$KEY"
  echo "public key (kVersionPubKeyB64 in mobile/lib/update_check.dart):" >&2
  pubkey "$KEY"
  exit 0
fi

VERSION="${1:-}"
KEY="${2:-}"
SITE="${3:-$(cd "$(dirname "$0")/.." && pwd)/site}"
[ -n "$VERSION" ] && [ -f "$KEY" ] || usage
[[ "$VERSION" =~ ^[0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,4}$ ]] || {
  echo "the version is x.y.z: $VERSION" >&2; exit 2; }
[ -f "$SITE/build.py" ] && [ -d "$SITE/static" ] || {
  echo "no site at $SITE (build.py and static/)" >&2; exit 2; }
REL="$SITE/l10n/release.json"
if [ -f "$REL" ]; then
  HAVE=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$REL")
  [ "$HAVE" = "$VERSION" ] || {
    echo "release.json is at $HAVE, not $VERSION: run site/release.py first" >&2; exit 2; }
fi

passphrase "$KEY"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
printf '{"app":"kryfo","version":"%s"}\n' "$VERSION" > "$WORK/version.json"
openssl pkeyutl -sign -inkey "$KEY" -passin env:KRYFO_VERSION_KEY_PASS -rawin \
  -in "$WORK/version.json" -out "$WORK/sig"
# checked against the public half before anything is written
openssl pkey -in "$KEY" -passin env:KRYFO_VERSION_KEY_PASS -pubout -out "$WORK/pub.pem"
openssl pkeyutl -verify -pubin -inkey "$WORK/pub.pem" -rawin \
  -in "$WORK/version.json" -sigfile "$WORK/sig" >/dev/null
[ "$(wc -c < "$WORK/sig")" -eq 64 ] || { echo "not an ed25519 signature" >&2; exit 2; }
{ openssl base64 -A < "$WORK/sig"; echo; } > "$WORK/version.json.sig"
cp "$WORK/version.json" "$WORK/version.json.sig" "$SITE/static/"
echo "signed $VERSION into $SITE/static/version.json and version.json.sig" >&2
echo "with the public key $(pubkey "$KEY")" >&2
echo "then: site/build.py && site/check.py" >&2
