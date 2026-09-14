#!/bin/bash
# ============================================================================
#  READ BEFORE TOUCHING ./vendor
#
#  three headers under vendor/github.com/alexballas/go-libtor are PATCHED BY
#  HAND, see VENDOR_PATCHES.md next to this file. upstream generated them on a
#  64-bit machine and ships them for every target; unpatched, the 32-bit
#  (armeabi-v7a) engine builds fine and tor never bootstraps: the phone sits
#  at "connecting" forever, 0%, no error anywhere.
#
#  `go mod vendor` REGENERATES ./vendor AND DESTROYS THOSE PATCHES. it has
#  been run by accident here before. do not run it. if the vendor tree ever
#  has to be rebuilt, re-apply VENDOR_PATCHES.md and build with HALO_FULL=1.
#
#  go's build cache does not see those headers change either (they live
#  outside the go package), so after any edit to them: HALO_FULL=1 ./build.sh
# ============================================================================
#
# builds libhalo.so for android. fully offline: deps come from ./vendor and
# the compiled tor/openssl objects are cached in ./.gocache, so only the
# first build pays the c compile.
#
# paths are discovered, not hardcoded, so this works on a dev box and on
# f-droid's build server alike:
#   NDK   - ANDROID_NDK_HOME | ANDROID_NDK_ROOT | NDK_HOME | newest in $ANDROID_HOME/ndk
#   JNI   - relative to this script, so any clone location works
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
export CGO_LDFLAGS="-Wl,--build-id=none"
export SOURCE_DATE_EPOCH=1700000000
LDFLAGS="-buildid= -w -s"
# go does not track c headers outside a package, so a change to a vendored
# config header (the openssl and libevent ones under go-libtor) leaves the
# cache serving objects built with the old header. HALO_FULL=1 rebuilds
# every object.
BUILD_FLAGS="${HALO_FULL:+-a}"
# go stamps the git commit, commit time and a dirty flag into every binary
# it builds inside a checkout. that is ninety bytes that differ between the
# tag and whatever was HEAD on the dev box, and the dirty flag flips on any
# untracked file, so no two machines agree. off, or nothing reproduces.
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
