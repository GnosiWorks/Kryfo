#!/bin/bash
# the signal shim in each apk was built from the libsignal and spqr sources
# Cargo.lock pins: ks_build_info's two strings are in the library as the
# lock names them. the app refuses any other library when it opens it
# (lsCheckBuild); this refuses the apk before it ships. a consistency check
# of the build, not an attestation of the code (LIBSIGNAL-SHIM.md)
# usage: shim-check.sh [--ref <commit>] <apk or libkryfo_signal.so>...
# --ref reads the lock and the app's constants from that commit, the one
# release.sh built; without it, from this checkout
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
REF=""
if [ "${1:-}" = "--ref" ]; then REF="$2"; shift 2; fi
LOCK_PATH=mobile/native/kryfo_signal/Cargo.lock
DART_PATH=mobile/lib/signal_ffi/kryfo_signal.dart
read_file() {
  if [ -n "$REF" ]; then git -C "$HERE/.." show "$REF:$1"; else cat "$HERE/../$1"; fi
}
LOCK_TEXT=$(read_file "$LOCK_PATH") || { echo "no $LOCK_PATH at ${REF:-the checkout}" >&2; exit 1; }
DART_TEXT=$(read_file "$DART_PATH") || { echo "no $DART_PATH at ${REF:-the checkout}" >&2; exit 1; }

source_of() {
  printf '%s\n' "$LOCK_TEXT" | awk -v n="$1" '$0 == "name = \"" n "\"" { f = 1; next }
    f && /^source = / { gsub(/^source = "|"$/, ""); print; exit }'
}
LIBSIGNAL=$(source_of libsignal-protocol)
SPQR=$(source_of spqr)
[ -n "$LIBSIGNAL" ] && [ -n "$SPQR" ] || { echo "no libsignal or spqr source in the lock" >&2; exit 1; }
# the app takes the same two: its constants are the lock's, joined
flat=$(printf '%s' "$DART_TEXT" | tr -d " '\n")
for s in "$LIBSIGNAL" "$SPQR"; do
  case "$flat" in *"$s"*) ;; *) echo "the app does not name $s" >&2; exit 1 ;; esac
done

check_so() {
  local so=$1 what=$2
  for s in "$LIBSIGNAL" "$SPQR"; do
    grep -aqF "$s" "$so" || { echo "$what was not built from $s" >&2; return 1; }
  done
}

[ $# -gt 0 ] || { echo "usage: shim-check.sh <apk or .so>..." >&2; exit 1; }
for f in "$@"; do
  case "$f" in
    *.apk)
      tmp=$(mktemp -d)
      unzip -q -o "$f" 'lib/*/libkryfo_signal.so' -d "$tmp" || { rm -rf "$tmp"; echo "$f has no signal shim" >&2; exit 1; }
      for so in "$tmp"/lib/*/libkryfo_signal.so; do
        check_so "$so" "$f ${so#"$tmp"/}" || { rm -rf "$tmp"; exit 1; }
      done
      rm -rf "$tmp"
      ;;
    *) check_so "$f" "$f" ;;
  esac
  echo "ok  $f: libsignal and spqr as Cargo.lock pins them"
done
