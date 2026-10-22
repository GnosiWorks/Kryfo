// SPDX-License-Identifier: GPL-3.0-or-later
#include "kryfo_voice.h"

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
};

static int kv_stopped(const volatile int32_t *cancel) {
  return cancel != NULL && *cancel != 0;
}

// whisper writes model details and timings to stderr; the app keeps quiet
static void kv_quiet(enum ggml_log_level level, const char *text, void *user) {
  (void)level;
  (void)text;
  (void)user;
}

int32_t kv_abi(void) { return KV_ABI; }

int32_t kv_open(const char *model_path, kv_model **out) {
  if (out == NULL) return KV_ERR_ARGS;
  *out = NULL;
  if (model_path == NULL || model_path[0] == 0) return KV_ERR_ARGS;
  whisper_log_set(kv_quiet, NULL);
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
    // whisper counts time in hundredths of a second
    int64_t t0 = whisper_full_get_segment_t0_from_state(state, i) * 10;
    int64_t t1 = whisper_full_get_segment_t1_from_state(state, i) * 10;
    if (text == NULL) text = "";
    rs->on_segment(rs->user, i, t0, t1, text, (int32_t)strlen(text));
  }
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

  struct kv_run_state rs = {cancel, on_segment, user};
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
  p.new_segment_callback = kv_new_segments;
  p.new_segment_callback_user_data = &rs;
  p.encoder_begin_callback = kv_encoder_begin;
  p.encoder_begin_callback_user_data = &rs;
  p.abort_callback = kv_abort;
  p.abort_callback_user_data = &rs;

  int rc = whisper_full(m->ctx, p, audio, (int)n);
  free(audio);
  if (kv_stopped(cancel)) return KV_CANCELLED;
  if (rc != 0) return KV_ERR_RUN;
  const char *used = whisper_lang_str(whisper_full_lang_id(m->ctx));
  if (used == NULL) used = detect ? "" : lang;
  strncpy(lang_out, used, 7);
  lang_out[7] = 0;
  return KV_OK;
}
