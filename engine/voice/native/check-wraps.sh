#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# check-wraps.sh <llvm-nm or nm> <dir with the built archives>: the link
# answers fork, execlp and prctl with an error for the whole library
# (kv_no_spawn in CMakeLists.txt), which is meant for ggml's backtrace in
# ggml.c alone. another caller, such as the SVE length lookup in
# ggml-feats.h that a cpu variant or kleidiai build pulls in, would run on
# the error and give wrong results, so the build fails instead.
set -euo pipefail
nm="$1"
dir="$2"
mapfile -t libs < <(find "$dir" -name '*.a' | sort)
if [[ ${#libs[@]} -eq 0 ]]; then echo "error: no archives under $dir" >&2; exit 1; fi
bad="$("$nm" -A --undefined-only "${libs[@]}" |
  awk '$NF ~ /^(fork|execlp|prctl)$/ && $1 !~ /:ggml\.c\.o:$/ {print $1 " " $NF}')"
if [[ -n "$bad" ]]; then
  echo "error: wrapped calls reached from outside ggml.c, the wrap would answer them with -1:" >&2
  echo "$bad" >&2
  exit 1
fi
