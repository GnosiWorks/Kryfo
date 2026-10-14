# threat model

what this protects against and what it does not. if getting this wrong could
put you in danger, read all of it.

## what it protects against

- network observers. by default your messages go through tor. your isp sees
  a tor connection, or a bridge when tor is blocked, not who you talk to or
  what you say. relay and fast modes, which you can choose, skip tor for
  speed.
- networks that block tor. automatic mode tries tor the usual way first.
  when tor's own signals say the network cuts it off, it tries bridges one
  at a time: what the tor project suggests (only after you say yes), the
  built-in obfs4 bridges, snowflake and saved webtunnel lines. it keeps the
  first that carries tor and remembers it per network type for 30 days.
- the relays. messages travel through nostr relays, sealed twice with
  nip-44/59 and sent from a throwaway key to a mailbox address that belongs
  to one conversation and to nobody's identity. no relay can read them. on
  the onion route the relays never learn your ip address or who you are. on
  the relay and fast routes they see your ip address, never what you say.
- server seizure. there is no central server holding a contact graph or
  message history. our relay deletes sealed messages after 14 days.
- casual device access. the database is sqlcipher encrypted, the app can
  require a pin or biometrics, and panic wipe removes everything including
  media on disk.
- phone number correlation. there is no number or email to tie you to a real
  identity, and no address book upload.
- someone making you unlock the app. a decoy pin opens an empty Kryfo, as if
  just installed. while it is open your own account sends nothing, not even
  delivery ticks. what arrives for it is still kept, unseen, and what waits
  goes once your own PIN opens Kryfo again. ticks for hidden
  chats may wait until the hidden chats are opened. hidden chats open only
  with their own pin and show no trace in the everyday app: no row, no
  count, no notification while they are shut. a wipe pin removes Kryfo
  from the phone.
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
- a network that punishes trying tor. automatic tries plain tor first,
  unless you chose "Tor is blocked here" on the first start or plain tor was
  blocked on that network type in the last 30 days. if trying tor alone is
  risky where you are, choose that, or pick snowflake or a bridge from a
  friend.
- the services bridges use. snowflake asks public stun servers for your
  address, reaches the tor project's broker through a cdn and connects
  through a volunteer's computer. each of them sees your ip. asking the tor
  project for bridges goes through a cdn and shows the tor project your ip,
  and so roughly where you are. that is how every tor app gets bridges. none
  of them see who you talk to or what you say.
- a bridge you were given. whoever runs a bridge is your first tor hop and
  sees your ip and when you use tor.
- check-ins through snowflake, when it is the only bridge that worked on
  that network type. each check-in meets the snowflake broker again, a
  regular pattern a network can notice.
- the fact that you communicated. metadata is minimized, not erased. if you
  send while a contact is online, that timing existed.
- the helper app mode, if you choose it. the helper's server sees your
  phone's ip address and when each of your sixteen endpoints is knocked.
  fake knocks make the real ones harder to pick out, not impossible: a
  server that watches long enough can still tell many conversations from
  the fakes, and one that works with our relay can match knocks to messages
  arriving. our relay learns which endpoints your addresses use, and
  together with the helper's server it can tie your mailboxes to your
  phone's ip address. with a helper server of your own, the server's name
  ties all of them to one person. a relay that watches can tell which
  mailboxes are hidden chats within two or three months: they are read and
  never registered.
  our relay holds a limited number of helper registrations: per well-known
  public push server 20,000 endpoints and 80,000 addresses, for all other
  servers together the same, and for any one of those 256 endpoints. new
  ones are taken at a pace (4,000 an hour on a public server, 1,000 on the
  others), endpoints that have not worked yet hold at most a tenth of a
  public server's share and a quarter of any other server's room, and endpoints that have worked for a day keep a queue of their
  own. someone registering in bulk can use up a server's room for new
  sign-ups for a while; registrations already there keep working.
  check-ins and always on involve no one else.
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
