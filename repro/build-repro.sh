#!/bin/bash
# runs inside the image. the source tree is mounted at the f-droid path;
# the engine is built from scratch, then the apks, and the three apks are
# left in /out for verify.sh to diff against what was published.
#
# nothing here is special: it is engine/build.sh and flutter build, the
# same two commands RELEASING.md gives, run where f-droid runs them.
set -e

# where verify.sh mounted the checkout. it builds twice, at f-droid's path
# and at another one, because a file that changes with the path is a file
# f-droid's rebuild will disagree with us about.
SRC=${HALO_SRC:-/home/vagrant/build/app.kryfo}
OUT=/out

if [ ! -f "$SRC/engine/build.sh" ]; then
  echo "no source at $SRC. verify.sh and release.sh mount one there." >&2
  exit 2
fi

echo "== toolchain"
go version
flutter --version | head -1
java -version 2>&1 | head -1
echo "ndk $ANDROID_NDK_HOME"
echo

echo "== engine (all three archs, every object rebuilt)"
cd "$SRC/engine"
# raise to whatever the hard limit allows. asking for a fixed number that
# is above it fails, and the failure was being swallowed.
ulimit -n "$(ulimit -Hn)" 2>/dev/null || true
echo "open files: $(ulimit -n)"
HALO_FULL=1 bash build.sh

echo
echo "== apk (unsigned: the keystore never comes near this container)"
cd "$SRC/mobile"
export HALO_UNSIGNED=1
flutter pub get --enforce-lockfile
flutter build apk --release --split-per-abi

echo
echo "== out"
cp build/app/outputs/flutter-apk/app-*-release*.apk "$OUT/"
cd "$OUT"
sha256sum app-*.apk
