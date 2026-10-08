# Changelog

## [0.5.0] - 2026-10-08

### Added
- decoy pin: a second pin opens an empty Kryfo, as if just installed. set it up in app lock, advanced protection.
- a chat with Marios, who builds Kryfo, pinned at the top of the list. nothing is sent until you write, and you can write anonymously, from a name made for that chat alone. his key is built into the app.
- pair codes show the other person's three words and face to check against their screen before adding them.
- hidden chats: chosen chats and groups stay out of the chat list, search and notifications until you enter the hidden chats pin. set it up in app lock, advanced protection.
- stickers: the Fokia and Fokia Remix packs, 47 animated stickers, in chats, groups and rooms. a sticker travels as its name and the app draws it, so it costs a few bytes and no picture leaves the phone. older versions show its emoji.
- a group file's bubble says how many members have it, and after three days how many didn't get it.

### Changed
- a timed message you receive starts its countdown when you first see it, or a day after it arrives if still unread. blocking someone starts the countdown on their unread ones. your own copy still counts from when you send it. unread timed messages stay out of search, shared media, pins and previews until read.
- delivery is steadier after being offline. messages fetched from relays are kept until the app confirms it has them, and a long catch-up runs to the end, in order.
- a relay that fails now and then is tried again sooner, sends wait longer for a slow relay over tor, and missing pieces of a file are asked for sooner.
- in groups, texts, polls, stickers, files, member changes and deletions for everyone go again to members a send missed, in order, until each has them.
- messages sent in quick succession keep their order and all go out.
- the app lock comes up more reliably when you leave the app, also from a photo or file picker.
- the app lock is drawn above every screen, sheet and dialog, and players, the recorder and the camera stop when it comes up.
- the composer no longer shows a proof-of-work line for a first message to someone new.
- home, chats and settings show one connection state, and the tor sheet says when tor is up but no relay answers yet.
- the strip on home shows only when the phone cannot send, and the waiting line under bubbles is gone.
- time and ticks on bubbles are lighter.
- a chat keeps your reading place when new messages arrive.
- videos, and files whose name carries a date, leave under a made-up name with the same extension, so the name no longer says when something was taken.
- pairing and adding say what went wrong, such as your own invite or someone you blocked.
- a restore that stops partway says so, closes Kryfo and asks for the file once more.
- deleting your handle asks first.
- safety numbers read left to right in every language, and the camera timer keeps its digits still.
- Kryfo calls itself alpha everywhere. a few places said pre-alpha.
- arabic and persian text uses fuller fonts, so every mark and joiner shows.
- handle, search and badge requests go over a tor circuit of their own, and your handle is only sent again when your invite changes.
- lists, sheets and transitions across the app were polished, and every language uses sentence case.
- your own chats, each room and each pair code go over their own tor circuits, and relays no longer see one running count across them.
- your contacts' addresses are spread over four tor circuits instead of one, and your first-contact address has a circuit of its own.
- private mode checks its relay connections every 90 seconds instead of every 19, and a slow reply over tor no longer drops the connection.
- the relay takes only what the app sends and paces each connection, the handle registry paces reads, writes and new names, and the badge service paces receipt checks.
- the tor dot on the chat list and in chats stops pulsing once tor is usable, and pulses only a few times while it starts.
- chat stickers play three times and rest; a tap plays them again. open chats stop their timers while they are out of sight, and the drifting chat backgrounds hold still with reduced motion.
- the first start was polished: a step bar, calmer transitions, clearer text, and every step fits small screens and large text.
- after a restore, Kryfo says to check your protections in settings. settings are not part of a backup.

### Fixed
- notifications use the name you gave a contact, and clear when you open the chat.
- clearing, deleting or declining a chat also removed that person's messages in groups.
- rooms could stop receiving after a change of delivery mode.
- a menu could open under the keyboard.
- the button on the restore sheet could be out of reach.
- an introduction to someone you had deleted did not show up.
- the introductions sheet showed its count the wrong way round.
- a chat could show only part of its messages.
- older messages in a long chat load as you scroll up.
- when someone accepts you, no empty unread message shows up in the chat any more.

### Security
- the engine's crypto and network libraries are updated: x/crypto 0.55.0, x/net 0.58.0, age 1.3.2 and websocket 1.8.15.
- security improvements throughout. update when you can.

## [0.4.2] - 2026-09-28

### Fixed
- more reliable message delivery when a relay sends unexpected data.
- more careful handling of contacts and groups.

## [0.4.1] - 2026-09-25

### Security
- a security fix. update when you can.

## [0.4.0] - 2026-09-25

### Added
- polls in groups and rooms: two to twelve answers, one pick or several. you can change your vote, and whoever asked can close the poll.
- search across all your chats: names, messages, photos, files and links. the index lives in the encrypted database and nothing you search for leaves the phone.
- "show me in search" on the handle screen, off unless you turn it on. people search asks the registry over tor, only when you type @ or tap to look.
- the language sheet shows every language by its own name.

### Changed
- a message that goes burns away and the chat closes the gap.
- banners at the top of the screen drop in and can be flicked away.
- words keep their own direction in mixed-language text.

### Fixed
- in search, a person could only be opened by tapping their picture.
- sheets with the keyboard up slid under the status bar.
- handle errors were shown in english whatever the language.
- a few buttons were in lowercase.

## [0.3.2] - 2026-09-25

### Security
- a security fix. update when you can.

## [0.3.1] - 2026-09-25

### Security
- a security fix. update when you can.

## [0.3.0] - 2026-09-24

0.2.11 and 0.2.12 were never released, so this covers everything since 0.2.10.

### Security
- the engine is built with go 1.25.14 (was 1.25.0).
- tor 0.4.9.12 (was 0.4.9.5): two use-after-free fixes and a crash fix.
- three certificate and key agreement fixes from openssl 3.6.3 in the bundled openssl.
- a video opened in another app left a decrypted copy behind. it is removed when you come back, and at start.
- voice notes left the undisguised recording in the cache. it is removed after sending, and at start.
- setting a pin turns notification previews off.
- after a panic wipe the app started itself again in the background. nothing starts it now until it is opened.
- ntfy push is removed. it connected outside tor, and every message carried an address for the other side to call.
- photos sent as files are cleaned of metadata too: jpeg, png, webp, heic, avif, gif.
- the cleaner also removes vendor data after the image, attached second images and png text chunks.
- tor and the c libraries under it are built with stack protection.
- pins and reactions are only accepted from people in that chat.

### Added
- 15 languages, persian and arabic right to left. translations ship inside the app.
- tools tab, all offline: what a photo gives away, a cleaner for photos and videos, qr codes, and age file encryption.
- check-ins: a delivery mode that wakes every 15 minutes. easier on the battery, messages can be late. offered once if the phone keeps killing always on.
- videos show a first frame, their length and a play button, and play inside the app.
- tapping a file opens it. share moved to a long press.
- pins: a list behind the pin in the top bar, shown to both sides in 1:1 chats, up to fifty per chat.
- a room link in a message shows a join button.

### Fixed
- always on could get stuck on "connecting" for good. tor's control connection is no longer shared, and a stuck reconnect gives up after five minutes.
- fetching several contacts' backlogs could skip messages. each conversation keeps its own place now.
- going from check-ins back to always on could stay deaf for up to 15 minutes.
- messages sat unsent after a network change. tor is told at once, and "ready" means messages go through.
- the bridges screen said connected too early.
- the mic button could stop working inside a chat.
- a file with missing pieces asks for just those pieces.
- relays only hand back the newest hundred messages. the app pages back through the rest.
- changing bridges restarted tor, which could hang or close the app. tor is reconfigured in place, in about half a second.
- tor could stay off when its control port stopped answering. every command has a timeout and a dead connection is replaced.
- home says "Kryfo is offline" after five minutes without a connection.
- paying with bitcoin froze the app. it shows progress and offers the plain address after 20 seconds.
- voice notes stopped a second in.
- a big file could be sent twice.
- moving to a new phone lost the public handle.
- restoring over an account with a handle left the handle pointing nowhere.
- jumping to a pin scrolled past the message.
- room links in chats could not be tapped.
- a sent file stayed on "sending" in an open chat.
- the photo tool showed a lone button when there was nothing to remove.
- a phone whose account had moved still said it would deliver.

### Changed
- the link preview setting is gone. the per-message button shows whenever tor is up.
- the voice mask sits a little lower.
- the public handle page carries its own fonts instead of loading them from google.

## [0.2.10] - 2026-09-16

### Added
- moving to another phone. a move retires the old phone, and the restore says what comes over before it writes anything.
- backups hold photos, voice notes and files, written a piece at a time. saved through the system dialog as kryfo-backup-N.kryfo. old backups still restore.
- a video tile next to the gif one.

### Fixed
- gallery videos kept where, when and on what phone they were filmed. cleaned now: mp4, mov, 3gp.
- picking onion during setup could leave the app on the relay.
- scanning a code from the first screen added nobody.
- the button at the bottom of the backup screen could be out of reach.
- the bitcoin page said the payment service was unreachable when it was having trouble.
- the add row under the plus button was easy to miss.

### Changed
- transitions finish within 300 ms.
- capitalisation fixes in speed & privacy, the group attach sheet and donations.

## [0.2.9] - 2026-09-16

### Fixed
- the app re-downloaded twelve hours of messages every fifteen minutes, which could use gigabytes of mobile data. it checks the connection instead and only catches up on the gap.
- media showed a tick before it arrived. it waits for the receipt now.
- one bad piece killed a whole transfer. each piece retries on its own.
- voice notes stopped partway and restarted from the beginning.
- the tor screen still said the faster modes were coming soon.
- the date label was drawn twice while scrolling.
- a missing photo showed as a black square.
- a picture sent as a file showed as a document.

### Added
- cancel on the sending strip, in chats and groups.

## [0.2.8] - 2026-09-15

### Fixed
- a way around the app lock. update when you can.
- the scam shield never ran in groups.
- a burner room message that could not be stripped of your identity was sent anyway. it is dropped now.
- blocking someone in a group left their old messages on screen.
- a message waiting for someone to add you back was hidden on home.
- cancelling a file send used up one of a stranger's two messages.
- on android 13 and newer, a refused notification permission was asked for in a loop, which broke typing and crashed the app.
- scrolling back in a group could stop early.

### Added
- home says when android is blocking notifications and opens the setting.

### Changed
- release builds are made in a pinned container at f-droid's build path, so the apks can be checked byte for byte. see repro/README.md.
- dependencies moved up within the declared versions.

## [0.2.7] - 2026-09-14

### Added
- stop a photo or file while it is sending.
- a wallpaper from your own photo, per chat.
- setup asks how messages should travel: onion, relay or fast.
- the scam shield checks first messages from group members you never added.
- 32-bit phones (armeabi-v7a).

### Fixed
- the wipe left the pins behind. it uses android's clear data now.
- the app lock only covered home. it covers every screen now.
- screenshots, permission prompts and the notification shade no longer ask for the pin.
- a message to someone who had not added you back showed a tick.
- a retried first message to a stranger was dropped.
- a stalled transfer says paused and resumes from the missing piece.
- toggling screenshots flashed white.
- light boxes across the bottom of two screens.
- queued disappearing messages lost their timer.
- the pin could be set to the wipe pin, which disarmed the wipe.
- a stranger could edit or delete messages by id, and groups from strangers showed up.
- declined contacts were forgotten after a restart.
- adding by @handle left the sheet open.
- retrying a photo dropped its caption. chat search only covered the last sixty messages.
- copied ids, codes and links are marked sensitive.
- wrong pins are rate limited: five tries hold the pad, longer each time.
- request notifications no longer show the stranger's words.
- offline edits queue and retry.
- accept, decline and block on the requests list.
- resetting your invite link also replaces its key, so old links stop working everywhere.
- the onion listener has limits on connections and inbox size.
- in-app camera photos came out sideways.
- yellow lines under the shared contact card.
- the pairing code could be shown but not typed in.
- the home strip nagged about every pending message.
- a stranger gets two of anything before you accept, media included.
- relay and onion users could not reach each other. every mode shares one relay now.
- switching to tor twice in a minute could hang on "connecting".
- notifications clear when you open the chat.
- the sender sees the countdown on timed photos.
- the recording bar drew under the keyboard.
- a photo, file or voice note could be edited into text.
- the send estimate for files was wrong.
- the receiving banner showed for voice notes.
- atmospheres stuttered.
- claiming a handle froze the app.
- adding by handle, or by a used link, failed after the first person. invites carry a lasting key now.
- messages past a stranger's two are held until you accept.

### Changed
- photos and files send five pieces at a time and fall back to the relay when the onion stops answering. camera shots are resized like gallery picks.
- a slow send retries on its own instead of saying failed.
- sentence case everywhere.
- bridges and transport sit with the network rows.
- one screenshot switch for the whole app.
- the card payment tab and the unused profile name are gone.
- short screens and large display zoom: pin pads and setup scroll.
- the first message to someone new shows the proof of work counting.
- sheets scroll and move up with the keyboard.
- less memory: pictures decode at display size, files stream from disk.

## [0.2.6] - 2026-09-12

### Fixed
- after android closed the app in the background it could say "Kryfo is on" and receive nothing.
- reopening after swiping from recents started a second copy of the app in the same process.
- xiaomi phones were never asked for the battery exemption.
- messages already on the phone in onion mode waited for tor before being read.

### Added
- a background job every fifteen minutes reconnects and fetches what is waiting, even after a kill.
- transport shows whether the app is listening, the last check, the last message, the battery exemption and why it last stopped.

## [0.2.5] - 2026-09-12

### Added
- link previews that don't phone home: your phone fetches the title over tor and sends it inside the message. the other phone fetches nothing.
- atmospheres: six animated wallpapers.
- the contact page shows verified, vouches and how long you have been chatting.

### Changed
- the reader's link preview setting is gone. your phone never fetches a link someone sent you.
- settings is grouped.
- a tidier home.
- the plus sheet is "add someone".
- the protections card says relay mode instead of connecting forever.

### Fixed
- a cold start on a new phone showed nothing for several seconds.
- the empty home only offered scan.
- the camera asked for the microphone before a photo.

## [0.2.4] - 2026-09-11

### Fixed
- opening an invite link while the app was closed did nothing.
- on a clean install, opening a group failed and its unread count never cleared.
- a backup handed to the share sheet could be wiped while the other app was still reading it.
- a stranger's link could fetch its title before the app knew who they were.
- the photo cleaner's self-check could be fooled, and a broken file went through. a file it cannot read is refused now.
- an interrupted video stayed on disk until the next start.
- a quick backspace after a new pin could shorten it.
- a link followed by a full stop or bracket previewed the wrong address.
- an attachment that could not be saved arrived as an empty bubble.
- you are told if timed messages stop clearing.
- picked files stayed in the cache.

### Changed
- the link preview choice says why it exists.
- every icon button has a name for screen readers.
- the two background prompts use the same sheet as the rest.
- phones without a camera can install the app, and the legacy storage permission is gone.

## [0.2.3] - 2026-09-09

### Added
- in-app camera. photos are stripped of exif, location and maker notes, and nothing goes to the gallery unless you keep a copy. video is not stripped yet.
- link previews are a choice: automatic, on tap, or off.

### Fixed
- the app fetched every link you sent before sending it, outside tor unless you were on onion mode.
- the backup screen and the file picker left files in the cache.
- decrypting a backup froze the screen.
- links the keyboard had capitalised were not recognised.

### Changed
- restore is three steps and shows what is in the backup before touching anything.
- a stranger's link and any link in a burner room stays plain text.
- previews load the title only, never images.

## [0.2.2] - 2026-09-08

### Added
- introductions, with vouches on the profile.
- scam shield: warns about lookalike names and the usual scam messages. runs on the phone and never blocks anything.
- burner rooms: group chats that expire, joined under a one-off identity.
- handle lookup.
- mentions in groups, wallpapers per chat.

### Fixed
- a first message to someone new could get lost on retry.
- messages from someone you had not accepted stopped after a restart.
- a chat you had left kept running in memory.
- home could miss messages queued offline.

### Changed
- adding someone is rebuilt around scanning in person or sending an invite.
- one page per contact.
- bridges and the second pin explain themselves.
- setup rewritten.

## [0.2.1] - 2026-09-06

### Added
- introductions: a contact can hand you a friend's card, five a week.
- vouches from several contacts.
- scam shield, advice only.
- burner rooms with an end time and their own keys.

### Fixed
- a stranger's queued first message lost its proof of work on retry.
- the screen shield stayed on after leaving a room, and chat screens leaked listeners.
- leaving a room from its info screen closed the app.
- the burn timer left the files behind.
- release builds no longer log ids, onions or message text.
- grey colours replaced by the palette.

### Changed
- current flutter apis for sharing and switches.
- three unused dependencies removed.

## [0.2.0] - 2026-09-04

### Added
- group chats with photos, files, voice notes, replies, reactions and pins
- relay as a route of its own
- obfs4 bridges in process, no executable shipped
- pair codes and a shareable contact card
- public handles
- 1200 drawn avatars
- first contact over a relay
- one apk per abi

### Fixed
- photos drew as a black rectangle in 1:1 chats
- the first stranger could claim the shared first-contact tag
- chats could blank out when two day dividers shared a key
- a tree with no engine built an apk that crashed on launch
- boot failures say what went wrong

## [0.1.0-alpha] - 2026-05-20

First public pre-alpha, for technical testers.

### Added
- 1:1 chat over tor onion v3 with nostr relays as the fallback
- signal double ratchet with x25519 identity keys
- anonymous three-word identities
- qr pairing, paired back on the first message
- ghost mode: messages that delete themselves after 30s to 24h
- reactions and replies
- app lock with pin and biometrics
- panic pin that wipes the app
- generated avatars
- foreground service and boot receiver so messages arrive while locked
- three privacy modes: fast, normal, private
- sqlcipher storage
- encrypted backup and restore
- notes, never synced

### Privacy
- no telemetry, crash reporting or analytics
- no google play services
- no proprietary blobs
- no phone numbers, emails or accounts
