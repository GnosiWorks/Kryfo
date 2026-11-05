#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# the shim for the windows app, cross-built on linux with mingw-w64:
# target/x86_64-pc-windows-gnu/release/kryfo_signal.dll, where kryfo.iss
# takes it from. needs the x86_64-pc-windows-gnu rust target and protoc.
set -euo pipefail
cd "$(dirname "$0")"
CRATE="$(pwd)"
die() { echo "error: $*" >&2; exit 1; }

T=x86_64-pc-windows-gnu
CC_W="${CC_W:-x86_64-w64-mingw32-gcc}"
CHECK="$CRATE/../../../packaging/windows/check-pe.sh"
for c in cargo protoc "$CC_W"; do
  command -v "$c" >/dev/null || die "$c not found"
done
CARGO=(cargo --locked ${CARGO_OFFLINE:+--offline})

# no C in what ships: a libsignal bump that brings some in has to be seen
c=$("${CARGO[@]}" tree -q -e normal,build --target "$T" --prefix none --format '{p}' |
  grep -E '^(cc|cmake|bindgen|boring|boring-sys|openssl-sys|ring) v' | sort -u || true)
[[ -z "$c" ]] || die "C code in the $T graph: $c"

# build paths become fixed ones, libgcc and winpthread go inside the dll so it
# needs nothing the installer does not ship, and no pe timestamp
export SOURCE_DATE_EPOCH=1700000000 CARGO_INCREMENTAL=0 CARGO_NET_GIT_FETCH_WITH_CLI=true
unset CARGO_ENCODED_RUSTFLAGS CARGO_BUILD_RUSTFLAGS CARGO_TARGET_DIR RUSTFLAGS
export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER="$CC_W"
export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_RUSTFLAGS="--remap-path-prefix=$CRATE=/kryfo_signal --remap-path-prefix=${CARGO_HOME:-$HOME/.cargo}=/cargo -C target-feature=+crt-static -C link-arg=-Wl,--no-insert-timestamp -C link-arg=-Wl,--dynamicbase,--high-entropy-va,--nxcompat"
"${CARGO[@]}" build --release --target "$T"

DLL="target/$T/release/kryfo_signal.dll"
# exactly the calls of the header, imports only windows' own
want=$(grep -o 'ks_[a-z_0-9]*' include/kryfo_signal.h | sort -u)
got=$("$CHECK" --exports "$DLL" | sort -u)
[[ "$got" == "$want" ]] || die "exports differ from include/kryfo_signal.h: $(diff <(echo "$want") <(echo "$got") | grep '^[<>]' | tr '\n' ' ')"
"$CHECK" "$DLL"
grep -q "$CRATE" "$DLL" && die "a build path is left in the dll"
echo "built $CRATE/$DLL ($(wc -c <"$DLL") bytes)"
