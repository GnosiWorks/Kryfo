# releasing

a feature goes into a release finished or not at all.

## checks

- `flutter analyze` shows nothing but the known deprecation infos
- `flutter test` passes
- `cd mobile/android && ./gradlew --offline :app:lintDebug :app:lintVitalAnalyzeRelease` passes
- every `ALTER TABLE` in mobile/lib/app/database.dart is inside a try/catch,
  and every new column is in each `CREATE TABLE` (test/schema_parity_test.dart)
- no logging outside dlog: `grep -rn "print(" mobile/lib | grep -v dlog` is empty
- the engine builds from clean: `cd engine && ulimit -n 65536 && HALO_FULL=1 ./build.sh`
- the tor tests pass: `cd engine && ./torconf-tests.sh` (needs the network, ~30 min).
  the two blocked tests build with the test censor on their own
- jniLibs holds a normal engine, not the test censor build: gradle and
  release.sh refuse that one (engine/censor-scan.sh). after a
  HALO_TOR_BLOCKED build, `cd engine && ./build.sh` again
- after a plugin change, read the merged manifest in
  build/app/intermediates/merged_manifests/, plugins add permissions
- a fresh clone resolves the lockfile: `flutter pub get --enforce-lockfile`
- the update key is pinned: `KRYFO_RELEASE=1 flutter test test/update_key_test.dart`

## version

- `version: X.Y.Z+N` in mobile/pubspec.yaml, then `flutter pub get`
- the version string, `settings030Alpha` in every mobile/lib/l10n/app_*.arb,
  then `flutter gen-l10n`
- a section in CHANGELOG.md
- the built-in bridges are current: `scripts/builtin-bridges.sh`, read the
  diff it shows before committing engine/builtin.json
- fastlane changelogs, one per abi, same text:
  `mobile/fastlane/metadata/android/en-US/changelogs/<N*10+1>.txt`, `+2`, `+3`

commit it as `X.Y.Z`. no tag yet.

## update notice

copies from the site or github check https://kryfo.app/version.json once a
day over tor. the file is signed with an ed25519 key kept offline.

once, to make the key (outside any git tree, under a passphrase):

    scripts/make-version-key.sh ~/offline/kryfo-version.pem

it prints the public key: put it in `kVersionPubKeyB64` in
mobile/lib/update_check.dart, in place of `kVersionKeyPlaceholder`.
release.sh refuses to sign while the placeholder is in
(scripts/check-version-key.sh), and sign-version.sh refuses any key but the
pinned one.

each release, after site/release.py has the new version in release.json:

    scripts/sign-version.sh X.Y.Z ~/offline/kryfo-version.pem [site folder]
    scripts/sign-version.sh --pubkey ~/offline/kryfo-version.pem

the second line has to print the key the app pins. the first writes
static/version.json and version.json.sig into the site folder (site/ by
default), and `site/build.py` and `site/check.py` take them into public/.
deploy after the github release is up, so the notice never points at a
page without the packages.

## build

    cd repro && ./release.sh

builds the commit in the pinned container at f-droid's build path, signs
outside it, and leaves the three apks in repro/out/. it refuses a dirty tree.
it has to be the container: libapp.so and two plugin libraries embed the
build path.

it retries twice when a fetch fails on the network and stops at once on
anything else. `./release.sh --offline` fetches the commit's pub and gradle
dependencies into repro/cache first and then builds with no network, same
bytes. see repro/README.md.

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
