# building

two parts: the go engine (libhalo.so), then the flutter app that bundles it.

## toolchain

- flutter 3.41.7
- go 1.25.14
- android ndk r28c (28.2.13676358)
- jdk 17

release builds pin all of these in repro/Dockerfile.

## engine

    cd engine
    ./build.sh

builds arm64-v8a, armeabi-v7a and x86_64 into the app's jniLibs. it finds the
ndk from ANDROID_NDK_HOME or $ANDROID_HOME/ndk. deps are vendored, so it runs
offline.

don't run `go mod vendor` in engine/. three vendored headers are patched for
32-bit phones (engine/VENDOR_PATCHES.md) and it drops the patches. after
touching them, build with `HALO_FULL=1 ./build.sh`, go's cache doesn't see
them.

## app

    cd mobile
    flutter pub get --offline
    flutter build apk --release --split-per-abi

gradle runs offline. a fresh machine needs one online run first:

    cd mobile/android && ./gradlew :app:lintDebug

## signing

release signing needs key.properties and a keystore, neither is in the repo.
debug builds use the debug key.
