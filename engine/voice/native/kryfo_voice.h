// SPDX-License-Identifier: GPL-3.0-or-later
// a small c api over whisper.cpp for the app to call through dart:ffi. the
// audio goes in as 16-bit pcm, the text comes out a segment at a time on
// the calling thread, which the app keeps off the ui isolate. the files it
// opens: the model, /proc/cpuinfo once (ggml names the cpu backend from
// it) and, only on a crash path, /proc/self/status (ggml's backtrace looks
// for a tracer there). it touches no network and never spawns a process.
#ifndef KRYFO_VOICE_H
#define KRYFO_VOICE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// the library is built with hidden symbols; these four are its api
#if defined(__GNUC__)
#define KV_API __attribute__((visibility("default")))
#else
#define KV_API
#endif

// the abi the dart bindings check before any other call
#define KV_ABI 1

// what kv_open and kv_run return
#define KV_OK 0
#define KV_ERR_ARGS 1
#define KV_ERR_MODEL 2
#define KV_ERR_AUDIO 3
#define KV_ERR_RUN 4
#define KV_CANCELLED 5

typedef struct kv_model kv_model;

// one segment as it is decoded: its place, its times in milliseconds from
// the start of the note, and len bytes of utf-8 text. the caller copies
// len bytes and never scans past them for the nul, a read mte phones
// trap when it runs ahead. text is only valid during the call.
typedef void (*kv_segment_fn)(void *user, int32_t index, int64_t t0_ms,
                              int64_t t1_ms, const char *text, int32_t len);

KV_API int32_t kv_abi(void);

// loads a ggml whisper model. KV_OK with *out set, or an error with *out
// null.
KV_API int32_t kv_open(const char *model_path, kv_model **out);

// transcribes n frames of interleaved 16-bit pcm at rate hz with channels
// channels. lang is a whisper language code, or null or "auto" to detect
// it (a whole extra pass: the app always names one); the code used is
// written into lang_out (at least 8 bytes). the note is run in pieces cut
// at quiet points, so segments come piece by piece and silence makes none. the run
// stops with KV_CANCELLED once *cancel is nonzero, which another thread
// may set at any time. one run per model at a time.
KV_API int32_t kv_run(kv_model *m, const int16_t *pcm, int64_t frames,
                      int32_t rate, int32_t channels, const char *lang,
                      int32_t threads, const volatile int32_t *cancel,
                      kv_segment_fn on_segment, void *user, char *lang_out);

KV_API void kv_close(kv_model *m);

#ifdef __cplusplus
}
#endif

#endif
