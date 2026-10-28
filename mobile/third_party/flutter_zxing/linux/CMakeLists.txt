# the desktop build of the same native code android uses, from ../src
cmake_minimum_required(VERSION 3.16)
project(flutter_zxing_linux LANGUAGES C CXX)

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")

set(flutter_zxing_bundled_libraries
  $<TARGET_FILE:flutter_zxing>
  PARENT_SCOPE
)
