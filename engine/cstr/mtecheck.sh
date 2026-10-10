#!/bin/bash
# runs the cstr tests for arm64 under qemu with glibc heap tagging, where a
# read past a string's nul traps the way it does on an mte phone. String has
# to pass and the old C.GoString has to fault with SEGV_MTESERR (code 9).
# needs docker and network for apt. usage: engine/cstr/mtecheck.sh
set -e
cd "$(dirname "$0")/.."
GOROOT_HOST="$(go env GOROOT)"
docker run --rm -v "$PWD":/src:ro -v "$GOROOT_HOST":/gotc:ro \
  debian:bookworm-20250630-slim bash -c '
set -e
apt-get update -qq >/dev/null
apt-get install -y -qq qemu-user gcc-aarch64-linux-gnu libc6-dev-arm64-cross >/dev/null 2>&1
export PATH=/gotc/bin:$PATH GOTOOLCHAIN=local GOCACHE=/tmp/gocache GOFLAGS="-mod=vendor -buildvcs=false"
cd /src
CC=aarch64-linux-gnu-gcc CGO_ENABLED=1 GOOS=linux GOARCH=arm64 \
  go test -c -tags mtecheck -o /tmp/cstr.test ./cstr
run() { qemu-aarch64 -cpu max -L /usr/aarch64-linux-gnu -E GLIBC_TUNABLES=glibc.mem.tagging=3 "$@"; }
echo "== cstr.String"
run /tmp/cstr.test -test.v -test.run "^(TestMTEOn|TestString)\$"
echo "== old C.GoString, has to crash"
if run -E MTECHECK_OLD=1 /tmp/cstr.test -test.v -test.run "^TestOldGoString\$" >/tmp/old.log 2>&1; then
  tail -5 /tmp/old.log
  echo "FAIL: old C.GoString did not trap, the check proves nothing"
  exit 1
fi
grep -m1 "SIGSEGV.*code=0x9" /tmp/old.log || { tail -20 /tmp/old.log; echo "FAIL: no mte fault"; exit 1; }
echo "ok: cstr.String passes, C.GoString traps"
'
