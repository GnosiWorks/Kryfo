# Building

three parts: the go engine (libhalo.so), the libsignal shim
(libkryfo_signal.so), then the flutter app that bundles both.

## toolchain

- flutter 3.41.7
- go 1.26.9
- rust 1.97.0 with the three android targets (mobile/native/kryfo_signal/rust-toolchain.toml;
  rustup installs it on first use), protoc and a host cc
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

## libsignal shim

    mobile/native/kryfo_signal/build-android.sh

builds arm64-v8a, armeabi-v7a and x86_64 into the app's jniLibs, with a
stamp beside each. the first run vendors the crates into the crate's
target/vendor (network), every compile after that is offline
(`--frozen`). it refuses another ndk or rust, a Cargo.lock that moved
libsignal or spqr, and any C in the android graph, and checks each library:
the 18 exports, libc and libdl only, 16 kb pages, no build path inside.
gradle refuses a library whose stamp does not match this checkout's crate:
build it in every tree, never copy it from another.

`build-host.sh --test` builds the host library and runs the rust tests,
then `KRYFO_SIGNAL_LIB=<it> flutter test test/signal_ls`. `mtecheck.sh`
runs the rust tests for arm64 under qemu with heap tagging and for 32-bit
arm (docker). after a Cargo.lock change, `acknowledgments.sh` (cargo-about
0.8.2) writes the licences screen's crate list.

## app

    cd mobile
    flutter pub get --offline
    flutter build apk --release --split-per-abi --flavor foss

foss is the build f-droid, github and the site ship, with no google code,
and the one a build that names no flavor gets. the google play bundle is
`flutter build appbundle --release --flavor play`.

the play build has google push, so it needs the firebase project's
`google-services.json`, which is never in git: put it at
`~/.kryfo-secrets/play/google-services.json`, or name it in
`KRYFO_GOOGLE_SERVICES`. a play build without it stops and says so. only its
public ids go into the bundle's resources (android/app/build.gradle.kts), and
a foss build never opens it.

gradle runs offline. a fresh machine needs one online run first:

    cd mobile/android && ./gradlew :app:lintFossDebug

## desktop

both desktop apps start at lib/main_desktop.dart, never at main.dart.

linux, on the machine it runs on (x64 or arm64):

    engine/build-linux.sh
    mobile/native/kryfo_signal/build-host.sh
    mobile/linux/build-sqlcipher.sh
    cd mobile && flutter build linux --release -t lib/main_desktop.dart
    linux/check-bundle.sh

build-linux.sh writes engine/out/linux-<arch>/libhalo.so, offline from
vendor/ like build.sh. mobile/linux/engine.cmake links it and the shim into
the runner and puts both in the bundle's lib/ with the sqlcipher, and a
release build stops without the sqlcipher. check-bundle.sh checks the
bundle's libraries and exports. the flatpak below takes that bundle.

for the tests that need the engine on this computer, `sh
mobile/tool/host_engine.sh` builds engine/build/host/libhalo.so.

windows, x64 only. the engine and the shim cross-build on linux with
mingw-w64; the flutter app builds on windows:

    TOR_EXE=<tor.exe> engine/build-windows.sh
    mobile/native/kryfo_signal/build-windows.sh
    packaging/windows/stage-tor.sh <tor-expert-bundle.tar.gz>
    packaging/windows/stage-tor.sh --check-dll engine/out/windows-x64/halo.dll
    flutter build windows --release -t lib/main_desktop.dart   (in mobile, on windows)
    iscc packaging\windows\kryfo.iss

go-libtor has no windows build, so halo.dll runs tor\tor.exe next to the
app. TOR_EXE pins that file's sha256 into halo.dll, which refuses any other
tor.exe; `HALO_DEV=1` instead makes a dev build that takes any tor.exe, and
with neither it does not build. the shim needs the x86_64-pc-windows-gnu
rust target. stage-tor.sh checks the expert bundle and its tor.exe against
packaging/windows/tor-pin.txt and copies tor.exe, what sits beside it and the
licences to packaging/build/windows/tor. kryfo.iss makes a per-user
installer, needs no admin rights, and checks tor.exe against the same pin.
on release-06 the pins in tor-pin.txt and kryfo.iss are zeros, so a
release build stops there. the rest of the windows packaging (the real tor
pins, the sqlcipher, the bundle checks and ci) lives on desktop-windows until
it merges.

## flatpak

for a local or own-repo build, after the linux steps above (x64):

    packaging/test.sh
    flatpak install flathub org.freedesktop.Sdk//26.08 org.freedesktop.Platform//26.08
    flatpak-builder --user --install --force-clean build-flatpak \
      packaging/flatpak/app.kryfo.Kryfo.yml
    flatpak run app.kryfo.Kryfo

or `--repo=<dir>` in place of `--install` for a repo of our own, then
`flatpak build-bundle <dir> kryfo.flatpak app.kryfo.Kryfo`.

the manifest takes mobile/build/linux/x64/release/bundle as a local dir and
builds sqlcipher (the pin and options of build-sqlcipher.sh) and a small
ffmpeg (raw pcm in, wav out, for parecord's voice notes) from pinned
archives. it drops the bundle's own libsqlcipher.so.0, so the app opens
/app/lib's. tor is go-libtor inside libhalo.so, pinned by engine/vendor.
the build stops when the bundle needs a newer glibc than the runtime has:
then build the bundle on an older system. packaging/test.sh checks the
permissions, the pins and the module layout, and validates the metainfo.

each permission is argued for in the manifest. files, dropped files, links,
the vault's key (secret portal), and starting with the computer (background
portal) need none. notifications still use org.freedesktop.Notifications,
the one bus name, until the app sends through the notification portal. the
tray is gtk's status icon, so it shows only under x11.

after the first build, check that voice notes record and play:
`flatpak run --command=sh app.kryfo.Kryfo -c 'command -v parecord ffmpeg'`.

each release adds a `<release>` line to app.kryfo.Kryfo.metainfo.xml.

flathub builds everything from source with no network, so it needs, besides
this: the engine from engine/ with the golang sdk extension (vendor/ is
already offline), the shim with the rust extension and its crates vendored
(flatpak-cargo-generator), flutter itself and every pub package as pinned
sources (flatpak-flutter), screenshots in the metainfo, and its own
flathub repo with this manifest.

## test build for blocked networks

    cd engine && HALO_TOR_BLOCKED=1 HALO_TEST_ID=1 ./build.sh
    cd ../mobile && HALO_TEST_ID=1 flutter build apk --debug

the engine then acts as if a censor sat on the network (engine/censor_on.go):
tor's connections to relays are reset or stall, bridges get through. it is
for driving blocked detection and automatic mode on any phone.
HALO_TOR_BLOCKED=2 cuts the built-in obfs4 bridges off as well, so automatic
has to reach snowflake or webtunnel. HALO_TOR_BLOCKED=3 cuts every bridge
off, so automatic runs out and offers relay mode.

HALO_TEST_ID=1 makes the debug app app.kryfo.bridgetest, named "Kryfo test"
on the launcher, which installs next to the real one with its own data.
every other build is named "Kryfo", and gradle checks the name. build.sh
refuses HALO_TOR_BLOCKED without HALO_TEST_ID=1, and the censor stays off in
any other app. every gradle build except that debug app runs
engine/censor-scan.sh on jniLibs and stops on a test engine, at any
level, and repro/release.sh scans the engines in each apk the same way. run
`./build.sh` again before any other build.

the tor tests behind the censor:

    cd engine && ./torconf-tests.sh TestBlockedDirectIsJudged TestBlockedAutomaticMovesOn

## signing

release signing needs key.properties and a keystore, neither is in the repo.
debug builds use the debug key.
