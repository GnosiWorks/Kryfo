#!/bin/bash
# builds libhalo.so for the linux desktop app, for the machine it runs on.
# mobile/linux/engine.cmake links it into the runner and bundles it.
# same offline flags as build.sh, without the ndk.
set -e
cd "$(dirname "$0")"
ENGINE_DIR="$(pwd)"

case "$(go env GOARCH)" in
  amd64) ARCH=x64 ;;
  arm64) ARCH=arm64 ;;
  *) echo "error: no flutter linux target for $(go env GOARCH)"; exit 1 ;;
esac
OUT="${HALO_LINUX_OUT:-$ENGINE_DIR/out/linux-$ARCH}"
mkdir -p "$OUT"

export GOFLAGS="-mod=vendor -trimpath"
export GOPROXY=off
export GOCACHE="${GOCACHE:-$ENGINE_DIR/.gocache}"
export CGO_ENABLED=1
export CGO_CFLAGS="-O2 -g -fstack-protector-strong -D_FORTIFY_SOURCE=2"
export CGO_LDFLAGS="-Wl,--build-id=none"
export SOURCE_DATE_EPOCH=1700000000

go build ${HALO_FULL:+-a} -buildvcs=false -buildmode=c-shared \
  -ldflags "-buildid= -w -s" -o "$OUT/libhalo.so" .
rm -f "$OUT/libhalo.h"
ls -la "$OUT/libhalo.so"
