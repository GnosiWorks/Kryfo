#!/bin/bash
# checks a linux bundle after `flutter build linux`: the runner loads the
# engine, the shim and the qr scanner from lib/, every library resolves,
# both native libraries export what the dart side looks up first, and lib/
# has the sqlcipher the database needs and no plain sqlite.
# usage: linux/check-bundle.sh [build/linux/x64/release/bundle]
set -e
B="${1:-$(dirname "$0")/../build/linux/x64/release/bundle}"
fail=0
no() { echo "FAIL: $*"; fail=1; }
exports() {
  for sym in "${@:2}"; do
    nm -D --defined-only "$B/lib/$1" | grep -q " T $sym$" || no "$1 does not export $sym"
  done
}

[ -x "$B/kryfo" ] || { echo "FAIL: no runner in $B"; exit 1; }
for lib in libhalo.so libkryfo_signal.so libflutter_zxing.so libflutter_linux_gtk.so libsqlcipher.so.0; do
  [ -f "$B/lib/$lib" ] || no "lib/$lib missing"
done
for lib in libhalo.so libkryfo_signal.so; do
  readelf -d "$B/kryfo" | grep -q "NEEDED.*\[$lib\]" || no "runner does not load $lib"
done
# flatpak takes only an id of three parts or more, and the app id names the
# data folder, so it is the same id everywhere
grep -aq 'app\.kryfo\.Kryfo' "$B/kryfo" || no "runner id is not app.kryfo.Kryfo"
if ldd "$B/kryfo" | grep -q 'not found'; then
  no "unresolved: $(ldd "$B/kryfo" | grep 'not found' | tr -s ' \t' ' ')"
fi
[ -f "$B/lib/libhalo.so" ] && exports libhalo.so HaloVersion HaloFree HaloGenerateIdentity HaloStartListener
[ -f "$B/lib/libkryfo_signal.so" ] && exports libkryfo_signal.so ks_abi_version ks_free
[ -f "$B/lib/libsqlcipher.so.0" ] && exports libsqlcipher.so.0 sqlite3_key sqlite3_rekey
if [ -f "$B/lib/libsqlcipher.so.0" ] && ldd "$B/lib/libsqlcipher.so.0" | grep -q 'not found'; then
  no "libsqlcipher.so.0 does not resolve"
fi
ls "$B/lib" | grep -q '^libsqlite3' && no "a plain sqlite is in lib/"
[ -f "$B/data/kryfo.png" ] || no "data/kryfo.png missing"
[ -e "$B/lib/libdartjni.so" ] && no "lib/libdartjni.so is in the bundle (it needs a java vm)"
# run paths only inside the bundle, and no home folder in any file
for f in "$B/kryfo" "$B"/lib/*.so*; do
  rp=$(readelf -d "$f" | sed -n 's/.*(R\(UN\)\{0,1\}PATH).*\[\(.*\)\]/\2/p')
  for p in $(echo "$rp" | tr ':' ' '); do
    case "$p" in '$ORIGIN'*) ;; *) no "$(basename "$f") has the run path $p" ;; esac
  done
done
if [ -n "${HOME:-}" ] && [ "$HOME" != / ] && grep -rlaF "$HOME/" "$B" >/dev/null; then
  no "the bundle carries $HOME: $(grep -rlaF "$HOME/" "$B" | tr '\n' ' ')"
fi
[ "$fail" = 0 ] && echo "bundle ok: $B"
exit "$fail"
