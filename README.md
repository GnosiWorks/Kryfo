# halo

a private messenger. no phone number, no email, no account. messages go end
to end encrypted, routed over tor onion services or through nostr relays when
the other side is offline.

## status: pre-alpha, unaudited

this is early software built by one person. it has not had an independent
security review. the crypto rests on standard libraries (libsignal, tor,
sqlcipher, nip-44/59) but the integration is new and unproven. do not rely on
it for anything where being wrong would hurt you. read THREAT_MODEL.md for a
straight account of what it does and does not protect against.

known caveat in the current build: databases created before the random-key
fix use a weaker key derived from the install time. wipe and re-onboard to
upgrade.

## how it works

- identity is a key pair. your handle is three words derived from it.
- direct messages go device to device over tor onion services.
- when a contact is offline, messages wait on public nostr relays, sealed so
  the relay learns nothing about who is talking or what is said.
- contents use the signal double ratchet. storage is encrypted with sqlcipher.
- no address book upload, no analytics, no push service, nothing phones home.

## building

the flutter app builds with the standard toolchain. the go engine
(libhalo.so) has a reproducible build so anyone can confirm the binary in a
release matches this source:

    cd repro && ./fill-checksums.sh && ./verify.sh path/to.apk

see repro/README.md for detail.

## layout

- `mobile/` flutter app
- `engine/` go engine: identity, tor, nostr transport, crypto ffi
- `relay/` optional fast relay (store-and-forward, no auth yet, not for
  production)
- `repro/` reproducible engine build

## license

GPL-3.0.
