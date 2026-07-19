#!/bin/bash
# build-offline.sh - drop-in replacement for build.sh, fully offline after
# make-engine-offline.sh has been run once.
#   - -mod=vendor: use engine/vendor/, never the network
#   - GOCACHE=engine/.gocache: reuse compiled tor/openssl C objects between
#     builds so only the first build pays the ~700MB compile
#   - GOPROXY=off: hard guarantee nothing reaches out
set -e
NDK=$HOME/android-sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/bin
JNI=$HOME/halo/mobile/android/app/src/main/jniLibs
cd "$(dirname "$0")"

export GOFLAGS=-mod=vendor
export GOPROXY=off
export GOCACHE="$(pwd)/.gocache"

echo "→ arm64 (phone)…"
CC=$NDK/aarch64-linux-android27-clang CGO_ENABLED=1 GOOS=android GOARCH=arm64 \
  go build -buildmode=c-shared -o "$JNI/arm64-v8a/libhalo.so" .

echo "→ x86_64 (emulator)…"
CC=$NDK/x86_64-linux-android24-clang CGO_ENABLED=1 GOOS=android GOARCH=amd64 \
  go build -buildmode=c-shared -o "$JNI/x86_64/libhalo.so" .

ls -la "$JNI"/*/libhalo.so
echo "✓ both archs built (offline)"
