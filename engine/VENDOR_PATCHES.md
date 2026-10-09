# patched dependencies

vendor/ is rebuilt with `./vendor.sh`, never with a bare `go mod vendor`.
go mod vendor copies go package dirs only, while go-libtor, sonic, base64x
and golang-asm compile c and asm from the dirs next to them, and it knows
nothing of the go-libtor patch below. vendor.sh copies those modules whole
from the module cache, drops what the repo does not keep and applies
`vendor-patches/go-libtor.patch`. after it, `git status` shows only what the
go.mod change meant. go's build cache doesn't track the c headers, so build
with `HALO_FULL=1 ./build.sh` after any change there.

## go-libtor: 32-bit headers

go-libtor v1.0.8 ships tor 0.4.9.12 and openssl 3.6.3. six headers under
`vendor/github.com/alexballas/go-libtor/` differ from it or are added, all in
vendor-patches/go-libtor.patch. without them the 32-bit engine builds fine
but never connects.

### openssl: bignum word size

`openssl_config/openssl/configuration.h` and
`linux/openssl/include/openssl/configuration.h`.

upstream hard-codes `SIXTY_FOUR_BIT_LONG`. on armeabi-v7a `unsigned long` is
four bytes, so every bignum operation is wrong. the patch defines
`THIRTY_TWO_BIT` when `ARCH_ANDROID32`, `ARCH_LINUX32` or `ARCH_WINDOWS32` is
set (go-libtor sets these in `libtor/libtor_preamble.go`), like go-libtor's own
`openssl_config/crypto/bn_conf.h`.

### libevent: generated config

`linux/libevent/include/event2/event-config.h` was generated on a 64-bit box
(eight-byte `long`, `size_t`, `time_t`, `pthread_t` and pointers), and it wins
over go-libtor's per-target configs, which are not on the include path.

the generated file is kept as `event-config.64.h`, `event-config.32.h` has the
five sizes set to 4 and `_FILE_OFFSET_BITS 64`, and `event-config.h` switches
on the same `ARCH_*32` defines. both leave `EVENT__HAVE_EPOLL_PWAIT2` unset,
as does `builddeps/libevent/usr/local/include/event2/event-config.h`: bionic
has no epoll_pwait2 below api 35.

### check

    cd engine
    HALO_FULL=1 ./build.sh

on a 32-bit phone, settings > transport: tor leaves "starting" and reaches
100%.

reported upstream to alexballas/go-libtor.

go-libtor's process types come from its own copy of bine's process package
(github.com/alexballas/bine). tor_process.go hands them to cretz/bine, which
the engine uses, through `libtorCreator`.

## fiatjaf.com/nostr: a fork, not a hand patch

the relay library lives in `third_party/nostr` and go.mod points at it with
a `replace`, so `go mod vendor` copies it into vendor/ like any other module
and this one survives a re-vendor. it holds upstream's files for the two
packages the engine imports, tests left out, and upstream's go.mod. six
files differ, the new lines marked `kryfo:`:

- `relay.go`: subscription ids are counted per connection. upstream numbers
  every REQ in the process from one counter, which lets a relay line up a
  phone's sockets, burner rooms included, by where the counter has got to.
- `relay.go`: `RelayOptions.PingInterval` and `PongTimeout`. zero keeps
  upstream's 19s and 800ms. the relay runners pass 90s and 20s in private
  mode (lanes.go): over tor a pong often takes longer than 800ms, and three
  late ones close the socket.
- `relay.go`: `handleMessage` ends at most its own connection, whatever
  the frame, and the caller dials again.
- `relay.go`: a publish that sees its connection end clears the OK
  callbacks under their lock. upstream clears them without it, which races
  with other publishes on the same connection.
- `helpers.go`, `envelopes.go`, `relay.go`: length checks in the frame
  pre-parsers and the OK envelope.
- `signature.go`, `signature_libsecp256k1.go`: `VerifySignature` also
  requires the event's id field to be the id its body hashes to. the hash
  is computed once, as before.
- `subscription.go`: a CLOSED frame hands its reason over only while the
  channel has room, and without a goroutine of its own. upstream starts one
  per frame, and each waits until someone reads.
- `subscription.go`, `relay.go`: a subscription's events are queued in the
  order they were read and handed over by one goroutine at a time, and once
  the subscription has ended the rest is dropped. upstream starts a
  goroutine per event, so a later one can overtake an earlier one, and a
  catch-up page cut short could keep an older event and lose newer ones
  sent before it. `Events` is closed only while nothing is handing over, so
  nothing sends on it once it is closed. `dispatchEose` takes the same lock
  and queues the EOSE behind the stored events, and the same goroutine
  hands it over on `EndOfStoredEvents`, which is unbuffered: an event after
  it waits until it is taken, so a reader taking either channel cannot take
  a live event for a stored one. an EOSE faked after `MaxWaitForEOSE`
  waits behind the stored events still queued too, where upstream drops
  them. a subscription that ends, or gets a CLOSED, drops what is still
  queued, the EOSE with it. a reader that wants events after the EOSE has
  to take it.

vendor/fiatjaf.com/nostr is a copy of it and has to stay one:

    diff -r third_party/nostr vendor/fiatjaf.com/nostr    # only go.mod

the change against upstream:

    go mod download fiatjaf.com/nostr@v0.0.0-20260508234157-a4c590d923ee
    up="$(go env GOMODCACHE)/fiatjaf.com/nostr@v0.0.0-20260508234157-a4c590d923ee"
    for f in relay.go helpers.go envelopes.go signature.go signature_libsecp256k1.go subscription.go; do
        diff -u "$up/$f" "third_party/nostr/$f"
    done

to move to a newer upstream: save that diff as a patch, copy the new
version's go.mod and the non-test files of its root and `nip45/hyperloglog`
over `third_party/nostr`, apply the patch, put the new version in go.mod's
require and in the first line of vendor/modules.txt, and copy
`third_party/nostr` into `vendor/fiatjaf.com/nostr` without its go.mod. if
the new go.mod moves any dependency it is a full update: `./vendor.sh`.

the engine's embedded module list names the replacement,
`=> ./third_party/nostr`, the same on every machine.

## snowflake: a client-only fork without sqs

snowflake v2.14.1 (cd33fc638ac0) lives in `third_party/snowflake` and go.mod
points at it with a `replace`, like nostr above. it holds upstream's
LICENSE, go.mod, `client/lib` and the `common` packages it imports, tests
left out. it differs from upstream in:

- `client/lib/rendezvous_sqs.go` is gone, and the aws sdk with it. the
  broker is reached through cdn fronting only. upstream has no build tag
  for it.
- `client/lib/rendezvous.go`: a config that asks for sqs, or for no
  rendezvous at all, gets an error back instead of `log.Fatal`, which would
  end the app the engine runs in. marked `kryfo:`.
- `go.mod`: the aws and golang/mock requirements are dropped.

vendor/gitlab.torproject.org/.../snowflake/v2 is a copy of it:

    diff -r third_party/snowflake vendor/gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/v2    # only go.mod

to move to a newer upstream: copy the new tag's LICENSE, go.mod and the
non-test files of the same packages over `third_party/snowflake`, delete
`rendezvous_sqs.go`, redo the two edits, then `./vendor.sh`.

## lyrebird

lyrebird-0.8.1, commit 0b10edbb61e0. its tags are not go semver tags, so
go.mod names the tag's commit as a pseudo-version. 0.9.0 asks for go
1.26.0 and the engine builds with 1.25.14. the engine imports the obfs4,
webtunnel and meek_lite transports one by one, never `transports.Init()`.

lyrebird 0.8.1's own go.mod replaces utls with a temporary fork for the
chrome120 profile. go ignores replaces in dependencies, so the engine gets
utls v1.8.2 through snowflake, which dropped the same backport when it
moved to that utls.
