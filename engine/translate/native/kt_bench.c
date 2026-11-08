// SPDX-License-Identifier: GPL-3.0-or-later
// times kt_translate on a file of lines, one line per call (a chat) and all
// lines in one call (a backlog). counts words on the english side, so zh to
// en counts output words and en to zh input words. cpu time is the calling
// thread's own, which a busy machine disturbs less than wall time.
//
//   kt_bench <config.yml> <lines.txt> [max lines]
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "kryfo_translate.h"

static double now(clockid_t c) {
  struct timespec t;
  clock_gettime(c, &t);
  return t.tv_sec + t.tv_nsec / 1e9;
}

static long words(const char *s) {
  long n = 0;
  int in = 0;
  for (; *s; s++) {
    int sp = *s == ' ' || *s == '\n' || *s == '\t';
    if (!sp && !in) n++;
    in = !sp;
  }
  return n;
}

static int ascii(const char *s) {
  for (; *s; s++)
    if ((unsigned char)*s >= 0x80) return 0;
  return 1;
}

static char *slurp(const char *p) {
  FILE *f = fopen(p, "rb");
  if (!f) return NULL;
  fseek(f, 0, SEEK_END);
  long n = ftell(f);
  fseek(f, 0, SEEK_SET);
  char *b = malloc(n + 1);
  if (fread(b, 1, n, f) != (size_t)n) n = 0;
  b[n] = 0;
  fclose(f);
  return b;
}

int main(int argc, char **argv) {
  if (argc < 3) {
    fprintf(stderr, "usage: %s <config.yml> <lines.txt> [max lines]\n", argv[0]);
    return 2;
  }
  int max = argc > 3 ? atoi(argv[3]) : 1 << 30;
  char *cfg = slurp(argv[1]), *txt = slurp(argv[2]);
  if (!cfg || !txt) {
    fprintf(stderr, "cannot read input\n");
    return 1;
  }
  const char **lines = malloc(sizeof(char *) * (strlen(txt) + 1));
  int n = 0;
  for (char *s = strtok(txt, "\n"); s && n < max; s = strtok(NULL, "\n")) lines[n++] = s;

  char *err = NULL;
  double w0 = now(CLOCK_MONOTONIC), c0 = now(CLOCK_THREAD_CPUTIME_ID);
  kt_model *m = kt_open(cfg, &err);
  if (!m) {
    fprintf(stderr, "open: %s\n", err);
    return 1;
  }
  printf("load: %.2fs wall %.2fs cpu\n", now(CLOCK_MONOTONIC) - w0, now(CLOCK_THREAD_CPUTIME_ID) - c0);

  char **out = calloc(n, sizeof(char *));
  // warm up on the first line, as the first message after opening would:
  // what a person waits for on their first tap, after the load
  w0 = now(CLOCK_MONOTONIC), c0 = now(CLOCK_THREAD_CPUTIME_ID);
  kt_translate(m, lines, 1, out, &err);
  printf("first line: %.2fs wall %.2fs cpu\n", now(CLOCK_MONOTONIC) - w0, now(CLOCK_THREAD_CPUTIME_ID) - c0);
  kt_free(out[0]);

  long inw = 0, outw = 0, inb = 0;
  w0 = now(CLOCK_MONOTONIC), c0 = now(CLOCK_THREAD_CPUTIME_ID);
  for (int i = 0; i < n; i++) {
    if (kt_translate(m, lines + i, 1, out + i, &err) != 0) {
      fprintf(stderr, "translate: %s\n", err);
      return 1;
    }
  }
  double w1 = now(CLOCK_MONOTONIC) - w0, c1 = now(CLOCK_THREAD_CPUTIME_ID) - c0;
  for (int i = 0; i < n; i++) {
    inw += words(lines[i]);
    outw += words(out[i]);
    inb += strlen(lines[i]);
  }
  int srcEn = ascii(lines[0]);
  long ew = srcEn ? inw : outw;
  for (int i = 0; i < n && i < 8; i++) printf("  %s\n  -> %s\n", lines[i], out[i]);
  printf("lines %d, english words %ld (%s side), source bytes %ld\n", n, ew, srcEn ? "source" : "target", inb);
  printf("one per call: %.2fs wall %.2fs cpu, %.0f words/s cpu, %.0f words/s wall, %.1f ms/line cpu\n", w1, c1,
         ew / c1, ew / w1, 1000 * c1 / n);
  for (int i = 0; i < n; i++) kt_free(out[i]);

  w0 = now(CLOCK_MONOTONIC), c0 = now(CLOCK_THREAD_CPUTIME_ID);
  if (kt_translate(m, lines, n, out, &err) != 0) {
    fprintf(stderr, "translate: %s\n", err);
    return 1;
  }
  w1 = now(CLOCK_MONOTONIC) - w0, c1 = now(CLOCK_THREAD_CPUTIME_ID) - c0;
  printf("one batch:    %.2fs wall %.2fs cpu, %.0f words/s cpu, %.0f words/s wall\n", w1, c1, ew / c1, ew / w1);
  for (int i = 0; i < n; i++) kt_free(out[i]);
  kt_close(m);
  return 0;
}
