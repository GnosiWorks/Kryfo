cmake_minimum_required(VERSION 3.16)

project(flutter_zxing LANGUAGES C CXX)

# zxing-cpp needs real char8_t: its C++17 fallback typedefs it to unsigned
# char, and NDK r28's libc++ removed char_traits<unsigned char>. upstream
# zxing itself defaults to C++20 - the flutter wrapper just forgot to.
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(
    flutter_zxing
    SHARED
    zxcommon.cpp
    native_zxing.cpp
)

set (ZXING_WRITERS ON)

add_subdirectory(zxing/core EXCLUDE_FROM_ALL)

target_link_libraries(flutter_zxing ZXing)

# use log-lib only for android platform
if (ANDROID)
    find_library(log-lib log)
    target_link_libraries(flutter_zxing ${log-lib})
endif (ANDROID)

# Command to update zxing submodule
# cd src/zxing
# git checkout v2.2.0
# git submodule update --init --recursive