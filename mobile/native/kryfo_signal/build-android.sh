#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# builds libkryfo_signal.so for android (arm64-v8a, armeabi-v7a, x86_64)
# into the app's jniLibs, the same bytes on any machine: the dependencies
# come from target/vendor, the compile never touches the network, and the
# remap flags turn every build path into /kryfo_signal.
#
#   KS_OFFLINE=1   never vendor, fail when target/vendor is missing
#   JNI_LIBS_DIR   where the libraries go (default the app's jniLibs)
#   --tree-id      only print the id of this crate's source, for the stamp
#   --vendor       only fill target/vendor (the fetch step of repro/release.sh)
#
# needs the rust in rust-toolchain.toml with its three android targets,
# protoc, a host cc for build scripts, and ndk r28c (found the way
# engine/build.sh finds it).
set -euo pipefail
cd "$(dirname "$0")"
CRATE="$(pwd)"

# the source the stamp names: every file of the crate but target/, so a
# library built from other code is refused by gradle
tree_id() {
  find . -path ./target -prune -o -type f -print | LC_ALL=C sort |
    xargs -d '\n' sha256sum | sha256sum | cut -c1-64
}
if [[ "${1:-}" == "--tree-id" ]]; then
  tree_id
  exit 0
fi

die() { echo "error: $*" >&2; exit 1; }

NDK_WANT=28.2.13676358
LIBSIGNAL_REV=387da3e29ac87c821aedc697aee77646a1c72fff
SPQR_REV=fd320484dcec89004021e6fdc7481825f5f261fa
TARGETS=(aarch64-linux-android armv7-linux-androideabi x86_64-linux-android)
declare -A ABI=([aarch64-linux-android]=arm64-v8a [armv7-linux-androideabi]=armeabi-v7a [x86_64-linux-android]=x86_64)
declare -A LINKER=([aarch64-linux-android]=aarch64-linux-android24-clang
  [armv7-linux-androideabi]=armv7a-linux-androideabi24-clang
  [x86_64-linux-android]=x86_64-linux-android24-clang)

# the ndk
NDK_ROOT="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-${NDK_HOME:-}}}"
if [[ -z "$NDK_ROOT" ]]; then
  SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/android-sdk}}"
  # the pinned ndk, even when a newer one sits beside it
  if [[ -d "$SDK/ndk/$NDK_WANT" ]]; then
    NDK_ROOT="$SDK/ndk/$NDK_WANT"
  elif [[ -d "$SDK/ndk" ]]; then
    NDK_ROOT="$SDK/ndk/$(ls "$SDK/ndk" | sort -V | tail -1)"
  fi
fi
[[ -d "$NDK_ROOT" ]] || die "android ndk not found. set ANDROID_NDK_HOME, or install ndk $NDK_WANT under \$ANDROID_HOME/ndk/"
NDK_REV=$(sed -n 's/^Pkg.Revision *= *//p' "$NDK_ROOT/source.properties" 2>/dev/null | tr -d '\r')
[[ "$NDK_REV" == "$NDK_WANT" ]] || die "ndk $NDK_ROOT is ${NDK_REV:-unknown}, the shim is built with $NDK_WANT (r28c)"
BIN="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin"
[[ -d "$BIN" ]] || die "no linux-x86_64 toolchain in $NDK_ROOT"

# the rust and protoc
command -v cargo >/dev/null || die "cargo not found: install rust with rustup"
RUST_WANT=$(sed -n -E 's/^channel = "([0-9.]+)"$/\1/p' rust-toolchain.toml)
RUST_HAVE=$(rustc -vV | sed -n 's/^release: //p')
[[ "$RUST_HAVE" == "$RUST_WANT" ]] || die "rustc is ${RUST_HAVE:-missing}, rust-toolchain.toml wants $RUST_WANT"
export PROTOC="${PROTOC:-$(command -v protoc || true)}"
[[ -n "$PROTOC" ]] || die "protoc not found: libsignal-protocol builds its protobufs with it"

# the two git dependencies stay at the reviewed commits, whatever their tags say
grep -q "git+https://github.com/signalapp/libsignal?rev=$LIBSIGNAL_REV#$LIBSIGNAL_REV\"" Cargo.lock ||
  die "Cargo.lock does not pin libsignal at $LIBSIGNAL_REV"
grep -q "git+https://github.com/signalapp/SparsePostQuantumRatchet.git?tag=v1.5.3#$SPQR_REV\"" Cargo.lock ||
  die "Cargo.lock does not pin spqr at $SPQR_REV"
[[ $(grep '^source = "git+' Cargo.lock | sort -u | wc -l) -eq 2 ]] || die "Cargo.lock has a git dependency beside libsignal and spqr"

# vendor once per Cargo.lock. the output is the source config, git included
LOCK_SHA=$(sha256sum Cargo.lock | cut -c1-64)
mkdir -p target
if [[ "$(cat target/vendor.lock 2>/dev/null)" != "$LOCK_SHA" || ! -f target/vendor.toml ]]; then
  [[ -z "${KS_OFFLINE:-}" ]] || die "KS_OFFLINE is set and target/vendor does not hold this Cargo.lock"
  echo "vendoring the dependencies into target/vendor"
  rm -rf target/vendor target/vendor.toml target/vendor.lock
  CARGO_NET_GIT_FETCH_WITH_CLI=true cargo vendor --locked --versioned-dirs target/vendor >target/vendor.toml.new
  mv target/vendor.toml.new target/vendor.toml
  echo "$LOCK_SHA" >target/vendor.lock
fi
# the directory as an absolute path, whichever path vendored it
sed -i -E "s|^directory = .*|directory = \"$CRATE/target/vendor\"|" target/vendor.toml
[[ "${1:-}" != "--vendor" ]] || exit 0
CARGO=(cargo --frozen --config "$CRATE/target/vendor.toml")

# no C in what ships: a libsignal bump that brings some in has to be seen
for t in "${TARGETS[@]}"; do
  c=$("${CARGO[@]}" tree -q -e normal,build --target "$t" --prefix none --format '{p}' |
    grep -E '^(cc|cmake|bindgen|boring|boring-sys|openssl-sys|ring) v' | sort -u || true)
  [[ -z "$c" ]] || die "C code in the $t graph: $c"
done

JNI="${JNI_LIBS_DIR:-$CRATE/../../android/app/src/main/jniLibs}"
TREE=$(tree_id)

# remap: the crate, its target/ (generated protobufs, vendor/) and any cargo
# home become fixed paths. no build-id note, 16 kb pages on the 64-bit abis.
# the rest is the release profile in Cargo.toml
export SOURCE_DATE_EPOCH=1700000000 CARGO_INCREMENTAL=0
unset CARGO_ENCODED_RUSTFLAGS CARGO_BUILD_RUSTFLAGS CARGO_TARGET_DIR
CARGO_HOME_DIR="${CARGO_HOME:-$HOME/.cargo}"

echo "ndk: $NDK_ROOT"
echo "rustc: $(rustc -vV | head -1)"
echo "out: $JNI"
for t in "${TARGETS[@]}"; do
  abi=${ABI[$t]}
  flags="--remap-path-prefix=$CRATE=/kryfo_signal --remap-path-prefix=$CARGO_HOME_DIR=/cargo -C link-arg=-Wl,--build-id=none"
  [[ "$t" == armv7* ]] || flags="$flags -C link-arg=-Wl,-z,max-page-size=16384"
  echo "$abi"
  env "CARGO_TARGET_$(echo "$t" | tr 'a-z-' 'A-Z_')_LINKER=$BIN/${LINKER[$t]}" RUSTFLAGS="$flags" \
    "${CARGO[@]}" build --release --target "$t"
  so="target/$t/release/libkryfo_signal.so"

  # exactly the 18 calls of the header, linked against libc and libdl only
  want=$(grep -o 'ks_[a-z_0-9]*' include/kryfo_signal.h | sort -u)
  got=$("$BIN/llvm-nm" -D --defined-only --format=just-symbols "$so" | sort -u)
  [[ "$got" == "$want" ]] || die "$abi exports differ from include/kryfo_signal.h: $(diff <(echo "$want") <(echo "$got") | grep '^[<>]' | tr '\n' ' ')"
  needed=$("$BIN/llvm-readelf" -d "$so" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p' | grep -vxE 'libc\.so|libdl\.so|libm\.so' || true)
  [[ -z "$needed" ]] || die "$abi needs $needed"
  if [[ "$t" != armv7* ]]; then
    bad=$("$BIN/llvm-readelf" -lW "$so" | awk '$1=="LOAD" && $NF!="0x4000"')
    [[ -z "$bad" ]] || die "$abi has a LOAD segment not aligned to 16 kb"
  fi
  for p in "$CRATE" "$HOME" "$CARGO_HOME_DIR" /tmp/; do
    ! strings -a "$so" | grep -qF "$p" || die "$abi carries the path $p"
  done

  mkdir -p "$JNI/$abi"
  cp "$so" "$JNI/$abi/libkryfo_signal.so"
  printf 'sha256 %s\ntree %s\n' "$(sha256sum "$so" | cut -c1-64)" "$TREE" >"$JNI/$abi/libkryfo_signal.stamp"
  echo "  $(wc -c <"$so") bytes, sha256 $(sha256sum "$so" | cut -c1-64)"
done
echo "built arm64-v8a, armeabi-v7a and x86_64"
