#!/bin/sh
# builds the engine for this computer, for the tests that need its own
# crypto (test/host_engine.dart): host_engine.sh [engine dir] [out]
set -eu
here=$(cd "$(dirname "$0")" && pwd)
src=$(cd "${1:-$here/../../engine}" && pwd)
out=${2:-$src/build/host/libhalo.so}
mkdir -p "$(dirname "$out")"
cd "$src"
GOFLAGS="-mod=vendor -trimpath" GOPROXY=off CGO_ENABLED=1 \
  go build -buildvcs=false -buildmode=c-shared -o "$out" .
rm -f "${out%.so}.h"
echo "$out"
