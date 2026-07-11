#!/bin/bash
# runs inside the pinned container. builds both arch libhalo.so with every
# known source of non-determinism stripped, then prints sha256 so a verifier
# can compare against the shipped binary.
set -e

OUT=/build/out
mkdir -p "$OUT/arm64-v8a" "$OUT/x86_64"

# -buildid= clears go's random build id. -w -s drop debug tables (also a
# repro win - dwarf carries paths). the ndk linker gets --build-id=none so
# lld doesn't stamp a random note. trimpath comes from GOFLAGS in the image.
LDFLAGS="-buildid= -w -s"
CFLAGS_REPRO="-Wl,--build-id=none"

echo "arm64..."
CC="$NDK/aarch64-linux-android27-clang $CFLAGS_REPRO" \
  GOOS=android GOARCH=arm64 \
  go build -buildmode=c-shared -ldflags "$LDFLAGS" \
  -o "$OUT/arm64-v8a/libhalo.so" .

echo "x86_64..."
CC="$NDK/x86_64-linux-android24-clang $CFLAGS_REPRO" \
  GOOS=android GOARCH=amd64 \
  go build -buildmode=c-shared -ldflags "$LDFLAGS" \
  -o "$OUT/x86_64/libhalo.so" .

echo
echo "sha256 (compare these against the shipped apk's libs):"
cd "$OUT"
sha256sum arm64-v8a/libhalo.so x86_64/libhalo.so
