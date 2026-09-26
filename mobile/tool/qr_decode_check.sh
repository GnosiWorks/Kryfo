#!/usr/bin/env bash
# decode every QR the app builds with somebody else's decoder.
#
# qr_all_nine_test.dart renders each kind to build/qr_check/<name>.png and
# writes what it meant to encode beside it as <name>.expected. this reads the
# pngs back with zxing and compares, since our own builder agreeing with
# itself says nothing about what a scanner sees, escaping especially.
#
#   flutter test test/qr_all_nine_test.dart && tool/qr_decode_check.sh
#
# the jars are not vendored. fetch them once:
#   B=https://repo1.maven.org/maven2
#   curl -LO $B/com/google/zxing/core/3.5.3/core-3.5.3.jar
#   curl -LO $B/com/google/zxing/javase/3.5.3/javase-3.5.3.jar
#   curl -LO $B/com/beust/jcommander/1.82/jcommander-1.82.jar
# and point ZXING_DIR at where they landed.
set -u
DIR="${1:-build/qr_check}"
Z="${ZXING_DIR:-$HOME/.cache/zxing}"
CP="$Z/core-3.5.3.jar:$Z/javase-3.5.3.jar:$Z/jcommander-1.82.jar"

for j in core javase; do
  [ -f "$Z/$j-3.5.3.jar" ] || { echo "no $j jar in $Z - see the header"; exit 2; }
done
[ -d "$DIR" ] || { echo "no $DIR - run the test first"; exit 2; }

pass=0
fail=0
for png in "$DIR"/*.png; do
  name="$(basename "$png" .png)"
  got=$(java -cp "$CP" com.google.zxing.client.j2se.CommandLineRunner \
        "file://$(cd "$(dirname "$png")" && pwd)/$(basename "$png")" 2>/dev/null \
        | awk '/^Raw result:/{f=1;next} /^Parsed result:/{f=0} f' | sed -e '$ { /^$/d }')
  want=$(cat "$DIR/$name.expected")
  if [ "$got" = "$want" ]; then
    printf '  OK   %-10s %s\n' "$name" "$(echo "$want" | head -1 | cut -c1-56)"
    pass=$((pass + 1))
  else
    printf '  FAIL %-10s\n       want: %q\n       got:  %q\n' "$name" "$want" "$got"
    fail=$((fail + 1))
  fi
done

echo
echo "decoded $pass ok, $fail wrong"
[ "$fail" -eq 0 ]
