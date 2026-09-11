# Changelog

All notable user-facing changes to kryfo will land here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [0.2.4] - 2026-09-11

### Fixed
- opening an invite link while kryfo was closed did nothing. the contact was never added and nothing said so. the link now waits for the app to finish starting.
- on a clean install, opening any group threw underneath and its unread count never cleared. every phone we had tested on was an upgrade. fixed for new installs.
- a backup handed to the share sheet could be zeroed while the other app was still reading it, leaving an empty file to discover at restore time. gone.
- a link from someone you had not accepted could fetch its title on its own in automatic mode, in the moment before the app knew who they were. it waits now.
- the photo stripper's self-check could be fooled by a legal but unusual jpeg, and a broken file was copied through untouched. one walker for both now, and a file it cannot read is refused.
- a video interrupted by a call or a switch to another app left the clip on disk until the next cold start. it is stopped and shredded on the spot.
- a backspace in the moment after the fourth digit of a new pin could shorten it and guarantee a mismatch.
- a link followed by a full stop or a closing bracket previewed the wrong address.
- an attachment that could not be saved, a full phone say, arrived as an empty bubble. the message now says so.
- if timed messages stop clearing you are told, instead of nothing.
- cached copies of every file you ever picked stayed in the app cache. shredded the moment they are read.

### Changed
- the link preview choice says why it exists, in plain words.
- every icon-only button has a name for screen readers.
- the two background prompts sit on the same sheet as every other ask.
- a phone with no camera can install kryfo, and the legacy storage grant is gone from the listing.

## [0.2.3] - 2026-09-09

### Added
- in-app camera. photos get their exif, location and maker notes stripped before anything else touches them, and nothing lands in your gallery unless you tap keep a copy. video isn't stripped yet and the screen says so.
- link previews are a choice now. first time you tap one you pick: show them on their own, only when i tap, or not at all. changeable in settings.

### Fixed
- your phone used to fetch every link you sent, twice, before the message went out, on a plain connection unless you were on onion mode. the site learned your address and that the request came from kryfo. gone.
- the backup screen left the encrypted file sitting in a cache. so did the file picker, for everything you ever picked. both shredded now, and swept at boot.
- decrypting a backup froze the screen while it worked.
- links the keyboard had capitalised never matched, so they showed as plain text.

### Changed
- restore reads as three steps: the file, the passphrase, what comes back. it shows what's in the backup and when it was made before touching anything, and says which of four things went wrong instead of "an error occurred".
- a stranger's link, and any link in a burner room, stays plain text. no preview offered.
- previews never load images, only the title.

## [0.2.2] - 2026-09-08

### Added
- introductions. know two people who don't know each other? introduce them. both sides get a request that skips the usual first-contact wait, and each profile shows who vouched. only people you've already added count. a stranger vouched for by strangers shows nothing.
- scam shield. tells you when a new request is using the name of someone you already know, lookalike letters included. flags the usual stuff in a stranger's first message. runs on your phone, talks to nothing, and never blocks anything for you.
- burner rooms. group chats that expire and take everything with them. you join under an identity that only exists in that room, so leaving ends it completely. screenshots don't work while a room is open.
- handles can be looked up now. you could claim one before but nobody could find it.
- mentions in groups. wallpapers per chat.

### Fixed
- a first message to someone new could quietly never arrive. if the direct send failed and it queued, the retry went out without the proof it needed and the other side dropped it.
- messages from someone you hadn't accepted stopped arriving after a restart, while the sender still saw them delivered.
- a chat you'd left stayed in memory with everything still running.
- home could say nothing was waiting while messages sat queued offline, and never showed queued on the row.

### Changed
- adding someone is rebuilt around what you're actually doing: scanning a code with someone next to you, or sending an invite to someone far away.
- one page per contact. verification, shared media and vouches together instead of scattered.
- bridges and the second pin explain themselves properly now.
- setup rewritten.

## [0.2.1] - 2026-09-06

Third pre-alpha. Friends can introduce you, strangers get looked at on your
phone before you do, and a room can be made to disappear.

### Added
- introductions: a contact you accepted can hand you a friend's card. the request skips the stranger gate, shows who vouched, and the introducer has five a week
- vouches as their own table, so several people you know can vouch for one person and the profile says so
- scam shield: a stranger's first message and a lookalike name are checked on the phone, with rules that ship in the app. it advises, never blocks
- burner rooms: a room with an end time, joined under a key made for it alone. late joiners see no history, expiry shreds everything, the screen is shielded while it is open
- per-room keys in the engine, so a room's relay addresses share nothing with your identity

### Fixed
- a stranger's queued first message lost its proof-of-work on retry and was dropped at the far end without a word
- the screen shield stayed on after leaving a room, and every chat screen leaked its listeners on the way out: an unswiped bubble built its spring inside dispose
- leaving a room from its info screen closed the app
- the burn timer deleted rows but never the files behind them
- release builds no longer print ids, onions or message text to the log
- grey hex colours replaced by the palette tokens on every screen

### Changed
- sharing and switches use the current flutter apis
- three dependencies nothing imported are gone, and so is the dead status bar

## [0.2.0] - 2026-09-04

Second pre-alpha. Groups, a relay route that works on its own, and the photo
bubble finally paints.

### Added
- group chats with photos, files, voice notes, replies, reactions and pins
- relay as a route in its own right, named on every screen, surviving restart
- obfs4 bridges in process over socks5, with no executable shipped
- pair codes and a contact card you can share
- public handles, which follow wipes and invite resets
- 1200 drawn avatars picked by shape and colour, now offered during setup
- first contact over a relay, so a stranger reaches you before your onion publishes
- one apk per abi, each with its own version code

### Fixed
- photos drew as a black rectangle in 1:1 chats
- the first stranger to write could claim the shared first-contact tag, and everyone after them silently failed to pair
- chats could blank out when two day dividers shared one key
- a tree with no engine built an apk that died on launch; it now fails at build time
- boot failures say what went wrong instead of sitting on the tor splash forever

## [0.1.0-alpha] - 2026-05-20

First public pre-alpha. Usable for technical testers; not yet ready for everyday use.

### Added
- 1:1 chat over tor onion v3 (direct p2p) with nostr relays as the store-and-forward fallback
- libsignal double ratchet end-to-end encryption with x25519 identity keys
- bip-39 anonymous identities ("thumb-behave-boring") derived from ed25519
- in-app qr pairing with auto back-pair on first message (no need to scan from both sides)
- ghost mode - self-destructing messages with 30s / 1m / 5m / 1h / 24h windows
- reactions - long-press any message for a floating emoji picker
- reply-to - quote any message in your response
- app lock with pin + biometric
- panic pin - second pin that silently wipes the app (looks like a crash)
- procedurally generated avatars from each kryfo id
- editorial design language: italic serif accents, jetbrains mono for technical bits, ink + amber palette
- foreground service + boot receiver + jobscheduler so messages arrive while the phone is locked
- three privacy modes: fast (1 onion hop), normal (3 hops, default), private (3 hops + nostr mailbox)
- sqlcipher encrypted local storage
- backup + restore via encrypted file
- notes tab - private space, never syncs anywhere

### Privacy posture
- no telemetry, crash reporting, analytics - ever
- no google play services
- no proprietary blobs
- no phone numbers, emails, or accounts

### Known limitations
- group chats not yet implemented (planned next)
- ios port pending hardware arrival (~sept-oct 2026)
- no voice messages, files, or rich link embeds yet
