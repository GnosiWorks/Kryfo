# reproducible engine build

libhalo.so is halo's crypto/tor engine, built from the go source in
`../engine`. this setup lets anyone rebuild it byte for byte and confirm the
binary shipped in the apk matches the public source. no trust required.

## pinned

- go 1.23.4
- android ndk r28c (28.2.13676358)
- debian bookworm (snapshot-tagged)

all three are checksum-verified during the image build, so the toolchain
itself can't be swapped under you.

## first time

fetch the toolchain checksums into the Dockerfile (one time, then commit):

    ./fill-checksums.sh

## build and verify

just build and print hashes:

    ./verify.sh

build and compare against a shipped apk:

    ./verify.sh ../mobile/build/app/outputs/flutter-apk/app-release.apk

a `MATCH` on each arch means the engine in that apk was built from exactly
this source. a `DIFFERS` means something in the toolchain, source, or build
env changed.

## what makes it deterministic

- `-trimpath` strips absolute module and gopath prefixes from the binary
- `-buildid=` clears go's random build id
- `-w -s` drop debug/dwarf tables (which also carry local paths)
- the ndk linker runs with `--build-id=none` so lld adds no random note
- the build runs in a fixed `/build` workdir (cgo records the cwd)
- `SOURCE_DATE_EPOCH` pins any embedded timestamp

## note on go 1.25 toolchain auto-switch

the engine go.mod says `go 1.25.0`. the image ships exactly that, so go
won't try to download a different toolchain. if you bump the go directive in
go.mod, bump `GO_VERSION` in the Dockerfile to match or the build stops.
