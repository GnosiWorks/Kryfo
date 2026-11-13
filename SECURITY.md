# Security

If you found a way to read someone's messages, learn who talks to whom, unmask a Kryfo user, get past the app lock, or make the app or the servers do something they shouldn't, please tell me privately first.

Kryfo is built by one person, so these reports come straight to me.

## How to report

Any of these reaches me:

- **GitHub:** a [private security advisory](https://github.com/GnosiWorks/Kryfo/security/advisories/new). Only you and I see it.
- **Email:** gnosiworks@proton.me
- **In the app:** the "Marios · built Kryfo" chat at the top of the chat list (from Kryfo 0.5.0). You can write from your own identity, or anonymously from a throwaway one. Its key is built into the app, so nobody else can answer as me.

The pinned developer identity:

    three words   scare-raven-rare
    key           2f3b ddfa dec1 e445 a44e 0b76 08b5 fcac
                  a5b8 4f00 b1ba 0341 c233 fc84 0ca8 7d3a

The key is what counts. Anyone can pick three words; the key is checked by the app. The same fingerprint is on kryfo.app.

Please don't open a public issue for a security problem.

## What to include

- what an attacker can do, and what they need first (a network position, a contact, the phone in hand)
- the Kryfo version (Settings, About) and where you installed it from
- the phone or computer and its system version
- the steps to reproduce, or a proof of concept
- whether you plan to publish, and when

A short note is enough. No need for a polished write-up.

Leave out other people's data. If you run into real user data while testing, stop, don't keep it, and tell me what you saw.

## What happens next

- I reply within 7 days, usually much sooner.
- Within 14 days I tell you whether I can reproduce it and how serious I think it is.
- A fix for anything that exposes messages, contacts or identities comes before everything else. I tell you when it ships, and credit you in the changelog if you want.
- Please give me 90 days, or until a fix is out, before you publish. If it is being exploited, we can move faster together.

I'm one person. If I'm away, a reply can take longer, but it won't get lost.

## Bounty

There is no bug bounty yet. I can credit you in the changelog and the release notes.

## Safe harbour

I won't take legal action against good faith research that keeps to this page:

- test on your own identities, devices and installs
- don't read, change or delete other people's data
- don't degrade the servers for others: no floods, no load tests, no spam into the handle registry or people search
- give me the time above before you publish

If someone else takes action against you for research that kept to this page, I'll say publicly that it did.

For heavy testing of the relay, run your own: the code is in `relay-live/`, see docs/RELAYS.md.

## In scope

- **The app:** Android, and the Windows and Linux betas (`mobile/`). Crypto, pair codes, storage and the lock layer, decoy and hidden chats, backups and restores, linked devices, the update check, the Tor and relay transport.
- **The engine** (`engine/`) and **the libsignal shim** (`mobile/native/kryfo_signal/`).
- **Our relays:** relay.kryfo.app and relay2.kryfo.app, and their onion addresses (`relay-live/`).
- **Our other services:** the handle registry, people search and the GIF relay on relay.kryfo.app, the files service (files.kryfo.app), the push gateway and the badge service (`server/`).
- **The website:** kryfo.app.
- **Release builds:** a way to make our reproducible build check pass on an APK that isn't ours.

## Out of scope

- attacks that need an unlocked phone or computer in someone else's hands, beyond what THREAT_MODEL.md says Kryfo should still hold
- a device that is already compromised (malware, root access)
- denial of service by volume
- public Nostr relays we don't run, and copies of Kryfo from sites other than F-Droid, GitHub, kryfo.app and Google Play
- findings in Tor, libsignal, Flutter or other upstream projects: report those upstream, but tell me too if Kryfo uses them in a way that makes it worse
- scanner output without a working attack, such as missing headers with no impact
- social engineering and physical attacks on me or the servers

## Audit

Kryfo has not been audited yet. Cure53 has quoted for an independent audit, and it is booked once it is funded: [Open Collective](https://opencollective.com/kryfo/projects/independent-security-audit). The report will be public.

THREAT_MODEL.md says what Kryfo protects against and what it doesn't.
