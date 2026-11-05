// SPDX-License-Identifier: GPL-3.0-or-later
// marian's path library, pathie, calls iconv and glob, which bionic has only
// from android 9 on. this is put in front of pathie's own files alone. file
// names on android are utf-8 (PATHIE_ASSUME_UTF8_ON_UNIX), so its iconv path
// never runs, and marian never globs: both refuse here instead of linking
// against calls an android 7 phone lacks.
#ifndef KRYFO_ANDROID_COMPAT_H
#define KRYFO_ANDROID_COMPAT_H
#if defined(__ANDROID__) && __ANDROID_API__ < 28
#include <errno.h>
#include <glob.h>
#include <iconv.h>
#include <stddef.h>

static inline iconv_t iconv_open(const char *to, const char *from) {
  (void)to;
  (void)from;
  errno = EINVAL;
  return (iconv_t)-1;
}
static inline size_t iconv(iconv_t c, char **in, size_t *inn, char **out, size_t *outn) {
  (void)c, (void)in, (void)inn, (void)out, (void)outn;
  errno = EBADF;
  return (size_t)-1;
}
static inline int iconv_close(iconv_t c) {
  (void)c;
  return 0;
}
static inline int glob(const char *p, int f, int (*e)(const char *, int), glob_t *g) {
  (void)p, (void)f, (void)e;
  g->gl_pathc = 0;
  g->gl_pathv = NULL;
  return GLOB_NOMATCH;
}
static inline void globfree(glob_t *g) { (void)g; }
#endif
#endif
