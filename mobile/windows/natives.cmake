# the natives the windows app ships next to kryfo.exe, built on linux:
# engine/build-windows.sh, native/kryfo_signal/build-windows.sh,
# windows/build-sqlcipher.sh, and tor from packaging/windows/stage-tor.sh.
# the runner loads the three dlls by full path before flutter starts
set(KRYFO_HALO_DLL "${CMAKE_CURRENT_SOURCE_DIR}/../../engine/out/windows-x64/halo.dll"
  CACHE FILEPATH "halo.dll")
set(KRYFO_SIGNAL_DLL
  "${CMAKE_CURRENT_SOURCE_DIR}/../native/kryfo_signal/target/x86_64-pc-windows-gnu/release/kryfo_signal.dll"
  CACHE FILEPATH "kryfo_signal.dll")
set(KRYFO_SQLCIPHER_DLL "${CMAKE_CURRENT_SOURCE_DIR}/out/sqlcipher.dll"
  CACHE FILEPATH "sqlcipher.dll")
set(KRYFO_TOR_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../packaging/build/windows/tor"
  CACHE PATH "the staged tor folder")

foreach(dll KRYFO_HALO_DLL KRYFO_SIGNAL_DLL KRYFO_SQLCIPHER_DLL)
  if(EXISTS "${${dll}}")
    install(FILES "${${dll}}" DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)
  else()
    # a build without one starts only to say which is missing
    message(FATAL_ERROR "no ${${dll}}: build it in wsl and copy it here")
  endif()
endforeach()
foreach(f tor.exe openssl.cnf)
  if(NOT EXISTS "${KRYFO_TOR_DIR}/${f}")
    message(FATAL_ERROR "no ${KRYFO_TOR_DIR}/${f}: run packaging/windows/stage-tor.sh")
  endif()
endforeach()
install(DIRECTORY "${KRYFO_TOR_DIR}/" DESTINATION "${CMAKE_INSTALL_PREFIX}/tor"
  COMPONENT Runtime)
