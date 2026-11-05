# SPDX-License-Identifier: GPL-3.0-or-later
# libkryfo_translate.so: kryfo_translate.cpp over bergamot, marian and their
# libraries, linked in statically, with only the four kt_ calls exported.
# build.sh drives it; BERGAMOT_SRC is the pinned tree fetch-bergamot.sh put
# together.
cmake_minimum_required(VERSION 3.22)
project(kryfo_translate C CXX)

set(BERGAMOT_SRC "" CACHE PATH "pinned bergamot tree")
if(NOT EXISTS "${BERGAMOT_SRC}/inference/src/translator/service.h")
  message(FATAL_ERROR "BERGAMOT_SRC has no bergamot: run fetch-bergamot.sh")
endif()

set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

# marian replaces CMAKE_CXX_FLAGS in its own folder, so the flags every
# object must carry (path maps, hardening) go in as compile options
separate_arguments(KT_FLAGS UNIX_COMMAND "${KT_FLAGS}")
add_compile_options(${KT_FLAGS})

# pcre2 for ssplit: 8 bit, unicode, no jit (no executable memory), none of
# its tools or tests
set(PCRE2_BUILD_PCRE2_8 ON CACHE BOOL "" FORCE)
set(PCRE2_BUILD_PCRE2_16 OFF CACHE BOOL "" FORCE)
set(PCRE2_BUILD_PCRE2_32 OFF CACHE BOOL "" FORCE)
set(PCRE2_SUPPORT_JIT OFF CACHE BOOL "" FORCE)
set(PCRE2_SUPPORT_UNICODE ON CACHE BOOL "" FORCE)
set(PCRE2_BUILD_PCRE2GREP OFF CACHE BOOL "" FORCE)
set(PCRE2_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(PCRE2_SHOW_REPORT OFF CACHE BOOL "" FORCE)
set(PCRE2_STATIC_PIC ON CACHE BOOL "" FORCE)
set(BUILD_STATIC_LIBS ON CACHE BOOL "" FORCE)
add_subdirectory("${BERGAMOT_SRC}/pcre2" pcre2 EXCLUDE_FROM_ALL)
# ssplit's FindPCRE2 keeps these instead of searching the system
set(PCRE2_LIBRARIES pcre2-8-static CACHE STRING "" FORCE)
set(PCRE2_INCLUDE_DIRS "${CMAKE_CURRENT_BINARY_DIR}/pcre2" CACHE PATH "" FORCE)

# cpu inference only: nothing fetched, no git, no cuda, blas, mkl, tools,
# tests or docs
set(GIT_SUBMODULE OFF CACHE BOOL "" FORCE)
set(COMPILE_WASM OFF CACHE BOOL "" FORCE)
set(USE_WASM_COMPATIBLE_SOURCE OFF CACHE BOOL "" FORCE)
set(COMPILE_TESTS OFF CACHE BOOL "" FORCE)
set(COMPILE_UNIT_TESTS OFF CACHE BOOL "" FORCE)
set(COMPILE_CUDA OFF CACHE BOOL "" FORCE)
set(COMPILE_SERVER OFF CACHE BOOL "" FORCE)
set(COMPILE_EXAMPLES OFF CACHE BOOL "" FORCE)
set(COMPILE_LIBRARY_ONLY ON CACHE BOOL "" FORCE)
set(USE_NCCL OFF CACHE BOOL "" FORCE)
set(USE_FBGEMM OFF CACHE BOOL "" FORCE)
set(USE_MKL OFF CACHE BOOL "" FORCE)
set(USE_MPI OFF CACHE BOOL "" FORCE)
set(USE_DOXYGEN OFF CACHE BOOL "" FORCE)
set(USE_CCACHE OFF CACHE BOOL "" FORCE)
set(USE_SENTENCEPIECE ON CACHE BOOL "" FORCE)
set(USE_STATIC_LIBS ON CACHE BOOL "" FORCE)
set(SPM_ENABLE_SHARED OFF CACHE BOOL "" FORCE)
set(SPM_ENABLE_TCMALLOC OFF CACHE BOOL "" FORCE)
set(SSPLIT_COMPILE_LIBRARY_ONLY ON CACHE BOOL "" FORCE)
set(SSPLIT_USE_INTERNAL_PCRE2 OFF CACHE BOOL "" FORCE)
# the float gemm is ruy's on every abi (arm: marian picks it; x86_64: no
# blas on a phone), the int8 one ruy on arm and intgemm on x86_64
set(USE_RUY ON CACHE BOOL "" FORCE)
set(USE_RUY_SGEMM ON CACHE BOOL "" FORCE)
# marian sets these for its own folder only, but bergamot's sources and ours
# include its headers too: without them simd_utils takes its x86 path on arm
if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm)")
  add_compile_definitions(ARM FMA SSE)
  add_compile_options(-flax-vector-conversions)
endif()
if(ANDROID_ABI STREQUAL "armeabi-v7a")
  # SHELL: keeps cmake from folding two -include flags into one
  add_compile_options("SHELL:-include ${CMAKE_CURRENT_SOURCE_DIR}/armv7_compat.h")
endif()
add_subdirectory("${BERGAMOT_SRC}/inference" bergamot EXCLUDE_FROM_ALL)

if(ANDROID)
  target_compile_definitions(pathie-cpp PRIVATE PATHIE_ASSUME_UTF8_ON_UNIX)
  target_compile_options(pathie-cpp PRIVATE
    "SHELL:-include ${CMAKE_CURRENT_SOURCE_DIR}/android_compat.h")
endif()

add_library(kryfo_translate SHARED kryfo_translate.cpp)
target_include_directories(kryfo_translate PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(kryfo_translate PRIVATE bergamot-translator-source)
set_target_properties(kryfo_translate PROPERTIES
  CXX_VISIBILITY_PRESET hidden
  VISIBILITY_INLINES_HIDDEN ON)
target_link_options(kryfo_translate PRIVATE
  "-Wl,--version-script=${CMAKE_CURRENT_SOURCE_DIR}/exports.map"
  -static-libstdc++
  -Wl,--build-id=none
  -Wl,--gc-sections
  -Wl,--exclude-libs,ALL
  # sentencepiece asks for libandroid and liblog and uses neither
  -Wl,--as-needed
  # marian's popen calls land on kryfo_translate.cpp's refusals
  -Wl,--wrap=popen
  -Wl,--wrap=pclose
  -Wl,-z,noexecstack
  -Wl,-z,relro
  -Wl,-z,now)
if(ANDROID)
  # android 15 phones with 16 kb pages refuse a library aligned to 4 kb
  target_link_options(kryfo_translate PRIVATE -Wl,-z,max-page-size=16384)
endif()

# a bench for a phone's shell (build.sh with KT_BENCH=1), never in the app
option(KT_BENCH "build kt_bench against the library" OFF)
if(KT_BENCH)
  add_executable(kt_bench kt_bench.c)
  target_link_libraries(kt_bench PRIVATE kryfo_translate)
endif()
