# releasing

a feature goes into a release finished or not at all.

## checks

- `flutter analyze` shows nothing but the known deprecation infos
- `flutter test` passes
- `cd mobile/android && ./gradlew --offline :app:lintDebug :app:lintVitalAnalyzeRelease` passes
- every `ALTER TABLE` in mobile/lib/main.dart is inside a try/catch, and every
  new column is in each `CREATE TABLE` (test/schema_parity_test.dart)
- no logging outside dlog: `grep -rn "print(" mobile/lib | grep -v dlog` is empty
- the engine builds from clean: `cd engine && ulimit -n 65536 && HALO_FULL=1 ./build.sh`
- the tor tests pass: `cd engine && ./torconf-tests.sh` (needs the network, ~30 min)
- after a plugin change, read the merged manifest in
  build/app/intermediates/merged_manifests/, plugins add permissions
- a fresh clone resolves the lockfile: `flutter pub get --enforce-lockfile`

## version

- `version: X.Y.Z+N` in mobile/pubspec.yaml, then `flutter pub get`
- the version string in mobile/lib/screens/settings_screen.dart
- a section in CHANGELOG.md
- fastlane changelogs, one per abi, same text:
  `mobile/fastlane/metadata/android/en-US/changelogs/<N*10+1>.txt`, `+2`, `+3`

commit it as `X.Y.Z`. no tag yet.

## build

    cd repro && ./release.sh

builds the commit in the pinned container at f-droid's build path, signs
outside it, and leaves the three apks in repro/out/. it refuses a dirty tree.
it has to be the container: libapp.so and two plugin libraries embed the
build path.

## verify

    ./verify.sh --ref HEAD out/app-arm64-v8a-release.apk \
        out/app-armeabi-v7a-release.apk out/app-x86_64-release.apk

both builds have to pass: MATCH at f-droid's path, SAME at another one. no
`--no-cross` or `--cache` for a release.

## tag and push

    git tag vX.Y.Z
    git push origin main
    git push origin vX.Y.Z

attach the three apks from repro/out/ to the github release.

## f-droid

fdroiddata/app.kryfo.yml goes into the fdroiddata fork as
metadata/app.kryfo.yml. one `Builds:` block per abi (version codes N*10+1,
+2, +3) and `CurrentVersion` / `CurrentVersionCode` for the newest. it has to
agree with the release:

- `ndk: r28c`, the one repro/Dockerfile pins
- `binary:` points at the release asset `app-<abi>-release.apk`
- the signature is a pure insertion, release.sh passes `--alignment-preserved`
- `AllowedAPKSigningKeys` is the certificate sha-256 that release.sh prints

then check the tag is up: `git ls-remote --tags origin | grep vX.Y.Z`
