#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# puts the pinned bergamot sources (bergamot.lock) together in
# .third_party/ and prints the tree's path. each tarball is github's
# archive of its commit, checked against its sha256 before anything reads
# it. KT_TARBALLS=<dir> takes copies fetched beforehand, for a build with
# no network; KT_SRCLIB_<name>=<dir> (name with - as _) a clean git
# checkout of that commit, as an f-droid srclib is. both give the same files.
set -euo pipefail
cd "$(dirname "$0")"
HERE="$(pwd)"
LOCK="$HERE/bergamot.lock"

# the tree is named by the pins and by this script, whose edits it carries
key="$( { grep -v '^#' "$LOCK"; cat "$HERE/fetch-bergamot.sh"; } | sha256sum | cut -c1-16)"
DEST=".third_party/bergamot-$key"
if [[ -f "$DEST/.kt-pin" && "$(cat "$DEST/.kt-pin")" == "$key" ]]; then
  echo "$HERE/$DEST"
  exit 0
fi
rm -rf "$DEST" "$DEST.tmp"
mkdir -p "$DEST.tmp" .third_party/dl

# unpacks one pinned source into the tree at its path
put() {
  local name="$1" repo="$2" commit="$3" sum="$4" path="$5"
  local to="$DEST.tmp/tree/$path" var="KT_SRCLIB_${name//-/_}"
  mkdir -p "$to"
  if [[ -n "${!var:-}" ]]; then
    local dir="${!var}" head
    head="$(git -C "$dir" rev-parse HEAD)"
    [[ "$head" == "$commit" ]] || { echo "error: $dir is at $head, pinned $commit" >&2; exit 1; }
    [[ -z "$(git -C "$dir" status --porcelain --untracked-files=no)" ]] || { echo "error: $dir has changes" >&2; exit 1; }
    git -C "$dir" archive --format=tar "$commit" | tar -x -C "$to" --no-same-owner --no-same-permissions
    return
  fi
  local tar=".third_party/dl/$name-$commit.tar.gz"
  if [[ -n "${KT_TARBALLS:-}" ]]; then
    cp "$KT_TARBALLS/$name-$commit.tar.gz" "$tar"
  elif [[ ! -f "$tar" ]]; then
    command -v curl >/dev/null || { echo "error: curl not found" >&2; exit 1; }
    curl -fsSL --retry 2 -o "$tar.part" "https://github.com/$repo/archive/$commit.tar.gz" >&2
    mv "$tar.part" "$tar"
  fi
  local got
  got="$(sha256sum "$tar" | cut -d' ' -f1)"
  if [[ "$got" != "$sum" ]]; then
    rm -f "$tar"
    echo "error: $name tarball is $got, pinned $sum" >&2
    exit 1
  fi
  tar -xzf "$tar" -C "$to" --strip-components=1 --no-same-owner --no-same-permissions
}

while read -r name repo commit sum path; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  put "$name" "$repo" "$commit" "$sum" "$path"
done <"$LOCK"

T="$DEST.tmp/tree"
# only the c++ inference code is built; the rest of mozilla's repo (training
# pipeline, docs, wasm, emsdk) and the submodules' tests and tools never
# reach the build, and go so no scanner trips over their binaries
find "$T" -mindepth 1 -maxdepth 1 ! -name inference ! -name pcre2 -exec rm -rf {} +
rm -rf "$T/inference/wasm" "$T/inference/3rd_party/emsdk" "$T/inference/examples" \
  "$T/inference/marian-fork/src/3rd_party/sentencepiece/data" \
  "$T/inference/marian-fork/src/3rd_party/sentencepiece/python" \
  "$T/inference/marian-fork/src/3rd_party/ruy/third_party/cpuinfo/test" \
  "$T/inference/marian-fork/src/3rd_party/ruy/third_party/cpuinfo/bench" \
  "$T/pcre2/testdata" "$T/pcre2/doc"

# clang sizes two arrays with a non-const int, and marian builds with
# -Werror. making them const changes nothing else.
sed -i 's/^\(\s*\)unsigned int MAX_NUM_FRAMES = /\1const unsigned int MAX_NUM_FRAMES = /; s/^\(\s*\)unsigned int MAX_FUNCNAME_SIZE = /\1const unsigned int MAX_FUNCNAME_SIZE = /' \
  "$T/inference/marian-fork/src/3rd_party/ExceptionWithCallStack.cpp"

# simd_utils calls fesetround with fenv.h's names, which glibc's math.h
# brings along and android's does not
sed -i 's/^#include <math.h>\(\r\?\)$/#include <fenv.h>\1\n#include <math.h>\1/' \
  "$T/inference/marian-fork/src/3rd_party/simd_utils/simd_utils.h"
grep -q '^#include <fenv.h>' "$T/inference/marian-fork/src/3rd_party/simd_utils/simd_utils.h" ||
  { echo "error: fenv.h not added to simd_utils.h" >&2; exit 1; }

# two lines of simd_utils' sse2neon that only 32-bit arm compiles, wrong
# there: a store cast to a 64-bit-only vector type, and a call with two
# int64 where the function takes __m64. arm64 and x86 never reach them
SN="$T/inference/marian-fork/src/3rd_party/simd_utils"
sed -i 's/__builtin_nontemporal_store(a, (float64x2_t \*) p);/__builtin_nontemporal_store(a, (__m128d *) p);/' "$SN/sse2neon.h"
sed -i 's/    return _mm_set_epi64(a1, a0);/    return _mm_set_epi64x(a1, a0);/' "$SN/sse2neon_wrapper.h"
grep -q '(__m128d \*) p);' "$SN/sse2neon.h" && grep -q '_mm_set_epi64x(a1, a0)' "$SN/sse2neon_wrapper.h" ||
  { echo "error: the 32-bit arm lines of sse2neon were not changed" >&2; exit 1; }

# faiss uses __m128 under __SSE__ and counts on glibc's headers to have
# brought it in; on android x86_64 it says so itself
FV="$T/inference/marian-fork/src/3rd_party/faiss/VectorTransform.cpp"
sed -i 's/^#include <cstring>$/#include <cstring>\n#ifdef __SSE__\n#include <immintrin.h>\n#endif/' "$FV"
grep -q '^#include <immintrin.h>$' "$FV" || { echo "error: faiss has no immintrin.h" >&2; exit 1; }

# marian stamps its git revision in at build time with git log, into its
# source tree. there is no git here, and the revision is the pin's: written
# once, and the step that would run git taken out
M="$T/inference/marian-fork/src"
sed -i '/^set(MARIAN_GIT_DIR /,/^add_custom_target(marian_version /d; /^add_dependencies(marian marian_version)/d' "$M/CMakeLists.txt"
grep -q 'marian_version\|git log' "$M/CMakeLists.txt" && { echo "error: marian's revision step is still there" >&2; exit 1; }
tr_commit="$(awk '$1 == "translations" {print substr($3, 1, 7)}' "$LOCK")"
printf '#define GIT_REVISION "%s"\n' "$tr_commit" >"$M/common/git_revision.h"

mv "$T" "$DEST"
rm -rf "$DEST.tmp"
echo "$key" >"$DEST/.kt-pin"
echo "$HERE/$DEST"
