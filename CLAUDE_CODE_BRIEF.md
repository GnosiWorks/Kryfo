# brief: the photo bug and the blank chat

## the app

Kryfo, a privacy messenger. Flutter UI in `mobile/`, Go engine in `engine/`
(built to `libhalo.so`, called over FFI). `mobile/lib/screens/chat_screen.dart`
is ~8,200 lines and is where both bugs live.

Build: `cd ~/halo/mobile && flutter build apk --debug --target-platform android-arm64`
Devices: `export ADB_WIN=/mnt/c/platform-tools/adb.exe` then
`"$ADB_WIN" -s R58R42N3DDE ...` (Samsung) or `-s 6TONZDJNHM4D9D7D` (Redmi,
MIUI blocks fresh adb installs — push to /sdcard/Download and install via the
file manager).

---

## bug 1 — photos render as a black rectangle

**What is known for certain, do not re-derive:**

- The file on disk is a **complete, valid JPEG**. Verified with
  `run-as app.kryfo` — correct size, magic bytes `ffd8 ffe1` (JPEG with EXIF).
  **The media pipeline is innocent** — chunking, decryption and the file write
  all work. Only rendering fails.
- `errorBuilder` on the `Image.file` **never fires**. No exception is thrown.
- The row reaches the UI: logcat shows
  `LOAD: row dir=out txt=4 media=/data/user/0/app.kryfo/app_flutter/media/<uid>.jpg`
- There is a `LayoutBuilder` probe already in the bubble that prints
  `PHOTOBOX w=... h=...` on build. **It has never printed, in any test.**

That last point is the important one and reframes everything: if the probe
never runs, **the bubble widget is never built at all**. This is not a
sizing or decode problem — something upstream is preventing the widget from
being constructed. Start there, not at the image.

**Things already tried that did NOT fix it — do not repeat:**

1. Wrapping in `ConstrainedBox` with explicit width/minHeight, on a theory
   that a `Stack`'s loose constraints collapsed `width: double.infinity` to
   zero. Reverted; made things worse.
2. `FLAG_SECURE` blacking out hardware surfaces. Ruled out —
   `_blockScreenshots` and `_secureChats` both default `false` in
   `main.dart` (~line 3142).
3. `cacheWidth: 1080` + `filterQuality: FilterQuality.medium` under the
   Impeller renderer producing a blank texture. **Both parameters have been
   removed already.** Plausible but never cleanly tested because bug 2 kept
   firing first.

**Where to look:** the item builder and row builder wrapping the bubble.
There is a `try/catch` fallback around row building that renders
"this message can't be shown" — check it is not silently swallowing an
exception. Grep `itemBuilder`, `_buildRow`.

**Related but separate, not our bug:** "preparing your selected media 0 of 1
ready" hanging is **Android's own system photo picker** stalling on
cloud-backed photos that are not cached locally. Camera-fresh photos get
through fine.

---

## bug 2 — chats go blank / red screen `'_owner != null'`

**Root cause was found and fixed, but the fix has NEVER been verified on a
device** (the machine's SSD died before it could be tested).

The error was `A GlobalKey was used multiple times inside one widget's child
list`, which tears down the subtree and produces the `_owner != null`
assertion.

`_dateDivider()` handed out one `GlobalKey` per **calendar day**. A divider is
emitted whenever a message's day differs from the previous message's day — so
an out-of-order list emitted two dividers for one day, both grabbing the same
key. Several paths appended to `_messages` rather than inserting by time, so
late arrivals (retries, slow-route wraps, reconnect backfills) landed after
messages newer than themselves.

**Fixes applied (all committed):**
- `_normaliseMessages()` — sorts by time and dedups by `msgUid` — called from
  every path that populates `_messages` (initial load, pagination, incremental
  receive, and the three image/video/file send paths)
- dividers now keyed by **message uid**, not by day, matching what
  `group_chat_screen.dart` already did correctly. `Map<String, GlobalKey>` +
  `Map<String, int> _dayMsOf` for the sticky header. Collisions are now
  structurally impossible rather than merely unlikely.

**First job: verify this actually works** before touching bug 1, since a
red screen tears the tree down before the photo bubble ever builds — the two
may be the same event at different severities. If chats hold up under heavy
send/receive and photos then render, bug 1 never existed separately.

---

## how to work on this

**Do not patch blind.** Three theories on bug 1 have been wrong. `flutter run`
now works on this machine — use it, press `w` for the widget tree (shows real
constraints and RenderObject sizes) or `p` for debug paint (draws every
widget's bounds, so zero-size vs painted-nothing is visible directly).

`flutter run -d R58R42N3DDE` — note the VM Service connection over the
Windows adb bridge is fragile and has hung before. A hang is not a new bug.

**When a red screen appears, read the actual error text on the phone.** The
GlobalKey root cause was found in one read from a photo of the error, after
days of fruitless logcat archaeology.

**Verify the flashed build's timestamp before trusting any test result:**
`"$ADB_WIN" -s R58R42N3DDE shell dumpsys package app.kryfo | grep lastUpdateTime`
More than one session was lost to testing a stale APK.

**Code style — this is open source and must not read as AI-written.** Short
lowercase comments, no em-dashes, no "leverage"/"seamless"/"robust"/"ensure",
no explaining the obvious. Commits: short, imperative, lowercase.

**Do not run `go mod vendor` in `engine/`** — it deletes go-libtor's C sources
and breaks the build irrecoverably.
