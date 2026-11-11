// SPDX-License-Identifier: GPL-3.0-or-later
#include "kryfo_voice.h"

#include <errno.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

#include "whisper.h"

#define KV_RATE 16000
// a voice note is minutes long; this keeps a bad header from asking for gigabytes
#define KV_MAX_SECONDS 1800

struct kv_model {
  struct whisper_context *ctx;
};

struct kv_run_state {
  const volatile int32_t *cancel;
  kv_segment_fn on_segment;
  void *user;
  // where the piece being run starts in the note, and the segments sent
  // before it
  int64_t at_ms;
  int64_t len_ms;
  int32_t sent;
};

// a note goes to whisper in pieces cut where it is quiet: each piece's
// words come as soon as it is done, and the encoder works on the piece's
// length instead of a fixed 30 s window. the first piece is short so the
// first words come early
#define KV_FRAME 320
#define KV_FIRST_MIN (3 * KV_RATE)
#define KV_FIRST_MAX (6 * KV_RATE)
#define KV_NEXT_MIN (8 * KV_RATE)
#define KV_NEXT_MAX (15 * KV_RATE)
// a rest shorter than this joins the piece before it
#define KV_TAIL (2 * KV_RATE)
// room past the piece's end in the encoder's window, in its 20 ms steps,
// and the smallest window (10.24 s); a full one is 1500 steps
#define KV_CTX_PAD 64
#define KV_CTX_STEP 512
// a piece is run only when its loudest 20 ms is over both of these: the
// note's own floor (its quiet tenth, room noise or hiss) times KV_OVER, and
// KV_SILENT. whisper only makes up words for silence and steady noise, but a
// quiet or far-off voice (loudest 20 ms at 0.0023) can be under a room's
// noise (0.003), so the level alone cannot tell them apart. noise from a
// real phone room stays under 2x its floor, speech goes 40x and more
#define KV_SILENT 0.0003f
#define KV_OVER 3.0f
// under one step of 16-bit pcm: zeros the recorder pads with, not the room
#define KV_ZERO (1.0f / 32768.0f)
// whisper writes mandarin in traditional characters unless led to
// simplified, which this line in simplified does
#define KV_ZH_PROMPT "\xe4\xbb\xa5\xe4\xb8\x8b\xe6\x98\xaf\xe6\x99\xae\xe9\x80\x9a\xe8\xaf\x9d\xe7\x9a\x84\xe5\x8f\xa5\xe5\xad\x90\xe3\x80\x82"

static int kv_stopped(const volatile int32_t *cancel) {
  return cancel != NULL && *cancel != 0;
}

// whisper writes model details and timings to stderr; the app keeps quiet
static void kv_quiet(enum ggml_log_level level, const char *text, void *user) {
  (void)level;
  (void)text;
  (void)user;
}

// on an assert ggml forks the app, grants the child ptrace on it and runs
// gdb by PATH. the link sends its fork, execlp and prctl here instead
// (CMakeLists.txt), so the process holding the keys never spawns anything
int __wrap_fork(void) {
  errno = ENOSYS;
  return -1;
}

int __wrap_execlp(const char *file, const char *arg, ...) {
  (void)file;
  (void)arg;
  errno = ENOSYS;
  return -1;
}

int __wrap_prctl(int option, ...) {
  (void)option;
  errno = EPERM;
  return -1;
}

// an assert goes straight to abort(), without the backtrace attempt
static void kv_abort_quiet(const char *message) { (void)message; }

int32_t kv_abi(void) { return KV_ABI; }

int32_t kv_open(const char *model_path, kv_model **out) {
  if (out == NULL) return KV_ERR_ARGS;
  *out = NULL;
  if (model_path == NULL || model_path[0] == 0) return KV_ERR_ARGS;
  whisper_log_set(kv_quiet, NULL);
  ggml_set_abort_callback(kv_abort_quiet);
  struct whisper_context_params cp = whisper_context_default_params();
  cp.use_gpu = false;
  struct whisper_context *ctx = whisper_init_from_file_with_params(model_path, cp);
  if (ctx == NULL) return KV_ERR_MODEL;
  kv_model *m = calloc(1, sizeof(*m));
  if (m == NULL) {
    whisper_free(ctx);
    return KV_ERR_RUN;
  }
  m->ctx = ctx;
  *out = m;
  return KV_OK;
}

void kv_close(kv_model *m) {
  if (m == NULL) return;
  whisper_free(m->ctx);
  free(m);
}

// the voice, gone from memory before the buffer goes back. through a
// volatile pointer, so the compiler cannot drop it as a store nobody reads
static void *(*const volatile kv_memset)(void *, int, size_t) = memset;
static void kv_wipe(void *p, size_t n) {
  if (p != NULL) kv_memset(p, 0, n);
}

// mono floats at 16 khz, which is all whisper reads. a box average when
// going down keeps higher notes from folding back as noise.
static float *kv_resample(const int16_t *pcm, int64_t frames, int32_t rate,
                          int32_t channels, int64_t *n_out) {
  float *mono = malloc((size_t)frames * sizeof(float));
  if (mono == NULL) return NULL;
  for (int64_t i = 0; i < frames; i++) {
    int32_t sum = 0;
    for (int32_t c = 0; c < channels; c++) sum += pcm[i * channels + c];
    mono[i] = (float)sum / (32768.0f * (float)channels);
  }
  if (rate == KV_RATE) {
    *n_out = frames;
    return mono;
  }
  int64_t n = frames * KV_RATE / rate;
  if (n < 1) n = 1;
  float *res = malloc((size_t)n * sizeof(float));
  if (res == NULL) {
    kv_wipe(mono, (size_t)frames * sizeof(float));
    free(mono);
    return NULL;
  }
  double step = (double)rate / KV_RATE;
  for (int64_t i = 0; i < n; i++) {
    double at = (double)i * step;
    if (step > 1.0) {
      int64_t a = (int64_t)at;
      int64_t b = (int64_t)(at + step);
      if (b > frames) b = frames;
      if (b <= a) b = a + 1;
      double s = 0;
      for (int64_t j = a; j < b; j++) s += mono[j];
      res[i] = (float)(s / (double)(b - a));
    } else {
      int64_t a = (int64_t)at;
      int64_t b = a + 1 < frames ? a + 1 : a;
      float f = (float)(at - (double)a);
      res[i] = mono[a] * (1.0f - f) + mono[b] * f;
    }
  }
  kv_wipe(mono, (size_t)frames * sizeof(float));
  free(mono);
  *n_out = n;
  return res;
}

static bool kv_abort(void *user) {
  return kv_stopped(((struct kv_run_state *)user)->cancel);
}

static bool kv_encoder_begin(struct whisper_context *ctx, struct whisper_state *state,
                             void *user) {
  (void)ctx;
  (void)state;
  return !kv_stopped(((struct kv_run_state *)user)->cancel);
}

static void kv_new_segments(struct whisper_context *ctx, struct whisper_state *state,
                            int n_new, void *user) {
  (void)ctx;
  struct kv_run_state *rs = user;
  // nothing reaches the app once it asked to stop
  if (kv_stopped(rs->cancel) || rs->on_segment == NULL) return;
  int n = whisper_full_n_segments_from_state(state);
  for (int i = n - n_new; i < n; i++) {
    if (i < 0) continue;
    const char *text = whisper_full_get_segment_text_from_state(state, i);
    // whisper counts time in hundredths of a second, from the piece's start
    int64_t t0 = whisper_full_get_segment_t0_from_state(state, i) * 10;
    int64_t t1 = whisper_full_get_segment_t1_from_state(state, i) * 10;
    // a time past the piece's end is the model's guess, not the note's
    if (t0 > rs->len_ms) t0 = rs->len_ms;
    if (t1 > rs->len_ms) t1 = rs->len_ms;
    if (t1 < t0) t1 = t0;
    t0 += rs->at_ms;
    t1 += rs->at_ms;
    if (text == NULL) text = "";
    rs->on_segment(rs->user, rs->sent++, t0, t1, text, (int32_t)strlen(text));
  }
}

// the loudness of 20 ms from sample i
static float kv_level(const float *a, int64_t n, int64_t i) {
  int64_t end = i + KV_FRAME < n ? i + KV_FRAME : n;
  if (end <= i) return 0;
  double sum = 0;
  for (int64_t j = i; j < end; j++) sum += (double)a[j] * a[j];
  return (float)sqrt(sum / (double)(end - i));
}

// where the piece from start ends: the quietest 60 ms between lo and hi
// samples on, or the note's end when what is left is short
static int64_t kv_cut(const float *a, int64_t n, int64_t start, int64_t lo, int64_t hi) {
  if (n - start <= hi + KV_TAIL) return n;
  int64_t best = start + hi;
  float quiet = -1;
  for (int64_t i = start + lo; i + 3 * KV_FRAME <= start + hi; i += KV_FRAME) {
    float l = kv_level(a, n, i) + kv_level(a, n, i + KV_FRAME) + kv_level(a, n, i + 2 * KV_FRAME);
    if (quiet < 0 || l < quiet) {
      quiet = l;
      best = i + KV_FRAME + KV_FRAME / 2;
    }
  }
  return best;
}

static int kv_cmp(const void *x, const void *y) {
  float a = *(const float *)x, b = *(const float *)y;
  return (a > b) - (a < b);
}

// the level the note's quietest tenth stays under, from the whole note so
// a piece of room noise alone is measured against itself. 0 when nothing
// but zeros, or no memory: then only KV_SILENT holds a piece back
static float kv_floor(const float *a, int64_t n) {
  int64_t frames = (n + KV_FRAME - 1) / KV_FRAME;
  float *lv = malloc((size_t)frames * sizeof(float));
  if (lv == NULL) return 0;
  int64_t k = 0;
  for (int64_t i = 0; i < n; i += KV_FRAME) {
    float l = kv_level(a, n, i);
    if (l >= KV_ZERO) lv[k++] = l;
  }
  float low = 0;
  if (k > 0) {
    qsort(lv, (size_t)k, sizeof(float), kv_cmp);
    low = lv[k / 10];
  }
  kv_wipe(lv, (size_t)frames * sizeof(float));
  free(lv);
  return low;
}

static int kv_silent(const float *a, int64_t n, float gate) {
  for (int64_t i = 0; i < n; i += KV_FRAME)
    if (kv_level(a, n, i) >= gate) return 0;
  return 1;
}

int32_t kv_run(kv_model *m, const int16_t *pcm, int64_t frames, int32_t rate,
               int32_t channels, const char *lang, int32_t threads,
               const volatile int32_t *cancel, kv_segment_fn on_segment,
               void *user, char *lang_out) {
  if (lang_out != NULL) lang_out[0] = 0;
  if (m == NULL || m->ctx == NULL || lang_out == NULL) return KV_ERR_ARGS;
  int detect = lang == NULL || lang[0] == 0 || strcmp(lang, "auto") == 0;
  if (!detect && whisper_lang_id(lang) < 0) return KV_ERR_ARGS;
  if (pcm == NULL || frames <= 0 || channels < 1 || channels > 8 ||
      rate < 8000 || rate > 192000)
    return KV_ERR_AUDIO;
  if (frames / rate > KV_MAX_SECONDS) return KV_ERR_AUDIO;
  if (kv_stopped(cancel)) return KV_CANCELLED;

  int64_t n = 0;
  float *audio = kv_resample(pcm, frames, rate, channels, &n);
  if (audio == NULL) return KV_ERR_RUN;

  struct kv_run_state rs = {cancel, on_segment, user, 0, 0, 0};
  struct whisper_full_params p = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
  p.n_threads = threads < 1 ? 4 : (threads > 8 ? 8 : threads);
  p.language = detect ? "auto" : lang;
  p.detect_language = false;
  p.translate = false;
  p.no_context = true;
  p.print_special = false;
  p.print_progress = false;
  p.print_realtime = false;
  p.print_timestamps = false;
  p.suppress_nst = true;
  if (!detect && strcmp(lang, "zh") == 0) p.initial_prompt = KV_ZH_PROMPT;
  p.new_segment_callback = kv_new_segments;
  p.new_segment_callback_user_data = &rs;
  p.encoder_begin_callback = kv_encoder_begin;
  p.encoder_begin_callback_user_data = &rs;
  p.abort_callback = kv_abort;
  p.abort_callback_user_data = &rs;

  float gate = KV_OVER * kv_floor(audio, n);
  if (gate < KV_SILENT) gate = KV_SILENT;
  int rc = 0;
  int ran = 0;
  for (int64_t start = 0; start < n && rc == 0;) {
    // short until the first piece with something in it has run
    int64_t end = ran ? kv_cut(audio, n, start, KV_NEXT_MIN, KV_NEXT_MAX)
                      : kv_cut(audio, n, start, KV_FIRST_MIN, KV_FIRST_MAX);
    int64_t len = end - start;
    if (!kv_silent(audio + start, len, gate)) {
      // the encoder's window in a few fixed sizes: fitted to each piece
      // exactly, the model drops or repeats words
      int64_t need = (len * 50 + KV_RATE - 1) / KV_RATE + KV_CTX_PAD;
      p.audio_ctx = need <= KV_CTX_STEP ? KV_CTX_STEP : (need <= 2 * KV_CTX_STEP ? 2 * KV_CTX_STEP : 0);
      rs.at_ms = start * 1000 / KV_RATE;
      rs.len_ms = len * 1000 / KV_RATE;
      rc = whisper_full(m->ctx, p, audio + start, (int)len);
      ran = 1;
    }
    if (kv_stopped(cancel)) break;
    start = end;
  }
  kv_wipe(audio, (size_t)n * sizeof(float));
  free(audio);
  if (kv_stopped(cancel)) return KV_CANCELLED;
  if (rc != 0) return KV_ERR_RUN;
  // a note with nothing to hear: no words, and the language asked for
  if (!ran) {
    strncpy(lang_out, detect ? "" : lang, 7);
    lang_out[7] = 0;
    return KV_OK;
  }
  const char *used = whisper_lang_str(whisper_full_lang_id(m->ctx));
  if (used == NULL) used = detect ? "" : lang;
  strncpy(lang_out, used, 7);
  lang_out[7] = 0;
  return KV_OK;
}
