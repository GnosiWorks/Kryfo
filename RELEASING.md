# releasing

what a release actually is, from the three we have cut. follow it top to
bottom. each step exists because skipping it has bitten us once.

## 1. before anything

- `cd mobile && flutter analyze` shows nothing but the known deprecation
  infos (flutter_secure_storage's `encryptedSharedPreferences`). a warning
  or an error stops the release.
- `flutter test` passes.
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
- the engine builds both architectures from a clean tree:
  `rm -rf engine/.gocache && cd engine && bash build.sh`. about twelve
  minutes; raise the file limit first (`ulimit -n 65536`) or cgo dies with
  "too many open files".
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
  `N * 10 + 2` for arm64, `N * 10 + 3` for x86_64. write both files, same
  text, a few short paragraphs, no markdown:
  `mobile/fastlane/metadata/android/en-US/changelogs/<N*10+2>.txt`
  `mobile/fastlane/metadata/android/en-US/changelogs/<N*10+3>.txt`
  these were missed until 0.2.3. f-droid shows them under "what's new".

## 3. commit and tag

    git add mobile/pubspec.yaml mobile/pubspec.lock CHANGELOG.md mobile/fastlane
    git commit -m "X.Y.Z"
    git tag vX.Y.Z
    git push origin main
    git push origin vX.Y.Z

the tag goes on the version commit itself, nothing after it. f-droid builds
the tag, so anything pushed later is the next release.

## 4. build the apks

    cd engine && bash build.sh && cd ../mobile
    flutter build apk --release --split-per-abi

signed with the release keystore that is not in the repo. attach the arm64
and x86_64 apks to the github release for anyone sideloading before the
f-droid index catches up.

## 5. f-droid

the recipe lives in the fdroiddata fork as `metadata/app.kryfo.yml`. once
the merge request is accepted their bot follows tags on its own
(`AutoUpdateMode: Version`). until then, add a `Builds:` block per abi for
the new tag and bump `CurrentVersion` and `CurrentVersionCode`.

## afterwards

confirm the tag is on github: `git ls-remote --tags origin | grep vX.Y.Z`.
