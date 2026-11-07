#!/bin/sh
# makes from_053.json from a 0.5.3 checkout: make_invites_053.sh <checkout>
# the generator runs there, against that tree's own code: the qr and link
# 0.5.3 shows, its share text, its six digit code, and what 0.5.3 makes of
# each 0.6 form in from_06.json
set -eu
here=$(cd "$(dirname "$0")" && pwd)
src=$(cd "$1/mobile" && pwd)
test -f "$src/lib/main.dart"
test -f "$src/test/sqlite_channel.dart"
grep -q "version: 85," "$src/lib/app/database.dart"
cp "$here/make_invites_053.dart" "$src/test/make_invites_053_test.dart"
trap 'rm -f "$src/test/make_invites_053_test.dart"' EXIT
cd "$src"
flutter pub get >/dev/null
INVITES_DIR="$here" flutter test test/make_invites_053_test.dart
