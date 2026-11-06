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
# the linux bundle ships this library: no build path inside it
CRATE=$(pwd)
CARGO_HOME_DIR="${CARGO_HOME:-$HOME/.cargo}"
export RUSTFLAGS="${RUSTFLAGS:-} --remap-path-prefix=$CRATE=/kryfo_signal --remap-path-prefix=$CARGO_HOME_DIR=/cargo"
cargo build --locked --release
if [[ -f target/release/libkryfo_signal.so ]]; then
  for p in "$CRATE" "$HOME" "$CARGO_HOME_DIR"; do
    if strings -a target/release/libkryfo_signal.so | grep -qF "$p"; then
      echo "libkryfo_signal.so carries the path $p" >&2
      exit 1
    fi
  done
fi

for f in target/release/libkryfo_signal.so target/release/libkryfo_signal.dylib; do
  if [[ -f "$f" ]]; then
    echo "built $(pwd)/$f ($(wc -c <"$f") bytes)"
    echo "dart tests: KRYFO_SIGNAL_LIB=$(pwd)/$f flutter test test/signal_ls"
  fi
done
