#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# remakes the s2t tables here from opencc's tagged release, checked against
# the hashes below. lib/translate/hant.dart reads them.
set -eu
TAG=ver.1.1.9
CHARS=ed1d268e0ad028511dcf5b0089faed0a980ad332449ec11d481ceefde6879f41
PHRASES=17fece21a28f3db2dc32397abd73d21ae73261c3f295fa6a3fe64b5e8d8b554b
cd "$(dirname "$0")"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for f in STCharacters STPhrases; do
  curl -sfL -o "$tmp/$f.txt" "https://raw.githubusercontent.com/BYVoid/OpenCC/$TAG/data/dictionary/$f.txt"
done
echo "$CHARS  $tmp/STCharacters.txt" | sha256sum -c -
echo "$PHRASES  $tmp/STPhrases.txt" | sha256sum -c -
for f in STCharacters STPhrases; do
  gzip -9 -n -c "$tmp/$f.txt" > "$f.txt.gz"
done
