# Reproducible build

f-droid builds its own apk from the tagged source, copies our signature onto
it, and publishes only if every byte matches. this directory runs that check
before a release.

## use

    ./release.sh

the release build. it clones the commit clean, builds the engine, the
shim and the three apks in the pinned container at f-droid's build path,
signs them outside the container with apksigner, and leaves them in `out/`
with `libkryfo_signal-<version>-source.tar.gz`, the complete source of the
signal shim for the release page: its own crate and every crate its
Cargo.lock names, build scripts and their dependencies included, vendored
with checksums and a `.cargo/config.toml`, so `cargo build --offline` builds
it from the archive alone. the keystore
never goes into the container. `--unsigned` stops before signing. it builds
the foss flavor, the one f-droid builds, and names the apks
`app-<abi>-release.apk` as before.

a step that fails on the network (a fetch error, a mirror answering 404) is
run again twice, after 60s and then 120s, from a fresh clone. any other
failure stops at once. the logs are in `out/`.

    ./release.sh --offline

the same build with the container's network cut. first, with the network,
the fetch step runs the apk build once in a throwaway clone and keeps what
it downloaded in `cache/` (about 2 GB, gitignored, replaced for a new
commit): the pub packages, flutter's own tool packages included,
gradle's dependency cache plus its distribution, and the shim's vendored
crates (135 MB). then the release build
gets a copy of both at the paths a normal build uses and runs with
`--network none`, pub `--offline`, `flutter build --no-pub` and gradle
offline, and the shim's crates copied into the clone with `KS_OFFLINE=1`.
`--fetch` only fills the cache. go needs nothing, engine/vendor has every
module. the image itself still needs the network the first time.

the cache holds downloads only, no build output, so it can't change a byte.
checked on c53cdbae: the offline build (container network none) and the
normal one gave the same three apks, byte for byte. f-droid builds with the
network and never sees `cache/`.

    ./verify.sh --ref vX.Y.Z out/app-arm64-v8a-release.apk \
        out/app-armeabi-v7a-release.apk out/app-x86_64-release.apk

builds the ref twice in the container and compares:

- at f-droid's path, against the apks you publish. every zip entry is
  compared by sha256 (v1 signature files aside), then `apksigcopier compare`
  copies your signature onto the container build, which has to give your apk
  byte for byte. that is f-droid's own check. prints MATCH.
- at a second path, against the first build. everything but
  `lib/*/libapp.so` has to be the same, since f-droid builds on its own
  machine. prints SAME.

`NO SHIM` means an apk lacks `lib/<abi>/libkryfo_signal.so`.
`CONTAINER DIFFERS` means the entries matched and the zip around them didn't.
`DIFFERS` lists each entry with both hashes. `--no-cross` skips the second
build, `--cache` mounts your pub cache. neither for a release.
`--compare built.apk published.apk` only diffs two apks.

## pinned

| what | version | why |
|---|---|---|
| debian | bookworm, snapshot 2025-06-30 | f-droid's buildserver |
| jdk | openjdk 17 | f-droid's buildserver, classes.dex can differ otherwise |
| go | 1.26.9 | engine/go.mod and the recipe |
| flutter | 3.41.7, commit cc0734ac | the f-droid srclib |
| android ndk | 28.2.13676358 | ndkVersion in build.gradle.kts |
| rust | 1.97.0, rustc 2d8144b7, minimal, three android targets | mobile/native/kryfo_signal/rust-toolchain.toml |
| rust channel manifest | sha256 3804d266... | holds the sha256 of every component: the six rustup installs must carry its hashes |
| rustup-init | 1.29.1, by sha256 | installs the toolchain, adds no byte to it |
| protoc, gcc | debian's | protoc 3.21 and 36.2 give the same shim; gcc only links build scripts |
| shim crates | Cargo.lock, vendored into the crate's target/vendor | libsignal 387da3e2 (v0.99.4), spqr fd320484 (v1.5.3) |
| platforms | android-34, 35, 36 | flutter and plugins |
| build-tools | 35.0.0, 36.0.0 | agp 8.11 and a plugin |
| cmake | 3.22.1 | jni and flutter_zxing |
| build path | /home/vagrant/build/app.kryfo | f-droid's path |
| signing | apksigner, v2/v3 only, outside the container | see below |

## what the path and flags fix

- `lib/*/libapp.so` embeds the path of the generated plugin registrant, and
  `libdartjni.so` and `libflutter_zxing.so` get a build-id from the path. so
  the build runs at f-droid's path.
- the engine is built with `-buildvcs=false`, `-trimpath`, `-buildid=`,
  `-w -s`, `--build-id=none` and `SOURCE_DATE_EPOCH`.
- go's cache doesn't track the c headers in engine/vendor, so the container
  always builds with `HALO_FULL=1`.
- the shim (libkryfo_signal.so) is built by build-android.sh with
  `--remap-path-prefix` for the crate and the cargo home, `--build-id=none`,
  16 kb pages on the 64-bit abis, and the committed release profile (fat
  lto, one codegen unit, strip). panic messages keep their source paths, so
  every build, here, on a dev box and on f-droid's, compiles from the same
  `target/vendor` layout. its sha256 per abi is printed by verify.sh and
  written into the stamp beside each library in jniLibs.
- the container's gradle runs with a 2560m heap and a 1g kotlin daemon
  (build-repro.sh writes them into its gradle user home), not the project's
  4G, and two workers, so a build leaves room on an 8 GB machine. the bytes
  are the same.
- the container gets 65536 open files. cgo building tor and openssl runs out
  at docker's default 1024.

## v2/v3 only

f-droid copies our signature onto its unsigned build. v1 adds three entries
inside the zip and moves bytes, v2/v3 sits outside the entries. minSdk is 24,
so v1 isn't needed. `release.sh` passes `--alignment-preserved` so signing
doesn't re-pad the zip.

## engine only, offline

`Dockerfile.offline` and `engine-only.sh` build only libhalo.so from local
tarballs (`./prep-offline.sh` fetches them once). keep its pins equal to the
ones above. bumping go means go.mod, `GO_VERSION` in both dockerfiles and
prep-offline.sh together.
