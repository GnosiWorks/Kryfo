# HALO — PROJECT BIBLE

> **v13 — May 14, 2026.** Mario migrating implementation work to Claude Code (CLI) starting now. This file lives as `~/halo/CLAUDE.md` at repo root and auto-loads every Claude Code session. Continue to paste it into Claude.ai chats used for design/strategy/mockups. Phase 1.6 nearly complete after 6 sprints shipped May 13 (Tor SOCKS, fire-and-forget UI, foreground service, boot receiver, notification polish, JobScheduler skeleton).

---

## What it is

Halo (working name, will change) is a privacy-first messenger. Solo dev, open source, 24-month realistic timeline. Pivot from Session/Signal hybrid: BIP-39 anonymous IDs ("neon-tiger-saturn"), libsignal Double Ratchet, Tor onion routing default, SQLCipher persistence, editorial design language. Eventually a marketplace + creator economy on top.

Mario, solo. Windows 10 + WSL2 (Ubuntu). Android-first. iOS at month ~8 when Mac Mini arrives. First mobile app project, Go skills rusty.

**Positioning:** "SimpleX privacy with Telegram polish, editorial design first." The first privacy app that doesn't feel like brutalist hacker software.

---

## Working with Claude (communication contract)

- Brief replies, simple language, no AI-tell hype, search the web before factual claims
- Code reads human-written: short imperative commit messages, no verbose AI-tell comments, gofmt erases stylistic fingerprints — worry about tone, not syntax
- Burn-paced — push to ship fast, 24-month roadmap is a *ceiling not a goal*
- Prefer `cat`-heredoc commands; use base64 for large files (>50 lines) to avoid terminal mangling **(legacy guidance — supplanted by Claude Code which edits files directly)**
- Mockups: match `08_complete_spec.html` (primary). `Halo.html` is advisory only.
- Names/branding: never suggest without trademark + existing-app check first
- Update CONTEXT.md (and the synced `CLAUDE.md` in repo root) when decisions made — flag with [DECISION]
- **GrapheneOS as small inspiration** — calm, technical, no marketing fluff, restraint over excitement
- After shipping something meaningful, explain simply what just happened
- **Claude's sandbox filesystem ≠ user's WSL.** If Claude (.ai chat) needs to write a file on user's machine, use heredoc or base64-encoded script paste. **Claude Code does NOT have this limitation** — it edits files directly in `~/halo/`.

## Tool split (from May 14 onward)

**Claude Code (terminal in WSL):**
- All implementation sprints — file edits, builds, debugging, logcat analysis
- Direct access to `~/halo/` filesystem, runs bash itself, no paste loop
- Auto-loads `~/halo/CLAUDE.md` (this file) every session
- Best for: Sprint 9.1+, push UI tiers, future code work

**Claude.ai (this chat):**
- Design language, mockups (HTML/SVG render natively here)
- Strategy, positioning, branding, naming decisions
- High-level planning, CONTEXT.md updates
- When in doubt: ship it through whichever tool the work *renders* in (terminal output → Claude Code; visual mockup → Claude.ai)

---

## Stack & architecture

- **Mobile UI**: Flutter (Dart), single codebase Android + iOS later
- **Engine**: Go shared library (`libhalo.so`), CGO + go-libtor (alexballas/go-libtor v1.0.7)
- **Crypto**: libsignal_protocol_dart 0.7.4 — Double Ratchet, prekey bundles, X25519 identity
- **Storage**: SQLCipher (encrypted SQLite) via sqflite_sqlcipher
- **Transport**: Tor onion v3 for direct P2P (Fast mode). Nostr relays for store-and-forward mailbox (Normal/Private modes). **Tor SOCKS wraps Nostr WebSockets (✅ shipped Sprint 7).**
- **Background**: Foreground service (✅ Sprint 8.1) keeps process alive. Boot receiver (✅ Sprint 8.3) auto-starts after phone reboot. JobScheduler (✅ Sprint 9 skeleton) handles Doze-mode periodic wake. Custom notification (✅ Sprint 8.4).
- **Identity**: BIP-39 word triples derived from ed25519, X25519 reused as libsignal IdentityKey AND seed for per-conversation ephemeral Nostr keys
- **QR**: mobile_scanner package + halo:// deep link via app_links
- **Native architectures**: x86_64 (emulator), arm64-v8a (real devices)
- **Push (planned)**: 3-tier toggle (foreground service default ✅ infra ready / FCM opt-in / UnifiedPush opt-in) — Halo is the only privacy messenger that gives the user the choice

Repo at `~/halo/`. Local commits only — GitHub being set up.

---

## Devices & dev environment

- **Workstation**: Windows 10 + WSL2 (Ubuntu), hostname `DESKTOP-4FIMDBE`
- **Phone**: Redmi arm64, ADB serial `6TONZDJNHM4D9D7D`. Android 14+ (MIUI/HyperOS).
- **Emulator**: x86_64, ADB id `emulator-5556` (currently flaky from Android Studio launch — port 5037/5038 conflict due to Hyper-V; needs setup work for next session)
- **ADB binary**: `"$ADB_WIN"` = `/mnt/c/Users/mario/AppData/Local/Android/Sdk/platform-tools/adb.exe` (re-export per shell — resets between sessions)
- **ADB server port**: 5038 (Hyper-V holds 5037 on Windows)
- **Working dirs**: `~/halo/engine/` (Go) · `~/halo/mobile/` (Flutter) · `~/halo/mobile/android/app/src/main/kotlin/com/halo/halo_app/` (native Android)
- **Mac Mini M1**: arrives ~Sept-Oct 2026 (month 8) for iOS port
- **MIUI Autostart**: must be manually enabled per-app for BootReceiver to fire (Settings → Apps → halo_app → "background auto start" → ON)

---

## Design language (LOCKED)

- **Aesthetic**: editorial, quiet, premium. Not hacker brutalism, not cute Discord, not Telegram bouncy.
- **Fonts**: Fraunces serif (headers), Instrument Sans (body), JetBrains Mono (times/IDs/prices)
- **Primary color**: amber #F59E0B as signature accent, warm near-black ink #0D0B09
- **Greys (AAA contrast)**: text-2 `#C8BFB2` (10.8:1), text-3 `#B5AB9A` (8.66:1) — never go below text-3 for body text.
- **Default theme**: dark mode, light mode also available
- **Motion**: ink-settles vocabulary — drawing hairlines, blinking cursors, breathing pulses, fade-in serif italics. NOT Telegram bouncy physics.
- **Avatars**: AI-generated deterministic from user ID, style-selectable (glitch / bauhaus / memphis / monogram / noir / cyberpunk / risograph / topographic). Creative, NOT cute.
- **Lists**: chapter-numbered entries, hairline separators, tabular time
- **Tone**: Duolingo-level warmth without being cartoonish.
- **Tor warmup**: 4-onion zig-zag graph (SELF/GUARD/MIDDLE/HSDIR), concentric ring pulse on active node, curve fills as bootstrap progresses, turns green on REACHABLE. Plain-language copy (CONNECTING → BUILDING → PUBLISHING → READY · "you're anonymous"). Phase animation walks through every stage even when engine flies through.
- **Send pills (mode-aware, below outgoing bubbles in flight)**: Fast = no pill (delivered ✓ shows inline at bottom-right of bubble, WhatsApp-style). Normal = `1 hop ◉` with 1 rotating onion. Private = `3 hops ◉◉◉` 3 staggered onions. On delivery, pill disappears + inline ✓ appears in bubble. On failure, "failed · tap to retry" — tappable.
- **Identity reveal (onboarding screen 3)**: 56px breathing amber orb, BIP-39 word triple in shimmer pill with word-by-word stagger reveal (200/600/1000ms, blur→clear, letter-spacing tight→0), serif italic "three words. *yours alone.*", regenerate or "this is me".
- **System notification (Sprint 8.4)**: monochrome halo ring icon (white-on-transparent vector), tinted amber by Android system, "halo · you are anonymous". Tap opens app. No timestamp, no badge, no vibration, no sound.

---

## Locked decisions [DECISION]

Chronological. Don't relitigate without a real reason.

**Positioning & business model:**
- [DECISION] No phone number, no email, no registration. BIP-39 IDs only.
- [DECISION] Open source from day one
- [DECISION] No ads ever, no data sales ever, no investors
- [DECISION] No custom blockchain / token (this is what killed Session)
- [DECISION] Tor mandatory in engine (not optional). Cannot be turned off in v1.
- [DECISION] F-Droid compatible from day one. No Google Play Services, no Firebase by default. UnifiedPush for push (as opt-in tier).
- [DECISION] Swiss non-profit structure planned for v2+
- [DECISION] Free for everyone + Pro tier model. NOT Threema-style pay-upfront. Pro adds power features, never gates basic functionality.
- [DECISION] Donor badges as Pro tier visible recognition — fits free+Pro model. Editorial styling, not garish.
- [DECISION] Real money (USD) as primary display for marketplace. Credits only for utility features (AI, storage).
- [DECISION] Editorial polish is a structural moat, not a "cheap win." Lean in, don't water down.
- [DECISION] Contact discovery — solve via curated invites + vouch networks + in-person QR + Spaces. NOT phone-number scraping.
- [DECISION] Spaces promoted from Phase 3 to Phase 2 priority. Network-effect lever.
- [DECISION] BTC-only for escrow (multisig mature). XMR for simple payments, not escrow. Don't build own chain.

**Engineering decisions:**
- [DECISION] Go engine via FFI, not gomobile — keeps Flutter side simple
- [DECISION] alexballas/go-libtor for embedded Tor (not separate process)
- [DECISION] BIP-39 ID derived from ed25519 pubkey hash, 3-word format
- [DECISION] libsignal_protocol_dart for Stage C — Double Ratchet + prekey bundles
- [DECISION] Reuse existing X25519 keys as libsignal IdentityKeyPair (no re-pair). Same Curve25519 underneath.
- [DECISION] All Signal protocol crypto in Dart. Go engine becomes transport-only (Tor send/receive opaque bytes; Nostr publish/subscribe opaque bytes) going forward.
- [DECISION] SQLCipher schema v2 — adds 5 tables: prekeys, signed_prekeys, sessions, peer_identities, signal_meta
- [DECISION] Stage C phased: foundation (stores + bootstrap) → protocol switch (encrypt/decrypt) → wiring (QR/URI v2)
- [DECISION] DevScreen kept as ECDH fallback during Stage C migration. ChatScreen is libsignal-only.
- [DECISION] Flutter `Curve` hidden in main.dart to avoid collision with libsignal `Curve` (ECC)
- [DECISION] Clamp X25519 private key per RFC 7748 before passing to libsignal
- [DECISION] URI v2 format with prekey bundle: `halo://share?id=...&onion=...&v=2&bundle=<b64>`
- [DECISION] In-app QR scanner (mobile_scanner) + system halo:// deep link (app_links + intent-filter). Both go through `handleHaloUri()` helper.
- [DECISION] URI shown as selectable mono text under QR — works around emulator camera limitations
- [DECISION] `08_complete_spec.html` is primary design reference. `Halo.html` is advisory only.

**Tooling/env:**
- [DECISION] `ANDROID_ADB_SERVER_PORT=5038` in WSL because Hyper-V holds port 5037 on Windows
- [DECISION] WSL adb older than Windows adb — use Windows adb via PowerShell directly when iterating
- [DECISION] Cross-compile Android arm64 with `aarch64-linux-android27-clang`
- [DECISION] Real-device sideload path: `adb push <apk> /sdcard/Download/halo.apk` then install from Files app on phone
- [DECISION] Multi-arch APK (`flutter build apk --target-platform android-arm64,android-x64`) for emulator + real-device coverage
- [DECISION] **(May 14)** Migrate implementation work to Claude Code (CLI) installed in WSL. CLAUDE.md at repo root auto-loads every session. Heredoc/base64 patch workflow retired for code work. Claude.ai chat retained for design/strategy/mockups.

**Privacy posture (GrapheneOS-inspired):**
- [DECISION] **No telemetry, no crash reporting, no analytics — ever.** Bug reports user-initiated only.
- [DECISION] **Storage access scoped to user-selected files only.** Use Android's scoped storage / per-file picker.
- [DECISION] **SQLCipher unlock — Phase 1: random 256-bit key in flutter_secure_storage (Android Keystore-protected).** Phase 2 adds optional user-passphrase mode.
- [DECISION] **GrapheneOS as small inspiration**: passphrase-encrypted DB option, scoped storage, profile compartmentalization, no Google Play Services dependency, calm aesthetic.

**Phase 1.5 design + UX decisions:**
- [DECISION] Tor warmup graph = 4-onion zig-zag with progressive curve fill, plain-language copy, serif italic accent line per state. Phase animation walks states internally.
- [DECISION] Mode-aware send pills below outgoing bubbles in flight. Fast = no pill. Normal = `1 hop ◉`. Private = `3 hops ◉◉◉`. WhatsApp-style inline timestamp + ✓.
- [DECISION] Tap-to-retry on failed bubbles.
- [DECISION] Friendly error filtering. Raw `error: dial: socks connect tcp ...` → "couldn't reach peer · they may be offline".
- [DECISION] Onboarding = 4 single-screens: Welcome → Identity Reveal → Keep Safe → First Contact. Tor warmup runs *during* Keep Safe.
- [DECISION] Welcome h1 = "private messaging, *without the catch*."
- [DECISION] Keep Safe rule 03 acknowledges current limitation honestly — replaced with mailbox promise once Phase 1.6 ships.
- [DECISION] First Contact: visible amber-pill SKIP button (not hidden grey footer).
- [DECISION] Welcome breathing orb = 70px gradient amber→amber-deep with soft 40px glow.
- [DECISION] BIP-39 identity reveal pattern: word-by-word blur→clear stagger, shimmer pill, regenerate option.
- [DECISION] AppState `onboardingComplete` persisted via flutter_secure_storage. Gate widget at MaterialApp.home routes between OnboardingScreen and RootShell.

**Phase 1.6 architecture — store-and-forward via Nostr (May 10, 2026):**
- [DECISION] **Path E — Nostr relays as the store-and-forward rail.** Halo posts encrypted blobs to existing public Nostr relays; recipient subscribes and pulls. Free infrastructure (1000+ relays, 18M users). Functionally equivalent to Session swarm or SimpleX queues using infra we don't pay for.
- [DECISION] **libsignal Double Ratchet wrapped inside Nostr events.** Our crypto stays the same; Nostr is dumb-pipes transport. Relays see only encrypted blobs addressed to ephemeral pubkeys. If Nostr ever fades, we can pivot transport in weeks.
- [DECISION] **Per-conversation ephemeral secp256k1 Nostr pubkeys**, derived from signal session shared secrets via HKDF. Never reuse user identity on Nostr. Relays cannot link conversations to identities.
- [DECISION] **All Nostr relay WebSocket connections through Tor SOCKS.** Relays never see user IP. Halo's existing Tor pipe doubles as Nostr's transport.
- [DECISION] **Existing public Nostr relays only for v1 — no own infra.** Hardcoded shortlist. Spread each event across 3-5 random relays for redundancy.
- [DECISION] **Three-tier push notification system** — single Halo policy that beats every competitor's:
  - **Default (privacy-first)**: Foreground service + Nostr WebSocket subscription. Adaptive — real-time when active, JobScheduler 15min check when dormant. Zero Google. Same approach as Briar.
  - **Toggle: "Faster notifications via Google" (opt-in)**: FCM with encrypted payload (Signal-style). Disclosure: "Google sees Halo has data for you, never contents."
  - **Toggle: "UnifiedPush" (opt-in, power users)**: Routes through ntfy.sh / NextPush distributor. Real-time + zero Google.
- [DECISION] **Halo is the only privacy messenger that lets the user choose their push tradeoff.** Signal forces FCM. Briar refuses any compromise. Halo trusts the user with disclosed-tradeoff toggles. Real strategic differentiator.
- [DECISION] **Speed targets per mode (with Nostr added):** Fast ~300-800ms, Normal ~700ms-2.5s, Private ~1.5-5s. Faster than Session in every mode.

**Phase 1.6 implementation decisions (May 11, 2026):**
- [DECISION] **Engine Nostr layer in `engine/nostr.go`** (~340 lines as of Sprint 7). 4 FFI exports: `HaloNostrInit(relaysCSV)`, `HaloNostrSend(peerXPubHex, msg)`, `HaloNostrSubscribe(peerXPubHex)`, `HaloNostrPoll() → "peer|content\n..."`. Uses fiatjaf.com/nostr library. Persistent per-peer subscription goroutines auto-reconnect on relay drop.
- [DECISION] **Library: fiatjaf.com/nostr** (canonical fork; older `nbd-wtf/go-nostr` is archived). Active maintenance by Nostr's creator. New API uses `chan Event` value (not pointer), `RelayOptions{}` struct, `nostr.SecretKey([32]byte)` constructor.
- [DECISION] **Per-peer xPub via libsignal IdentityKeyStore lookup, not a new DB column.** Single source of truth (libsignal already stores X25519 IdentityKey for each peer during pairing). Helper `signalSession.peerXPubHex(haloId)` returns hex of the 32-byte X25519 pubkey. Avoids DB migration risk + drift.
- [DECISION] **Dart FFI wrappers + record types**: `nostrPoll()` returns `List<({String peer, String cipher})>` using Dart 3 named records.
- [DECISION] **Default relay shortlist (May 2026)**: relay.damus.io, nos.lol. (relay.snort.social dropped Sprint 7 — consistently broken through Tor.)
- [DECISION] **Build script `engine/build.sh`** automates cross-compile for both archs. ~30s for arm64 + x86_64 combined.

**Phase 1.6 production-validation decisions (May 12, 2026):**
- [DECISION] **Bidirectional pairing required** for Nostr-derived ephemeral keys. Both peers must scan/import each other's halo URI — each needs the OTHER's X25519 pubkey to derive matching ephemeral Nostr address. Workaround: both sides scan. Future TODO 1.6.13: first-contact handshake to auto-back-pair on first message receive.
- [DECISION] **subscribe-on-pair pattern**: `handleHaloUri` calls `appState.subscribePeer(haloId)` after v1+v2 contact upserts → libsignal lookup → `_xPubToHaloId` map + `engine.nostrSubscribe`. Single hook covers QR scan + deep link + paste paths.
- [DECISION] **Receive path uses `signalDecrypt`, NOT `engine.decryptFrom`.** Cipher payloads are libsignal Double Ratchet, not engine AES. The dev-screen poll loop's original `engine.decryptFrom` call was leftover from earlier architecture.
- [DECISION] **ChatScreen listens to AppState changes** via `appState.addListener(_onAppStateChanged)` in initState → `_loadMessages()` re-runs from db on notify → real-time chat refresh without polling.

**Sprint 7 — Nostr over Tor SOCKS (May 12-13, 2026):**
- [DECISION] **Tor SOCKS wraps every Nostr WebSocket.** `engine.torNostrClient()` builds an `http.Client` with `Transport.DialContext = torDialer.DialContext`, passed to `(*Relay).ConnectWithClient(ctx, client)`. Relays only see Tor exit IPs, never user IPs. `fiatjaf.com/nostr.NewConnection` doesn't exist — used `NewRelay` + `ConnectWithClient` instead.
- [DECISION] **Singleton cached http.Client.** Each goroutine calling `t.Dialer(ctx, nil)` concurrently caused Tor control-channel contention → indefinite hangs. Fix: call `t.Dialer` exactly once, cache the resulting http.Client globally (mutex-protected). All subsequent ops reuse the cache.
- [DECISION] **First-success early return in `nostrPublishMulti`.** Channel-based instead of WaitGroup. Publish returns as soon as 1 relay confirms (typically 2-3s). Other goroutines continue in background. Trade-off: publish lands on 1-2 relays on average instead of 3, but mailbox semantics make redundancy less critical than speed.
- [DECISION] **Drop relay.snort.social.** Consistently times out with "connection took too long" through Tor SOCKS even after successful bootstrap to other relays. Suspect: relay slow/overloaded or specific Tor exit path broken. Removed from defaults in both Go (`nostrRelays`) and Dart (`engine.nostrInit` call).
- [DECISION] **Per-relay timeout 15s → 8s.** Successful relays respond in 1-2s; broken ones hang ~10-30s. 8s is tight enough for fail-fast while tolerant of slow networks.
- [DECISION] **TLS handshake timeout 30s → 10s.** Same rationale.
- [DECISION] **Android logging bridge.** `engine/android_log.go` adds cgo wrapper to `__android_log_print` and redirects Go's default `log` writer to it. Engine logs now visible via `adb logcat | grep halo-engine`. Closes deferred TODO #3 from Phase 1.5.

**Sprint 7.5 — UX wins (May 13, 2026):**
- [DECISION] **Dart fire-and-forget send.** Engine FFI no longer awaited. Bubble flips to ✓ optimistically the instant send fires; engine.nostrSend runs in background. On failure (after timeout), bubble flips to "failed · tap to retry". WhatsApp/Signal UX pattern. UI never freezes during publish.
- [DECISION] **Auto-start Tor at boot.** `boot()` in main.dart fires `engine.startListener(docsDir.path)` fire-and-forget after refreshContacts. User never has to tap "start listening" again. Tor bootstraps in background; Nostr subs retry every 10s until ready.

**Sprint 8.1 — Foreground service (May 13, 2026):**
- [DECISION] **HaloListenerService** as foreground service with persistent notification. Keeps the Flutter process alive when app is backgrounded so Tor + Nostr goroutines continue running. `START_STICKY` so OS restarts the service if killed.
- [DECISION] **POST_NOTIFICATIONS runtime permission** requested in MainActivity.onResume via ActivityCompat. Android 13+ requires this even when declared in manifest. Without it, notifications silently don't show.
- [DECISION] **Android 14 allows users to dismiss foreground service notifications** by OS policy. Service stays running regardless. We don't fight this; the service is what matters, the notification is just an OS requirement.

**Sprint 8.3 — Boot receiver (May 13, 2026):**
- [DECISION] **BootReceiver** auto-starts HaloListenerService when phone reboots. BroadcastReceiver on `android.intent.action.BOOT_COMPLETED`.
- [DECISION] **`foregroundServiceType` changed from `dataSync` to `specialUse`.** Android 14 blocks `dataSync` foreground services from being started by BOOT_COMPLETED (privacy restriction). `specialUse` is allowed and is the correct category for our "private messenger background relay" use case. Requires `<property android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE">` with a human-readable description explaining what the service does.
- [DECISION] **Permission swap**: `FOREGROUND_SERVICE_DATA_SYNC` → `FOREGROUND_SERVICE_SPECIAL_USE` (paired with the type change).
- [DECISION] **MIUI Autostart caveat**: Xiaomi requires user to manually enable "background auto start" per-app under Settings → Apps → halo → Other permissions. Without this, BootReceiver never fires on MIUI regardless of manifest. Document in onboarding.

**Sprint 8.4 — Notification UX polish (May 13, 2026):**
- [DECISION] **Custom halo notification icon**: monochrome vector drawable `ic_halo_notification.xml` — ring/donut shape (10-radius circle with 7-radius hole, white fill, evenOdd fillType). Android system tints with our amber color (`0xFFF59E0B`).
- [DECISION] **Tap-to-open**: PendingIntent (immutable + update-current) launches MainActivity with FLAG_ACTIVITY_SINGLE_TOP. Tapping the notification brings halo to front.
- [DECISION] **Editorial copy**: "halo · you are anonymous". No timestamp (`setShowWhen(false)`). No badge, no vibration, no sound. CATEGORY_SERVICE.

**Sprint 9 — JobScheduler skeleton (May 13, 2026):**
- [DECISION] **HaloPeriodicJobService** as JobService skeleton, scheduled 15-min periodic on app launch. `setPersisted(true)` survives reboot. `setRequiredNetworkType(NETWORK_TYPE_ANY)` because we need network for Nostr poll. Idempotent — checks `getPendingJob` before scheduling.
- [DECISION] **Job logs each fire to logcat for now.** Sprint 9.1 will wire the job to `engine.nostrPoll()` + per-message notifications. The plumbing is in place tonight; the actual receive-while-doze work lands in 9.1.
- [DECISION] **15-min interval is Android's enforced minimum** for periodic jobs. Smaller intervals silently get rounded up. Acceptable tradeoff for battery friendliness.

---

## Feature list (LOCKED)

### v1 Core (Phase 1-3)
1:1 chat, small groups ≤50, voice messages, reactions, reply-to, ghost mode (self-destructing) with burn timers, personas (multi-identity), three privacy modes (Normal/Private/Fast with IP warning), human-readable BIP-39 IDs, QR connect, Drop tab (files/GIFs/sounds/ringtones, 1GB free, onion-linked, 7-day expiry), avatar picker (1200+ generated variants), onboarding, settings, Notes tab ("Note to Self"), rich link embeds (Tor-safe fetching), on-device AI (translation, scam detection, scoped search, relationship nudge — all free).

### v1 Privacy-unique (Phase 2-3)
- **Panic wipe** — second PIN opens clean/burner state.
- **Burner rooms** — auto-dissolving groups
- **Time capsules** — messages decrypt on future date
- **Ghost mode** — self-destructing messages with burn timers

### v2 Privacy-unique (Phase 5-6+)
- **Witness mode** — stream encrypted chunks to trusted contacts in real time
- **Dead drop** — encrypted messages at GPS coordinates
- **Spacetime presence** — location fuzzing per contact
- **Signed messages** — cryptographic proof of sender identity
- **Confession threads** ⭐ — anonymous post in a Space; ring signatures prove membership without revealing identity. **World-first feature.**
- **Shadow account linking** ⭐ — zk-SNARK prove two personas to one specific person only, non-transferable. **World-first feature.**

### v2 Spaces (capped 2,000 members)
Discord-style but capped to avoid moderation hell. Channels, roles, threads, custom emoji/sticker packs per Space.

### v2 Social (trust-enabled)
Shared envelopes, group buys, inheritance messages, shared memory timeline, weekly ring, hand-off, draft-with-recipient, running RSVP, paid consult, brief (auto-escrow for freelance work).

### v2 Marketplace (revenue engine)
Art, stickers, GIFs, sounds, ringtones, themes, voice filters, PDFs/ebooks/zines, fonts, services with escrow, courses (Whop-style). 15% platform / 85% creator. Non-custodial multi-sig escrow.

### v3 Delight
Shared playlist (Spotify-first), question of the day, time spent together Wrapped, co-watch rooms.

### Identity unlocks
Proof of longevity, mutual vouching, skill tags with endorsements, DNS verification, social proof ownership (Keybase-style), 2-word premium IDs.

### AI tiers
Free (on-device): translation, scam detection, scoped search, relationship nudge.
Paid (credits): voice transcription (2cr/min), smart drafts (5cr/draft), group digests (5cr), voice filter (3cr/min).

### CUT — do not build
Running tabs, retro mode, Whispernet/Bluetooth mesh (harassment vector), silent mention (stalking vector), padded traffic toggle (battery killer), custom blockchain/token (killed Session), VPN (Tor already does it), pay-to-view (legal mess), Discord Activities/embedded games, mega-servers 10k+ (moderation trap), adult content, drugs, weapons, gambling.

### Screenshot prevention — honest limits
iOS: cannot prevent, only detect-and-notify. Android: FLAG_SECURE works for most. Both: watermark with viewer-ID. Don't lie to users.

---

## Monetization — 4 pillars

1. **Marketplace commission** (primary, 15% cut)
2. **Credits** (AI features + Drop storage + premium IDs)
3. **Identity unlocks** (one-time: 2-word IDs, DNS verification, extra personas)
4. **Donations** (transparent cost dashboard)

---

## Payment architecture — 3 rails

- **Fiat (~80%):** Paddle primary (merchant of record). Mollie EU backup. Stripe tertiary.
- **BTC:** BTCPay Server self-hosted. BTC + Lightning. No processor who can drop us.
- **Multi-crypto:** NOWPayments for XMR, USDC, USDT on Polygon
- **Escrow:** BTC multisig (2-of-3), fiat via Paddle hold, XMR no-escrow (direct p2p), stablecoins via smart contract

**Framing trick:** apply to processors as "digital goods marketplace for independent creators" NOT "privacy messenger."

---

## Marketplace governance — 3 layers

- **Layer 1 (anyone):** stickers, art, themes, sounds, fonts, zines — no verification. Buyers protected via escrow + refunds.
- **Layer 2 (trust-built):** courses, services, ebooks — requires account age 90d + mutual vouches + small credit deposit.
- **Layer 3 (verified):** regulated professions — cryptographic credential attestation via Persona/Jumio. Store signed proof, NOT identity.

---

## In-chat deals

Structured deal card created via "+" → "Propose a deal". Fields: what, amount, delivery date, escrow terms. Appears as amber-bordered card with Accept/Counter buttons. Updates live through deal lifecycle. Auto-animated: amber pulse when funds lock, checkmark on release.

---

## Phase status

- **Phase 0 — Foundation** ✅ done (May 5, 2026)
- **Phase 1 — v1 Core** ✅ closed (May 7, 2026)
- **Phase 1.5 — Pre-alpha polish** ✅ closed (May 10, 2026)
- **Phase 1.6 — Mailbox infrastructure (Nostr + Tor + push tiers)** 🟡 active. **MVP green (May 12). Tor SOCKS green (May 13 morning). Full background infra green (May 13 evening).** Sprints 1-9 shipped + 6.1/6.2/6.3 fixes. Remaining: Sprint 8.2 (test backgrounded receive end-to-end — needs working emulator), Sprint 9.1 (wire JobScheduler to engine.nostrPoll + per-msg notifications), Sprint 10 (3-tier push UI), Sprint 11 (UnifiedPush opt-in), Sprint 12 (FCM opt-in).
- **Phase 2 — Alpha (closed beta, ~100 users)** planned
- **Phase 3 — Public Beta** planned (Month 8-11 — iOS port)
- **Phase 4 — v1.0 Launch** planned (Month 12-15)
- **Phase 5 — Marketplace** planned (Month 16-20)
- **Phase 6 — Deepen** planned (Month 21-24)

---

## Phase 1 — what shipped (11 commits)

```
caabc32 qr scanner, deep links, scan flow, modes wired, per-peer dedup
b118b88 arm64 cross-compile of engine for real-device testing
3d9640a libsignal double ratchet over tor, end-to-end
f2bf551 libsignal foundation (stores + bootstrap)
671c85c editorial home + chat screens, send/receive via UI
05bb076 sqlcipher identity persistence
3bce2f5 qr identity exchange + ecdh proven end-to-end
fa63e19 stage B: x25519 ecdh per-peer encryption
60e02c0 stage A: aes-gcm encryption + bip39 ids
9470220 phase 0 complete: plaintext over tor between two halos
ff92854 phase 0: ffi bridge + cross-compiled tor for android
```

---

## Phase 1.5 — what shipped (5 commits, May 8-10, 2026)

```
cf881f9 phase 1.5: cross-device build + onboarding polish
a136110 phase 1.5 #5: editorial onboarding flow
d290761 phase 1.5: tor status state machine, ui status text
564d588 phase 1.5: multi-message inbox queue, drain api
c2c86e0 phase 1.5: persist onion key across restarts
```

**Architectural finding (#6 cross-device test):** direct P2P over Tor onions between two devices is unreliable. Confirms store-and-forward mailbox is critical pre-alpha infrastructure. Became Phase 1.6.

---

## Phase 1.6 — what shipped (May 11-13, 2026)

```
8704c31 phase 1.6 sprint 9: jobscheduler skeleton for periodic 15-min wakeups
6e91663 phase 1.6 sprint 8.4: notification UX polish
1f10d07 phase 1.6 sprint 8.3: boot receiver auto-starts service on phone reboot
63ceab7 phase 1.6 sprint 8.1: foreground service + persistent notification
0df776b phase 1.6 sprint 7.5: dart fire-and-forget send + auto-start tor at boot
92ec6ad phase 1.6 sprint 7: nostr over tor SOCKS
fc96432 phase 1.6: subscribe-on-pair + signal decrypt + chat auto-refresh
889b391 phase 1.6 sprint 5+6: nostr engine + ffi + integration
a5b8c03 phase 1.6 sprint 2-4: nostr probe with encrypt + ephemeral keys + fanout
```

**Production validation (real Redmi phone):**
- Bidirectional Nostr through Tor SOCKS: publish ~2s, receive in real-time
- Foreground service: process survives home button + notification swipe
- Boot receiver: service auto-starts after phone reboot (with MIUI Autostart enabled)
- Notification: custom halo ring icon, amber tint, tap opens app
- JobScheduler: forced run via `cmd jobscheduler run -f` fires the periodic log; real 15-min wakeups scheduled
- Privacy property confirmed: relay operators see only Tor exit IPs

---

## Phase 1.5 punch list — status

1. ✅ Tor onion key persistence
2. ✅ Multi-message inbox queue
3. ✅ Onion publish progress UI
4. ✅ Editorial Tor warmup + mode-aware send pills + tap-to-retry
5. ✅ Editorial onboarding flow
6. ✅ Real-network testing — **Nostr mailbox solves direct P2P unreliability (validated May 12).**
7. ✅ Per-screen lastCipher dedup
8. ✅ Creative Tor loading animation (subsumed in #4)

---

## Deferred TODOs — must address before public alpha

1. **[FUTURE POLISH] Standby state for Tor warmup graph.** Dimmed/grey state before listening starts.
2. **[FUTURE POLISH] Send timeout.** `engine.sendTo` (onion direct) still hangs forever on unreachable peer. Add 60s timeout. (Note: `engine.nostrSend` now has 8s per-relay timeout as of Sprint 7.)
3. ~~Engine logging visibility~~ ✅ **Resolved Sprint 7** via `android_log.go` cgo bridge.
4. **[TECH DEBT] "Reachable" status is 60s timeout heuristic.** Should be event-driven via HSDir UPLOADED events.
5. **[TECH DEBT] First send after Tor startup is slower** (~3-5s) because singleton client init runs on first call. Pre-warm on Tor "reachable" transition would fix.
6. **[SPRINT 9.1] Wire JobScheduler to engine.nostrPoll + per-message notifications.** Job currently just logs that it fired; needs to drain events and post notifications.
7. **[SPRINT 8.2] Validate backgrounded receive end-to-end.** Emulator port flakiness (Hyper-V holds 5037 vs Android Studio expects 5037) blocked the test on May 13 evening. Tomorrow: get emulator + phone both connected and verify a message sent while phone halo is backgrounded actually surfaces.
8. **[ONBOARDING TODO] MIUI Autostart prompt.** On Xiaomi/MIUI, walk users through enabling "background auto start" so BootReceiver fires. Without it, halo doesn't auto-resume after phone reboot.

---

## Phase 1.6 remaining sprint table (as of May 13 evening)

| # | Sprint | Status | Est |
|---|---|---|---|
| 1-6.3 | Nostr stack + bidirectional | ✅ shipped | done |
| 7 | All Nostr through Tor SOCKS | ✅ shipped | done |
| 7.5 | Dart fire-and-forget + auto-start Tor | ✅ shipped | done |
| 8.1 | Foreground service + persistent notification | ✅ shipped | done |
| 8.2 | Validate backgrounded receive | ⏳ blocked on emulator | ~30min once emu works |
| 8.3 | Boot receiver (auto-start on reboot) | ✅ shipped | done |
| 8.4 | Notification UX polish (icon + tap + copy) | ✅ shipped | done |
| 9 | JobScheduler skeleton | ✅ shipped | done |
| 9.1 | Wire job to engine.nostrPoll + per-msg notifications | ⏳ next | ~2-3h |
| 10 | Push settings UI (3-tier toggle screen) | ⏳ | ~2-3h |
| 11 | UnifiedPush opt-in integration | ⏳ | ~3-5h |
| 12 | FCM opt-in (Google variant build) | ⏳ | ~6-10h |
| 6.13 | first-contact auto-back-pair (POLISH) | ⏳ future | ~3-5h |

**Remaining estimate to close Phase 1.6:** ~13-23h = 2-4 burn days.

**Pace projection (May 13 evening → July 8 = 56 days):**
- Phase 1.6 closure — ~1 week at burn pace
- Phase 1.5 deferred TODOs cleared — 3-4 days
- Phase 2 alpha prep (bug bash, friend testing, doc) — 2-3 weeks
- **Realistic by July 8: closed alpha with 5-15 friend testers, full Nostr+Tor stack, all 3 push tiers, iOS not yet started.**
- iOS port begins month 8 (Mac Mini arrives ~Sept-Oct 2026).

---

## Sprint 7 debug session (May 12-13) — lessons captured

**What went wrong:**
1. Test sends froze UI indefinitely. No logs to diagnose because Go's `log.Printf` doesn't reach Android logcat by default.
2. First hypothesis (multiple `t.Dialer` calls hanging) was partially wrong — some runs they returned in 3ms, other runs they hung.
3. Real culprit: combination of concurrent control-channel contention + `relay.snort.social` always timing out + WaitGroup forcing wait for slowest relay.

**What we built to solve it:**
1. `android_log.go` — engine logs now visible. **Closes deferred TODO #3.** Permanent debugging infrastructure.
2. Singleton cached http.Client — only ONE `t.Dialer` call per app lifetime. Eliminates contention.
3. First-success channel pattern in publish — return ASAP.
4. Drop the bad relay.

**Recurring pain points to remember:**
1. `$ADB_WIN` env var resets between shells — must re-export every session.
2. Terminal mangles heredocs >50 lines — use base64-encoded patch scripts.
3. Multiple concurrent goroutines hitting bine/tor Dialer can deadlock under load.
4. Engine init crash modes: confirm via fresh `logcat -c` then app open, not stale buffer.
5. **Claude's sandbox filesystem is NOT user's WSL.** When Claude uses `create_file`, it goes to Claude's container. Always use heredoc or base64 to deliver patches to user's machine.
6. **Kotlin scope shadowing**: function parameter `flags: Int` shadows `Intent.flags` setter inside `.apply{}`. Use `addFlags()` or `setFlags()` method calls explicitly.
7. **Android 14 FGS BOOT_COMPLETED restriction**: `dataSync` foregroundServiceType not allowed from BOOT_COMPLETED. Use `specialUse` with PROPERTY description.
8. **POST_NOTIFICATIONS runtime permission** required on Android 13+ even when declared in manifest.
9. **MIUI Autostart**: Xiaomi devices require manual enable per app for BroadcastReceivers to fire.

**Tooling improvements made:**
- Build chain still 5-7min per iteration (engine + cross-compile + APK + push + install). Acceptable for now.
- Logging chain proven: Go `log.Printf` → `androidLogWriter.Write` → `__android_log_print` → `logcat | grep halo-engine`. Use freely.
- For Kotlin Log: `Log.i("halo-engine", ...)` surfaces under the same tag.

---

## Realistic 24-month roadmap

| Phase | Time | What ships |
|---|---|---|
| 0 — Foundation | Month 1 | Hello onion, Hello chat. FFI bridge. Two instances exchange plaintext over onion. |
| 1 — MVP Core | Month 2-4 | libsignal E2E, SQLCipher, BIP-39 IDs, QR connect, editorial chat UI, reliable 1:1 delivery. |
| 2 — Alpha | Month 5-7 | Voice, images, reactions, reply-to, ghost mode, personas, privacy modes. APK to ~100 users. |
| 3 — Public Beta | Month 8-11 | Small groups, iOS port + push relay, store submissions, onboarding, avatar picker, AI features. |
| 4 — v1.0 Launch | Month 12-15 | Notes, Spaces v1, settings polish, donation flow. Store live. First real users. |
| 5 — Marketplace | Month 16-20 | Spaces v2, marketplace, escrow + deals, payment rails, AI tier expansion. Revenue starts. |
| 6 — Deepen | Month 21-24 | Witness mode, dead drop, ring-signature confessions, zk-SNARK shadow linking. |

---

## Repo structure

```
~/halo/
  CONTEXT.md                                this file (kept only in Claude project knowledge)
  08_complete_spec.html                     primary design reference
  Halo.html                      advisory bundle
  scripts/haloup                            adb bridge for WSL → Windows
  engine/
    bridge.go                               Tor FFI exports
    nostr.go                                Nostr FFI exports + Tor SOCKS client (Sprint 7)
    android_log.go                          cgo bridge: Go log.Printf → android logcat (Sprint 7)
    build.sh                                cross-compile both archs
    cmd/nostrtest/                          sprint 1.6.1 probe
    cmd/nostrtest2/                         sprint 1.6.2+3+4 probe
    go.mod, go.sum
    libhalo.h, libhalo.so
  mobile/
    lib/
      main.dart                             AppState, RootShell, _OnboardingGate, deep links, Nostr poll loop, _xPubToHaloId, auto-start Tor in boot() (Sprint 7.5)
      theme.dart                            design tokens
      signal_session.dart                   libsignal bootstrap + peerXPubHex helper
      signal_stores.dart                    4 SQLCipher-backed libsignal stores
      widgets/motion.dart                   TorWarmupGraph, SendPill, etc
      screens/
        home_screen.dart
        chat_screen.dart                    AppState listener for real-time receive; fire-and-forget send (Sprint 7.5)
        modes_screen.dart
        scan_screen.dart
        onboarding_screen.dart
    android/app/src/main/
      AndroidManifest.xml                   FGS specialUse perms + receiver + JobService + halo:// intent (Sprint 7-9)
      kotlin/com/halo/halo_app/
        MainActivity.kt                     starts service + schedules periodic job + runtime perm (Sprint 8-9)
        HaloListenerService.kt              foreground service + persistent notification (Sprint 8.1, 8.4)
        BootReceiver.kt                     BOOT_COMPLETED auto-start (Sprint 8.3)
        HaloPeriodicJobService.kt           15-min periodic JobService skeleton (Sprint 9)
      res/drawable/
        ic_halo_notification.xml            monochrome halo ring vector drawable (Sprint 8.4)
        launch_background.xml
      jniLibs/
        x86_64/libhalo.so                   (with Nostr-over-Tor + android logging)
        arm64-v8a/libhalo.so                (with Nostr-over-Tor + android logging)
```

---

## Identity & onion model (current state, post-1.6)

- **BIP-39 ID** — derived from ed25519 pubkey, persisted in SQLCipher, stable across restarts
- **X25519 keypair** — persisted, doubles as libsignal IdentityKey AND seed for per-conversation ephemeral Nostr keys
- **libsignal session state** — persisted in SQLCipher (5 tables)
- **Tor onion address** — persisted. Stable across restarts.
- **Onboarding-complete flag** — flutter_secure_storage `onboarding_done`
- **Listener port** — random ephemeral per launch
- **Per-conversation Nostr ephemeral keypair** — NOT persisted. Derived deterministically from `HKDF(myXPriv·peerXPub + conversationID)`. Both peers compute the same address.

---

**Last updated**: May 14, 2026 (v13) · **Mario** (solo dev, WSL + Mac M1 pipeline)  
**Next review**: After Sprint 9.1 + push UI sprints (10/11/12), now via Claude Code CLI
