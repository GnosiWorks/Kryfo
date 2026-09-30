#!/bin/bash
# runs inside the image: builds the engine from scratch, then the apks, and
# leaves the three apks in /out for verify.sh to diff against the release.
# the same two commands RELEASING.md gives, run where f-droid runs them.
set -e

# where verify.sh mounted the checkout. it builds at f-droid's path and at
# another one, since a file that changes with the path breaks f-droid's
# rebuild.
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

# HALO_STEP=fetch fills the pub and gradle caches mounted by release.sh
# --fetch, so the release build can then run with no network. gradle
# resolves some artifacts only when the task that needs them runs (lint,
# aapt2, the flutter engine jars per abi), so this runs the apk build once
# and throws the apk away. empty engine libs get it past the preBuild check.
if [ "$HALO_STEP" = fetch ]; then
  echo "== fetch: pub packages and gradle artifacts"
  cd "$SRC/mobile"
  flutter pub get --enforce-lockfile
  for abi in arm64-v8a armeabi-v7a x86_64; do
    mkdir -p "android/app/src/main/jniLibs/$abi"
    : > "android/app/src/main/jniLibs/$abi/libhalo.so"
  done
  HALO_UNSIGNED=1 flutter build apk --release --split-per-abi
  exit 0
fi

# HALO_OFFLINE=1: the container has no network and the caches come from
# the fetch step. pub and gradle are told so, rather than left to time out.
PUB_OFFLINE=
NO_PUB=
if [ -n "$HALO_OFFLINE" ]; then
  PUB_OFFLINE=--offline
  # flutter build runs its own pub get first, which goes online and has no
  # offline switch. the offline pub get below does the same.
  NO_PUB=--no-pub
  mkdir -p "$GRADLE_USER_HOME/init.d"
  echo 'startParameter.offline = true' > "$GRADLE_USER_HOME/init.d/offline.gradle"
  # flutter resolves its own tool's packages into this pub cache on first
  # use, and that resolve goes online whatever the project gets. doing it
  # here, offline, leaves flutter nothing to fetch.
  dart pub --suppress-analytics --directory /opt/flutter/packages/flutter_tools get --offline --example
fi

# pub first: with the network it is the step most likely to fail, and this
# way it fails before the engine rather than after
echo "== pub"
cd "$SRC/mobile"
flutter pub get --enforce-lockfile $PUB_OFFLINE
echo

echo "== engine (all three archs, every object rebuilt)"
cd "$SRC/engine"
# raise to the hard limit, a fixed number above it fails quietly
ulimit -n "$(ulimit -Hn)" 2>/dev/null || true
echo "open files: $(ulimit -n)"
HALO_FULL=1 bash build.sh

echo
echo "== apk (unsigned: the keystore never comes near this container)"
cd "$SRC/mobile"
export HALO_UNSIGNED=1
flutter build apk --release --split-per-abi $NO_PUB

echo
echo "== out"
cp build/app/outputs/flutter-apk/app-*-release*.apk "$OUT/"
cd "$OUT"
sha256sum app-*.apk
