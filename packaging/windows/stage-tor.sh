#!/bin/bash
# stages tor for the windows installer from the pinned expert bundle.
#   stage-tor.sh <tor-expert-bundle.tar.gz>   check it, unpack tor/ to build/windows/tor
#   stage-tor.sh --check-dll <halo.dll>       the dll was built with the same pin
# a bundle, tor.exe or dll that does not match tor-pin.txt stops the build.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PIN="${TOR_PIN:-$HERE/tor-pin.txt}"
OUT="${TOR_STAGE:-$HERE/../build/windows/tor}"
VENDOR="${TOR_LICENSES:-$HERE/../../engine/vendor/github.com/alexballas/go-libtor/linux}"

pin() { sed -n "s/^$1=//p" "$PIN"; }
sha() { sha256sum "$1" | cut -d' ' -f1; }
hex64() { [[ "$1" =~ ^[0-9a-f]{64}$ ]]; }

want_exe="$(pin TOR_EXE_SHA256)"
hex64 "$want_exe" || { echo "FAIL: no TOR_EXE_SHA256 in $PIN"; exit 1; }
# a real halo.dll has runs of 64 zeros in its data, so the placeholder
# would pass the dll check below
[[ "$want_exe" =~ ^0+$ ]] && { echo "FAIL: TOR_EXE_SHA256 in $PIN is the placeholder"; exit 1; }

if [ "${1:-}" = --check-dll ]; then
  dll="${2:?usage: stage-tor.sh --check-dll halo.dll}"
  # -X main.torExeSHA256 leaves the hex string as is in the dll's data
  grep -qaF "$want_exe" "$dll" \
    || { echo "FAIL: $dll does not pin tor.exe $want_exe"; exit 1; }
  echo "halo.dll pins tor.exe $want_exe"
  exit 0
fi

tarball="${1:?usage: stage-tor.sh tor-expert-bundle.tar.gz}"
want_tar="$(pin TOR_BUNDLE_SHA256)"
hex64 "$want_tar" || { echo "FAIL: no TOR_BUNDLE_SHA256 in $PIN"; exit 1; }
got="$(sha "$tarball")"
[ "$got" = "$want_tar" ] || { echo "FAIL: bundle sha256 $got, pinned $want_tar"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
tar -xzf "$tarball" -C "$tmp" --no-same-owner --no-same-permissions
[ -f "$tmp/tor/tor.exe" ] || { echo "FAIL: no tor/tor.exe in the bundle"; exit 1; }
got="$(sha "$tmp/tor/tor.exe")"
[ "$got" = "$want_exe" ] || { echo "FAIL: tor.exe sha256 $got, pinned $want_exe"; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT/licenses"
# only the files next to tor.exe: the engine runs the pluggable transports
# itself, so tor/pluggable_transports stays out
find "$tmp/tor" -maxdepth 1 -type f -exec cp {} "$OUT/" \;
cp "$VENDOR/tor/LICENSE" "$OUT/licenses/tor.txt"
cp "$VENDOR/libevent/LICENSE" "$OUT/licenses/libevent.txt"
echo "staged tor $(pin TOR_BUNDLE_VERSION) in $OUT"
