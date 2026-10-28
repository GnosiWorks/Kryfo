// SPDX-License-Identifier: GPL-3.0-or-later
// ggml's abort paths, linked as the library links them: an assert must
// end in abort() with no process spawned. a gdb and lldb stand-in on PATH
// leaves a mark if anything runs one.
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#include "../kryfo_voice.h"
#include "ggml.h"

// in ggml-impl.h, which pulls in far more than this needs
void ggml_print_backtrace(void);
// the test forks its own children past the wrap
pid_t __real_fork(void);

static int failed;

#define CHECK(c)                                                   \
  do {                                                             \
    if (!(c)) {                                                    \
      fprintf(stderr, "%s:%d: check failed: %s\n", __FILE__, __LINE__, #c); \
      failed++;                                                    \
    }                                                              \
  } while (0)

static char mark[512];

static int marked(void) { return access(mark, F_OK) == 0; }

static void stand_in(const char *dir, const char *name) {
  char path[512];
  snprintf(path, sizeof(path), "%s/%s", dir, name);
  FILE *f = fopen(path, "w");
  if (f == NULL) {
    perror(path);
    exit(2);
  }
  fputs("#!/bin/sh\n: > \"$KV_MARK\"\n", f);
  fclose(f);
  chmod(path, 0755);
}

// runs fn in a child and returns its wait status
static int in_child(void (*fn)(void)) {
  pid_t pid = __real_fork();
  if (pid < 0) {
    perror("fork");
    exit(2);
  }
  if (pid == 0) {
    fn();
    _exit(7);
  }
  int status = 0;
  waitpid(pid, &status, 0);
  return status;
}

static void assert_fails(void) { ggml_abort(__FILE__, __LINE__, "a failed assert"); }

static void terminate_path(void) { ggml_print_backtrace(); }

int main(void) {
  char dir[] = "/tmp/kv_abort_XXXXXX";
  if (mkdtemp(dir) == NULL) {
    perror("mkdtemp");
    return 2;
  }
  stand_in(dir, "gdb");
  stand_in(dir, "lldb");
  snprintf(mark, sizeof(mark), "%s/ran", dir);
  setenv("KV_MARK", mark, 1);
  setenv("PATH", dir, 1);
  unsetenv("GGML_NO_BACKTRACE");

  // kv_open sets the abort callback even when the model is missing
  kv_model *m = NULL;
  CHECK(kv_open("/nonexistent/model.bin", &m) == KV_ERR_MODEL);

  int st = in_child(assert_fails);
  CHECK(WIFSIGNALED(st) && WTERMSIG(st) == SIGABRT);
  CHECK(!marked());

  // the uncaught exception handler calls the backtrace directly
  st = in_child(terminate_path);
  CHECK(WIFEXITED(st) && WEXITSTATUS(st) == 7);
  CHECK(!marked());

  unlink(mark);
  char path[512];
  snprintf(path, sizeof(path), "%s/gdb", dir);
  unlink(path);
  snprintf(path, sizeof(path), "%s/lldb", dir);
  unlink(path);
  rmdir(dir);

  if (failed) {
    fprintf(stderr, "kv_abort_test: %d failed\n", failed);
    return 1;
  }
  printf("kv_abort_test: no process spawned on an abort\n");
  return 0;
}
