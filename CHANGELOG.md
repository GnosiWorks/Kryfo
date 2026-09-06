# Changelog

All notable user-facing changes to kryfo will land here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

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
