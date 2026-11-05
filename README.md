# Kryfo

a private messenger for android, with test builds for linux and windows.
no phone number, no email, no account. messages are end to end encrypted
and by default go phone to phone over tor onion services, or wait on nostr
relays when the other side is offline.

alpha and not audited yet. THREAT_MODEL.md says what it protects against
and what it doesn't.
found a security problem? SECURITY.md says how to tell me privately.

## features

- chats and groups with photos, videos, files, voice notes, replies,
  reactions and pins
- polls in groups and rooms, and search across all your chats, on the phone
- disappearing messages and burner rooms that expire with everything in them
- an identity made of three words, no phone number. optional public handle
- post-quantum encryption (pqxdh and spqr) in every chat between 0.6 phones,
  and older chats move over once both sides update
- add someone by qr code, invite link, handle or an eight digit pair code.
  a stranger's request shows only words until you accept
- app lock with a pin, a wipe pin and a decoy pin
- encrypted backups and moving to a new phone
- photos, voice notes and files are encrypted on the phone too, and no
  photo stays decoded behind the lock
- tools that work offline: see what a photo or video gives away and remove
  all of it in one tap, qr codes, file encryption with age
- tor bridges: snowflake, webtunnel and obfs4. automatic mode tries one when
  tor is blocked, tested in heavily censored countries. PRIVACY.md says what
  they connect to
- a check-ins mode that is easier on the battery
- optional push through a unifiedpush helper app such as ntfy, off by
  default. our relay sends it an empty knock when something waits for you,
  and Kryfo still fetches over tor. the helper's server learns your ip, that
  you use Kryfo, and when knocks come. PRIVACY.md has the details
- google push in the google play build only, off until you pick it
- 17 languages, including persian, arabic and hindi
- no contact upload and no analytics

## build

see BUILDING.md. short version:

    cd engine && ./build.sh
    cd ../mobile && flutter build apk --release --split-per-abi --flavor foss

## verify

release apks are reproducible. `repro/verify.sh` builds a tagged commit the
same way f-droid builds it and compares it with the published apk, see
repro/README.md.

the release signing certificate (sha-256):

    10928a61642c5cc471a99869e2ea4e2d4d70026e797dfba48c0f306b5b3473db

## license

GPL-3.0-or-later. the sticker art is CC BY-SA 4.0, see
`mobile/tool/stickers/fokia/LICENSE.md` and
`mobile/tool/stickers/fokiaremix/LICENSE.md`. the names Kryfo and Fokia are
not included: a fork may use the art, not the names.
