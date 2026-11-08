// SPDX-License-Identifier: GPL-3.0-or-later
#include "kryfo_translate.h"

#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <string>
#include <vector>

#include "translator/parser.h"
#include "translator/response_options.h"
#include "translator/service.h"
#include "translator/translation_model.h"

using namespace marian::bergamot;

// marian opens a path ending in "|" as a shell command (popen), and has a
// helper that runs one. nothing here asks for either, and the library starts
// no process: the link sends both calls here (-Wl,--wrap), which refuse
extern "C" {
FILE *__wrap_popen(const char *, const char *) {
  errno = EPERM;
  return nullptr;
}
int __wrap_pclose(FILE *) {
  errno = ECHILD;
  return -1;
}
}

struct kt_model {
  std::unique_ptr<BlockingService> service;
  std::shared_ptr<TranslationModel> model;
};

static char *dup(const std::string &s) {
  char *p = static_cast<char *>(std::malloc(s.size() + 1));
  if (p) std::memcpy(p, s.c_str(), s.size() + 1);
  return p;
}

static void fail(char **err, const char *what) {
  if (err) *err = dup(what);
}

kt_model *kt_open(const char *config_yaml, char **err) {
  try {
    auto options = parseOptionsFromString(config_yaml, /*validate=*/false);
    auto m = std::make_unique<kt_model>();
    BlockingService::Config sc;
    sc.cacheSize = 0;
    m->service = std::make_unique<BlockingService>(sc);
    m->model = std::make_shared<TranslationModel>(options);
    return m.release();
  } catch (const std::exception &e) {
    fail(err, e.what());
  } catch (...) {
    fail(err, "unknown error");
  }
  return nullptr;
}

int kt_translate(kt_model *m, const char **texts, int n, char **out, char **err) {
  if (!m || n < 0) {
    fail(err, "bad arguments");
    return -1;
  }
  try {
    std::vector<std::string> in(texts, texts + n);
    std::vector<ResponseOptions> opts(n);
    auto res = m->service->translateMultiple(m->model, std::move(in), opts);
    for (int i = 0; i < n; i++) out[i] = dup(res[i].target.text);
    return 0;
  } catch (const std::exception &e) {
    fail(err, e.what());
  } catch (...) {
    fail(err, "unknown error");
  }
  return -1;
}

void kt_free(char *s) { std::free(s); }

void kt_close(kt_model *m) { delete m; }
