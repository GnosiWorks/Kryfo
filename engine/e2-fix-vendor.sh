#!/usr/bin/env bash
# e2-fix-vendor.sh
# `go mod vendor` copies only files Go itself needs - it DROPS directories that
# contain no .go files. go-libtor builds tor/libevent/openssl from C sources and
# includes headers via relative paths (../openssl_config/gotor_extra.h), so the
# vendored copy is missing every C config dir -> "file not found".
#
# everything is already in the module cache (the vendor step downloaded it), so
# we just copy the complete module content into vendor/ without clobbering what
# go put there. no network needed.
set -e
cd "$(dirname "$0")"   # engine/

MODCACHE="$(go env GOMODCACHE)"
echo "module cache: $MODCACHE"

fix_mod() {
  local modpath="$1"   # e.g. github.com/alexballas/go-libtor
  local version="$2"   # e.g. v1.0.7
  local src="$MODCACHE/${modpath}@${version}"
  local dst="vendor/${modpath}"
  if [ ! -d "$src" ]; then
    echo "  ! missing in cache: $src"
    return
  fi
  if [ ! -d "$dst" ]; then
    echo "  ! not vendored: $dst"
    return
  fi
  # -n = never overwrite what go mod vendor already placed
  cp -rn "$src/." "$dst/" 2>/dev/null || true
  chmod -R u+w "$dst"
  echo "  ✓ restored C sources for $modpath"
}

# every module version that ships C/asm sources go mod vendor would drop
while read -r modpath version; do
  [ -z "$modpath" ] && continue
  echo "→ $modpath $version"
  fix_mod "$modpath" "$version"
done < <(awk '/^# /{print $2, $3}' vendor/modules.txt | grep -E 'libtor|sonic|base64x|golang-asm' || true)

# belt and braces: if the header is still absent, restore go-libtor wholesale
HDR="vendor/github.com/alexballas/go-libtor/openssl_config/gotor_extra.h"
if [ ! -f "$HDR" ]; then
  echo "→ header still missing, doing a full restore of go-libtor…"
  VER="$(awk '/^# github.com\/alexballas\/go-libtor /{print $3}' vendor/modules.txt | head -1)"
  SRC="$MODCACHE/github.com/alexballas/go-libtor@${VER}"
  rm -rf vendor/github.com/alexballas/go-libtor
  cp -r "$SRC" vendor/github.com/alexballas/go-libtor
  chmod -R u+w vendor/github.com/alexballas/go-libtor
fi

if [ -f "$HDR" ]; then
  echo "✓ gotor_extra.h present - vendor tree repaired"
else
  echo "✗ still missing. fall back to module-cache mode instead of vendor:"
  echo "    edit build.sh: replace 'export GOFLAGS=-mod=vendor' with 'export GOFLAGS=-mod=mod'"
  echo "  (GOPROXY=off keeps it offline; the module cache already has everything)"
  exit 1
fi

echo "now run: ./build.sh"
