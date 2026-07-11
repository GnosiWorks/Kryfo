#!/bin/bash
# reproducible build entry point. builds libhalo.so inside the pinned
# container from the engine source, then (if an apk is given) extracts the
# shipped libs and checks they match byte for byte.
#
# usage:
#   ./verify.sh                 build + print hashes
#   ./verify.sh path/to.apk     build + compare against that apk's libs
set -e
cd "$(dirname "$0")"

ENGINE_DIR="${ENGINE_DIR:-../engine}"
IMAGE=halo-repro

if grep -q '9457d95a1e8a4a344c9f9d2b1a5f6b9c9e2e7c7c8b4e5f6a7b8c9d0e1f2a3b4c' Dockerfile; then
  echo "checksums are still placeholders. run ./fill-checksums.sh first."
  exit 1
fi

echo "building image (first run pulls go + ndk, ~10 min)..."
docker build -t "$IMAGE" .

echo "building libhalo.so from $ENGINE_DIR..."
docker run --rm -v "$(cd "$ENGINE_DIR" && pwd)":/build:ro -v "$PWD/out":/build/out "$IMAGE"

if [ -n "$1" ]; then
  APK="$1"
  echo
  echo "extracting shipped libs from $APK..."
  TMP=$(mktemp -d)
  unzip -q "$APK" 'lib/*/libhalo.so' -d "$TMP" || true
  for arch in arm64-v8a x86_64; do
    built="out/$arch/libhalo.so"
    shipped="$TMP/lib/$arch/libhalo.so"
    if [ -f "$shipped" ]; then
      if cmp -s "$built" "$shipped"; then
        echo "  $arch: MATCH"
      else
        echo "  $arch: DIFFERS"
        echo "    built:   $(sha256sum "$built"   | cut -d' ' -f1)"
        echo "    shipped: $(sha256sum "$shipped" | cut -d' ' -f1)"
      fi
    fi
  done
  rm -rf "$TMP"
fi
