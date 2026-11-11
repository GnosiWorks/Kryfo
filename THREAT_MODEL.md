# Threat model

what this protects against and what it does not. if getting this wrong could
put you in danger, read all of it.

## what it protects against

- network observers. by default your messages go through tor. your isp sees
  a tor connection, or a bridge when tor is blocked, not who you talk to or
  what you say. fast mode, which you can choose, skips tor for speed. on
  fast your network can see that you connect to Kryfo's servers, not what
  you send or to whom. burner rooms, pair codes and first contacts still go
  through tor on fast.
- networks that block tor. automatic mode tries what worked on that
  network type before, then tor the usual way. when tor's own signals say
  the network cuts it off, it tries bridges one at a time: what the tor
  project suggests (only after you say yes), the built-in obfs4 bridges,
  snowflake and saved webtunnel lines, with obfs4 last where tor looks
  blocked. it keeps the first that carries tor and remembers it per network
  type for 30 days. this was tested in heavily censored countries.
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
- recorded traffic and a future quantum computer. chats between 0.6 phones
  use post-quantum keys (pqxdh and spqr) from the first message, and older
  chats move over once both phones run 0.6. FORWARD_SECRECY.md says what
  that does not cover.
- someone guessing a pair code. a pair code is eight digits: two find the
  other phone and six are the secret, checked with cpace, so a relay or a
  listener learns nothing it can try offline. a guess has to be made live
  against the phone showing the code, and it stops taking answers after
  three wrong ones.
- server seizure. there is no central server holding a contact graph or
  message history. our relay deletes sealed messages after 14 days.
- casual device access. the database is sqlcipher encrypted, photos,
  voice notes and files are encrypted too, each container's under a key
  made from its database key, and the app can require a pin or biometrics.
  a wipe drops the keys first, in the first second or two, so messages and
  files never open again. then the files are overwritten and deleted, a
  few seconds in all. flash storage can keep old blocks of a file after
  that: without the keys they do not open, but a file from before 0.6,
  encrypted since or not, can have left plain blocks behind, and those are
  only as gone as the storage makes them.
  while the lock is up no photo or video frame stays decoded in memory. the
  small blur a picture shows while it loads is sealed next to it under the
  same key.
- phone number correlation. there is no number or email to tie you to a real
  identity, and no address book upload.
- strangers sending media. until you accept a request it shows only words:
  photos and files wait, and links stay plain with no preview.
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
- the mailboxes a relay sees together. Kryfo asks each relay for your chats'
  mailboxes in fixed groups of up to eight, each group on a connection and
  a tor circuit of its own, so a relay knows that the mailboxes of one group
  are one phone's. each hidden chat has a connection of its own. hiding a
  chat you already have moves its mailbox out of its group, so a relay can
  see that something changed in that group, and which mailbox left. a chat
  made in hidden chats from the start never joins a group.
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
  storage and battery figures for the app are not hidden either.
  up to 0.5.3, photos, voice notes and files were kept unencrypted inside
  the app's own folder, hidden chats' in folders of their own and under
  the names people gave them: a copy of the phone shows them, hidden ones
  too, without any pin. from 0.6 they are encrypted, the hidden chats'
  under a key that only their pin opens, and their names on disk say
  nothing. files from before are encrypted when their chats first open
  after the update, as space allows: one that needs more free space than
  the phone has stays as it was until there is room, and is tried again
  each time its chats open. until the hidden chats pin is used once, theirs
  stay as they were, and the decoy's own until the decoy pin is used. older
  plain copies can also linger in the phone's storage after that. if a
  forensic copy is the fear, the wipe pin is the tool, and not having the
  data on the phone at all is better still.
- what the everyday side keeps to reach a hidden chat while it is shut. the
  card it keeps for each one, readable with the everyday database key, holds
  the keys and addresses needed to receive, and those of their linked
  devices, which shows how many they use, and whether the chat blocks
  screenshots and when that last changed.
- a linked computer and a hidden chat. a hidden chat never goes to a
  linked computer, and a chat hidden on the phone leaves the computer as a
  deleted one does. one shown again comes back there with its name, note and
  settings as they were, where a deleted chat added again starts empty: the
  computer can tell it was hidden.
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

the linux and windows apps are test builds. a computer runs an identity of
its own, or is linked to your phone (below).
what Kryfo keeps on a computer is sealed on the disk: the database,
photos, voice notes, files, contacts, keys and settings, under one random
key. the engine's onion key, relay marks and top-up queue are kept in
memory while Kryfo runs (on windows in the process itself) and sealed
between runs. that key is kept one of two ways.

- by default the computer account keeps it: the system keyring on linux,
  windows' own data protection (with the tpm where there is one). Kryfo
  then opens without a question, and so it does for anyone or anything
  running as you: a person at your unlocked account, malware, another app
  that may read your keyring. without a passphrase the key is as safe as
  your computer account's password. a copy of Kryfo's folder alone does not
  open. what does: an account or keyring with no password (a login keyring
  with an empty password, as automatic login often sets it up, lies
  unencrypted on the disk, and a windows account with no password on a
  computer without a tpm opens from a copy of the disk), and a full copy
  of your home folder together with your account's password, on another
  computer too (on windows only without a tpm). disk encryption keeps a
  stolen disk closed.
- with a passphrase, asked at every start, the key is wrapped under it
  instead and the computer keeps nothing. someone who copies Kryfo's folder
  can try passphrases on their own computer as fast as it allows. a long
  passphrase holds, a short one does not. the folder opens anywhere with it.
- without a passphrase, a reset keyring, a password reset by an admin or a
  cleared tpm loses the key on that computer. a Kryfo backup is the way
  back.
- adding, changing or removing the passphrase seals Kryfo's key file under
  a new random key, so an older copy of that file no longer opens the
  current one. an older copy of the folder opens only the data as it was
  then, with what opened it then: an old passphrase, or an old keyring
  item. the keys of the databases and files inside stay the same, so that
  older copy together with a copy of today's databases and files opens
  those too.

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

a computer linked to your phone (linked devices):

- your contacts' apps and the relays can count your devices. your
  contacts' apps hold the list of them your phone signs, and each message
  goes as one copy for each device of yours and of theirs, all at once and
  in one size, so a relay sees how many go. a contact with a changed app
  sees when you add or remove one.
- a linked computer runs tor as a client only, with no onion address of
  its own, so tor and the relays can tell it from a phone. it never adds
  contacts, makes invites, holds hidden chats or a decoy, or changes a
  group: those stay on the phone. a whole chat deleted or cleared, or a
  block, on the computer stays on the computer. a single message deleted
  there, or a timed one opened there, goes on the phone too.
- your contacts' apps do not show when you link or remove a device: they go
  by the list your phone signs. someone who takes your phone's keys can
  sign a list with a device of their own on it and be sent a copy of what
  your contacts write to you, and nothing in their app shows it.
- the keys of a link and of a history copy are erased once they are done,
  but the engine that holds them cannot clear every copy of them from
  memory: until Kryfo stops they can stay there, and reach the disk
  through swap.

- a linked computer erases itself after 30 days without being opened, or
  when its clock is set back. this helps with a computer you forgot.
  someone who already has it can copy its disk first: a copy of the disk,
  with the clock set to the copy's time, beats both rules, and Kryfo kept
  from running counts no days at all. so remove a lost computer from your
  phone. what stops new messages reaching it is your phone and your
  contacts' lists: once your contacts' apps have your new list, nothing new
  goes to it, within minutes for contacts online and later for those
  offline. a computer kept online with a changed Kryfo stays linked until
  you remove it.
- a removed computer keeps what it already held, and it still knows your
  phone's onion address, so it can tell when your phone is online. a
  contact who took one of its bundles before the removal can still start a
  session with it until their app has your new list.
- a contact you deleted is not told when you remove a computer, so they
  cannot tell you still use Kryfo. if they still have you, their app may
  keep sending that computer a copy of what they write to you, until you
  add them again.
- restoring your phone from a backup cuts every linked computer off, but
  cannot tell one that is away: it erases itself once it has heard nothing
  from your phone for 30 days of being online.

## status

alpha, unaudited, one person. do not rely on it where being wrong would
hurt you. security issues: report privately, not in a public issue.
SECURITY.md says how.
