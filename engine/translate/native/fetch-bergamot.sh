#!/bin/bash
# fetches the inference engine firefox uses (bergamot, in mozilla/translations
# under inference/) and builds it for this machine, outside the repo. a
# prototype for measuring speed, not part of the app build.
#
#   ./fetch-bergamot.sh <workdir>
#
# the workdir must be outside the repo: sources, build and models are
# hundreds of megabytes and none of it is ever committed.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${1:?usage: $0 <workdir outside the repo>}"
mkdir -p "$WORK"
WORK="$(cd "$WORK" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
case "$WORK/" in
  "$REPO"/*) echo "error: $WORK is inside the repo"; exit 1 ;;
esac

# a branch or tag of mozilla/translations; set it to repeat a measurement
REV="${BERGAMOT_REV:-main}"
SRC="$WORK/translations"
if [ ! -d "$SRC/.git" ]; then
  git clone --filter=blob:none --no-checkout --depth 1 --branch "$REV" \
    https://github.com/mozilla/translations "$SRC"
  git -C "$SRC" sparse-checkout set --cone inference
  git -C "$SRC" checkout
fi
git -C "$SRC" log -1 --format='engine at %H %cs'
# only what a cpu build needs: the cmake files would otherwise pull every
# submodule in the repo, the training tools and emsdk included
M=inference/marian-fork/src/3rd_party
git -C "$SRC" submodule update --init --depth 1 -- \
  inference/3rd_party/ssplit-cpp "$M/sentencepiece" "$M/intgemm" "$M/simd_utils"
git -C "$SRC" submodule update --init --recursive --depth 1 -- "$M/ruy"

# our c api and the bench, built in the same tree so they link the same
# objects. added to the scratch clone, never to anything committed.
HOOK="$SRC/inference/src/CMakeLists.txt"
if ! grep -q kryfo_translate "$HOOK"; then
  cat >> "$HOOK" <<'EOF'

add_library(kryfo_translate STATIC ${KRYFO_NATIVE}/kryfo_translate.cpp)
target_include_directories(kryfo_translate PUBLIC ${KRYFO_NATIVE})
target_link_libraries(kryfo_translate PUBLIC bergamot-translator-source)
add_executable(kt_bench ${KRYFO_NATIVE}/kt_bench.c)
target_link_libraries(kt_bench PRIVATE kryfo_translate)
EOF
fi

# clang 18 warns on two arrays sized by a non-const int, and marian builds
# with -Werror. making them const changes nothing else.
sed -i 's/^\(\s*\)unsigned int MAX_NUM_FRAMES = /\1const unsigned int MAX_NUM_FRAMES = /; s/^\(\s*\)unsigned int MAX_FUNCNAME_SIZE = /\1const unsigned int MAX_FUNCNAME_SIZE = /' \
  "$SRC/$M/ExceptionWithCallStack.cpp"

# ruy builds only for arm; x86 takes its float gemm from openblas
# (libopenblas-dev)
case "$(uname -m)" in
  aarch64|arm64) RUY=ON ;;
  *) RUY=OFF ;;
esac

# native x86-64 or arm64. the int8 gemm is intgemm on x86 and ruy on arm
B="$WORK/build"
cmake -S "$SRC/inference" -B "$B" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="${CC:-clang}" -DCMAKE_CXX_COMPILER="${CXX:-clang++}" \
  -DGIT_SUBMODULE=OFF \
  -DCOMPILE_WASM=OFF -DUSE_WASM_COMPATIBLE_SOURCE=OFF \
  -DCOMPILE_TESTS=OFF -DCOMPILE_UNIT_TESTS=OFF \
  -DCOMPILE_CUDA=OFF -DUSE_NCCL=OFF -DUSE_FBGEMM=OFF -DUSE_DOXYGEN=OFF \
  -DUSE_MKL=OFF -DUSE_RUY_SGEMM=$RUY \
  -DKRYFO_NATIVE="$HERE" \
  ${BERGAMOT_CMAKE_EXTRA:-}
cmake --build "$B" -j "${JOBS:-3}"
echo "built in $B"
