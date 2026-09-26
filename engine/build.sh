#!/bin/bash
# READ BEFORE TOUCHING ./vendor: three headers under
# vendor/github.com/alexballas/go-libtor are patched by hand, see
# VENDOR_PATCHES.md. upstream ships 64-bit ones for every target, and without
# the patch the 32-bit engine builds but tor never bootstraps.
# `go mod vendor` wipes those patches, do not run it. go's cache does not see
# the headers change either, so after any edit to them: HALO_FULL=1 ./build.sh
#
# builds libhalo.so for android, offline: deps come from ./vendor and the c
# objects are cached in ./.gocache. the ndk is ANDROID_NDK_HOME,
# ANDROID_NDK_ROOT, NDK_HOME or the newest in $ANDROID_HOME/ndk.
set -e
cd "$(dirname "$0")"
ENGINE_DIR="$(pwd)"

# ── locate the ndk ──
NDK_ROOT="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-${NDK_HOME:-}}}"
if [ -z "$NDK_ROOT" ]; then
  SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/android-sdk}}"
  if [ -d "$SDK/ndk" ]; then
    # highest version present
    NDK_ROOT="$SDK/ndk/$(ls "$SDK/ndk" | sort -V | tail -1)"
  fi
fi
if [ ! -d "$NDK_ROOT" ]; then
  echo "error: android ndk not found."
  echo "set ANDROID_NDK_HOME, or install the ndk under \$ANDROID_HOME/ndk/"
  exit 1
fi
NDK="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin"
[ -d "$NDK" ] || { echo "error: no linux-x86_64 toolchain in $NDK_ROOT"; exit 1; }

# ── output dir, relative to this script ──
JNI="${JNI_LIBS_DIR:-$ENGINE_DIR/../mobile/android/app/src/main/jniLibs}"
mkdir -p "$JNI/arm64-v8a" "$JNI/armeabi-v7a" "$JNI/x86_64"

# ── offline, reproducible-ish flags ──
export GOFLAGS="-mod=vendor -trimpath"
export GOPROXY=off
export GOCACHE="${GOCACHE:-$ENGINE_DIR/.gocache}"
export CGO_ENABLED=1
# tor, openssl, libevent and zlib are c that parses network bytes, so they
# get a stack protector and fortify on top of cgo's default -O2 -g.
export CGO_CFLAGS="-O2 -g -fstack-protector-strong -D_FORTIFY_SOURCE=2"
export CGO_LDFLAGS="-Wl,--build-id=none"
export SOURCE_DATE_EPOCH=1700000000
LDFLAGS="-buildid= -w -s"
# go does not track the vendored c headers, HALO_FULL=1 rebuilds every object
BUILD_FLAGS="${HALO_FULL:+-a}"
# no vcs stamp: the commit and dirty flag differ between machines, so the
# build would not reproduce
BUILD_FLAGS="$BUILD_FLAGS -buildvcs=false"

echo "ndk: $NDK_ROOT"
echo "out: $JNI"

echo "→ arm64 (phone)…"
CC="$NDK/aarch64-linux-android27-clang" GOOS=android GOARCH=arm64 \
  go build $BUILD_FLAGS -buildmode=c-shared -ldflags "$LDFLAGS" -o "$JNI/arm64-v8a/libhalo.so" .

echo "→ armeabi-v7a (32-bit phones)…"
CC="$NDK/armv7a-linux-androideabi24-clang" GOOS=android GOARCH=arm GOARM=7 \
  go build $BUILD_FLAGS -buildmode=c-shared -ldflags "$LDFLAGS" -o "$JNI/armeabi-v7a/libhalo.so" .

echo "→ x86_64 (emulator)…"
CC="$NDK/x86_64-linux-android24-clang" GOOS=android GOARCH=amd64 \
  go build $BUILD_FLAGS -buildmode=c-shared -ldflags "$LDFLAGS" -o "$JNI/x86_64/libhalo.so" .

ls -la "$JNI"/*/libhalo.so
echo "✓ all three archs built (offline)"
