# SPDX-License-Identifier: GPL-3.0-or-later
# libkryfo_voice.so: kryfo_voice.c over whisper.cpp and ggml, linked in
# statically, with only the four kv_ calls exported. build.sh and
# build-host.sh drive it; WHISPER_SRC is the pinned source fetch-whisper.sh
# unpacked.
cmake_minimum_required(VERSION 3.22)
project(kryfo_voice C CXX)

set(WHISPER_SRC "" CACHE PATH "pinned whisper.cpp source")
if(NOT EXISTS "${WHISPER_SRC}/include/whisper.h")
  message(FATAL_ERROR "WHISPER_SRC has no whisper.cpp: run fetch-whisper.sh")
endif()

# whisper and ggml go into a shared library
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# cpu only, nothing fetched at configure time, no tools or tests of theirs
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(WHISPER_CURL OFF CACHE BOOL "" FORCE)
set(WHISPER_SDL2 OFF CACHE BOOL "" FORCE)
set(WHISPER_ALL_WARNINGS OFF CACHE BOOL "" FORCE)
set(GGML_ALL_WARNINGS OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)
set(GGML_CCACHE OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
set(GGML_BLAS OFF CACHE BOOL "" FORCE)
set(GGML_BACKEND_DL OFF CACHE BOOL "" FORCE)
set(GGML_CPU_KLEIDIAI OFF CACHE BOOL "" FORCE)
set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
set(GGML_OPENCL OFF CACHE BOOL "" FORCE)
set(GGML_METAL OFF CACHE BOOL "" FORCE)

add_subdirectory("${WHISPER_SRC}" whisper EXCLUDE_FROM_ALL)

add_library(kryfo_voice SHARED kryfo_voice.c)
target_link_libraries(kryfo_voice PRIVATE whisper)
set_target_properties(kryfo_voice PROPERTIES
  C_VISIBILITY_PRESET hidden
  C_STANDARD 11)
target_link_options(kryfo_voice PRIVATE
  "-Wl,--version-script=${CMAKE_CURRENT_SOURCE_DIR}/exports.map"
  -Wl,--build-id=none
  -Wl,--gc-sections
  -Wl,-z,noexecstack
  -Wl,-z,relro
  -Wl,-z,now)
if(ANDROID)
  # android 15 phones with 16 kb pages refuse a library aligned to 4 kb
  target_link_options(kryfo_voice PRIVATE -Wl,-z,max-page-size=16384)
endif()

option(KV_TESTS "build the c test against the host library" OFF)
if(KV_TESTS)
  add_executable(kv_test test/kv_test.c)
  target_link_libraries(kv_test PRIVATE kryfo_voice pthread)
endif()
