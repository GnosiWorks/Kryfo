# halo

*a privacy-first messenger*

anonymous bip-39 identities · libsignal double ratchet · tor onion routing · sqlcipher persistence

---

## status

pre-alpha. solo dev, open source, taking the time to do it right. usable for technical testers; not yet ready for friends-and-family.

## what it does today

- 1:1 encrypted chat over tor onion v3 (direct p2p) or nostr relays (store-and-forward)
- bip-39 anonymous ids ("thumb-behave-boring")
- libsignal double ratchet end-to-end
- in-app qr pairing
- ghost mode (self-destructing messages, 30s/1m/5m/1h/24h)
- reactions, reply-to
- app lock with pin + biometric, panic pin (silent wipe)
- procedurally generated avatars
- editorial design language — calm, restrained, italic serif accents, no neon "encrypted!!" stickers

## what it doesn't do

- no telemetry, crash reporting, analytics — ever
- no phone numbers, emails, accounts
- no google play services
- no proprietary blobs

## stack

- flutter (dart) — mobile ui, single codebase
- go shared library via cgo — embedded tor + nostr transport
- libsignal_protocol_dart — double ratchet, prekey bundles
- sqlcipher — encrypted local storage
- alexballas/go-libtor — embedded tor v3

android-first. ios port when a mac arrives.

## build from source

~~~
git clone https://github.com/<placeholder>/halo
cd halo
flutter build apk --debug --target-platform android-arm64,android-x64
~~~

requires:
- flutter 3.x
- android sdk + ndk
- go 1.21+ for the engine (cross-compiled to libhalo.so via aarch64-linux-android27-clang)

## license

[GNU Affero General Public License v3.0](LICENSE)

if you fork halo and run it as a hosted service, you must share your changes with users. if that doesn't work for your use case, a commercial license is available from the author.

## inspiration

graphene os (calm, technical, restraint over excitement). signal (the protocol). simplex (the architecture). telegram (the polish, not the politics).

---

**author**: mario · solo · open to issues, slow with prs (single-author repo for now)
