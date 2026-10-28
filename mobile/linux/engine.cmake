# the go engine (engine/build-linux.sh) and the libsignal shim
# (native/kryfo_signal/build-host.sh). the dart side finds the engine with
# DynamicLibrary.process() off android and opens the shim by name, so the
# runner links both as needed libraries and the bundle carries them in lib/.
set(HALO_ENGINE_ARCH "x64")
if(FLUTTER_TARGET_PLATFORM STREQUAL "linux-arm64")
  set(HALO_ENGINE_ARCH "arm64")
endif()
set(HALO_ENGINE_LIB
  "${CMAKE_CURRENT_SOURCE_DIR}/../../engine/out/linux-${HALO_ENGINE_ARCH}/libhalo.so"
  CACHE FILEPATH "libhalo.so for the linux app")
set(HALO_SIGNAL_LIB
  "${CMAKE_CURRENT_SOURCE_DIR}/../native/kryfo_signal/target/release/libkryfo_signal.so"
  CACHE FILEPATH "libkryfo_signal.so for the linux app")

foreach(lib HALO_ENGINE_LIB HALO_SIGNAL_LIB)
  set(path "${${lib}}")
  if(EXISTS "${path}")
    get_filename_component(dir "${path}" DIRECTORY)
    get_filename_component(name "${path}" NAME)
    # nothing in the runner calls into them, so as-needed would drop them.
    # -l: keeps the bare file name in NEEDED, the shim has no soname
    target_link_libraries(${BINARY_NAME} PRIVATE
      "-L${dir}" -Wl,--no-as-needed "-l:${name}" -Wl,--as-needed)
    install(FILES "${path}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
      COMPONENT Runtime)
  else()
    message(WARNING "no ${path}: the app builds but stops at start without it")
  endif()
endforeach()

# the sqlcipher the database opens with (build-sqlcipher.sh). the dart side
# opens it from lib/ by name and refuses any sqlite without the cipher
set(HALO_SQLCIPHER_LIB
  "${CMAKE_CURRENT_SOURCE_DIR}/out/libsqlcipher.so.0"
  CACHE FILEPATH "libsqlcipher.so.0 for the linux app")
if(EXISTS "${HALO_SQLCIPHER_LIB}")
  install(FILES "${HALO_SQLCIPHER_LIB}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
else()
  message(WARNING "no ${HALO_SQLCIPHER_LIB}: the app cannot open its database")
endif()

# the window's and the tray's icon
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/../assets/icon/halo_icon.png"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" RENAME "kryfo.png"
  COMPONENT Runtime)
