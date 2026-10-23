#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# builds libkryfo_voice.so for arm64-v8a, armeabi-v7a and x86_64 into
# out/<abi>/ with the pinned ndk and cmake, from the pinned whisper.cpp.
# after fetch-whisper.sh has run once nothing here needs the network.
# the library is not copied into the app while transcripts are off;
# KV_JNI_LIBS_DIR=<dir> copies it there. its own name: engine/build.sh
# reads JNI_LIBS_DIR, and that one may be exported for a release
#
#   ./build.sh           the three abis
#   ./build.sh --twice   then again from a copy at another path, and
#                        compares the bytes
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
  if [[ "${KV_ANY_NDK:-}" != 1 ]]; then
    echo "error: ndk $rev, the pin is $NDK_PIN (KV_ANY_NDK=1 builds anyway)" >&2
    exit 1
  fi
  echo "warning: ndk $rev, not $NDK_PIN: these bytes will not match a release"
fi
LLVM="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin"
[[ -d "$LLVM" ]] || { echo "error: no linux-x86_64 toolchain in $NDK_ROOT" >&2; exit 1; }

CMAKE="${KV_CMAKE:-$SDK/cmake/$CMAKE_PIN/bin/cmake}"
[[ -x "$CMAKE" ]] || { echo "error: cmake $CMAKE_PIN not found: sdkmanager 'cmake;$CMAKE_PIN', or set KV_CMAKE" >&2; exit 1; }
if ! "$CMAKE" --version | head -1 | grep -qE " ${CMAKE_PIN//./\\.}(-|$)"; then
  echo "error: $CMAKE is not cmake $CMAKE_PIN" >&2
  exit 1
fi
NINJA="$(dirname "$CMAKE")/ninja"
[[ -x "$NINJA" ]] || { echo "error: no ninja next to $CMAKE" >&2; exit 1; }

SRC="$(./fetch-whisper.sh)"
OUT="${KV_OUT:-$HERE/out}"
JOBS="${KV_JOBS:-4}"

# reproducible: no clock, no locale, and git kept from stamping the
# surrounding repo's commit into ggml
export SOURCE_DATE_EPOCH=1700000000
export LC_ALL=C TZ=UTC
export GIT_DIR=/nonexistent

echo "ndk: $NDK_ROOT"
echo "whisper.cpp: $SRC"
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
  if [[ "$exported" != "kv_abi kv_close kv_open kv_run " ]]; then
    echo "error: $so exports [$exported]" >&2
    exit 1
  fi
  "$HERE/check-imports.sh" "$LLVM/llvm-nm" "$so" || exit 1
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
  local abi="$1" api="$2"
  shift 2
  local b="$HERE/build/android-$abi"
  rm -rf "$b"
  local flags="-ffile-prefix-map=$SRC=whisper -ffile-prefix-map=$HERE=kv"
  flags="$flags -ffile-prefix-map=$b=build -ffile-prefix-map=$NDK_ROOT=ndk"
  # whisper and ggml parse a downloaded file, so they get the same
  # hardening as the engine's c
  flags="$flags -fstack-protector-strong -D_FORTIFY_SOURCE=2"
  local t0=$SECONDS
  if ! { "$CMAKE" -S "$HERE" -B "$b" -G Ninja -DCMAKE_MAKE_PROGRAM="$NINJA" \
    -DCMAKE_TOOLCHAIN_FILE="$NDK_ROOT/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$abi" -DANDROID_PLATFORM="android-$api" -DANDROID_STL=c++_static \
    -DCMAKE_BUILD_TYPE=Release -DWHISPER_SRC="$SRC" \
    -DCMAKE_C_FLAGS="$flags" -DCMAKE_CXX_FLAGS="$flags" "$@" &&
    "$CMAKE" --build "$b" -j "$JOBS"; } >"$b.txt" 2>&1; then
    tail -30 "$b.txt" >&2
    echo "error: $abi build failed, all of it in $b.txt" >&2
    exit 1
  fi
  mkdir -p "$OUT/$abi"
  "$LLVM/llvm-strip" --strip-all -o "$OUT/$abi/libkryfo_voice.so" "$b/libkryfo_voice.so"
  check_so "$OUT/$abi/libkryfo_voice.so"
  echo "$abi: $(wc -c <"$OUT/$abi/libkryfo_voice.so") bytes in $((SECONDS - t0))s"
}

mkdir -p build
# arm64 at the plain armv8-a base: every 64-bit phone runs it
build_abi arm64-v8a 27 -DGGML_CPU_ARM_ARCH=armv8-a
build_abi armeabi-v7a 24
# the x86_64 android abi guarantees sse4.2 and nothing above it
build_abi x86_64 24 -DGGML_SSE42=ON -DGGML_AVX=OFF -DGGML_AVX2=OFF -DGGML_FMA=OFF \
  -DGGML_F16C=OFF -DGGML_BMI2=OFF -DGGML_AVX512=OFF

(cd "$OUT" && sha256sum */libkryfo_voice.so >SHA256SUMS && cat SHA256SUMS)

if [[ -n "${KV_JNI_LIBS_DIR:-}" ]]; then
  for abi in arm64-v8a armeabi-v7a x86_64; do
    mkdir -p "$KV_JNI_LIBS_DIR/$abi"
    cp "$OUT/$abi/libkryfo_voice.so" "$KV_JNI_LIBS_DIR/$abi/"
  done
  echo "copied into $KV_JNI_LIBS_DIR"
fi

if [[ "${1:-}" == "--twice" ]]; then
  T="$(mktemp -d)"
  trap 'rm -rf "$T"' EXIT
  mkdir -p "$T/elsewhere/native"
  cp -a CMakeLists.txt exports.map kryfo_voice.c kryfo_voice.h whisper.lock fetch-whisper.sh build.sh check-imports.sh test .third_party "$T/elsewhere/native/"
  echo "again from $T/elsewhere/native"
  KV_OUT="$T/out" KV_JNI_LIBS_DIR= "$T/elsewhere/native/build.sh"
  if (cd "$T/out" && sha256sum -c --quiet "$OUT/SHA256SUMS"); then
    echo "SAME: both builds gave the same bytes"
  else
    echo "DIFFERS"
    exit 1
  fi
fi
