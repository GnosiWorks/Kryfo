# Changelog

All notable user-facing changes to kryfo will land here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [0.2.7] - 2026-09-12

### Fixed
- the wipe did not wipe. both the wipe pin and the settings wipe deleted your messages and keys, then lost a race on the way out: the app pin, the wipe pin and the onboarding flag were still queued for disk when the process ended, so the next launch asked for your old pin and showed a fresh, nameless identity. the wipe now goes through android's own clear-data call, the same thing as "clear storage" in settings: everything gone, the process stopped, the next launch is onboarding.
- the app lock only ever covered the home screen. leave from settings, a chat or the pin page and come back, and that screen was still there; the pin only appeared once you walked back to home. the lock now sits above every screen, and after the pin you land where you were.
- taking a screenshot no longer asks for your pin afterwards. a permission prompt or the notification shade does not either.
- a message to someone who has not added you back yet could show a tick while it sat at an address they never read. it now says "waiting for them to come online or add you back" and keeps trying until they do. a false tick is worse than an honest wait.
- a manual retry of your first message to a stranger was silently dropped by their phone. it carries what their gate needs now.
- a photo that stalled at 98% and then "dropped": nothing was dropped. the pieces stay on the receiving phone for a week; the banner just vanished. it now says paused, with the count, and the sender resumes from the missing piece instead of starting over, chat open or not.
- switching screenshots on or off flashed white. the window behind the app was painted white; it is dark now.
- the speed & privacy and backup screens had a light box across the bottom. a layout error the release build paints as a plain box. fixed.
- disappearing messages that went through the queue (tor warming up, a retry) arrived with no timer and stayed forever on both phones. the timer rides along now.
- changing your pin to the same digits as your wipe pin quietly disarmed the wipe while the page said it was set. refused now.
- a stranger who could reach you could edit or delete any message in your history by id, and a group created by someone you never accepted appeared in your list. both need the author, or an accepted contact, now.
- someone you declined stopped being listened for after a restart, so their next message never resurfaced the request. they are listened for again.
- adding by @handle left the sheet open after it had worked.
- retrying a photo dropped its caption and its no-screenshot mark. searching a chat only searched the last sixty messages. the offline strip said "sending now" forever for a message waiting on someone who has not added you back.
- copying your id, a pairing code or a link is marked sensitive, so keyboards with a clipboard history and the android 13 preview treat it as such.
- the notifications row in settings shows the push mode you actually picked.
- a four digit pin could be guessed at pad speed with no limit. five wrong pins now hold the pad for thirty seconds, then a minute, then two, across restarts. the wipe pin is never held.
- a request notification showed the stranger's own words on the lock screen. it says a request arrived, nothing more.
- an edit made offline was one attempt and then silently lost. edits queue and retry like messages now.
- accept, decline and block are on the requests list, not only inside the chat.
- "reset my invite link" promised that old codes and links stop working. it moved only the relay address: an old link still opened a session and could still dial your onion directly. that promise was wrong and could have got someone hurt. reset now also replaces the key inside the invite, so an old link fails on every route, and the button says what it costs: anyone who has the old link but never used it needs a new one.
- the onion door has limits now: eight connections at once, a full inbox takes nothing more, a line has to look like a message before it costs the phone a decrypt, repeats are dropped. someone with your onion address could keep your phone busy for as long as they liked before.
- photos taken with the in-app camera came out sideways: the orientation tag was stripped before the pixels were turned. upright now.
- the shared contact card had thin yellow lines under every word. gone.
- the six digit pairing code could be shown but typed in nowhere. "they read you a code" under the code opens the way in.
- the home strip said "waiting" with a retry for every message still on its way. it speaks now only when the phone cannot send, or when a message waits on someone who has not added you back.
- two of anything before a stranger accepts you, photos, files and voice notes included; a third photo sat at a single tick.
- a member blocked from the scam shield sheet inside a group stays on screen until reopened. gone at once now.
- a friend in relay mode published to a relay nobody in onion mode read, so everything they sent sat at one tick. every mode now shares our relay, reached over tor in onion mode. the first-contact address follows a mode switch too.
- switching to tor a second time inside a minute could leave the app on "connecting" for good. the engine now reports off when a restart is skipped, so the watchdog tries again.
- notifications for a chat come down when you open it, not only when you tap them.
- a photo sent with a timer showed its countdown on the receiver only. the sender sees it now.
- holding the mic with the keyboard up recorded with no bar on screen: the bar drew under the keyboard. it sits above it now.
- a photo, a file or a voice note can no longer be edited into text.
- the send estimate for a file matched the old one-slice-at-a-time sender. it follows the pool now.
- the receiving banner no longer appears for a voice note.
- the atmospheres drifted at eight steps a second, which read as stutter on snow. they move on the frame clock now.
- the card payment tab in donate is gone until there is something behind it.
- one screenshot switch for the whole app, applied at the next start. the per-chat one is gone, and so is the flash on every toggle: changing the flag live recreated the window.
- a photo or file can be stopped while it is still on its way: hold it, stop sending. it goes here, and the other side drops the part it had along with its banner.
- a wallpaper can be one of your own photos, per chat. it lives in the app's folder and goes with a wipe.
- the name field in the profile is gone. it was stored on the phone and shown to nobody.
- onboarding asks how your messages should travel: onion, relay or fast, each with its cost in plain words, onion picked already, one tap to skip.
- claiming a handle froze the app until android offered to close it. the registry call ran on the screen's own thread. fixed, along with checking and deleting a handle.
- adding someone by handle, or by a link that had already been used once, went nowhere: the invite named a one-time key that the first person to use it consumed, so everyone after them was dropped unread. the invite now carries a key that is kept. a phone with a handle republishes it on the next start.
- direct-onion messages past a stranger's two are held on the phone and opened when you accept them, the way the relay lane already replayed them. someone you deleted has to pay the opener's proof of work again to come back.
- the scam shield now reads the first message of a group member you never added. a flagged member gets a small mark on their own bubbles, nothing above the thread. tap it for the reasons, block or ignore. in a group the content decides; a look-alike name is a footnote, since the id is on every bubble.

- photos and files send five slices at a time instead of one after another, and once the other phone's onion stops answering the rest of that send goes straight to the relay instead of waiting out the dial every slice. camera shots are brought to the same size and quality as gallery picks before sending, which halves them. debug builds log the time each slice took.

### Changed
- a slow send while online no longer shows "failed · tap to retry". it retries itself and stays pending; failed shows only when the phone cannot send at all, or after six goes.
- sentence case throughout: every label, hint, button, tab and line starts with a capital. the settings hints are shorter.
- bridges and transport moved out of about to sit with the network rows. the open source row copies the github link instead of opening it in a browser.
- the honest part in why kryfo ends on "yet".

## [0.2.6] - 2026-09-12

### Fixed
- after the system closed kryfo in the background, it could come back showing "kryfo is on" while receiving nothing at all, until you opened it again. the process the system restarted had no engine in it. it boots on its own now, screen or no screen.
- every time you reopened kryfo after swiping it out of recents, a second copy of the whole app started inside the same process, and the first one never stopped. two reopens doubled the memory, which is what xiaomi's killer looks for.
- xiaomi phones were asked for autostart but never for the battery exemption, so they slept through the night with a green notification up. both are asked now.
- messages already on the phone in onion mode waited for tor's state before being read. they are read as soon as they arrive.

### Added
- a floor under delivery: every fifteen minutes the system runs a short job that reconnects every relay and pulls what is waiting, even after a kill, even in deep sleep windows.
- transport shows a "staying alive" section: whether the app is listening, when it last checked, when the last message came in, the battery exemption, how long the process has been up, and why it last stopped, in the system's own words. enough to tell asleep from killed without a cable.

## [0.2.5] - 2026-09-12

### Added
- link previews that don't phone home. with "add link previews" on, typing a link offers a small add preview pill. tap it and your phone fetches the page title over tor and ships it inside the encrypted message. the other person's phone renders it and asks the network for nothing. their card says so: fetched over tor · by their device. offered only while tor is up, in chats and groups, never in a burner room. a stranger's preview stays plain text.
- atmospheres. the wallpaper sheet is now the atmosphere picker: six moods, rain, late night, warm afternoon, snow, desert, paper, above the old gradients and patterns. each tap previews live behind the sheet. just for you, they see their own, nothing is ever sent.
- the contact page shows the three facts as cards: verified, how many of your own contacts vouched, and how long you have been chatting. a zero is never drawn. message and verify keys sit at the bottom as buttons.

### Changed
- the reader's link preview setting is gone, along with the tap-to-fetch path. your phone never fetches a link someone sent you.
- settings is grouped: one surface per section, icon tiles, values on the right, the danger zone in rose.
- the home is tidier: note to self and saved are two small tiles, the chat list starts higher, and the tabs and status chip are lowercase.
- the plus sheet is "add someone": scan their code, paste a link or handle, or open every way to add someone.
- the protections card says off · relay mode instead of connecting forever when tor is not the route.

### Fixed
- a cold start showed nothing for several seconds on a new phone while the keystore was created. the splash paints first now and says what it is doing.
- the empty home offered only scan. it offers scan, link and handle.
- the camera asked for the microphone before a photo. it asks only when you switch to video.

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
