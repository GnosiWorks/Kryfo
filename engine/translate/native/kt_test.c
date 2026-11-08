// SPDX-License-Identifier: GPL-3.0-or-later
// two languages open at once, as the app keeps them: each must translate
// while the other is open, after the other closes, and when opened again.
// for a phone's shell next to kt_bench (build.sh with KT_BENCH=1). exits 0
// when every step translated, 1 otherwise.
//
//   kt_test <a.yml> <a.txt> <b.yml> <b.txt>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "kryfo_translate.h"

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

// a text file's first line
static char *line(const char *p) {
  char *b = slurp(p);
  if (b) b[strcspn(b, "\n")] = 0;
  return b;
}

static int failed = 0;

static kt_model *open_one(const char *step, const char *cfg) {
  char *err = NULL;
  kt_model *m = kt_open(cfg, &err);
  if (!m) {
    printf("FAIL %s: open: %s\n", step, err ? err : "?");
    kt_free(err);
    failed = 1;
  }
  return m;
}

static void say(const char *step, kt_model *m, const char *text) {
  if (!m) return;
  char *out = NULL, *err = NULL;
  if (kt_translate(m, &text, 1, &out, &err) != 0) {
    printf("FAIL %s: %s\n", step, err ? err : "?");
    kt_free(err);
    failed = 1;
    return;
  }
  if (!out[0]) {
    printf("FAIL %s: empty\n", step);
    failed = 1;
  } else {
    printf("ok   %s: %s\n", step, out);
  }
  kt_free(out);
}

int main(int argc, char **argv) {
  if (argc < 5) {
    fprintf(stderr, "usage: %s <a.yml> <a.txt> <b.yml> <b.txt>\n", argv[0]);
    return 2;
  }
  char *cfg[2] = {slurp(argv[1]), slurp(argv[3])};
  char *ta = line(argv[2]), *tb = line(argv[4]);
  if (!cfg[0] || !cfg[1] || !ta || !tb) {
    fprintf(stderr, "cannot read input\n");
    return 2;
  }

  kt_model *a = open_one("a open", cfg[0]);
  say("a alone", a, ta);
  kt_model *b = open_one("b open beside a", cfg[1]);
  say("b beside a", b, tb);
  say("a beside b", a, ta);
  kt_close(a);
  say("b after a closed", b, tb);
  a = open_one("a open again", cfg[0]);
  say("a again", a, ta);
  kt_close(a);
  kt_close(b);
  // all closed: the next open starts afresh
  b = open_one("b open after all closed", cfg[1]);
  say("b afresh", b, tb);
  kt_close(b);

  printf(failed ? "FAILED\n" : "PASS\n");
  return failed;
}
