// SPDX-License-Identifier: GPL-3.0-or-later
// the voice library on this machine: kv_test <model> <wav> [real model].
// the first model is whisper.cpp's own small test model, whose words mean
// nothing; the optional second is a real one, for the words themselves.
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "../kryfo_voice.h"

static int failed;

#define CHECK(c)                                                   \
  do {                                                             \
    if (!(c)) {                                                    \
      fprintf(stderr, "%s:%d: check failed: %s\n", __FILE__, __LINE__, #c); \
      failed++;                                                    \
    }                                                              \
  } while (0)

struct wav {
  int16_t *pcm;
  int64_t frames;
  int32_t rate;
  int32_t channels;
};

static uint32_t le32(const unsigned char *p) {
  return p[0] | p[1] << 8 | p[2] << 16 | (uint32_t)p[3] << 24;
}

// a 16-bit pcm wav, as the app records them
static int read_wav(const char *path, struct wav *w) {
  FILE *f = fopen(path, "rb");
  if (f == NULL) return -1;
  fseek(f, 0, SEEK_END);
  long n = ftell(f);
  fseek(f, 0, SEEK_SET);
  unsigned char *b = malloc(n);
  if (b == NULL || fread(b, 1, n, f) != (size_t)n) {
    fclose(f);
    free(b);
    return -1;
  }
  fclose(f);
  long at = 12;
  int bits = 0;
  while (at + 8 <= n) {
    uint32_t size = le32(b + at + 4);
    if (memcmp(b + at, "fmt ", 4) == 0) {
      w->channels = b[at + 10] | b[at + 11] << 8;
      w->rate = (int32_t)le32(b + at + 12);
      bits = b[at + 22] | b[at + 23] << 8;
    } else if (memcmp(b + at, "data", 4) == 0) {
      if (bits != 16 || w->channels < 1) break;
      if (size > (uint32_t)(n - at - 8)) size = (uint32_t)(n - at - 8);
      w->frames = size / (2 * w->channels);
      w->pcm = malloc(size);
      memcpy(w->pcm, b + at + 8, size);
      free(b);
      return 0;
    }
    at += 8 + size + (size & 1);
  }
  free(b);
  return -1;
}

struct seen {
  int count;
  int last_index;
  int ordered;
  int64_t last_t1;
  char text[4096];
  // set cancel from inside the first segment
  volatile int32_t *stop_after_first;
};

static void on_segment(void *user, int32_t index, int64_t t0, int64_t t1, const char *text,
                       int32_t len) {
  struct seen *s = user;
  if (index != s->last_index + 1 || t0 > t1 || t0 < 0) s->ordered = 0;
  if (len != (int32_t)strlen(text)) s->ordered = 0;
  s->last_index = index;
  s->last_t1 = t1;
  s->count++;
  strncat(s->text, text, sizeof(s->text) - strlen(s->text) - 1);
  if (s->stop_after_first != NULL) *s->stop_after_first = 1;
}

static void seen_init(struct seen *s) {
  memset(s, 0, sizeof(*s));
  s->last_index = -1;
  s->ordered = 1;
}

struct later {
  volatile int32_t *flag;
  int ms;
};

static void *cancel_later(void *arg) {
  struct later *l = arg;
  struct timespec ts = {l->ms / 1000, (l->ms % 1000) * 1000000L};
  nanosleep(&ts, NULL);
  *l->flag = 1;
  return NULL;
}

// w repeated k times, as a longer note
static struct wav repeat(const struct wav *w, int k) {
  struct wav r = *w;
  r.frames = w->frames * k;
  r.pcm = malloc(r.frames * w->channels * 2);
  for (int i = 0; i < k; i++)
    memcpy(r.pcm + i * w->frames * w->channels, w->pcm, w->frames * w->channels * 2);
  return r;
}

// mono 16 khz as stereo 48 khz: each frame three times on both sides
static struct wav stereo48(const struct wav *w) {
  struct wav r = {0};
  r.rate = 48000;
  r.channels = 2;
  r.frames = w->frames * 3;
  r.pcm = malloc(r.frames * 4);
  for (int64_t i = 0; i < r.frames; i++) {
    r.pcm[2 * i] = w->pcm[i / 3];
    r.pcm[2 * i + 1] = w->pcm[i / 3];
  }
  return r;
}

// every other frame, as 8 khz
static struct wav half(const struct wav *w) {
  struct wav r = {0};
  r.rate = 8000;
  r.channels = 1;
  r.frames = w->frames / 2;
  r.pcm = malloc(r.frames * 2);
  for (int64_t i = 0; i < r.frames; i++) r.pcm[i] = w->pcm[2 * i];
  return r;
}

static void test_args(kv_model *m, const struct wav *w) {
  char lang[8] = "zz";
  struct seen s;
  seen_init(&s);
  CHECK(kv_run(NULL, w->pcm, w->frames, w->rate, 1, NULL, 2, NULL, on_segment, &s, lang) == KV_ERR_ARGS);
  CHECK(lang[0] == 0);
  CHECK(kv_run(m, w->pcm, w->frames, w->rate, 1, NULL, 2, NULL, on_segment, &s, NULL) == KV_ERR_ARGS);
  CHECK(kv_run(m, w->pcm, w->frames, w->rate, 1, "xx-not", 2, NULL, on_segment, &s, lang) == KV_ERR_ARGS);
  CHECK(kv_run(m, NULL, w->frames, w->rate, 1, NULL, 2, NULL, on_segment, &s, lang) == KV_ERR_AUDIO);
  CHECK(kv_run(m, w->pcm, 0, w->rate, 1, NULL, 2, NULL, on_segment, &s, lang) == KV_ERR_AUDIO);
  CHECK(kv_run(m, w->pcm, w->frames, 4000, 1, NULL, 2, NULL, on_segment, &s, lang) == KV_ERR_AUDIO);
  CHECK(kv_run(m, w->pcm, w->frames, w->rate, 0, NULL, 2, NULL, on_segment, &s, lang) == KV_ERR_AUDIO);
  CHECK(kv_run(m, w->pcm, w->frames, w->rate, 9, NULL, 2, NULL, on_segment, &s, lang) == KV_ERR_AUDIO);
  // a header claiming hours is refused before anything is allocated
  CHECK(kv_run(m, w->pcm, (int64_t)16000 * 3600, 16000, 1, NULL, 2, NULL, on_segment, &s, lang) == KV_ERR_AUDIO);
  CHECK(s.count == 0);
}

static void test_open(const char *wav_path) {
  kv_model *m = (kv_model *)1;
  CHECK(kv_open(NULL, &m) == KV_ERR_ARGS);
  CHECK(m == NULL);
  CHECK(kv_open("", &m) == KV_ERR_ARGS);
  CHECK(kv_open("/nonexistent/model.bin", &m) == KV_ERR_MODEL);
  CHECK(m == NULL);
  // a file that is not a model
  CHECK(kv_open(wav_path, &m) == KV_ERR_MODEL);
  CHECK(m == NULL);
  CHECK(kv_open("x", NULL) == KV_ERR_ARGS);
  kv_close(NULL);
}

static void test_runs(kv_model *m, const struct wav *w) {
  char lang[8];
  struct seen s;

  // cancelled before it starts: nothing runs
  volatile int32_t stop = 1;
  seen_init(&s);
  CHECK(kv_run(m, w->pcm, w->frames, w->rate, w->channels, NULL, 2, &stop, on_segment, &s, lang) == KV_CANCELLED);
  CHECK(s.count == 0);

  // a whole run: segments in order with sane times
  stop = 0;
  seen_init(&s);
  int rc = kv_run(m, w->pcm, w->frames, w->rate, w->channels, "en", 2, &stop, on_segment, &s, lang);
  CHECK(rc == KV_OK);
  CHECK(s.ordered);
  CHECK(strcmp(lang, "en") == 0);
  printf("test model: %d segments\n", s.count);

  // the same model runs again after a run
  seen_init(&s);
  CHECK(kv_run(m, w->pcm, w->frames, w->rate, w->channels, "auto", 2, NULL, on_segment, &s, lang) == KV_OK);
  CHECK(strlen(lang) >= 2);

  // no callback at all is fine
  CHECK(kv_run(m, w->pcm, w->frames, w->rate, w->channels, "en", 1, NULL, NULL, NULL, lang) == KV_OK);

  // cancelled from another thread partway through a long note
  struct wav longer = repeat(w, 20);
  stop = 0;
  seen_init(&s);
  struct later l = {&stop, 200};
  pthread_t t;
  pthread_create(&t, NULL, cancel_later, &l);
  struct timespec a, b;
  clock_gettime(CLOCK_MONOTONIC, &a);
  rc = kv_run(m, longer.pcm, longer.frames, longer.rate, longer.channels, "en", 2, &stop, on_segment, &s, lang);
  clock_gettime(CLOCK_MONOTONIC, &b);
  pthread_join(t, NULL);
  double took = (b.tv_sec - a.tv_sec) + (b.tv_nsec - a.tv_nsec) / 1e9;
  printf("cancel: rc %d after %.2fs\n", rc, took);
  CHECK(rc == KV_CANCELLED);
  CHECK(lang[0] == 0);
  free(longer.pcm);
}

// the real model: words, the detected language, other rates, and no
// segment once cancel is set from inside one
static void test_words(const char *path, const struct wav *w) {
  kv_model *m = NULL;
  CHECK(kv_open(path, &m) == KV_OK);
  if (m == NULL) return;
  char lang[8];
  struct seen s;
  struct timespec a, b;

  seen_init(&s);
  clock_gettime(CLOCK_MONOTONIC, &a);
  CHECK(kv_run(m, w->pcm, w->frames, w->rate, w->channels, NULL, 4, NULL, on_segment, &s, lang) == KV_OK);
  clock_gettime(CLOCK_MONOTONIC, &b);
  printf("real model %.2fs for %.1fs of audio: [%s] %s\n",
         (b.tv_sec - a.tv_sec) + (b.tv_nsec - a.tv_nsec) / 1e9,
         (double)w->frames / w->rate, lang, s.text);
  CHECK(strcmp(lang, "en") == 0);
  CHECK(strstr(s.text, "fellow Americans") != NULL);
  CHECK(s.ordered && s.count >= 1);

  struct wav st = stereo48(w);
  seen_init(&s);
  CHECK(kv_run(m, st.pcm, st.frames, st.rate, st.channels, "en", 4, NULL, on_segment, &s, lang) == KV_OK);
  printf("48 khz stereo: %s\n", s.text);
  CHECK(strstr(s.text, "fellow Americans") != NULL);
  free(st.pcm);

  struct wav h = half(w);
  seen_init(&s);
  CHECK(kv_run(m, h.pcm, h.frames, h.rate, h.channels, "en", 4, NULL, on_segment, &s, lang) == KV_OK);
  printf("8 khz: %s\n", s.text);
  CHECK(strstr(s.text, "Americans") != NULL);
  free(h.pcm);

  // silence runs nothing and says the language asked for
  struct wav quiet = {calloc(16000 * 8, 2), 16000 * 8, 16000, 1};
  seen_init(&s);
  CHECK(kv_run(m, quiet.pcm, quiet.frames, quiet.rate, 1, "de", 4, NULL, on_segment, &s, lang) == KV_OK);
  CHECK(s.count == 0);
  CHECK(strcmp(lang, "de") == 0);
  free(quiet.pcm);

  // a long note comes in pieces: the first words within its first
  // seconds, the times in order across the whole note
  struct wav four = repeat(w, 4);
  seen_init(&s);
  CHECK(kv_run(m, four.pcm, four.frames, four.rate, four.channels, "en", 4, NULL, on_segment, &s, lang) == KV_OK);
  printf("44 s in %d segments, last ends %lld ms: %s\n", s.count, (long long)s.last_t1, s.text);
  CHECK(s.ordered && s.count >= 4);
  CHECK(s.last_t1 > 30000 && s.last_t1 <= 44100);
  free(four.pcm);

  struct wav longer = repeat(w, 4);
  volatile int32_t stop = 0;
  seen_init(&s);
  s.stop_after_first = &stop;
  CHECK(kv_run(m, longer.pcm, longer.frames, longer.rate, longer.channels, "en", 4, &stop, on_segment, &s, lang) == KV_CANCELLED);
  CHECK(s.count == 1);
  free(longer.pcm);
  kv_close(m);
}

int main(int argc, char **argv) {
  if (argc < 3) {
    fprintf(stderr, "usage: kv_test <test model> <wav> [real model]\n");
    return 2;
  }
  struct wav w = {0};
  if (read_wav(argv[2], &w) != 0) {
    fprintf(stderr, "cannot read %s\n", argv[2]);
    return 2;
  }
  CHECK(kv_abi() == KV_ABI);
  test_open(argv[2]);
  kv_model *m = NULL;
  CHECK(kv_open(argv[1], &m) == KV_OK);
  if (m != NULL) {
    test_args(m, &w);
    test_runs(m, &w);
    kv_close(m);
  }
  if (argc > 3) test_words(argv[3], &w);
  free(w.pcm);
  if (failed) {
    fprintf(stderr, "%d checks failed\n", failed);
    return 1;
  }
  printf("ok\n");
  return 0;
}
