# Kryfo

Kryfo is a private messenger for Android, with beta builds for Windows and Linux.
There is no phone number, no email and no account, and messages travel end to end encrypted over Tor.

## Who it's for

People who don't want their messages tied to a phone number or a real name. Journalists and their sources, activists, people on networks that block or watch messengers, and anyone who would rather not be findable by default.

## What's different

- **No phone number, email or account.** Your identity is three words, made on your phone. Nobody can look you up unless you pick a public @name, and that is off until you do.
- **Tor by default.** Messages go phone to phone over Tor onion services. When Tor is blocked, automatic mode tries bridges (Snowflake, WebTunnel, obfs4) and keeps the first one that works. Tested in heavily censored countries. Fast mode skips Tor for speed, and THREAT_MODEL.md says what it gives up.
- **Signal protocol, post-quantum.** Chats use libsignal. Between 0.6 phones a chat starts with PQXDH and runs SPQR, Signal's post-quantum ratchet, next to the double ratchet. Older chats move over once both sides have 0.6. FORWARD_SECRECY.md has the details.
- **Decoy PIN and hidden chats.** A decoy PIN opens an empty Kryfo, as if just installed. Hidden chats open only with their own PIN and leave no trace in the everyday app. A wipe PIN removes Kryfo from the phone.
- **Our servers keep no logs.** No accounts, no IP logs, no contact lists, no member lists. When the other side is offline, a message waits sealed on Nostr relays, ours and public ones, for up to 14 days. A relay can't read it and doesn't learn who sent it. SERVERS.md lists what each server could see.
- **No contact upload, no analytics, no ads.**

Optional push: a UnifiedPush app such as ntfy can wake Kryfo, off by default. Our relay sends it an empty knock and Kryfo still fetches over Tor. PRIVACY.md says what the helper's server learns. Google push exists only in the Google Play build, and stays off until you pick it.

Also in the app: groups, files up to 50 MB, voice notes with on-device transcripts, disappearing messages, linking a computer to your phone, offline translation, encrypted backups and a home screen icon that can look like an everyday app. CHANGELOG.md has the full list.

## Status

Kryfo is alpha software, written by one developer. It has not been audited yet.

Cure53 has quoted €15,470 for an independent security audit. It is booked once it is funded, and the full report will be public. If a funder brings its own audit firm, we use theirs. You can help fund it on [Open Collective](https://opencollective.com/kryfo/projects/independent-security-audit).

Read [THREAT_MODEL.md](THREAT_MODEL.md) before you rely on Kryfo. It says plainly what Kryfo protects against and what it doesn't. Don't rely on it where a mistake would put you in danger.

## Install

Install Kryfo only from these four places:

- **F-Droid:** [f-droid.org/packages/app.kryfo](https://f-droid.org/packages/app.kryfo/)
- **GitHub:** the [releases page](https://github.com/GnosiWorks/Kryfo/releases), with SHA-256 sums for every file. The universal APK installs on every ARM phone.
- **kryfo.app:** [kryfo.app/download](https://kryfo.app/download) has every build in one place.
- **Google Play:** [play.google.com/store/apps/details?id=app.kryfo](https://play.google.com/store/apps/details?id=app.kryfo)

Copies on other sites, such as APK mirrors, are not ours, even when they look the same.

Windows and Linux (beta) are on the releases page and on kryfo.app. The Windows installer is not signed yet, so SmartScreen warns before it runs. The Linux build needs glibc 2.38 or newer: Ubuntu 24.04 or newer, Debian 13, Fedora 39 or newer.

New contacts need 0.6 or newer on both phones. Chats with people still on 0.5.3 keep working; ask them to update before you add each other.

### Verify

Release APKs are reproducible. F-Droid builds Kryfo from the tagged source and publishes its build only if every byte matches ours. You can run the same check with `repro/verify.sh`, see [repro/README.md](repro/README.md).

The release signing certificate (SHA-256):

    10928a61642c5cc471a99869e2ea4e2d4d70026e797dfba48c0f306b5b3473db

Google Play installs are signed by Google's Play app signing key instead. Moving between Play and GitHub or F-Droid needs a backup, an uninstall and a restore.

The Windows build runs in public on GitHub Actions (.github/workflows/windows.yml). packaging/windows/CI.md says how to compare a download with a build of your own.

## Build from source

[BUILDING.md](BUILDING.md) has the toolchain versions, the desktop builds and the Flatpak. The short version for Android:

    cd engine && ./build.sh
    cd .. && mobile/native/kryfo_signal/build-android.sh
    cd mobile && flutter pub get --offline
    flutter build apk --release --split-per-abi --flavor foss

## Docs

- [THREAT_MODEL.md](THREAT_MODEL.md): what Kryfo protects against, and what it doesn't
- [PRIVACY.md](PRIVACY.md): what each part of Kryfo sends and what our servers see
- [FORWARD_SECRECY.md](FORWARD_SECRECY.md): what a key taken from a phone can open later
- [SERVERS.md](SERVERS.md): every server we run, where it runs and what it could log
- [RELAYS.md](RELAYS.md): the relay code and how it is deployed
- [BUILDING.md](BUILDING.md): every build, for Android and the desktop
- [RELEASING.md](RELEASING.md): the release checklist and the F-Droid recipe
- [repro/README.md](repro/README.md): reproducible builds and how to verify one
- [CHANGELOG.md](CHANGELOG.md): what changed in each version
- [ABUSE.md](ABUSE.md): child safety, and what we can and can't do
- [TERMS.md](TERMS.md): the terms for our servers and public listings

## Languages

17 languages: English, Arabic, Chinese (simplified and traditional), French, German, Hindi, Indonesian, Italian, Persian, Polish, Portuguese, Russian, Spanish, Turkish, Ukrainian and Vietnamese. Corrections from native speakers are welcome, see CONTRIBUTING.md.

## Contributing and security

- Bug reports, translations and pull requests: [CONTRIBUTING.md](CONTRIBUTING.md)
- Found a security problem? Please report it privately, see [SECURITY.md](SECURITY.md). Don't open a public issue for it.
- Support the work: [opencollective.com/kryfo](https://opencollective.com/kryfo)

## Licence

GPL-3.0-or-later, see [LICENSE](LICENSE). The sticker art is CC BY-SA 4.0, see `mobile/tool/stickers/fokia/LICENSE.md` and `mobile/tool/stickers/fokiaremix/LICENSE.md`. The names Kryfo and Fokia are not included: a fork may use the art, not the names.
