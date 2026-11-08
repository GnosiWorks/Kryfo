#!/bin/sh
# makes the 0.5.3 files from a 0.5.3 checkout: make_053.sh <checkout>
# the generator runs there, against that tree's own code, and writes here
set -eu
here=$(cd "$(dirname "$0")" && pwd)
src=$(cd "$1/mobile" && pwd)
test -f "$src/lib/main.dart"
test -f "$src/test/sqlite_channel.dart"
grep -q "version: 85," "$src/lib/app/database.dart"
cp "$here/make_053.dart" "$src/test/make_053_test.dart"
trap 'rm -f "$src/test/make_053_test.dart"' EXIT
cd "$src"
flutter pub get >/dev/null
UPGRADE_OUT="$here" flutter test test/make_053_test.dart
