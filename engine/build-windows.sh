#!/bin/bash
# builds halo.dll for windows amd64 on linux with mingw-w64, offline from
# ./vendor. go-libtor builds for linux and android only, so this engine has
# no tor inside: it starts tor\tor.exe next to the app (tor_process_windows.go).
#
# TOR_EXE=path/to/tor.exe pins that file's sha256 into the dll, and the
# engine refuses any other tor.exe. without a pin it refuses to build,
# unless HALO_DEV=1, a dev build that takes any tor.exe.
set -e
cd "$(dirname "$0")"
ENGINE_DIR="$(pwd)"

LDFLAGS="-buildid= -w -s"
if [ -n "${TOR_EXE:-}" ]; then
  [ -f "$TOR_EXE" ] || { echo "error: no file at TOR_EXE=$TOR_EXE"; exit 1; }
  SUM="$(sha256sum "$TOR_EXE" | cut -d' ' -f1)"
  LDFLAGS="$LDFLAGS -X main.torExeSHA256=$SUM"
  echo "tor.exe pinned: $SUM"
elif [ "${HALO_DEV:-}" = 1 ]; then
  LDFLAGS="$LDFLAGS -X main.torExeDev=1"
  echo "dev build: any tor.exe is taken"
else
  echo "error: set TOR_EXE to the tor.exe the app ships, or HALO_DEV=1 for a dev build"
  exit 1
fi

CC="${CC:-x86_64-w64-mingw32-gcc}"
command -v "$CC" >/dev/null || { echo "error: $CC not found (mingw-w64)"; exit 1; }

OUT="${HALO_WINDOWS_OUT:-$ENGINE_DIR/out/windows-x64}"
mkdir -p "$OUT"

export GOFLAGS="-mod=vendor -trimpath"
export GOPROXY=off
export GOCACHE="${GOCACHE:-$ENGINE_DIR/.gocache}"
export CGO_ENABLED=1 GOOS=windows GOARCH=amd64 CC
# the only c left on windows is cgo's glue, nothing that parses network
# bytes, and mingw has no libssp for -fstack-protector here
export CGO_CFLAGS="-O2 -g"
# a zero pe timestamp, so the build can reproduce. aslr and dep set by hand,
# check-pe.sh checks them
export CGO_LDFLAGS="-Wl,--no-insert-timestamp -Wl,--dynamicbase,--high-entropy-va,--nxcompat"
export SOURCE_DATE_EPOCH=1700000000

echo "windows amd64"
go build ${HALO_FULL:+-a} -buildvcs=false -buildmode=c-shared \
  -ldflags "$LDFLAGS" -o "$OUT/halo.dll" .
# exports are exactly the header's Halo calls, imports only windows' own
CHECK="$ENGINE_DIR/../packaging/windows/check-pe.sh"
want=$(grep -oE '^extern [^(]*\bHalo[A-Za-z0-9_]*\(' "$OUT/halo.h" | grep -oE 'Halo[A-Za-z0-9_]*' | sort -u)
rm -f "$OUT/halo.h"
got=$("$CHECK" --exports "$OUT/halo.dll" | sort -u)
[ -n "$want" ] && [ "$got" = "$want" ] || {
  echo "error: halo.dll exports differ from halo.h: $(diff <(echo "$want") <(echo "$got") | grep '^[<>]' | tr '\n' ' ')"
  exit 1
}
"$CHECK" "$OUT/halo.dll"
ls -la "$OUT/halo.dll"
