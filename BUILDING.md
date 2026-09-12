# building

two parts: the go engine (libhalo.so), then the flutter app that bundles it.

## toolchain

- flutter 3.41.7 stable (dart 3.11.5)
- go 1.23.4
- android ndk r28c (28.2.13676358)

the exact go and ndk versions matter for the reproducible build, see repro/.

## engine

    cd engine
    ./build.sh

finds the ndk from ANDROID_NDK_HOME or $ANDROID_HOME/ndk, builds arm64 and
x86_64, writes them into the app's jniLibs. fully offline: deps are vendored
and the tor/openssl objects cache in engine/.gocache, so only the first build
pays the native compile.

## gradle, offline

builds run with `--offline` and everything they need sits in the gradle
cache. a fresh machine, or a plugin bump that wants a newer android gradle
plugin (flutter_secure_storage 10.3 wants 8.13.2), needs one online run first:

    cd mobile/android && ./gradlew :app:lintDebug

after that the offline builds work again. release lint is on and warnings
fail the build; `android/app/lint.xml` lists the checks we chose to ignore
and why.

## app

    cd mobile
    flutter pub get --offline
    flutter build apk --release --target-platform android-arm64

arm64 only, matching the engine. debug build for a connected device:

    cd mobile/android
    ./gradlew --offline assembleDebug -Ptarget-platform=android-arm64

## signing

release signing uses a keystore that is not in this repo (key.properties and
*.jks are gitignored). debug builds sign with the standard debug key.
