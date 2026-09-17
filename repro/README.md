# reproducible build

f-droid does not take our apk. it builds one from the tagged source on its
own box, copies our signature onto it, and publishes only if every byte
matches. this directory is that check, run before a release instead of
after: the same source, in a container pinned to the same tools, at the
same path, diffed entry by entry against the apk you are about to publish.

## what a MATCH means

`verify.sh` builds twice and asks two different questions.

the first is the old one: does the apk you published match a build of that
commit at the path f-droid builds in. it unzips both and compares
the sha256 of every entry: the manifest, resources, classes.dex, every
asset, every `lib/*/*.so`, the metadata under META-INF. only the v1
signature files (`*.SF`, `*.RSA`, `MANIFEST.MF`) are left out, and the
v2/v3 signing block is not a zip entry at all, because the container has
no keystore and signs with a throwaway key; f-droid copies your signature
across before it compares, so the signature is by definition not part of
the claim. once the entries agree, verify runs `apksigcopier compare` from
the pinned image: your signature is copied onto the container build and the
result has to be your apk, to the byte. that is not like f-droid's test, it
is f-droid's test, with their tool. matching entries alone got 0.2.8 and
0.2.10 refused, because apksigner had re-padded the zip around them. MATCH
means apksigcopier said so.

`CONTAINER DIFFERS` means every entry matched and the zip around them did
not. release.sh passes `--alignment-preserved` to apksigner to keep that
from happening.

`DIFFERS` names each entry that is not, with both hashes. that list is the
finding.

the second question is the one we learned the hard way. the same commit is
built again at a different path inside the container and the two builds are
compared to each other. our container agreeing with our own build at one
path only says our pipeline is deterministic, which is not what f-droid
asks: they rebuild on their machine. 0.2.8 passed here and was rejected
there, on `lib/armeabi-v7a/libdartjni.so`, and nothing in this directory
could have seen it.

anything that differs between the two paths is reported, except one
allowlisted entry: `lib/*/libapp.so`. the dart snapshot embeds the path of
the generated plugin registrant and nothing can strip it, which is why
`release.sh` builds at f-droid's path rather than anywhere convenient.
every other name that ever appears on that list is a thing we have given up
on, so the list should stay one line long.

`--no-cross` skips the second build. it halves the wait and gives up the
only check that speaks to what f-droid's machine will do: fine while
iterating, not before a tag.

## use

    ./release.sh                 build the release apks in the container

that is the release build, not a check on one: it clones the commit
clean, builds engine and apks inside the image at f-droid's path, then
signs them here with apksigner and leaves them in `out/`. those files
are what you publish, so f-droid rebuilding the tag gets the same bytes
by construction.

the container builds unsigned and the keystore never goes into it. that
costs nothing: signing adds the block and the v1 files, which is exactly
what the comparison leaves out. measured on 2026-09-15 - an unsigned
build signed afterwards with apksigner is entry for entry identical to
the same source signed by gradle, same certificate. `--unsigned` stops
after the container and leaves the signing to you.

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
| signing | outside the container, apksigner, v2/v3 only | the key stays off the container; v1 would add three entries inside the zip, see below |

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

## why the release is signed v2/v3 and not v1

f-droid verifies by copying our signature onto their own unsigned build
and checking it still verifies. their page: "v2/v3 signatures cover all
other bytes in the APK. Thus, the APKs must be completely identical
before and after signing (apart from the signature) in order to verify
correctly."

a v1 (jar) signature is three more entries inside the zip. inserting them
moves bytes, so their placement has to be reproduced exactly or the v2
digest over the whole file fails. apksigcopier's own notes list v1
failures that come from zip metadata differing between signing tools.
the v2/v3 block sits outside the entries and is the thing it is built to
move.

minSdk is 24 and v1 is only needed below that, so dropping it costs
nothing. measured on 2026-09-15: f-droid's build of 0.2.8 was identical
to ours on all 558 content entries, same order, same compression, same
sizes. the only difference was our three v1 entries, and their digest
check failed on it.

## a build that failed once and passed once

the container is given 65536 open files on the command line. docker hands
one 1024 by default, and cgo building tor and openssl wants more than
that: the engine build died with "too many open files" on one run and
got through on the next, from the same source. a release tool that is a
coin flip is worse than one that always fails, so the limit is set
rather than asked for.

## engine only, offline

`Dockerfile.offline` and `engine-only.sh` build just libhalo.so with go and
the ndk from local tarballs (`./prep-offline.sh` once to fetch them). it is
for a box with no network; it checks the engine, not the apk. its pins
must stay equal to the ones above.

## go toolchain auto-switch

`engine/go.mod` says `go 1.25.0`. the images ship exactly that, so go never
tries to fetch another toolchain. bump the directive, bump `GO_VERSION` in
both dockerfiles, or the build stops.
