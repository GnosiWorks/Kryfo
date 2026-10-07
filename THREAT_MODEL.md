# threat model

what this protects against and what it does not. if getting this wrong could
put you in danger, read all of it.

## what it protects against

- network observers. by default everything goes through tor. your isp sees
  a tor connection, not who you talk to or what you say. relay and fast
  modes, which you can choose, skip tor for speed.
- the relays. offline messages sit on nostr relays sealed with nip-44/59. a
  relay learns neither who is talking nor what is said.
- server seizure. there is no central server holding a contact graph or
  message history. direct messages go device to device over onion services.
- casual device access. the database is sqlcipher encrypted, the app can
  require a pin or biometrics, and panic wipe removes everything including
  media on disk.
- phone number correlation. there is no number or email to tie you to a real
  identity, and no address book upload.
- someone making you unlock the app. a decoy pin opens an empty Kryfo, as if
  just installed. hidden chats open only with their own pin and show no trace
  in the everyday app: no row, no count, no notification while they are shut.
  a wipe pin removes Kryfo from the phone.
- someone answering as the developer. the key behind the "Marios · built
  Kryfo" chat is built into the app and checked on every message.

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
- a forensic copy of the phone. the decoy pin and hidden chats are for a
  quick look, someone scrolling through a phone you were made to unlock. they
  are not built to survive a lab. a copy of the phone can show that Kryfo
  holds more than it shows, and a short pin against such a copy can be
  guessed. android's storage and battery figures for the app are not hidden
  either. if a forensic copy is the fear, the wipe pin is the tool, and not
  having the data on the phone at all is better still.
- someone who already knows you. a person who knows your three words or
  handle sees different ones in the decoy, and nothing that arrives for you
  shows while it is open.
- backups kept outside the app. a backup made inside the hidden chats
  carries them, and its size can tell.
- the law. in some countries refusing to unlock a phone, or hiding data from
  officials, is an offence in itself. the decoy never invents conversations,
  because showing made-up messages to officials can make things worse. know
  the law where you are and where you travel.
- anonymous developer chats against their own content. writing anonymously
  hides your three words, not your writing style or what you say, and in
  relay and fast modes the relay sees your ip.
- this integration itself. the crypto is standard libraries (libsignal, tor,
  sqlcipher, nip-44/59) but the way they are wired together here is new and
  has not had an independent review.

FORWARD_SECRECY.md says what a key taken from a phone can open later.

## status

alpha, unaudited, one person. do not rely on it where being wrong would
hurt you. security issues: report privately, not in a public issue.
SECURITY.md says how.
