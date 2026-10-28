#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# fills libopus/ from a libopus release tarball and writes the c_*.c files
# that cgo compiles. only the fixed-point c the engine uses is kept: no
# simd, no dnn, no multistream, no tests.
#   ./vendor.sh opus-1.6.1.tar.gz
set -euo pipefail
cd "$(dirname "$0")"

VERSION=1.6.1
SHA256=6ffcb593207be92584df15b32466ed64bbec99109f007c82205f0194572411a1

tarball=${1:?usage: ./vendor.sh opus-$VERSION.tar.gz}
echo "$SHA256  $tarball" | sha256sum -c -

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
tar xzf "$tarball" -C "$tmp"
src="$tmp/opus-$VERSION"

# the source lists as upstream's own makefiles name them
lists() {
  sed -n "/^$1 =/,/^\$/p" "$src"/*_sources.mk | grep -o '[A-Za-z0-9_/]*\.c'
}
files=$( { lists OPUS_SOURCES; lists CELT_SOURCES; lists SILK_SOURCES; lists SILK_SOURCES_FIXED; } |
  grep -v -e multistream -e projection -e mapping_matrix)

rm -rf libopus c_*.c
mkdir -p libopus
for f in $files; do
  mkdir -p "libopus/$(dirname "$f")"
  cp "$src/$f" "libopus/$f"
done
for f in "$src"/include/*.h "$src"/src/*.h "$src"/celt/*.h "$src"/silk/*.h "$src"/silk/fixed/*.h; do
  rel=${f#"$src"/}
  mkdir -p "libopus/$(dirname "$rel")"
  cp "$f" "libopus/$rel"
done
cp "$src/COPYING" "$src/AUTHORS" libopus/
echo "$VERSION" > libopus/VERSION

# one c file per source, so each stays its own translation unit
for f in $files; do
  name="c_$(echo "${f%.c}" | tr '/' '_').c"
  printf '#include "libopus/%s"\n' "$f" > "$name"
done
echo "libopus $VERSION: $(echo "$files" | wc -l) sources"
