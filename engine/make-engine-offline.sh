#!/usr/bin/env bash
# make-engine-offline.sh
# ONE online run, then engine/build.sh never touches the network again.
#
# the 700MB isn't the go modules (~30MB) - it's go-libtor compiling the full
# C sources of tor + libevent + openssl through cgo. two fixes:
#   1. `go mod vendor` pins every go dependency into engine/vendor/ (committed,
#      so no proxy fetch ever again).
#   2. GOFLAGS=-mod=vendor + a PERSISTENT GOCACHE means the compiled tor/openssl
#      objects are cached on disk after the first build - every later build
#      reuses them and finishes in seconds instead of recompiling 700MB of C.
#
# run this ONCE with wifi. after it, build.sh (patched below) is fully offline.
set -e
cd "$(dirname "$0")"   # engine/

echo "→ vendoring go modules (one-time online)…"
until go mod tidy; do echo "  net dropped, retrying…"; sleep 3; done
until go mod vendor; do echo "  net dropped, retrying…"; sleep 3; done
echo "✓ engine/vendor/ populated ($(du -sh vendor | cut -f1))"

# a persistent, repo-local build cache so the compiled tor/openssl objects
# survive between builds (default GOCACHE can get wiped; this one won't).
mkdir -p .gocache
echo "✓ persistent GOCACHE at engine/.gocache"

cat > .gitignore << 'EOF'
.gocache/
EOF

echo
echo "next: replace build.sh with build-offline.sh (also written), then run it."
echo "the FIRST build still compiles tor once (~5-10 min, no network);"
echo "every build after is seconds."
