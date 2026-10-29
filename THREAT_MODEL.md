# Threat model

what this protects against and what it does not. if getting this wrong could
put you in danger, read all of it.

## what it protects against

- network observers. by default your messages go through tor. your isp sees
  a tor connection, or a bridge when tor is blocked, not who you talk to or
  what you say. fast mode, which you can choose, skips tor for speed.
- networks that block tor. automatic mode tries tor the usual way first.
  when tor's own signals say the network cuts it off, it tries bridges one
  at a time: what the tor project suggests (only after you say yes), the
  built-in obfs4 bridges, snowflake and saved webtunnel lines. it keeps the
  first that carries tor and remembers it per network type for 30 days.
- the relays. messages travel through nostr relays, sealed twice with
  nip-44/59 and sent from a throwaway key to a mailbox address that belongs
  to one conversation and to nobody's identity. no relay can read them.
  messages from 0.5.2 on are padded to one of five sizes, so a relay sees
  roughly how big a message is, not how long. how many you send and when
  still shows. on the onion route, the relays never learn your ip address
  or who you are. it writes to both our relays, each through its own onion,
  and to a few public ones, so one of ours can stop without messages
  stopping.
  in fast mode, our two relays see your ip address, never what you say. each
  of them sees which mailboxes one ip address reads and writes, and when both
  people in a chat use fast mode, it can see that two ip addresses share a
  mailbox. while the first relay is down, fast mode also reaches public
  relays, through tor, never directly.
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
  goes once your own pin opens Kryfo again. ticks for hidden chats may wait
  until the hidden chats are opened. hidden chats open only
  with their own pin and show no trace in the everyday app: no row, no
  count, no notification while they are shut. a wipe pin removes Kryfo
  from the phone.
- someone answering as the developer. the key behind the "Marios · built
  Kryfo" chat is built into the app and checked on every message.

## what it does not protect against

- a compromised device. malware or someone holding your unlocked phone sees
  what you see.
- the person you talk to. they can screenshot, copy, forward, or tell people
  they talk to you. a chat's screenshot blocking (android's FLAG_SECURE, on
  both phones) stops screenshots and screen recording inside Kryfo and turns
  off copying, forwarding and saving. it cannot stop apps allowed to read
  the screen for accessibility, a rooted or modified phone, or a copy of
  Kryfo patched to ignore it.
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
  our relay holds a limited number of helper registrations: per
  well-known public push server 20,000 endpoints and 80,000 addresses, for
  all other servers together the same, and for any one of those 256
  endpoints. new ones are taken at a pace (4,000 an hour on a public
  server, 1,000 on the others), endpoints that have not delivered yet hold
  at most a tenth of a public server's share and a quarter of any other
  server's room, and endpoints that have delivered once and are a day old,
  then a week, then a month, get more of the turns to be knocked. someone
  registering in bulk can use up a server's room for new sign-ups until
  they stop renewing: in our tests ntfy.sh's share filled in 3 h 50 min,
  and the common share took 75 registrable domains and 18 hours.
  registrations already there are still renewed and knocked.
  the hourly pace is per server, not per person: anyone can spend a
  server's new sign-ups for the hour, and new users on that server then
  wait for the next hour, on check-ins meanwhile. we accept this: the relay
  asks for no account it could count per person.
  check-ins and always on involve no one else.
- forensics on a seized unlocked phone or its backups, or on a forensic copy
  of the phone. the decoy pin and hidden chats are for a quick look, someone
  scrolling through a phone you were made to unlock. they are not built to
  survive a lab. a copy of the phone can show that Kryfo holds more than it
  shows, and a short pin against such a copy can be guessed. android's
  storage and battery figures for the app are not hidden either. if a
  forensic copy is the fear, the wipe pin is the tool, and not having the
  data on the phone at all is better still.
- what the everyday side keeps to reach a hidden chat while it is shut. the
  card it keeps for each one, readable with the everyday database key, holds
  the keys and addresses needed to receive, and whether the chat blocks
  screenshots and when that last changed.
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
  fast mode our relays see your ip.
- this integration itself. the crypto is standard libraries (libsignal, tor,
  sqlcipher, nip-44/59) but the way they are wired together here is new and
  has not had an independent review.

FORWARD_SECRECY.md says what a key taken from a phone can open later.

## on a computer

the linux app is a test build and runs its own identity for now. what
Kryfo keeps on a computer is always sealed on the disk: the database,
photos, voice notes, files, contacts, keys and settings, under one random
key. that key is kept one of two ways.

- by default the computer account keeps it: the system keyring on linux,
  windows' own data protection (with the tpm where there is one). Kryfo
  then opens without a question, and so it does for anyone or anything
  running as you: a person at your unlocked account, malware, another app
  that may read your keyring. a copy of the folder alone does not open,
  and neither does it on another account or computer.
- with a passphrase, asked at every start, the key is wrapped under it
  instead and the computer keeps nothing. someone who copies Kryfo's folder
  can try passphrases on their own computer as fast as it allows. a long
  passphrase holds, a short one does not. the folder opens anywhere with it.
- without a passphrase, a reset keyring, a password reset by an admin or a
  cleared tpm loses the key on that computer. a Kryfo backup is the way
  back.
- an older copy of the folder still opens with what opened it then: an old
  passphrase, or an old keyring item.

what follows is not covered by either.

- tor's own state stays on the disk as tor writes it: which relays it uses
  as guards and its cached directory. it holds no key and no message.
- the folder shows its shape: how many files there are, how big each is and
  when each changed. every install has the same set of names, with or
  without a decoy or hidden chats, but a used decoy or hidden chats are
  bigger than empty ones.
- what is open in memory can reach the disk through swap or hibernation.
  use encrypted swap or zram, and no hibernation, or turn swap off.
- someone who can write to the folder can put back an older copy of a file
  and it opens: an older set of keys and settings, or an older picture under
  the same name. Kryfo does not notice.
- screenshots: a computer cannot keep Kryfo's window out of a screenshot.
- malware running as you while Kryfo is open, or a keylogger, sees what you
  see and what you type.

## status

alpha, unaudited, one person. do not rely on it where being wrong would
hurt you. security issues: report privately, not in a public issue.
SECURITY.md says how.
