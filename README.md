# Halo

A private messenger that doesn't look like one.

Most private messengers make you choose: real metadata resistance, or an interface you'd actually want to use. Halo is a bet that you can have both. Tor onion routing and gift-wrapped relay messages underneath, an editorial, considered interface on top.

> **Pre-alpha. Unaudited. Do not trust this with anything that matters yet.**
> The crypto is real but not independently reviewed. Treat Halo as a work in progress, not a tool to rely on.

## What it is

- Anonymous identities — no phone number, no email. Your id is three words from a BIP-39 seed.
- Tor onion routing by default. Direct onion-to-onion when both people are online; an encrypted relay mailbox when they're not.
- End-to-end encryption with the Double Ratchet (libsignal), forward secrecy, per-message keys.
- Encrypted at rest (SQLCipher).
- Disappearing messages, message verification, panic wipe, decoy access.
- No read receipts, no typing indicators, no analytics, no push tokens to a central server. Nothing about your activity leaves your device by default.

## What it is not

- Not audited. No third party has reviewed the cryptography. Until one has, assume there are bugs.
- Not anonymous against a global passive adversary. Tor and gift-wrapping resist ordinary relay-level observation; they are not mixnet-grade against someone watching the whole network. If that's your threat model, this isn't the tool.
- Not finished. Features are landing, things break, the schema still changes.

## How it works

- **Identity:** an ed25519 keypair, surfaced as a three-word id. The X25519 key doubles as the libsignal identity key and seeds per-conversation relay keys.
- **Transport:** direct Tor onion when both peers are reachable; a Nostr relay mailbox for offline delivery. Relay messages are gift-wrapped so the relay can't see who's talking to whom.
- **Encryption:** Double Ratchet over the established session. Messages are sealed before they ever touch the transport.
- **Storage:** SQLCipher. The local database is encrypted.

There is no Halo server holding your messages or your contact graph. The relays are dumb mailboxes that see only opaque, gift-wrapped events.

## Stack

- Flutter / Dart front end
- Go engine (libhalo) over FFI for transport and crypto plumbing
- libsignal (Double Ratchet, X25519 identity, prekeys)
- SQLCipher for at-rest encryption
- Embedded Tor
- Nostr relays for the offline mailbox

## Security

Halo is built against the LINDDUN privacy framework and the design notes track each cell.

- **Strong against:** relay operators learning your social graph, at-rest device seizure (encrypted storage + wipe), content interception (E2E).
- **Unverified:** all of it, until a third-party audit.

Found a security issue? Report it privately rather than opening a public issue.

## Status

Pre-alpha, single developer, built in the open. Expect rough edges, breaking changes, and gaps. It is not ready to be anyone's only messenger.
