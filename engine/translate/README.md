# Offline translation

messages translated on the phone with bergamot, the engine behind
firefox's offline translations. chinese and english first. it is off:
`kOfflineTranslation` in mobile/lib/translate/hub_live.dart is false until
the native library below is built and has run on phones, and with it off
no screen shows translation and nothing of it is built.

## what is here

- `models.json`: the pinned manifest. each file of a pair with its size and
  sha256, gzipped and unpacked. a mirror, a cdn or an exit can stop a
  download but cannot get a different file loaded, which matters because
  the files are parsed by c++. `Parse` refuses unknown fields, non-https
  bases, paths that leave the base, and odd names, hashes or sizes.
- `fetch.go`, `bundle.go`, `jobs.go`: the download. every request is a
  1 MiB range with no user agent, cookies or compression. a cut leaves a
  part file the next start resumes from. a wrong hash throws the file away.
  a language's bundle is both directions, so the host cannot tell which
  way the person translates.
- `../translate_ffi.go`: the exports. the download dials through tor only
  (the update check's dialer), under a fresh socks name per download, with
  no direct fallback and no redirects.
- `native/`: a four-call c api over bergamot (`kryfo_translate.h`), a bench,
  and a script that builds bergamot for the desk outside the repo. none of
  it is built by the app build yet.
- `cmd/ktmodels`: a desk tool to list, fetch (directly, not over tor) and
  print a pair's bergamot config.

the app side is mobile/lib/translate/ and screens/translation_screen.dart.
the language guess runs in dart, so a message's words never go to the
engine for it. translations are kept in memory only, per open chat.

## the models

firefox's own, one direction each, int8 with a lexical shortlist:

| pair | arch | download | on disk |
|---|---|---|---|
| zh-en | base-memory | 38.3 MB | 54.6 MB |
| en-zh | base-memory | 36.7 MB | 49.9 MB |

they come from mozilla's public bucket. the mozilla/translations readme
says the model files are under the MPL 2.0. bergamot-translator is MPL
2.0, marian and intgemm MIT, ruy, sentencepiece and ssplit-cpp Apache 2.0,
pcre2 BSD. all of them can ship in a GPL-3.0-or-later app.

## what a download says, and to whom

- the file host sees which pair is fetched, from a tor exit, and nothing
  that ties it to a person.
- the exit sees the host name and the byte counts, not the path.
- the guard sees about 75 MB of tor traffic. bundle sizes differ, so the
  volume hints at the language. padding each bundle to a size class is not
  done.
- a download starts only from a tap that shows the size first, never
  because a message arrived, so its timing does not point at a message.
- the decoy sees none of the phone's packs and fetches nothing.

## before it is turned on

1. build `libkryfo_translate.so` for arm64-v8a with the ndk (marian's ruy
   path, `-DANDROID_ABI=arm64-v8a -DCOMPILE_WASM=OFF -DUSE_RUY_SGEMM=ON
   -DUSE_MKL=OFF`, `-static-libstdc++`, only `kt_*` exported), in the
   reproducible build, and add it to the f-droid recipe.
2. time a message on an a78-class phone and an a55-only one.
3. close the models when the app goes to the background.
4. groups: the bubble and the menu entry are wired in 1:1 chats only.
