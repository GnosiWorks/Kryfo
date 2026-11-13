#!/bin/bash
# runs inside the image: builds the engine and the shim from scratch, then
# the apks, and leaves the four apks (three per abi, one universal) in /out
# for verify.sh to diff against the release. the same commands
# docs/RELEASING.md gives, run where f-droid runs them.
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
rustc -vV | head -1
protoc --version
echo

# gradle in the container gets a smaller heap than the project's 4G: with
# its metaspace and the kotlin daemon that came to ~5.4G resident, too much
# beside other work on an 8G box. gradle reads the user home's
# gradle.properties over the project's, so f-droid and dev builds keep
# theirs. the heap changes no byte of the apks; raise it here if r8 runs out.
# two workers keep fewer r8 and dex tasks in memory at once
mkdir -p "$GRADLE_USER_HOME"
cat > "$GRADLE_USER_HOME/gradle.properties" <<EOF
org.gradle.jvmargs=-Xmx2560m -XX:MaxMetaspaceSize=1G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError -Djava.net.preferIPv4Stack=true
kotlin.daemon.jvmargs=-Xmx1g
org.gradle.workers.max=2
EOF

# HALO_STEP=fetch fills the pub and gradle caches mounted by release.sh
# --fetch, so the release build can then run with no network. gradle
# resolves some artifacts only when the task that needs them runs (lint,
# aapt2, the flutter engine jars per abi), so this runs the apk build once
# and throws the apk away. empty engine and shim libs get it past the
# preBuild check. the shim's crates go into its target/vendor, which
# release.sh keeps.
if [ "$HALO_STEP" = fetch ]; then
  echo "== fetch: pub packages, the shim's crates and gradle artifacts"
  cd "$SRC/mobile"
  flutter pub get --enforce-lockfile
  bash native/kryfo_signal/build-android.sh --vendor
  # the translation library's pinned sources, checked, for the offline build
  bash ../engine/translate/native/fetch-bergamot.sh >/dev/null
  # and whisper.cpp's for the voice library
  bash ../engine/voice/native/fetch-whisper.sh >/dev/null
  for abi in arm64-v8a armeabi-v7a x86_64; do
    mkdir -p "android/app/src/main/jniLibs/$abi"
    : > "android/app/src/main/jniLibs/$abi/libhalo.so"
    : > "android/app/src/main/jniLibs/$abi/libkryfo_signal.so"
  done
  HALO_UNSIGNED=1 flutter build apk --release --split-per-abi --flavor foss
  HALO_UNSIGNED=1 flutter build apk --release --target-platform android-arm,android-arm64 --flavor foss
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
echo "== shim (all three abis)"
# with HALO_OFFLINE the crates come from the fetch step, KS_OFFLINE says so
KS_OFFLINE=${HALO_OFFLINE:+1} bash "$SRC/mobile/native/kryfo_signal/build-android.sh"

echo
echo "== translation library (all three abis)"
# from the pinned sources; with HALO_OFFLINE they come from the fetch step.
# translation is on, so the apk carries it
KT_JNI_LIBS_DIR="$SRC/mobile/android/app/src/main/jniLibs" \
  bash "$SRC/engine/translate/native/build.sh"

echo
echo "== voice library (all three abis)"
# the same way, from the pinned whisper.cpp. voice transcripts are on,
# so the apk carries it
KV_JNI_LIBS_DIR="$SRC/mobile/android/app/src/main/jniLibs" \
  bash "$SRC/engine/voice/native/build.sh"

echo
echo "== apk (unsigned: the keystore never comes near this container)"
cd "$SRC/mobile"
export HALO_UNSIGNED=1
# foss is what f-droid and github ship. play is built and signed elsewhere
# a release candidate says so in its version name (release.sh --rc)
flutter build apk --release --split-per-abi --flavor foss $NO_PUB \
  ${HALO_BUILD_NAME:+--build-name "$HALO_BUILD_NAME"}
# the flavor goes into flutter's names. the release assets keep the names
# f-droid's binary: line points at. copied now, before the next build
for f in build/app/outputs/flutter-apk/app-*-foss-release*.apk; do
  cp "$f" "$OUT/$(basename "$f" | sed 's/-foss-release/-release/')"
done

echo
echo "== universal apk (both arm abis, for the site and github)"
# built second, so the per-abi apks are built exactly as f-droid builds them
flutter build apk --release --target-platform android-arm,android-arm64 --flavor foss $NO_PUB \
  ${HALO_BUILD_NAME:+--build-name "$HALO_BUILD_NAME"}
for f in build/app/outputs/flutter-apk/app-foss-release*.apk; do
  cp "$f" "$OUT/$(basename "$f" | sed 's/^app-foss-release/app-universal-release/')"
done

echo
echo "== out"
cd "$OUT"
sha256sum app-*.apk
