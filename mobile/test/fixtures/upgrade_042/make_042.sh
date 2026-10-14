#!/bin/sh
# makes the 0.4.2 file from a 0.4.2 checkout: make_042.sh <checkout>
# the generator runs there, against that tree's own code, and writes here
set -eu
here=$(cd "$(dirname "$0")" && pwd)
src=$(cd "$1/mobile" && pwd)
test -f "$src/lib/main.dart"
grep -q 'version: 51,' "$src/lib/main.dart"
cp "$here/../../sqlite_channel.dart" "$src/test/sqlite_channel.dart"
cp "$here/make_042.dart" "$src/test/make_042_test.dart"
trap 'rm -f "$src/test/sqlite_channel.dart" "$src/test/make_042_test.dart"' EXIT
cd "$src"
flutter pub get >/dev/null
UPGRADE_OUT="$here" flutter test test/make_042_test.dart
