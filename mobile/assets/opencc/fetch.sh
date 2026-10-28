#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# remakes the s2t, s2tw and s2hk tables here from opencc's tagged release, checked against
# the hashes below. lib/translate/hant.dart reads them.
set -eu
TAG=ver.1.1.9
CHARS=ed1d268e0ad028511dcf5b0089faed0a980ad332449ec11d481ceefde6879f41
PHRASES=17fece21a28f3db2dc32397abd73d21ae73261c3f295fa6a3fe64b5e8d8b554b
TW=30e6f8395edbfdd74e293fd8b9c62105d787c849fbb208d2a7832eac696734d7
HK=c3c93c35885902ba2b12a3235a7761b00fb2b027f36aa8314db2f6b6ad51d374
cd "$(dirname "$0")"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for f in STCharacters STPhrases TWVariants HKVariants; do
  curl -sfL -o "$tmp/$f.txt" "https://raw.githubusercontent.com/BYVoid/OpenCC/$TAG/data/dictionary/$f.txt"
done
echo "$CHARS  $tmp/STCharacters.txt" | sha256sum -c -
echo "$PHRASES  $tmp/STPhrases.txt" | sha256sum -c -
echo "$TW  $tmp/TWVariants.txt" | sha256sum -c -
echo "$HK  $tmp/HKVariants.txt" | sha256sum -c -
for f in STCharacters STPhrases TWVariants HKVariants; do
  gzip -9 -n -c "$tmp/$f.txt" > "$f.txt.gz"
done
