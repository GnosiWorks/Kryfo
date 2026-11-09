#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# smoke gate for the linux tarball on a stock arch (arch/Dockerfile: the image
# by digest, packages from the arch archive of one day). install.sh works,
# every library resolves, the sqlcipher opens a database while the system
# sqlite gtk pulls in is loaded, the app stays up under xvfb with the portal
# running, and smoke-tor.sh passes there.
# usage: smoke-arch.sh <kryfo-*-linux-x64.tar.gz> [seconds the app runs, default 30]
# needs docker and the network.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
tgz=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
secs=${2:-30}
day=$(sed -n 's|^ARG DAY=\([0-9]*\)/\([0-9]*\)/\([0-9]*\)$|\1\2\3|p' "$here/arch/Dockerfile")
img=kryfo-arch-smoke:$day
docker image inspect "$img" >/dev/null 2>&1 || docker build -q -t "$img" "$here/arch" >/dev/null
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM

cat > "$work/in.sh" <<'EOF'
set -u
secs=$1
fail=0
ok() { echo "ok   $*"; }
no() { echo "FAIL $*"; fail=1; }
mkdir /tmp/k && tar -xzf /k.tar.gz -C /tmp/k
if sh /tmp/k/*/install.sh >/tmp/install.log 2>&1; then ok "install.sh"; else
  no "install.sh: $(tail -n 1 /tmp/install.log)"; exit 1; fi
app=$HOME/.local/opt/kryfo
bad=$(for f in "$app/kryfo" "$app/lib/libsqlcipher.so.0"; do
  ldd "$f" 2>/dev/null | grep 'not found'; done | tr -s ' \t\n' ' ')
[ -z "$bad" ] && ok "every library resolves" || no "unresolved: $bad"
# the app's order: gtk, and with it the system sqlite, then the shipped sqlcipher
cat > /tmp/db.py <<'PY'
import ctypes, sys
ctypes.CDLL("libgtk-3.so.0", mode=ctypes.RTLD_GLOBAL)
if "libsqlite3" not in open("/proc/self/maps").read():
    sys.exit("gtk loaded no system sqlite: the gate would prove nothing, check the pin")
c = ctypes.CDLL(sys.argv[1])
db = ctypes.c_void_p()
assert c.sqlite3_initialize() == 0
assert c.sqlite3_open_v2(b"/tmp/smoke.db", ctypes.byref(db), 6, None) == 0
assert c.sqlite3_key(db, b"smoke", 5) == 0
assert c.sqlite3_exec(db, b"CREATE TABLE t(a); INSERT INTO t VALUES(1)", None, None, None) == 0
assert c.sqlite3_close(db) == 0
assert b"SQLite format 3" not in open("/tmp/smoke.db", "rb").read(16)
PY
if python3 -I /tmp/db.py "$app/lib/libsqlcipher.so.0"; then
  ok "sqlcipher opens a keyed database next to the system sqlite"
else no "sqlcipher failed next to the system sqlite (exit $?)"; fi

export DISPLAY=:99
Xvfb :99 -screen 0 1280x800x24 -nolisten tcp >/dev/null 2>&1 &
/usr/lib/xdg-desktop-portal -r >/dev/null 2>&1 &
sleep 2
"$app/kryfo" >/tmp/app.log 2>&1 &
pid=$!
sleep "$secs"
if kill -0 "$pid" 2>/dev/null; then
  ok "the app is up after ${secs}s"
  kill "$pid"
else
  wait "$pid"; rc=$?
  no "the app quit after start (exit $rc): $(tail -n 3 /tmp/app.log | tr '\n' ' ')"
fi
sh /smoke-tor.sh /k.tar.gz 240 auto || fail=1
[ "$fail" = 0 ] && echo "smoke-arch: PASS" || echo "smoke-arch: FAIL"
exit "$fail"
EOF

docker run --rm --user 1000:1000 \
  --tmpfs /run/user/1000:uid=1000,gid=1000,mode=0700 -e XDG_RUNTIME_DIR=/run/user/1000 \
  -v "$tgz:/k.tar.gz:ro" -v "$work/in.sh:/in.sh:ro" -v "$here/smoke-tor.sh:/smoke-tor.sh:ro" \
  "$img" dbus-run-session -- sh -c 'exec sh /in.sh "$1" 2>&1' sh "$secs" 2>/dev/null
