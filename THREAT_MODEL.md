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
