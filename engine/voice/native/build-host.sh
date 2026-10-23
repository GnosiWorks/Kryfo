#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# the voice library for this machine, for the go and dart tests:
# build/host/libkryfo_voice.so. --test also builds and runs the c tests on
# whisper.cpp's own test model and sample; KV_REAL_MODEL=<a ggml model>
# adds the checks on real words.
set -euo pipefail
cd "$(dirname "$0")"
HERE="$(pwd)"

CMAKE="${KV_CMAKE:-$(command -v cmake || true)}"
if [[ -z "$CMAKE" ]]; then
  SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/android-sdk}}"
  CMAKE="$(ls -d "$SDK"/cmake/*/bin/cmake 2>/dev/null | sort -V | tail -1 || true)"
fi
[[ -x "$CMAKE" ]] || { echo "error: cmake not found: set KV_CMAKE" >&2; exit 1; }
NINJA="$(dirname "$CMAKE")/ninja"
GEN=()
[[ -x "$NINJA" ]] && GEN=(-G Ninja -DCMAKE_MAKE_PROGRAM="$NINJA")

SRC="$(./fetch-whisper.sh)"
TESTS=OFF
[[ "${1:-}" == "--test" ]] && TESTS=ON

mkdir -p build
LOG="$HERE/build/host.txt"
# git would stamp the surrounding repo's commit into ggml
if ! { GIT_DIR=/nonexistent "$CMAKE" -S . -B build/host "${GEN[@]}" \
  -DCMAKE_BUILD_TYPE=Release -DWHISPER_SRC="$SRC" -DKV_TESTS="$TESTS" &&
  "$CMAKE" --build build/host -j "${KV_JOBS:-4}"; } >"$LOG" 2>&1; then
  tail -30 "$LOG" >&2
  echo "error: host build failed, all of it in $LOG" >&2
  exit 1
fi
echo "built $HERE/build/host/libkryfo_voice.so ($(wc -c <build/host/libkryfo_voice.so) bytes)"
./check-imports.sh "$(command -v llvm-nm || command -v nm)" build/host/libkryfo_voice.so

if [[ "$TESTS" == ON ]]; then
  build/host/kv_test "$SRC/models/for-tests-ggml-tiny.bin" "$SRC/samples/jfk.wav" ${KV_REAL_MODEL:+"$KV_REAL_MODEL"}
  build/host/kv_abort_test
fi
echo "dart tests: KRYFO_VOICE_LIB=$HERE/build/host/libkryfo_voice.so flutter test test/voice"
