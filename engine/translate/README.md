# Offline translation

messages translated on the phone with bergamot, the engine behind
firefox's offline translations. chinese and english first. it is off:
`kOfflineTranslation` in mobile/lib/translate/hub_live.dart is false until
the native library below is built and has run on phones, and with it off
no screen shows translation and nothing of it is built.

## what is here

- `models.json`: the pinned manifest. each file of a pair with its size and
  sha256, gzipped and unpacked, where it was published (`source`) and our
  mirror (`base`). a mirror, a cdn or an exit can stop a
  download but cannot get a different file loaded, which matters because
  the files are parsed by c++. `Parse` refuses unknown fields, non-https
  bases, paths that leave the base, and odd names, hashes or sizes.
- `fetch.go`, `bundle.go`, `jobs.go`: the download. every request is a
  1 MiB range with no user agent, cookies or compression. a cut leaves a
  part file the next start resumes from. a wrong hash throws the file away.
  a language's bundle is both directions, so the host cannot tell which
  way the person translates. `pad.go` pads it to a size class.
- `mirror.go`: what the mirror serves, made from the source and the pins.
- `../translate_ffi.go`: the exports. the download dials through tor only
  (the update check's dialer), under a fresh socks name per download, with
  no direct fallback and no redirects.
- `native/`: a four-call c api over bergamot (`kryfo_translate.h`), a bench,
  and a script that builds bergamot for the desk outside the repo. none of
  it is built by the app build yet.
- `cmd/ktmodels`: a desk tool to list, fetch (directly from the source,
  not over tor), fill a mirror directory, and print a pair's bergamot
  config.

the app side is mobile/lib/translate/ and screens/translation_screen.dart.
the language guess runs in dart, so a message's words never go to the
engine for it. translations are kept in memory only, per open chat, and
never stored. a reader of traditional chinese gets the models' simplified
output converted with opencc's s2t tables (apache 2.0,
mobile/assets/opencc, remade by its fetch.sh).

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

- the mirror sees which files are fetched, by their hashes, over its
  onion: no exit, and nothing that ties it to a person.
- the guard sees the bundle's size class: 48 MiB for small models, 96 MiB
  for base ones, whole steps of 96 MiB past that. the padding is fetched
  from the mirror's `pad` file after the real files and thrown away. it
  costs chinese about 24.4 MiB (75.0 MB of files in a 96 MiB class). a
  download that is cut and resumed sends the padding again in full.
- a download starts only from a tap that shows the size first, never
  because a message arrived, so its timing does not point at a message.
- the decoy sees none of the phone's packs and fetches nothing.

## the mirror

the box serves, under `/models/` on the relay onion (plain http on the
onion, which tor encrypts and authenticates), these files and nothing else:

- every file in models.json as `<gzSha256>.gz`, the published gzip
  unchanged;
- `pad`, 96 MiB of noise, with range requests;
- `SHA256SUMS`, the list of the above, for `sha256sum -c`.

`ktmodels mirror <dir>` makes all three from models.json: it fetches each
file from the source, checks it against its pins packed and unpacked,
names it by its hash, and writes the noise and the list. the hash list is
models.json itself, so the app trusts no list the box sends. the box needs
range requests, no compression, no redirects, and no logs of paths.

## before it is turned on

1. build `libkryfo_translate.so` for every abi the app ships: arm64-v8a,
   armeabi-v7a and x86_64, with the ndk (marian's ruy path on arm,
   `-DANDROID_ABI=<abi> -DCOMPILE_WASM=OFF -DUSE_RUY_SGEMM=ON
   -DUSE_MKL=OFF`, `-static-libstdc++`, only `kt_*` exported; on x86_64
   intgemm instead of ruy), in the reproducible build, and add it to the
   f-droid recipe. armeabi-v7a needs neon and ruy's 32-bit kernels.
2. fill the mirror and serve it from the box.
3. time a message on an a78-class phone, an a55-only one and a 32-bit one.
4. groups: the bubble and the menu entry are wired in 1:1 chats only.
