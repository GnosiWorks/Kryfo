// SPDX-License-Identifier: GPL-3.0-or-later
// a small c api over bergamot for the app to call through dart:ffi. one
// model per direction, translation on the calling thread, which the app
// keeps off the ui isolate. strings are utf-8 and every string returned is
// freed with kt_free.
#ifndef KRYFO_TRANSLATE_H
#define KRYFO_TRANSLATE_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct kt_model kt_model;

// loads a model from a bergamot yaml config (translate.Pair.Config in the
// engine writes it). null on failure, with *err set to a message.
kt_model *kt_open(const char *config_yaml, char **err);

// translates n texts in one batch and sets out[i] for each. returns 0, or
// -1 with *err set and nothing in out.
int kt_translate(kt_model *m, const char **texts, int n, char **out, char **err);

void kt_free(char *s);
void kt_close(kt_model *m);

#ifdef __cplusplus
}
#endif

#endif
