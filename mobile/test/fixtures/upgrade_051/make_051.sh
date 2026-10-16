#!/bin/sh
# makes the 0.5.1 files from a 0.5.1 checkout: make_051.sh <checkout>
# the generator runs there, against that tree's own code, and writes here
set -eu
here=$(cd "$(dirname "$0")" && pwd)
src=$(cd "$1/mobile" && pwd)
test -f "$src/lib/main.dart"
test -f "$src/test/sqlite_channel.dart"
grep -q 'version: 80,' "$src/lib/main.dart"
cp "$here/make_051.dart" "$src/test/make_051_test.dart"
trap 'rm -f "$src/test/make_051_test.dart"' EXIT
cd "$src"
flutter pub get >/dev/null
UPGRADE_OUT="$here" flutter test test/make_051_test.dart
