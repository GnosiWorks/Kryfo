# building

two parts: the go engine (libhalo.so), then the flutter app that bundles it.

## toolchain

- flutter 3.41.7
- go 1.26.9
- android ndk r28c (28.2.13676358)
- jdk 17

release builds pin all of these in repro/Dockerfile.

## engine

    cd engine
    ./build.sh

builds arm64-v8a, armeabi-v7a and x86_64 into the app's jniLibs. it finds the
ndk from ANDROID_NDK_HOME or $ANDROID_HOME/ndk. deps are vendored, so it runs
offline.

vendor/ is rebuilt with `./vendor.sh` in engine/, never a bare
`go mod vendor`. six vendored headers are patched for 32-bit phones
(engine/VENDOR_PATCHES.md) and go mod vendor drops the patches. after
touching them, build with `HALO_FULL=1 ./build.sh`, go's cache doesn't see
them.

## app

    cd mobile
    flutter pub get --offline
    flutter build apk --release --split-per-abi

gradle runs offline. a fresh machine needs one online run first:

    cd mobile/android && ./gradlew :app:lintDebug

## test build for blocked networks

    cd engine && HALO_TOR_BLOCKED=1 HALO_TEST_ID=1 ./build.sh
    cd ../mobile && HALO_TEST_ID=1 flutter build apk --debug

the engine then acts as if a censor sat on the network (engine/censor_on.go):
tor's connections to relays are reset or stall, bridges get through. it is
for driving blocked detection and automatic mode on any phone.
HALO_TOR_BLOCKED=2 cuts the built-in obfs4 bridges off as well, so automatic
has to reach snowflake or webtunnel.

HALO_TEST_ID=1 makes the debug app app.kryfo.bridgetest, named "Kryfo test"
on the launcher, which installs next to the real one with its own data.
every other build is named "Kryfo", and gradle checks the name. build.sh
refuses HALO_TOR_BLOCKED without HALO_TEST_ID=1, and the censor stays off in
any other app. every gradle build except that debug app runs
engine/censor-scan.sh on jniLibs and stops on a test engine, at either
level, and repro/release.sh scans the engines in each apk the same way. run
`./build.sh` again before any other build.

the tor tests behind the censor:

    cd engine && ./torconf-tests.sh TestBlockedDirectIsJudged TestBlockedAutomaticMovesOn

## signing

release signing needs key.properties and a keystore, neither is in the repo.
debug builds use the debug key.
