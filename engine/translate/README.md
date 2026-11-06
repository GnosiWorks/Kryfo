# Offline translation

messages translated on the phone with bergamot, the engine behind
firefox's offline translations. chinese and english first. it is off:
`kOfflineTranslation` in mobile/lib/translate/hub_live.dart is false until
the native library below is built and has run on phones. with it off no
screen shows translation and no part of it runs, though the opencc tables
(424 KB) ship in the apk and the go exports are in libhalo.

## what is here

- `models.json`: the pinned manifest. each file of a pair with its size and
  sha256, gzipped and unpacked, where it was published (`source`) and our
  mirror (`base`), the only host the app fetches from; there is no
  setting for another. the mirror can stop a download but cannot get a
  different file loaded, which matters because the files are parsed by
  c++. `Parse` refuses unknown fields, a base that is not https or an
  onion, paths that leave the source, and odd names, hashes or sizes.
- `bundle.go`, `pad.go`, `jobs.go`: the download. a language's bundle is
  both directions, so the host cannot tell which way the person
  translates, and it is one file on the mirror padded to a size class.
  every request is one whole 1 MiB range of it, in order, with no user
  agent, cookies or compression. the files are checked and unpacked only
  once the last byte is in. a cut keeps what came, padding counted, and
  the next start goes on from there. a wrong hash throws the part away.
  `resume.go`: in the app three chunks come at once, each lane on a tor
  circuit of its own; a request that brings no byte for 45 s (or takes 5
  min) stops, is asked again after a backoff from the byte the part holds,
  on a fresh circuit after two misses in a row, and the download ends only
  once no chunk came for 10 min. each stop is logged by its class.
- `fetch.go`: one file from where it was published, for the desk tool and
  for filling the mirror.
- `mirror.go`: what the mirror serves, made from the source and the pins.
- `../translate_ffi.go`: the exports. the download dials through tor only
  (the update check's dialer), under a fresh socks name per download, with
  no direct fallback and no redirects.
- `native/`: a four-call c api over bergamot (`kryfo_translate.h`), and
  `build.sh`, which builds it as `libkryfo_translate.so` for arm64-v8a,
  armeabi-v7a and x86_64 with the pinned ndk from the sources
  `bergamot.lock` pins (`fetch-bergamot.sh` checks each tarball's sha256);
  `--twice` builds again at another path and compares the bytes. the
  release builds it; gradle leaves it out of the apk while the switch is
  off. `KT_BENCH=1` adds `kt_bench`, for timing a phone from adb.
- `cmd/ktmodels`: a desk tool to list, fetch (directly from the source,
  not over tor), fill a mirror directory, and print a pair's bergamot
  config.

the app side is mobile/lib/translate/ and screens/translation_screen.dart.
the language guess runs in dart, so a message's words never go to the
engine for it. translations are kept in memory only, per open chat, never
stored, and wiped with the language guesses when the app locks.
a chat whose recent messages are mostly in one language the person does
not read gets a slim bar at its top (translate/translate_bar.dart): one
tap translates the whole chat, and its menu sets the language to always or
never translate, or puts the bar away in that chat. it is worked out from
the guesses the chat holds in memory; only those three choices are stored.
the decoy never shows it, and it is in 1:1 chats only; in groups a
message has its translate line and menu rows, and the group page its
switch. a reader of traditional chinese gets the models' simplified
output converted with opencc's tables (apache 2.0, mobile/assets/opencc,
remade by its fetch.sh): s2tw, taiwan's forms, for zh_Hant and zh_TW, as
the app's own traditional strings use, and s2hk for zh_HK and zh_MO. a
chat's auto-translate switch goes when the chat is deleted, and starts
over when a chat moves into or out of the hidden chats.

## the models

firefox's own, one direction each, int8 with a lexical shortlist:

| pair | arch | download | on disk |
|---|---|---|---|
| zh-en | base-memory | 38.3 MB | 54.6 MB |
| en-zh | base-memory | 36.7 MB | 49.9 MB |

they are published in mozilla's public bucket, and the app fetches them
from our mirror on the relay box, over its onion. the mozilla/translations readme
says the model files are under the MPL 2.0. bergamot-translator is MPL
2.0, marian and intgemm MIT, ruy, sentencepiece and ssplit-cpp Apache 2.0,
pcre2 BSD. all of them can ship in a GPL-3.0-or-later app.

## what a download says, and to whom

- the mirror sees which language is fetched, over its onion: no exit, and
  nothing that ties it to a person.
- the guard sees a download of one size class: 48 MiB for small models,
  96 MiB for base ones, whole steps of 96 MiB past that, as that many
  requests of 1 MiB each in a row. every language of a class looks the
  same. the padding costs chinese about 24.4 MiB (75.0 MB of files in a
  96 MiB class). the guard does see how many languages are fetched, one
  download each.
- a download starts only from a tap that shows the size first, never by
  itself. that tap often comes soon after a message in that language
  arrived, and the mirror is on the box that delivered the message, so
  the box can see a pack fetched soon after a message came in.
- the decoy sees none of the phone's packs and fetches nothing. android's
  storage page shows the app's size, packs included, whichever session is
  open.

## the mirror

the box serves, under `/models/` on the relay onion (plain http on the
onion, which tor encrypts and authenticates), these files and nothing else:

- one file per language, named by `BundleID` (a hash of the pins) plus
  `.bin`: the published gzips back to back in manifest order, then noise
  up to the size class (sha256 in counter mode over the id, so every fill
  makes the same bytes);
- `SHA256SUMS`, the list of the above, for `sha256sum -c`.

`ktmodels mirror <dir>` makes both from models.json: it fetches each file
from the source, checks it against its pins packed and unpacked, and
writes the bundles and the list. the app checks each part against
models.json, never against a list the box sends. the box needs range
requests, no compression, no redirects, and no logs of paths.

## before it is turned on

1. the mirror on the box, answering over the onion.
2. time the download and the first message on an a78-class phone, an
   a55-only one and a 32-bit one.
3. the switch: `kOfflineTranslation = true` in
   mobile/lib/translate/hub_live.dart and the
   `excludes += "**/libkryfo_translate.so"` line out of
   mobile/android/app/build.gradle.kts, in one commit.
