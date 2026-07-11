# threat model

this is an honest account of what halo protects, what it doesn't, and where
the current build (pre-alpha, unaudited) falls short of its own goals. it is
written against the LINDDUN privacy framework: linkability, identifiability,
non-repudiation, detectability, disclosure of information, unawareness,
non-compliance.

read this before trusting halo with anything that could put you at risk.
nothing here has been through an independent security audit.

## what halo is

a messenger that routes messages two ways: directly between devices over tor
onion services, or store-and-forward through public nostr relays when the
other side is offline. message contents are end-to-end encrypted with the
signal double ratchet. metadata is hidden through onion routing and, on the
relay path, through per-conversation disposable keys.

## who it is meant to protect against

- a relay operator who wants to read messages or map who talks to whom
- a network observer between you and the relay
- someone who steals or seizes the device (at-rest encryption + panic wipe)
- a stranger trying to reach you unsolicited (contact gating)

## who it does not protect against

- a global passive adversary who can watch the whole tor network at once.
  halo is not a mixnet. traffic-timing correlation by someone with that reach
  is out of scope, the same as it is for tor itself.
- a compromised device. if your phone is rooted by an attacker, keys in
  memory are exposed. nothing on the app side can fix that.
- someone you have knowingly added and verified who then betrays you.
  end-to-end encryption protects the channel, not the person on the far end.

## per-property notes

**linkability.** on the relay path each conversation uses a disposable key
pair derived from the shared secret, so a relay sees unconnected events, not
a thread. it cannot link your conversations to each other or to a stable
identity. weakness: within one conversation, the receive address is stable
for now, so a relay can group the messages flowing to that one address
(still not tied to you or your other chats). rotating the address per epoch
is planned.

**identifiability.** no phone number, no email, no account. identity is a
key pair; your public handle is three words derived from it. relays never
see your real pubkey on the relay path. on the direct path your onion
address is shared only with contacts you add.

**non-repudiation.** the double ratchet gives deniability at the protocol
level. we do not add signatures that would let a third party prove you sent
a given message.

**detectability.** tor use itself is detectable by your network provider
(they see you connecting to the tor network, not what you do). the fast
clearnet relay mode, when it ships, will be clearly labelled as revealing
your ip to the relay; it is off by default.

**disclosure of information.** contents are encrypted end to end. the
database is encrypted at rest with sqlcipher. IMPORTANT current-build
caveat: installs created before the csprng passphrase fix derived the
database key from the launch timestamp and are weaker; wipe and re-onboard
to get a strong key. link previews are fetched sender-side so the receiver
never leaks their ip to a link's host.

**unawareness.** every privacy-reducing convenience is off by default and
labelled where it is offered. the app does not upload your address book,
does not learn your social graph, and does not phone home. there is no
analytics, no firebase, no push service baked in.

**non-compliance.** open source, GPL-3.0. the engine is reproducibly
buildable so anyone can confirm the shipped binary matches this source.

## honest status

pre-alpha. unaudited. built by one person. the crypto core uses standard,
well-reviewed libraries (libsignal, nip-44/59, sqlcipher, tor) but the way
they are wired together here has not been reviewed by anyone else. treat it
as experimental until that changes. do not bet your safety on it yet.
