#!/bin/bash
# runs inside the offline image. builds all three libhalo.so with every
# known source of non-determinism stripped, then prints sha256 so they can
# be set against the libs in a shipped apk. engine only: the whole-apk
# check is build-repro.sh in the other image.
set -e

OUT=/build/out
mkdir -p "$OUT/arm64-v8a" "$OUT/armeabi-v7a" "$OUT/x86_64"

# -buildid= clears go's random build id. -w -s drop debug tables (also a
# repro win - dwarf carries paths). the ndk linker gets --build-id=none so
# lld doesn't stamp a random note. trimpath comes from GOFLAGS in the image.
LDFLAGS="-buildid= -w -s"
export CGO_LDFLAGS="-Wl,--build-id=none"
# no git stamp, same as engine/build.sh: the mounted tree has no .git and
# the shipped engine must not carry a commit either
export GOFLAGS="$GOFLAGS -buildvcs=false"

echo "arm64..."
CC="$NDK/aarch64-linux-android27-clang" \
  GOOS=android GOARCH=arm64 \
  go build -buildmode=c-shared -ldflags "$LDFLAGS" \
  -o "$OUT/arm64-v8a/libhalo.so" .

echo "armeabi-v7a..."
CC="$NDK/armv7a-linux-androideabi24-clang" \
  GOOS=android GOARCH=arm GOARM=7 \
  go build -buildmode=c-shared -ldflags "$LDFLAGS" \
  -o "$OUT/armeabi-v7a/libhalo.so" .

echo "x86_64..."
CC="$NDK/x86_64-linux-android24-clang" \
  GOOS=android GOARCH=amd64 \
  go build -buildmode=c-shared -ldflags "$LDFLAGS" \
  -o "$OUT/x86_64/libhalo.so" .

echo
echo "sha256 (compare these against the shipped apk's libs):"
cd "$OUT"
sha256sum arm64-v8a/libhalo.so armeabi-v7a/libhalo.so x86_64/libhalo.so
