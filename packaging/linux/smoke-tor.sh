#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# smoke gate for a linux bundle: its libhalo.so, driven as the app's boot
# drives it, in the desktop layout (engine/tor a link to docs/tor, umask 077,
# a non-dumpable process). fails unless tor reaches 100% and a relay answers
# through it within the limit.
# usage: smoke-tor.sh <bundle dir or .tar.gz> [seconds, default 240] [mode, default auto]
# needs python3 and the network. tor's state is fresh each run.
set -eu
src=${1:?usage: smoke-tor.sh <bundle dir or .tar.gz> [seconds] [mode]}
limit=${2:-240}
mode=${3:-auto}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM
case $src in
  *.tar.gz)
    mkdir "$work/b"
    tar -xzf "$src" -C "$work/b"
    lib=$(find "$work/b" -name libhalo.so -path '*/lib/*' | head -n 1)
    ;;
  *) lib=$(find "$src" -name libhalo.so -path '*/lib/*' | head -n 1) ;;
esac
[ -n "$lib" ] || { echo "smoke: no lib/libhalo.so in $src"; exit 2; }
echo "smoke: $lib ($(sha256sum "$lib" | cut -c1-12)), mode $mode, ${limit}s"

cat > "$work/smoke.py" <<'PY'
import ctypes, json, os, sys, threading, time
lib_path, root, mode, limit = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
libc = ctypes.CDLL(None)
libc.prctl(4, 0, 0, 0, 0)  # PR_SET_DUMPABLE 0, as the runner does
os.umask(0o077)
# the desktop layout: <runtime>/engine holds a link tor -> <data>/docs/tor
docs_tor = os.path.join(root, "data", "docs", "tor")
engine = os.path.join(root, "run", "engine")
os.makedirs(docs_tor, 0o700)
os.makedirs(engine, 0o700)
os.symlink(docs_tor, os.path.join(engine, "tor"))
h = ctypes.CDLL(lib_path)
S = ctypes.c_char_p
for n in ["HaloRestoreBridgeMode", "HaloStartListener", "HaloGetStatus",
          "HaloConnectivitySeen", "HaloSetTransportMode", "HaloNostrInit",
          "HaloGenerateIdentity", "HaloMyXPubkey", "HaloNostrSubscribe",
          "HaloBridgeStatus"]:
    getattr(h, n).restype = S
h.HaloNostrSubscribe.argtypes = [ctypes.c_int, S]
h.HaloSetDebug(1)  # engine-debug.log in the engine folder, shown on a failure
opts = {"auto": '{"consent":"yes"}'}.get(mode, "{}")
# the app's order: identity, the kept bridge mode, tor, mode, connectivity, relays
h.HaloGenerateIdentity()
print("restore:", h.HaloRestoreBridgeMode(mode.encode(), opts.encode()).decode())
started = {}
def start():
    started["r"] = h.HaloStartListener(engine.encode()).decode()
threading.Thread(target=start, daemon=True).start()
h.HaloSetTransportMode(b"private")
h.HaloConnectivitySeen(1)
relays = os.environ.get("SMOKE_RELAYS",
    "ws://z4waup3c6j6gknkjba72cqjjuffhgg6gtgqfu3vetzcvgoluvr42srid.onion,"
    "ws://cvwpee5zgbargtxd5wtbtnc6lkbgzxj5byfig3e53ic4t7su7r45n4yd.onion,"
    "wss://relay.kryfo.app")
print("relays:", h.HaloNostrInit(relays.encode()).decode())
subbed = False
t0 = time.time()
last = ""
while time.time() - t0 < limit:
    time.sleep(2)
    st = h.HaloGetStatus().decode()
    f = st.split("|")
    if "r" in started and started["r"].startswith("error"):
        print("smoke: FAIL, start said:", started["r"])
        sys.exit(1)
    if not subbed and "r" in started:
        print("start:", "onion" if started["r"].endswith(".onion") else started["r"])
        print("subscribe:", h.HaloNostrSubscribe(0, h.HaloMyXPubkey()).decode())
        subbed = True
    if st != last:
        print("%4ds %s" % (time.time() - t0, st), flush=True)
        last = st
    if len(f) >= 4 and f[1] == "100" and f[3] == "1":
        print("smoke: PASS, tor 100%% and a relay answered in %ds" % (time.time() - t0))
        sys.exit(0)
print("smoke: FAIL, no 100%% with a relay in %ds, last %s" % (limit, last))
print("bridges:", h.HaloBridgeStatus().decode()[:300])
sys.exit(1)
PY

rc=0
python3 -I -u "$work/smoke.py" "$lib" "$work/t" "$mode" "$limit" || rc=$?
if [ $rc -ne 0 ] && [ -f "$work/t/run/engine/engine-debug.log" ]; then
  echo "smoke: engine log, last lines:"
  tail -n 25 "$work/t/run/engine/engine-debug.log" | cut -c1-240
fi
exit $rc
