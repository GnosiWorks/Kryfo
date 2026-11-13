# Contributing

Kryfo is made by one developer, and help is welcome. Translations and good bug reports help the most.

Security problems don't go in public issues. See SECURITY.md.

## Translations

Kryfo is in 17 languages. Every word the app shows lives in `mobile/lib/l10n/app_<locale>.arb`. `app_en.arb` is the source: every key starts there.

Not a coder? Open an issue with the language, the screen, the text you see and what it should say. A screenshot helps, as long as it shows no names or messages.

To edit the files yourself:

- change the value, never the key
- keep placeholders such as `{count}` or `{name}` exactly as they are
- keep "Kryfo" as it is, with a capital K
- use sentence case where your language has it: a capital at the start of a label, button or sentence, the rest lowercase
- keep it short. A button has the room of a button

Then, in `mobile/`:

    flutter gen-l10n
    flutter test test/l10n_complete_test.dart

A few texts that Android shows itself (the keys starting with `android`) are copied into Android's resources with `python3 tool/arb_android.py`. Store texts are in `mobile/fastlane/metadata/android/<locale>/`.

Want to add a new language? Open an issue first, so we can talk about who reviews it.

## Bug reports

Open an issue with:

- the Kryfo version (Settings, About) and where you installed it from (F-Droid, GitHub, kryfo.app or Google Play)
- the phone or computer, and its system version
- the route: private or fast, and whether a bridge is on
- what you did, what you expected and what happened instead
- whether it happens every time

Keep personal data out of issues. No three words or @names that aren't yours to share, no invite links, no bridge lines, no IP addresses, no screenshots with names or messages. Read a log before you paste it.

The "Check my connection" report (Settings, Transport) is made to be shared. It has no IP address, no location and no bridge lines.

## Building

BUILDING.md has the toolchain and every build. The tests:

    cd mobile && flutter test
    cd engine && GOFLAGS=-mod=vendor go test ./...

Some app tests need the engine and the shim built for your computer first: `sh mobile/tool/host_engine.sh` and `bash mobile/native/kryfo_signal/build-host.sh`.

## Code style

- `dart format` and `flutter analyze` for Dart, `gofmt` for Go
- comments are short and lowercase, and say why, not what. No stories, no dates
- commit messages are one line, lowercase, imperative and under 60 characters, with no prefix and no body. For example: `fix pdf pages showing blank`
- new source files start with `// SPDX-License-Identifier: GPL-3.0-or-later`
- UI text is in sentence case and goes into `app_en.arb`, never into the code. Say in the pull request which languages you couldn't do, and I'll get them done before it merges
- every `ALTER TABLE` in `mobile/lib/app/database.dart` is inside a try/catch

## Pull requests

Pull requests are welcome. Keep them small: one fix or one change per request, with a test where it makes sense.

For anything bigger, open an issue first and wait for a reply before you write the code. That covers new features, new dependencies, anything in the crypto, the storage or the network code, and UI redesigns. A feature goes into a release finished or not at all, so a half-done one waits.

Work happens on a release branch, and `main` moves at each release. Open your pull request against `main`. I may pick your commits onto the release branch, and they keep you as the author.

## Privacy rules

These hold for every change:

- no analytics, no tracking, no crash reports that phone home
- no new network connection without an issue first: what it sends, to whom, and over which route. By default everything goes over Tor
- no Google or other closed code in the `foss` flavor, the build that F-Droid, GitHub and kryfo.app ship
- no new Android permission without a reason in the pull request
- no logging of message content, keys, contacts or addresses
- anything new our servers could see is written down in SERVERS.md and PRIVACY.md before it ships

## Licence

There is no CLA. Your contribution is under GPL-3.0-or-later, the same as the rest of Kryfo. The sticker art is under CC BY-SA 4.0.
