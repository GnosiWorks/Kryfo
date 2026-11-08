# Kryfo

a private messenger for android, with beta builds for windows and linux.
no phone number, no email, no account: your identity is three words.
messages are end to end encrypted with the signal protocol, post-quantum
between 0.6 phones, and travel over tor by default.

Kryfo is alpha software and has not been audited yet. an independent audit
by cure53 is planned. THREAT_MODEL.md says plainly what Kryfo protects
against and what it doesn't. found a security problem? SECURITY.md says how
to tell us privately.

## features

- chats and groups with photos, videos, files, voice notes, replies,
  reactions and pins
- polls in groups and rooms, and search across all your chats
- disappearing messages and burner rooms that expire with everything in them
- an identity made of three words. an optional public handle, if you want
  to be found
- post-quantum encryption (pqxdh and spqr) in every chat between 0.6
  phones. older chats move over by themselves once both sides have 0.6
- add someone by qr code, invite link, handle or an eight digit pair code.
  a stranger's request shows only words until you accept
- link a computer to your phone: scan its code, compare six digits, and
  pick what comes over: every chat, text only, or contacts and groups only.
  new messages reach both, read and deleted ones stay in step, and hidden
  chats stay on the phone. remove it from the phone at any time and it
  erases itself
- files up to 50 MB between 0.6 phones. they wait, sealed, on our files
  service until the other side fetches them, for a week at most
- app lock with a pin, a wipe pin and a decoy pin that opens an empty Kryfo
- hidden chats behind their own pin
- the home screen icon and name can look like an everyday app: notes,
  weather, tasks or news
- photos, voice notes and files are encrypted on the phone too, and no
  photo stays decoded behind the lock
- with message previews off, notifications are one shared "New message"
  alert, so nobody can count your chats
- encrypted backups and moving to a new phone
- tools that work offline: see what a photo or video gives away and remove
  all of it in one tap, private qr codes, file encryption with age
- offline translation on the phone, never on a server
- tor bridges (snowflake, webtunnel, obfs4). automatic mode picks one when
  tor is blocked. tested in heavily censored countries
- a check-ins mode that is easier on the battery, and optional push through
  a unifiedpush app such as ntfy, off by default. our relay sends it an
  empty knock and Kryfo still fetches over tor. PRIVACY.md says what the
  helper's server learns
- google push in the google play build only, off until you pick it
- 17 languages, including persian, arabic and hindi
- no contact upload, no analytics, no ads

## how it works

1:1 chats use libsignal. between 0.6 phones a chat starts with pqxdh and
runs the double ratchet together with spqr, signal's post-quantum ratchet.
chats that started before 0.6 began with x3dh and move over once both sides
have 0.6. groups are pairwise over each member's 1:1 session.
FORWARD_SECRECY.md has the details.

by default messages go phone to phone over tor onion services. when the
other side is offline they wait, sealed, on nostr relays: ours and public
ones. a relay sees only sealed envelopes: not what is in them and not who
sent them.

the servers hold nothing they don't need: no accounts, no ip logs, no
contact lists, no member lists. SERVERS.md and PRIVACY.md list what each
server keeps and for how long.

## install

- **f-droid:** [f-droid.org/packages/app.kryfo](https://f-droid.org/packages/app.kryfo/)
- **google play:** [play.google.com/store/apps/details?id=app.kryfo](https://play.google.com/store/apps/details?id=app.kryfo)
- **github releases:** the signed apks on the
  [releases page](https://github.com/GnosiWorks/Kryfo/releases), with their
  sha-256 sums. the universal apk works on every arm phone
- **windows and linux (beta):** on the releases page too. the windows
  installer is not signed yet, so SmartScreen warns before it runs. windows
  builds will be signed once SignPath approves. the linux beta needs glibc
  2.38 or newer: ubuntu 24.04 or newer, debian 13, fedora 39 or newer
- **[kryfo.app/download](https://kryfo.app/download)** has all of them in one
  place

new contacts need 0.6 on both phones. chats with people still on 0.5.3 keep
working; ask them to update before you add each other.

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
    cd ../mobile && flutter build apk --release --split-per-abi --flavor foss

the windows and linux builds are in BUILDING.md too.

## languages

english, arabic, chinese (simplified and traditional), french, german,
hindi, indonesian, italian, persian, polish, portuguese, russian, spanish,
turkish, ukrainian and vietnamese. corrections from native speakers are
welcome.

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
