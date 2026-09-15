# releasing

what a release actually is, from the three we have cut. follow it top to
bottom. each step exists because skipping it has bitten us once.

## 1. before anything

- `cd mobile && flutter analyze` shows nothing but the known deprecation
  infos (flutter_secure_storage's `encryptedSharedPreferences`). a warning
  or an error stops the release.
- `flutter test` passes.
- `cd mobile/android && ./gradlew --offline :app:lintDebug :app:lintVitalAnalyzeRelease`
  passes. warnings fail it on purpose; the first run of it found two style
  attributes above our minimum api.
- every `ALTER TABLE` in `mobile/lib/main.dart` sits inside a `try {} catch (_) {}`.
  a bare one hangs the app on boot for anyone whose database already has the
  column. `grep -n "ALTER TABLE" mobile/lib/main.dart` and eyeball each.
- every column a migration adds is also in every `CREATE TABLE` for that
  table, the fresh-install one and the one inside the old `oldV < 7` block.
  `flutter test test/schema_parity_test.dart` checks it; it found a real gap
  the first time it ran.
- no id, onion or message text reaches logcat in release: every log line goes
  through `dlog`, which is silent unless `kDebugMode`.
  `grep -rn "print(" mobile/lib | grep -v dlog` should be empty.
- the engine builds all three architectures from a clean tree:
  `cd engine && HALO_FULL=1 bash build.sh`. about twenty minutes; raise the
  file limit first (`ulimit -n 65536`) or cgo dies with "too many open
  files". HALO_FULL matters: go's cache does not see the hand-patched
  headers under engine/vendor (see engine/VENDOR_PATCHES.md), and a plain
  rebuild after touching them ships a 32-bit engine that never connects.
- the shipped manifest still says what you think. after any plugin change,
  build once and read `build/app/intermediates/merged_manifests/debug/processDebugManifest/AndroidManifest.xml`,
  not the source one: plugins merge permissions and components in silently.
- a fresh clone resolves the lockfile with no changes:
  `git clone . /tmp/kryfo-check && cd /tmp/kryfo-check/mobile && flutter pub get --enforce-lockfile`.

## 2. version

- `mobile/pubspec.yaml`: `version: X.Y.Z+N`. bump both. N is the build number
  and only ever goes up.
- `cd mobile && flutter pub get`, so the lockfile is confirmed unchanged
  against the bumped pubspec before it is committed.
- the version row in `mobile/lib/screens/settings_screen.dart` shows the same
  number. it is a string, it does not read pubspec, so bump it by hand.
- `CHANGELOG.md`: a new section at the top, dated, plain words, what a user
  notices. added, fixed, changed.
- fastlane changelogs. the gradle split gives each abi its own versionCode:
  `N * 10 + 1` for armeabi-v7a, `N * 10 + 2` for arm64, `N * 10 + 3` for
  x86_64. write all three files, same text, a few short paragraphs, no
  markdown:
  `mobile/fastlane/metadata/android/en-US/changelogs/<N*10+1>.txt`
  `mobile/fastlane/metadata/android/en-US/changelogs/<N*10+2>.txt`
  `mobile/fastlane/metadata/android/en-US/changelogs/<N*10+3>.txt`
  these were missed until 0.2.3. f-droid shows them under "what's new".

## 3. commit

    git add mobile/pubspec.yaml mobile/pubspec.lock CHANGELOG.md mobile/fastlane
    git commit -m "X.Y.Z"

no tag yet. the tag goes on this commit once the apks built from it have
been proven, below; f-droid builds the tag, so anything pushed later is
the next release.

## 4. build the apks, in the container

    cd repro && ./release.sh

that is the release build. it clones the commit clean, builds the engine
and the three apks inside the pinned image at `/home/vagrant/build/app.kryfo`,
signs them with the release keystore mounted read only, and leaves them in
`repro/out/`. those three files are what you attach.

it has to be the container, not this machine. the dart snapshot in
`libapp.so` and the build-id of two plugin libraries bake in the absolute
build path, so an apk built anywhere else can never match f-droid's, no
matter what else is pinned. building where they build settles it and
pins the jdk, flutter, go and the ndk at the same time.

it refuses a dirty working tree: what ships must be a commit.

## 5. prove it reproduces

f-droid rebuilds the tag on its own box and publishes only if every byte
matches. confirm that before the tag exists:

    ./verify.sh --ref HEAD out/app-arm64-v8a-release.apk \
        out/app-armeabi-v7a-release.apk out/app-x86_64-release.apk

all three must say MATCH. a DIFFERS names the entries; the usual causes
are in repro/README.md. no tag until they match. do not pass `--cache`
for a release check; it shares the pub cache, which is fine, but a
release deserves the cold path.

## 6. tag and push

    git tag vX.Y.Z
    git push origin main
    git push origin vX.Y.Z

attach the three apks from `repro/out/` to the github release for anyone
sideloading before the f-droid index catches up. the armeabi-v7a one is
the 32-bit phones; it exists since 0.2.7.

## 7. f-droid

the recipe lives in the fdroiddata fork as `metadata/app.kryfo.yml`. once
the merge request is accepted their bot follows tags on its own
(`AutoUpdateMode: Version`). until then, add a `Builds:` block per abi for
the new tag and bump `CurrentVersion` and `CurrentVersionCode`. the recipe
has blocks for arm64 and x86_64 only, and `VercodeOperation` lists +2 and
+3: the 32-bit apk needs a third block with
`--target-platform=android-arm`, output `app-armeabi-v7a-release.apk`,
and a `'%c * 10 + 1'` operation, or f-droid never ships it.

## afterwards

confirm the tag is on github: `git ls-remote --tags origin | grep vX.Y.Z`.
