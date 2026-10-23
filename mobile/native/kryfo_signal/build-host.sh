#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# the shim for this machine, for the dart tests: libkryfo_signal.so (or
# .dylib) in target/release. needs a stable rust (1.85 or newer) and protoc.
# android is build-android.sh. ios is not wired yet
set -euo pipefail
cd "$(dirname "$0")"

command -v cargo >/dev/null || { echo "cargo not found: install rust with rustup" >&2; exit 1; }
command -v protoc >/dev/null || { echo "protoc not found: libsignal-protocol builds its protobufs with it" >&2; exit 1; }

# the git dependency fetches through the system git, which honours a proxy
export CARGO_NET_GIT_FETCH_WITH_CLI=true

if [[ "${1:-}" == "--test" ]]; then
  cargo test --locked
fi
cargo build --locked --release

for f in target/release/libkryfo_signal.so target/release/libkryfo_signal.dylib; do
  if [[ -f "$f" ]]; then
    echo "built $(pwd)/$f ($(wc -c <"$f") bytes)"
    echo "dart tests: KRYFO_SIGNAL_LIB=$(pwd)/$f flutter test test/signal_ls"
  fi
done
