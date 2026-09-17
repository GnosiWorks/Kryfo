# threat model

what this protects against and what it does not. if getting this wrong could
put you in danger, read all of it.

## what it protects against

- network observers. everything goes through tor. your isp sees a tor
  connection, not who you talk to or what you say.
- the relays. offline messages sit on nostr relays sealed with nip-44/59. a
  relay learns neither who is talking nor what is said.
- server seizure. there is no central server holding a contact graph or
  message history. direct messages go device to device over onion services.
- casual device access. the database is sqlcipher encrypted, the app can
  require a pin or biometrics, and panic wipe removes everything including
  media on disk.
- phone number correlation. there is no number or email to tie you to a real
  identity, and no address book upload.

## what it does not protect against

- a compromised device. malware or someone holding your unlocked phone sees
  what you see. no messenger fixes an owned endpoint.
- the person you talk to. they can screenshot, copy, forward, or tell people
  they talk to you.
- global traffic analysis. tor raises the cost of correlation. an adversary
  watching large parts of the network can still try timing attacks. there is
  no cover traffic.
- the fact that you communicated. metadata is minimized, not erased. if you
  send while a contact is online, that timing existed.
- forensics on a seized unlocked device or on backups of it.
- our own server lining things up. the handle registry and the badge service
  run on the same machine as the relay today. nothing there logs who you are,
  but claiming a handle or buying a badge happens seconds away from your
  pubkey's relay traffic, and whoever holds that machine could match the two
  by time. they are moving to a separate box; SERVERS.md has the rule and the
  state of it. if you use neither, this does not touch you.
- this integration itself. the crypto is standard libraries (libsignal, tor,
  sqlcipher, nip-44/59) but the way they are wired together here is new and
  has not had an independent review.

## status

pre-alpha, unaudited, one person. do not rely on it where being wrong would
hurt you. security issues: report privately, not in a public issue.
