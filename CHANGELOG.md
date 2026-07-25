# Changelog

All notable user-facing changes to kryfo will land here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

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
