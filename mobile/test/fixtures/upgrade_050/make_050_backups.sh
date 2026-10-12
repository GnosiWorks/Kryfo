#!/bin/sh
# makes the 0.5.0 backups from a 0.5.0 checkout and the files here:
# make_050_backups.sh <checkout>. that checkout's engine is built for this
# computer first, so the cipher is 0.5.0's own
set -eu
here=$(cd "$(dirname "$0")" && pwd)
src=$(cd "$1/mobile" && pwd)
grep -q 'version: 65,' "$src/lib/main.dart"
engine="$1/engine/build/host/libhalo.so"
"$here/../../../tool/host_engine.sh" "$1/engine" "$engine"
for f in sqlite_channel.dart host_engine.dart; do
  cp "$here/../../$f" "$src/test/$f"
done
cp "$here/make_050_backups.dart" "$src/test/make_050_backups_test.dart"
trap 'rm -f "$src/test/sqlite_channel.dart" "$src/test/host_engine.dart" "$src/test/make_050_backups_test.dart"' EXIT
cd "$src"
flutter pub get >/dev/null
UPGRADE_OUT="$here" KRYFO_HOST_ENGINE="$(cd "$(dirname "$engine")" && pwd)/libhalo.so" \
  flutter test test/make_050_backups_test.dart
