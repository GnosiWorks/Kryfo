#!/bin/bash
# the signal shim in each apk was built from the libsignal and spqr sources
# Cargo.lock pins: ks_build_info's two strings are in the library as the
# lock names them. the app refuses any other library when it opens it
# (lsCheckBuild); this refuses the apk before it ships. a consistency check
# of the build, not an attestation of the code (LIBSIGNAL-SHIM.md)
# usage: shim-check.sh <apk or libkryfo_signal.so>...
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
LOCK="$HERE/../mobile/native/kryfo_signal/Cargo.lock"
DART="$HERE/../mobile/lib/signal_ffi/kryfo_signal.dart"

source_of() {
  awk -v n="$1" '$0 == "name = \"" n "\"" { f = 1; next }
    f && /^source = / { gsub(/^source = "|"$/, ""); print; exit }' "$LOCK"
}
LIBSIGNAL=$(source_of libsignal-protocol)
SPQR=$(source_of spqr)
[ -n "$LIBSIGNAL" ] && [ -n "$SPQR" ] || { echo "no libsignal or spqr source in $LOCK" >&2; exit 1; }
# the app takes the same two: its constants are the lock's, joined
flat=$(tr -d " '\n" < "$DART")
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
