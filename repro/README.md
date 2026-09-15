# reproducible build

f-droid does not take our apk. it builds one from the tagged source on its
own box, copies our signature onto it, and publishes only if every byte
matches. this directory is that check, run before a release instead of
after: the same source, in a container pinned to the same tools, at the
same path, diffed entry by entry against the apk you are about to publish.

## what a MATCH means

`verify.sh` unzips the published apk and the container's apk and compares
the sha256 of every entry: the manifest, resources, classes.dex, every
asset, every `lib/*/*.so`, the metadata under META-INF. only the v1
signature files (`*.SF`, `*.RSA`, `MANIFEST.MF`) are left out, and the
v2/v3 signing block is not a zip entry at all, because the container has
no keystore and signs with a throwaway key; f-droid copies your signature
across before it compares, so the signature is by definition not part of
the claim. MATCH means: everything f-droid would compare is byte for byte
what this source and this toolchain produce. it is the same test f-droid
runs.

`DIFFERS` names each entry that is not, with both hashes. that list is the
finding.

## use

    ./release.sh                 build the release apks in the container

that is the release build, not a check on one: it clones the commit
clean, builds engine and apks inside the image at f-droid's path, signs
them with the keystore mounted read only, and leaves them in `out/`.
those files are what you publish, so f-droid rebuilding the tag gets the
same bytes by construction. `--unsigned` keeps the keystore out of the
container and leaves the signing to you; the password is already in
plain text in `mobile/android/key.properties` either way.

    ./verify.sh --ref v0.2.8 path/to/app-arm64-v8a-release.apk

builds the image (first time: jdk, go, the android sdk, flutter, a while),
clones the repo at the ref into a temp dir, builds the engine from scratch
and then the apk inside the container, and diffs. give it all three apks
to check all three. `--cache` mounts your pub cache so the second run
does not fetch every package again; the output does not depend on it.
the gradle cache is never shared, because the host's journal lock
deadlocks against the container's daemon.
`--compare built.apk published.apk` skips the container and only diffs,
for looking at two apks you already have.

release rule: no tag until the three apks you will attach say MATCH
against a `--ref` of the commit you are about to tag. RELEASING.md has the
step.

## pinned

| what | version | why this one |
|---|---|---|
| debian | bookworm, snapshot 2025-06-30 | f-droid's buildserver is bookworm |
| jdk | debian's openjdk 17 | what f-droid's buildserver ships. build releases with 17 too, or classes.dex can differ |
| go | 1.25.0 | `engine/go.mod` and the f-droid recipe |
| flutter | 3.41.7, commit cc0734ac | the f-droid srclib; the commit is checked, a moved tag fails |
| android ndk | 28.2.13676358 | `ndkVersion` in `mobile/android/app/build.gradle.kts` |
| platforms | android-34, 35, 36 | flutter 3.41 compiles against 36; plugins such as just_audio still against 34 and 35 |
| build-tools | 35.0.0, 36.0.0 | agp 8.11 wants 35; a plugin asks for 36 |
| cmake | 3.22.1 | the jni and flutter_zxing plugins build native code with it |
| build path | /home/vagrant/build/app.kryfo | f-droid's path, see below |

go and the command line tools are checksum-verified; flutter is pinned to
a commit; the sdk pieces come from google's manager at exact versions.

## what makes it deterministic, and what breaks it

measured on 2026-09-14 against the published v0.2.7 arm64 apk:

- two clean `flutter build apk` runs on one machine, and the published
  apk, were identical. flutter, gradle, r8, the dex, resources, assets and
  the signing block are deterministic. every zip entry is stamped
  1981-01-01 by the android gradle plugin, so timestamps never enter.
- the same tag built in another directory differed in exactly three
  entries. `lib/*/libapp.so`, the dart aot snapshot, embeds the absolute
  path of the generated `dart_plugin_registrant.dart`, and a hash of that
  path is in a symbol name, so the whole snapshot shifts. `libdartjni.so`
  and `libflutter_zxing.so` are built by their plugins' own cmake and carry
  a build-id derived from the path. hence the fixed path in the container:
  build where f-droid builds and all three match.
- the engine, `lib/*/libhalo.so`, differed between two builds by ninety
  bytes: go's git stamp (`vcs.revision`, `vcs.time`, `vcs.modified`). the
  dirty flag flips on any untracked file, so no two machines agreed.
  `engine/build.sh` now passes `-buildvcs=false`. with that, plus
  `-trimpath`, `-buildid=`, `-w -s`, `--build-id=none` for the ndk linker
  and `SOURCE_DATE_EPOCH`, the engine is byte for byte across machines.
- go's build cache does not track the c headers under `engine/vendor`, so
  the container rebuilds every object (`HALO_FULL=1`). a dev box that
  edited those headers and rebuilt without it ships stale objects; the
  container does not, and the diff shows it.

## engine only, offline

`Dockerfile.offline` and `engine-only.sh` build just libhalo.so with go and
the ndk from local tarballs (`./prep-offline.sh` once to fetch them). it is
for a box with no network; it checks the engine, not the apk. its pins
must stay equal to the ones above.

## go toolchain auto-switch

`engine/go.mod` says `go 1.25.0`. the images ship exactly that, so go never
tries to fetch another toolchain. bump the directive, bump `GO_VERSION` in
both dockerfiles, or the build stops.
