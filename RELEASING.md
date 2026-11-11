# Releasing

a feature goes into a release finished or not at all.

## checks

- `flutter analyze` shows nothing but the known deprecation infos
- `flutter test` passes
- `cd mobile/android && ./gradlew --offline :app:lintFossDebug :app:lintPlayDebug
  :app:lintVitalAnalyzeFossRelease :app:lintVitalAnalyzePlayRelease` passes
- every `ALTER TABLE` in mobile/lib/app/database.dart is inside a try/catch,
  and every new column is in each `CREATE TABLE` (test/schema_parity_test.dart)
- no logging outside dlog: `grep -rn "print(" mobile/lib | grep -v dlog` is empty
- the engine builds from clean: `cd engine && ulimit -n 65536 && HALO_FULL=1 ./build.sh`
- the shim builds and its licence list is current:
  `mobile/native/kryfo_signal/build-android.sh` and `acknowledgments.sh --check`
- the tor tests pass: `cd engine && ./torconf-tests.sh` (needs the network, ~30 min).
  the two blocked tests build with the test censor on their own
- jniLibs holds a normal engine, not the test censor build: gradle and
  release.sh refuse that one (engine/censor-scan.sh). after a
  HALO_TOR_BLOCKED build, `cd engine && ./build.sh` again
- after a plugin change, read the merged manifest in
  build/app/intermediates/merged_manifests/, plugins add permissions
- a fresh clone resolves the lockfile: `flutter pub get --enforce-lockfile`
- the update key is pinned: `KRYFO_RELEASE=1 flutter test test/update_key_test.dart`
- the dev chat's current pinned card carries a kyber prekey, so a new dev chat can start:
  `KRYFO_RELEASE=1 flutter test test/dev_key_test.dart` (release.sh checks the ref's card too,
  scripts/check-dev-card.sh)
- each apk's signal shim was built from the libsignal and spqr Cargo.lock pins (release.sh runs it):
  `repro/shim-check.sh out/app-*.apk`
- a phone on 0.5.3 and this version still talk both ways: in mobile/tool/peer053,
  `flutter pub get --offline` then
  `KRYFO_SIGNAL_LIB=$PWD/../../native/kryfo_signal/target/release/libkryfo_signal.so flutter test`
  (after `native/kryfo_signal/build-host.sh`)
- the push gateway's key is pinned (`kPushGatewayPub` in mobile/lib/google_push.dart, from
  `kryfo-push pubkey` on the server): `KRYFO_RELEASE=1 flutter test test/push_gateway_key_test.dart`
- the foss apk carries no google code: `unzip -p app-arm64-v8a-release.apk 'classes*.dex' | strings |
  grep -c 'com/google/firebase\|com/google/android/gms/common\|com/android/billingclient'` is 0, and
  `./gradlew --offline :app:dependencies --configuration fossReleaseRuntimeClasspath | grep -ci 'firebase\|billing'` is 0

## version

- `version: X.Y.Z+N` in mobile/pubspec.yaml, then `flutter pub get`
- `kAppVersion` in mobile/lib/app_version.dart, the same X.Y.Z
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
outside it, and leaves four apks in repro/out/: one per abi and
app-universal-release.apk, with both arm abis in one file (for the site and
github, it installs on every arm phone). it refuses a dirty tree.
it has to be the container: libapp.so and two plugin libraries embed the
build path.

it retries twice when a fetch fails on the network and stops at once on
anything else. `./release.sh --offline` fetches the commit's pub and gradle
dependencies into repro/cache first and then builds with no network, same
bytes. see repro/README.md.

## verify

    ./verify.sh --ref HEAD out/app-arm64-v8a-release.apk \
        out/app-armeabi-v7a-release.apk out/app-x86_64-release.apk \
        out/app-universal-release.apk

both builds have to pass: MATCH at f-droid's path, SAME at another one. no
`--no-cross` or `--cache` for a release.

## tag and push

    git tag vX.Y.Z
    git push origin main
    git push origin vX.Y.Z

attach the four apks from repro/out/ to the github release, and
libkryfo_signal-X.Y.Z-source.tar.gz and SHA256SUMS from the same folder (X.Y.Z is the
release's version): the complete source of the signal shim, which the AGPL
and the GPL want offered beside the apks. it holds the shim's own crate and
every crate its Cargo.lock names (libsignal's AGPL-3.0 ones, and the build
scripts and their dependencies too), vendored with checksums, so it builds
with `cargo build --offline` and nothing else. its README says how.

release.sh writes SHA256SUMS (`repro/sums.sh`). put the windows installer and zip and the linux
tarball into repro/out/ too, then `./sums.sh out X.Y.Z` adds SHA256SUMS-windows and
SHA256SUMS-linux, and `./sums.sh --check out X.Y.Z` checks all three. `./sums-test.sh` tests it.

## version codes

pubspec's `+N` becomes N*10 + one digit per apk:

    universal     N*10      (github and the site)
    armeabi-v7a   N*10+1
    arm64-v8a     N*10+2
    x86_64        N*10+3
    play bundle   N*10+9

android takes an update only with the same key and a code at least as high
as the installed one. so a phone on the universal apk can move to the small
apk of the same version or any later one, and from any apk to any later
version. a small apk back to the universal one of the same version is a
downgrade and android refuses it: that phone waits for the next version.
f-droid offers its per-abi build of the same version to a phone on the
universal apk, which is a harmless update to the same code.

## f-droid

fdroiddata/app.kryfo.yml goes into the fdroiddata fork as
metadata/app.kryfo.yml. one `Builds:` block per abi (version codes N*10+1,
+2, +3) and `CurrentVersion` / `CurrentVersionCode` for the newest. it has to
agree with the release:

- `ndk: r28c`, the one repro/Dockerfile pins
- the build line has `--flavor foss` and `output:` is
  `build/app/outputs/flutter-apk/app-<abi>-foss-release.apk`
- rust from mobile/native/kryfo_signal/rust-toolchain.toml, and
  `build-android.sh` run before the engine in every block
- `binary:` points at the release asset `app-<abi>-release.apk`. the universal apk is
  ours only: no `Builds:` block and no `VercodeOperation` for it
- the signature is a pure insertion, release.sh passes `--alignment-preserved`
- `AllowedAPKSigningKeys` is the certificate sha-256 that release.sh prints
- the translation library, in every block: `bash ../engine/translate/native/fetch-bergamot.sh`
  in `prebuild:` (it fetches the eight tarballs bergamot.lock pins and checks each sha256,
  then unpacks them with their tests, docs and tools left out), `scandelete:
  engine/translate/native/.third_party/dl` (the tarballs; the unpacked tree scans clean with
  fdroid scanner 2.4.5), and in `build:` before the apk
  `KT_JNI_LIBS_DIR=$(pwd)/android/app/src/main/jniLibs bash ../engine/translate/native/build.sh`.
  offline translation is on, so the apk carries it
- the voice library, from 0.6.1 on (voice transcripts are on; 0.6.0's recipe has none), in
  every block: the srclib `whisper.cpp@d1be6fde11ac6e0407606b4e42fe72d34add8037`
  (whisper.lock's commit, v1.9.5; fdroiddata's `srclibs/whisper.cpp.yml` is `RepoType: git`,
  `Repo: https://github.com/ggml-org/whisper.cpp.git`), in `prebuild:`
  `KV_WHISPER_DIR=$$whisper.cpp$$ bash ../engine/voice/native/fetch-whisper.sh` (it checks the
  checkout is the pinned commit and clean, then unpacks it with git archive), `scandelete:`
  `engine/voice/native/.third_party/whisper.cpp-d1be6fde11ac6e0407606b4e42fe72d34add8037/models`,
  `.../examples` and `.../bindings` (the test models, three gradle files and a package.json
  without a lock: fdroid scanner 2.4.5 flags nothing else, and the library builds the same
  bytes without them), and in `build:` before the apk
  `KV_JNI_LIBS_DIR=$(pwd)/android/app/src/main/jniLibs bash ../engine/voice/native/build.sh`.
  voice transcripts are on, so the apk carries it

then check the tag is up: `git ls-remote --tags origin | grep vX.Y.Z`

## the developer card (0.6, and whenever the card changes)

the card a release pins is made by the developer's phone itself, from its first start on the
release's own code:
1. build a release candidate: `KRYFO_RC=1 ./repro/release.sh --rc`. it is the final code with the
   old card still pinned; `KRYFO_RC=1 KRYFO_RELEASE=1 flutter test test/dev_key_test.dart` skips only
   the card check. release.sh refuses a final while KRYFO_RC is set, and a candidate without it. the
   candidate goes to repro/out/rc/, every file named -rc, its version name `<version>-rc`; it is never
   uploaded anywhere.
2. verify the candidate like a release (`HALO_BUILD_NAME=<version>-rc ./verify.sh ...`). it goes on
   the developer's phone as an update
   (`pm install -r`, same key, data kept), as close to release day as possible: from its first start
   0.5.x phones can no longer start a new dev chat.
3. after that first start: open the own link (My Kryfo, share), read the card off it, check it with
   the dev card self-check (`flutter test test/dev_key_test.dart` with the card as the current key,
   both prekey signatures under his key, a pq session builds), and pin it as the current key's
   bundle (same key id).
4. make an encrypted backup of the developer's phone right away: the pinned keys live
   only there. never reset its invite link, regenerate its identity or restore an older backup on it.
5. build and verify the final from the pinned commit (without KRYFO_RC), with
   `KRYFO_RELEASE=1 flutter test test/dev_key_test.dart` passing (the card's signatures and a pq
   session on it; release.sh only checks the kyber fields are there), and install it on the
   developer's phone over the candidate.
6. publish the signed version.json on release day, not before: it is what tells 0.5.x phones to
   update.

