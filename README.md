# Kryfo

a private messenger for android. no phone number, no email, no account.
messages are end to end encrypted and go over tor onion services, or wait on
nostr relays when the other side is offline.

## status

pre-alpha and unaudited. one person builds it and nobody has reviewed its
security yet. don't rely on it where being wrong would hurt you.
THREAT_MODEL.md says what it protects against and what it doesn't.

databases created before the random-key fix use a weaker key derived from the
install time. wipe and set up again to upgrade.

## how it works

- your identity is a key pair, your handle is three words derived from it
- messages go phone to phone over tor onion services
- when a contact is offline, sealed messages wait on nostr relays (nip-44/59)
- signal double ratchet for messages, sqlcipher for storage
- no contact upload, no analytics, no push service

## building

see BUILDING.md. release builds are reproducible, see repro/README.md.

## layout

- `mobile/` flutter app
- `engine/` go engine: identity, tor, nostr, crypto
- `server/` handle registry
- `relay/` optional relay, not for production
- `repro/` reproducible release builds

## license

GPL-3.0
