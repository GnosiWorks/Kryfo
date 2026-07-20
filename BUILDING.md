# Building Halo

Two parts build in sequence: the Go engine (produces `libhalo.so`), then the
Flutter app that bundles it.

## Toolchain

- Flutter 3.41.7 (stable), Dart 3.11.5
- Go 1.23.4
- Android NDK r28c (28.2.13676358)
- Android SDK with platform-tools

The exact Go and NDK versions matter for a reproducible build — see `repro/`.

## 1. Build the engine

    cd engine
    ./build.sh

`build.sh` finds the NDK from `ANDROID_NDK_HOME` (or `$ANDROID_HOME/ndk/`),
builds `libhalo.so` for arm64 and x86_64, and writes them into the app's
`jniLibs`. It is fully offline: dependencies are vendored under
`engine/vendor/` and the Tor/OpenSSL C objects are cached in `engine/.gocache`,
so only the first build pays the native compile.

## 2. Build the app

    cd mobile
    flutter pub get --offline
    flutter build apk --release --target-platform android-arm64

The app ships arm64 only, matching the engine. A debug build for a connected
device:

    cd mobile/android
    ./gradlew --offline assembleDebug -Ptarget-platform=android-arm64

## Reproducible build

The engine has a reproducible build so anyone can confirm the `libhalo.so` in
a release matches this source. See `repro/README.md`. The toolchain there is
pinned to the versions listed above.

## Signing

Release builds are signed with a keystore that is not in this repository
(`key.properties` and `*.jks` are gitignored). Contributors build debug
APKs, which are signed with the standard Android debug key automatically.
