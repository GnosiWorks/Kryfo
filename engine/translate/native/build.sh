#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# builds libkryfo_translate.so for arm64-v8a, armeabi-v7a and x86_64 into
# out/<abi>/ with the pinned ndk and cmake, from the pinned bergamot
# sources (bergamot.lock). after fetch-bergamot.sh has run once nothing here
# needs the network. KT_JNI_LIBS_DIR=<dir> copies the three into the app's
# jniLibs (its own name: engine/build.sh reads JNI_LIBS_DIR)
#
#   ./build.sh           the three abis
#   ./build.sh --twice   then again from a copy at another path, and
#                        compares the bytes
#   KT_BENCH=1 ./build.sh   also kt_bench and kt_test, into bench/<abi>/,
#                        for timing a phone from adb shell and checking two
#                        languages open at once there (never in the app)
set -euo pipefail
cd "$(dirname "$0")"
HERE="$(pwd)"

NDK_PIN=28.2.13676358
CMAKE_PIN=3.22.1

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/android-sdk}}"
NDK_ROOT="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-${NDK_HOME:-$SDK/ndk/$NDK_PIN}}}"
if [[ ! -f "$NDK_ROOT/source.properties" ]]; then
  echo "error: android ndk $NDK_PIN not found: install it under \$ANDROID_HOME/ndk/ or set ANDROID_NDK_HOME" >&2
  exit 1
fi
rev="$(sed -n 's/^Pkg.Revision *= *//p' "$NDK_ROOT/source.properties" | tr -d '\r')"
if [[ "$rev" != "$NDK_PIN" ]]; then
  # another ndk builds, but other bytes than a release
  if [[ "${KT_ANY_NDK:-}" != 1 ]]; then
    echo "error: ndk $rev, the pin is $NDK_PIN (KT_ANY_NDK=1 builds anyway)" >&2
    exit 1
  fi
  echo "warning: ndk $rev, not $NDK_PIN: these bytes will not match a release"
fi
LLVM="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin"
[[ -d "$LLVM" ]] || { echo "error: no linux-x86_64 toolchain in $NDK_ROOT" >&2; exit 1; }

CMAKE="${KT_CMAKE:-$SDK/cmake/$CMAKE_PIN/bin/cmake}"
[[ -x "$CMAKE" ]] || { echo "error: cmake $CMAKE_PIN not found: sdkmanager 'cmake;$CMAKE_PIN', or set KT_CMAKE" >&2; exit 1; }
if ! "$CMAKE" --version | head -1 | grep -qE " ${CMAKE_PIN//./\\.}(-|$)"; then
  echo "error: $CMAKE is not cmake $CMAKE_PIN" >&2
  exit 1
fi
NINJA="$(dirname "$CMAKE")/ninja"
[[ -x "$NINJA" ]] || { echo "error: no ninja next to $CMAKE" >&2; exit 1; }

SRC="$(./fetch-bergamot.sh)"
OUT="${KT_OUT:-$HERE/out}"
JOBS="${KT_JOBS:-4}"

# reproducible: no clock, no locale, and git kept from stamping the
# surrounding repo's commit into marian's version
export SOURCE_DATE_EPOCH=1700000000
export LC_ALL=C TZ=UTC
export GIT_DIR=/nonexistent

echo "ndk: $NDK_ROOT"
echo "bergamot: $SRC"
echo "out: $OUT"

check_so() {
  local so="$1"
  local dyn
  dyn="$("$LLVM/llvm-readelf" -d "$so")"
  if grep -q TEXTREL <<<"$dyn"; then echo "error: $so has text relocations" >&2; exit 1; fi
  if grep -qE 'RPATH|RUNPATH' <<<"$dyn"; then echo "error: $so has an rpath" >&2; exit 1; fi
  local needed
  needed="$(sed -n 's/.*Shared library: \[\(.*\)\]/\1/p' <<<"$dyn" | sort | tr '\n' ' ')"
  for lib in $needed; do
    case "$lib" in
      libc.so|libm.so|libdl.so|liblog.so) ;;
      *) echo "error: $so needs $lib" >&2; exit 1 ;;
    esac
  done
  local exported
  exported="$("$LLVM/llvm-nm" -D --defined-only "$so" | awk '{print $3}' | sort | tr '\n' ' ')"
  if [[ "$exported" != "kt_close kt_free kt_open kt_translate " ]]; then
    echo "error: $so exports [$exported]" >&2
    exit 1
  fi
  # no network and no new process: it reads a model and some memory
  "$HERE/../../voice/native/check-imports.sh" "$LLVM/llvm-nm" "$so" || exit 1
  if "$LLVM/llvm-readelf" -n "$so" | grep -q 'GNU_BUILD_ID'; then
    echo "error: $so has a build id" >&2
    exit 1
  fi
  if ! "$LLVM/llvm-readelf" -lW "$so" | awk '$1 == "LOAD" { if ($NF != "0x4000") bad = 1 } END { exit bad }'; then
    echo "error: $so is not aligned to 16 kb pages" >&2
    exit 1
  fi
  if grep -qaF -e "$HERE" -e "$SRC" -e "$HOME" "$so"; then
    echo "error: $so holds a path of this machine" >&2
    exit 1
  fi
}

build_abi() {
  local abi="$1" api="$2" arch="$3"
  shift 3
  local b="$HERE/build/android-$abi"
  rm -rf "$b"
  local flags="-ffile-prefix-map=$SRC=bergamot -ffile-prefix-map=$HERE=kt"
  flags="$flags -ffile-prefix-map=$b=build -ffile-prefix-map=$NDK_ROOT=ndk"
  # marian parses a downloaded model, so it gets the same hardening as the
  # engine's c
  flags="$flags -fstack-protector-strong -D_FORTIFY_SOURCE=2"
  flags="$flags -ffunction-sections -fdata-sections"
  local t0=$SECONDS
  if ! { "$CMAKE" -S "$HERE" -B "$b" -G Ninja -DCMAKE_MAKE_PROGRAM="$NINJA" \
    -DCMAKE_TOOLCHAIN_FILE="$NDK_ROOT/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$abi" -DANDROID_PLATFORM="android-$api" -DANDROID_STL=c++_static \
    -DCMAKE_BUILD_TYPE=Release -DBERGAMOT_SRC="$SRC" -DBUILD_ARCH="$arch" \
    -DKT_FLAGS="$flags" -DKT_BENCH="${KT_BENCH:-OFF}" "$@" &&
    "$CMAKE" --build "$b" -j "$JOBS" --target kryfo_translate &&
    if [[ "${KT_BENCH:-}" == 1 ]]; then "$CMAKE" --build "$b" -j "$JOBS" --target kt_bench kt_test; fi; } >"$b.txt" 2>&1; then
    tail -30 "$b.txt" >&2
    echo "error: $abi build failed, all of it in $b.txt" >&2
    exit 1
  fi
  mkdir -p "$OUT/$abi"
  "$LLVM/llvm-strip" --strip-all -o "$OUT/$abi/libkryfo_translate.so" "$b/libkryfo_translate.so"
  check_so "$OUT/$abi/libkryfo_translate.so"
  # the bench sits beside the out folder, never in it or in SHA256SUMS
  if [[ "${KT_BENCH:-}" == 1 ]]; then
    mkdir -p "$HERE/bench/$abi"
    "$LLVM/llvm-strip" --strip-all -o "$HERE/bench/$abi/kt_bench" "$b/kt_bench"
    "$LLVM/llvm-strip" --strip-all -o "$HERE/bench/$abi/kt_test" "$b/kt_test"
  fi
  echo "$abi: $(wc -c <"$OUT/$abi/libkryfo_translate.so") bytes in $((SECONDS - t0))s"
}

mkdir -p build
ABIS="${KT_ABIS:-arm64-v8a armeabi-v7a x86_64}"
for abi in $ABIS; do
  case "$abi" in
    # the plain armv8-a base: every 64-bit phone runs it, and ruy picks its
    # dot-product kernels at run time where the core has them
    arm64-v8a) build_abi arm64-v8a 24 armv8-a ;;
    # every armeabi-v7a phone android 7 runs on has neon
    armeabi-v7a) build_abi armeabi-v7a 24 armv7-a ;;
    # the x86_64 android abi guarantees sse4.2 and nothing above it;
    # intgemm picks avx2 or avx512 at run time
    x86_64) build_abi x86_64 24 x86-64 ;;
    *) echo "error: unknown abi $abi" >&2; exit 1 ;;
  esac
done

(cd "$OUT" && sha256sum */libkryfo_translate.so >SHA256SUMS && cat SHA256SUMS)

if [[ -n "${KT_JNI_LIBS_DIR:-}" ]]; then
  for abi in $ABIS; do
    mkdir -p "$KT_JNI_LIBS_DIR/$abi"
    cp "$OUT/$abi/libkryfo_translate.so" "$KT_JNI_LIBS_DIR/$abi/"
  done
  echo "copied into $KT_JNI_LIBS_DIR"
fi

if [[ "${1:-}" == "--twice" ]]; then
  T="$(mktemp -d)"
  trap 'rm -rf "$T"' EXIT
  mkdir -p "$T/elsewhere/translate/native" "$T/elsewhere/voice/native"
  cp -a CMakeLists.txt exports.map android_compat.h armv7_compat.h kryfo_translate.cpp kryfo_translate.h kt_bench.c kt_test.c bergamot.lock \
    fetch-bergamot.sh build.sh .third_party "$T/elsewhere/translate/native/"
  cp -a ../../voice/native/check-imports.sh "$T/elsewhere/voice/native/"
  echo "again from $T/elsewhere/translate/native"
  KT_OUT="$T/out" KT_JNI_LIBS_DIR= "$T/elsewhere/translate/native/build.sh"
  if (cd "$T/out" && sha256sum -c --quiet "$OUT/SHA256SUMS"); then
    echo "SAME: both builds gave the same bytes"
  else
    echo "DIFFERS"
    exit 1
  fi
fi
