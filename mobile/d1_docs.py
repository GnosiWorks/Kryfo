#!/usr/bin/env python3
# d1: the repo docs a reviewer / privacy user reads first.
#   * THREAT_MODEL.md — the README already links to it but it doesn't exist
#     (broken link; reviewers click it). an honest what-it-does /
#     what-it-doesn't account, which for a privacy app is a credibility item,
#     not boilerplate.
#   * BUILDING.md — real build steps (the go engine needs go + ndk; "standard
#     toolchain" undersells it).
#   * README: fix the stale reproducible-build command and point at BUILDING.
# run from ~/halo
import io, os

io.open("THREAT_MODEL.md", "w", encoding="utf-8").write('''\
# Threat model

A straight account of what Halo protects against and what it does not. If you
face a serious adversary, read this in full before relying on the app.

## What Halo is

A messenger with no phone number, email, or account. Your identity is a key
pair generated on your device; your handle is derived from it. Messages are
end-to-end encrypted with the Signal double ratchet and travel over Tor onion
services, falling back to sealed nostr relay delivery when a contact is
offline.

## What it protects against

- **Network observers.** All traffic goes through Tor. A local network
  observer or ISP sees a Tor connection, not who you talk to or what you say.
- **The relays.** Offline messages sit on public nostr relays sealed with
  nip-44/59, so a relay learns neither the participants nor the content.
- **Server compromise.** There is no central server holding a contact graph
  or message history to seize. Onion delivery is device to device.
- **Casual device access.** The local database is encrypted with SQLCipher;
  the app can require biometric or PIN unlock; a panic action wipes
  everything, including media on disk.
- **Identity correlation by phone number.** There is no phone number or email
  to link you to a real identity, and no address-book upload.

## What it does NOT protect against

- **A compromised device.** Malware, a keylogger, or someone with your
  unlocked phone sees what you see. No messenger fixes an owned endpoint.
- **Your contact.** Anyone you talk to can screenshot, copy, or forward what
  you send, and can reveal that they talk to you.
- **Global traffic-analysis adversaries.** Tor raises the cost of correlation
  but a well-resourced adversary who can watch large portions of the network
  may still attempt timing analysis. Halo does not add cover traffic.
- **Metadata your own behavior leaks.** When you send while a contact is
  online, the timing of that exchange exists. Halo minimizes stored metadata;
  it cannot erase the fact that communication happened.
- **Endpoint forensics after the fact.** Encrypted-at-rest is not
  anti-forensics. A seized, unlocked, or backed-up device may yield data.
- **Compromised dependencies or this integration.** The crypto rests on
  standard libraries (libsignal, Tor, SQLCipher, nip-44/59), but the way they
  are wired together here is new and has NOT had an independent security
  review.

## Current status

Pre-alpha, unaudited, built by one person. Do not use it for anything where
being wrong would put you in danger. If you find a security issue, report it
privately (see the repository contact) rather than in a public issue.

## Cryptographic summary

- Identity: long-term key pair, on-device only.
- Sessions: Signal double ratchet (libsignal).
- Transport: Tor onion services; nostr relays with nip-44 encryption +
  nip-59 gift wrap for offline delivery.
- At rest: SQLCipher-encrypted database; media encrypted on disk.
- No telemetry, no analytics, no push service, no address-book upload.
''')
print("wrote THREAT_MODEL.md")

io.open("BUILDING.md", "w", encoding="utf-8").write('''\
# Building Halo

Two parts build in sequence: the Go engine (produces `libhalo.so`), then the
Flutter app that bundles it.

## Toolchain

- Flutter 3.41.7 (stable), Dart 3.11.5
- Go 1.23.4
- Android NDK r28c (28.2.13676358)
- Android SDK with platform-tools

The exact Go and NDK versions matter for a reproducible build — see `repro/`.

## 1. Build the engine

    cd engine
    ./build.sh

`build.sh` finds the NDK from `ANDROID_NDK_HOME` (or `$ANDROID_HOME/ndk/`),
builds `libhalo.so` for arm64 and x86_64, and writes them into the app's
`jniLibs`. It is fully offline: dependencies are vendored under
`engine/vendor/` and the Tor/OpenSSL C objects are cached in `engine/.gocache`,
so only the first build pays the native compile.

## 2. Build the app

    cd mobile
    flutter pub get --offline
    flutter build apk --release --target-platform android-arm64

The app ships arm64 only, matching the engine. A debug build for a connected
device:

    cd mobile/android
    ./gradlew --offline assembleDebug -Ptarget-platform=android-arm64

## Reproducible build

The engine has a reproducible build so anyone can confirm the `libhalo.so` in
a release matches this source. See `repro/README.md`. The toolchain there is
pinned to the versions listed above.

## Signing

Release builds are signed with a keystore that is not in this repository
(`key.properties` and `*.jks` are gitignored). Contributors build debug
APKs, which are signed with the standard Android debug key automatically.
''')
print("wrote BUILDING.md")

# README: fix the stale repro command + link BUILDING
r = io.open("README.md", encoding="utf-8").read()
old = """the flutter app builds with the standard toolchain. the go engine
(libhalo.so) has a reproducible build so anyone can confirm the binary in a
release matches this source:

    cd repro && ./fill-checksums.sh && ./verify.sh path/to.apk

see repro/README.md for detail."""
new = """see BUILDING.md for the full toolchain and steps. in short: build the go
engine (`cd engine && ./build.sh`), then the flutter app (`cd mobile &&
flutter build apk --release --target-platform android-arm64`).

the go engine (libhalo.so) has a reproducible build so anyone can confirm the
binary in a release matches this source; see repro/README.md."""
if old in r:
    r = r.replace(old, new)
    io.open("README.md", "w", encoding="utf-8").write(r)
    print("README build section fixed")
else:
    print("!! README build block not found verbatim — leaving it; check manually")

print("d1 ok")
