# Voice note transcripts

the engine side of transcripts made on the phone with whisper.cpp. it is
off: `kVoiceTranscripts` in mobile/lib/voice/voice_transcripts.dart is false
until the bubble, its strings and the storage rules are in, and with it off
nothing of it is built and no screen reaches mobile/lib/voice.

## what is here

- `models.json`: the pinned models, whisper base and small, q5_1, with
  their size and sha256, on a pinned huggingface revision. `Parse` refuses
  non-https bases (an onion may be plain http), names that leave the
  directory, and odd hashes or sizes.
- `fetch.go`, `jobs.go`, `store.go`: the download. every request is a
  1 MiB range with no user agent or compression. a cut leaves a part file
  the next start resumes from, a wrong hash throws the file away, and a
  model only ever lands in the app's own storage (`AppDir`). `Check`
  deletes a model that no longer matches its pin.
- `../voice_ffi.go`: the exports. the download dials through tor only,
  under a fresh socks name per download, with no direct fallback. a
  redirect is followed only to https hosts the manifest names, and never
  from another base.
- `native/`: libkryfo_voice, a four-call c api over whisper.cpp
  (`kryfo_voice.h`). 16-bit pcm in at any rate, segments out as they are
  decoded, a cancel flag another thread may set. it opens the model file
  and nothing else and imports no network call (build.sh checks).

the app side is mobile/lib/voice: the ffi bindings (a run on its own
isolate, segments streamed back, cancel), the wav reader and the model
download calls.

when offline translation lands, its pack download and this one share one
fetcher and one settings host; `WithBase` is the seam for that host.

## building the library

    native/build-host.sh --test   this machine, for the tests
    native/build.sh               arm64-v8a, armeabi-v7a, x86_64 in native/out
    native/build.sh --twice       and again at another path, bytes compared

`fetch-whisper.sh` unpacks whisper.cpp at the commit in `whisper.lock`,
checked against the tarball's sha256, into `native/.third_party`.
`KV_WHISPER_TARBALL` takes a tarball fetched beforehand, `KV_WHISPER_DIR` a
clean git checkout of the same commit (an f-droid srclib); both give the
same files. build.sh wants ndk 28.2.13676358 and cmake 3.22.1, the ones
repro/Dockerfile already pins, and builds with prefix maps, no build id,
16 kb pages and `SOURCE_DATE_EPOCH`.

the app build does not package the library yet. `JNI_LIBS_DIR` copies it
into jniLibs once transcripts are turned on.

## licences

whisper.cpp and ggml are MIT, the whisper weights MIT. both can ship in a
GPL-3.0-or-later app.
