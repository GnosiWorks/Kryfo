#!/usr/bin/env bash
# one online run: vendors every go module into engine/vendor/, so build.sh
# never needs the network again. the compiled tor, libevent and openssl
# objects stay in a persistent GOCACHE, so later builds take seconds.
set -e
cd "$(dirname "$0")"   # engine/

echo "!! this regenerates ./vendor and drops the hand patches listed in"
echo "!! VENDOR_PATCHES.md. 32-bit phones will not connect until they are"
echo "!! re-applied. ctrl-c now if that is not what you want."
sleep 8
echo "→ vendoring go modules (one-time online)…"
until go mod tidy; do echo "  net dropped, retrying…"; sleep 3; done
until go mod vendor; do echo "  net dropped, retrying…"; sleep 3; done
echo "✓ engine/vendor/ populated ($(du -sh vendor | cut -f1))"

# a repo-local build cache, the default GOCACHE can get wiped
mkdir -p .gocache
echo "✓ persistent GOCACHE at engine/.gocache"

cat > .gitignore << 'EOF'
.gocache/
EOF

echo
echo "next: replace build.sh with build-offline.sh (also written), then run it."
echo "the FIRST build still compiles tor once (~5-10 min, no network);"
echo "every build after is seconds."
