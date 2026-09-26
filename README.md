# Kryfo

a private messenger for android. no phone number, no email, no account.
messages are end to end encrypted and go phone to phone over tor onion
services, or wait on nostr relays when the other side is offline.

pre-alpha and not audited yet. THREAT_MODEL.md says what it protects against
and what it doesn't.

## features

- chats and groups with photos, videos, files, voice notes, replies,
  reactions and pins
- disappearing messages and burner rooms that expire with everything in them
- an identity made of three words, no phone number. optional public handle
- app lock with a pin, and a wipe pin
- encrypted backups and moving to a new phone
- tools that work offline: see what a photo gives away, clean photos and
  videos, qr codes, file encryption with age
- tor bridges (obfs4), and a check-ins mode that is easier on the battery
- 15 languages, including persian and arabic
- no contact upload, no analytics, no push service

## build

see BUILDING.md. short version:

    cd engine && ./build.sh
    cd ../mobile && flutter build apk --release --split-per-abi

## verify

release apks are reproducible. `repro/verify.sh` builds a tagged commit in
the same container f-droid uses and compares it with the published apk, see
repro/README.md.

the release signing certificate (sha-256):

    10928a61642c5cc471a99869e2ea4e2d4d70026e797dfba48c0f306b5b3473db

## license

GPL-3.0
