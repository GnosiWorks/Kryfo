# Kryfo

a private messenger. no phone number, no email, no account: your identity
is three words. messages are end to end encrypted with the signal protocol
and travel over tor by default.

kryfo is alpha software and has not been audited yet. an independent audit
by cure53 is planned. THREAT_MODEL.md says plainly what kryfo protects
against and what it doesn't. found a security problem? SECURITY.md says how
to tell us privately.

## features

- chats and groups with photos, videos, files, voice notes, replies,
  reactions and pins
- polls in groups and rooms, and search across all your chats
- disappearing messages and burner rooms that expire with everything in them
- an identity made of three words. an optional public handle, if you want
  to be found
- add someone by qr code, invite link or handle. a stranger's request shows
  only words until you accept
- app lock with a pin, a wipe pin and a decoy pin that opens an empty kryfo
- hidden chats behind their own pin
- encrypted backups and moving to a new phone
- tools that work offline: see what a photo or video gives away and remove
  all of it in one tap, private qr codes, file encryption with age
- tor bridges (snowflake, webtunnel, obfs4). automatic mode picks one when
  tor is blocked. tested in heavily censored countries
- a check-ins mode that is easier on the battery, and optional push through
  a unifiedpush app such as ntfy, off by default
- 15 languages, including persian and arabic
- no contact upload, no analytics, no ads

coming in 0.6: kryfo for windows and linux (beta) and linked devices,
post-quantum encryption between 0.6 phones, offline translation, an everyday
icon and name instead of kryfo's, and 17 languages.

## how it works

- **encryption:** 1:1 chats use libsignal: x3dh to start, the double ratchet
  after that. groups are pairwise over each member's 1:1 session.
  FORWARD_SECRECY.md has the details.
- **transport:** by default messages go phone to phone over tor onion
  services. when the other side is offline they wait, sealed, on nostr
  relays: ours and public ones. a relay sees only sealed envelopes: not what
  is in them and not who sent them.
- **servers hold nothing they don't need:** no accounts, no ip logs, no
  contact lists, no member lists. SERVERS.md and PRIVACY.md list what each
  server keeps and for how long.

## install

- **f-droid:** [f-droid.org/packages/app.kryfo](https://f-droid.org/packages/app.kryfo/)
- **google play (testing):** [play.google.com/apps/testing/app.kryfo](https://play.google.com/apps/testing/app.kryfo)
- **github releases:** the signed apks on the
  [releases page](https://github.com/GnosiWorks/Kryfo/releases), with their
  sha-256 sums
- **[kryfo.app/download](https://kryfo.app/download)** has all of them in one
  place

### verify

release apks are reproducible: `repro/verify.sh` builds a tagged commit the
same way f-droid does and compares it with the published apk, byte for byte.
see repro/README.md.

the release signing certificate (sha-256):

    10928a61642c5cc471a99869e2ea4e2d4d70026e797dfba48c0f306b5b3473db

google play installs are signed by google's play app signing key instead, so
moving between play and github or f-droid needs a backup, uninstall and
restore.

## build

see BUILDING.md. short version:

    cd engine && ./build.sh
    cd ../mobile && flutter build apk --release --split-per-abi

## languages

english, arabic, chinese (simplified and traditional), french, german,
indonesian, italian, persian, portuguese, russian, spanish, turkish,
ukrainian and vietnamese. corrections from native speakers are welcome.

## links

- website: [kryfo.app](https://kryfo.app)
- threat model: THREAT_MODEL.md and [kryfo.app/threat](https://kryfo.app/threat)
- security reports: SECURITY.md
- privacy: PRIVACY.md

## license

GPL-3.0-or-later. the sticker art is CC BY-SA 4.0, see
`mobile/tool/stickers/fokia/LICENSE.md` and
`mobile/tool/stickers/fokiaremix/LICENSE.md`. the names Kryfo and Fokia are
not included: a fork may use the art, not the names.
