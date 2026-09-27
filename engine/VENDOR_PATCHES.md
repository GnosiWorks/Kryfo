# patched dependencies

three files under `vendor/github.com/alexballas/go-libtor/` differ from
upstream. `go mod vendor` silently drops them, and the 32-bit engine then
builds fine but never connects. don't run it. if the vendor tree has to be
rebuilt, re-apply these and build with `HALO_FULL=1 ./build.sh`, go's build
cache doesn't track these headers.

## openssl: bignum word size

`openssl_config/openssl/configuration.h` and
`linux/openssl/include/openssl/configuration.h`.

upstream hard-codes `SIXTY_FOUR_BIT_LONG`. on armeabi-v7a `unsigned long` is
four bytes, so every bignum operation is wrong. the patch defines
`THIRTY_TWO_BIT` when `ARCH_ANDROID32`, `ARCH_LINUX32` or `ARCH_WINDOWS32` is
set (go-libtor sets these in `libtor/libtor_preamble.go`), like go-libtor's own
`openssl_config/crypto/bn_conf.h`.

## libevent: generated config

`linux/libevent/include/event2/event-config.h` was generated on a 64-bit box
(eight-byte `long`, `size_t`, `time_t`, `pthread_t` and pointers), and it wins
over go-libtor's per-target configs, which are not on the include path.

the generated file is kept as `event-config.64.h`, `event-config.32.h` has the
five sizes set to 4 and `_FILE_OFFSET_BITS 64`, and `event-config.h` switches
on the same `ARCH_*32` defines. the 64-bit build is unchanged.

## check

    cd engine
    HALO_FULL=1 ./build.sh

on a 32-bit phone, settings > transport: tor leaves "starting" and reaches
100%.

reported upstream to alexballas/go-libtor.

## fiatjaf.com/nostr: a fork, not a hand patch

the relay library lives in `third_party/nostr` and go.mod points at it with
a `replace`, so `go mod vendor` copies it into vendor/ like any other module
and this one survives a re-vendor. it holds upstream's files for the two
packages the engine imports, tests left out, and upstream's go.mod. only
`relay.go` differs, in two dozen lines, the new ones marked `kryfo:`:

- subscription ids are counted per connection. upstream numbers every REQ
  in the process from one counter, which lets a relay line up a phone's
  sockets, burner rooms included, by where the counter has got to.
- `RelayOptions.PingInterval` and `PongTimeout`. zero keeps upstream's 19s
  and 800ms. the relay runners pass 90s and 20s in private mode (lanes.go):
  over tor a pong often takes longer than 800ms, and three late ones close
  the socket.

vendor/fiatjaf.com/nostr is a copy of it and has to stay one:

    diff -r third_party/nostr vendor/fiatjaf.com/nostr    # only go.mod

the change against upstream:

    go mod download fiatjaf.com/nostr@v0.0.0-20260508234157-a4c590d923ee
    diff -u "$(go env GOMODCACHE)/fiatjaf.com/nostr@v0.0.0-20260508234157-a4c590d923ee/relay.go" \
        third_party/nostr/relay.go

to move to a newer upstream: save that diff as a patch, copy the new
version's go.mod and the non-test files of its root and `nip45/hyperloglog`
over `third_party/nostr`, apply the patch, put the new version in go.mod's
require and in the first line of vendor/modules.txt, and copy
`third_party/nostr` into `vendor/fiatjaf.com/nostr` without its go.mod. if
the new go.mod moves any dependency it is a full update: `go mod vendor`,
then the go-libtor patches above again.

the engine's embedded module list names the replacement,
`=> ./third_party/nostr`, the same on every machine.
