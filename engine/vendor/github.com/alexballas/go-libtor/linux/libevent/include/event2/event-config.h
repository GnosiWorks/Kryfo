/* event2/event-config.h
 *
 * kryfo: the header autoconf generated here was made on a 64-bit box and
 * shipped for every target. a 32-bit phone (armeabi-v7a) then built
 * libevent with eight-byte long, size_t, time_t and pointers: tor's event
 * loop never answered its control port and the app sat at "connecting"
 * for good. the 64-bit targets keep the generated file byte for byte;
 * the 32-bit ones get the same file with the five sizes corrected and
 * large file offsets on, the way go-libtor's own android32 config has
 * them. go-libtor sets ARCH_* per target in libtor_preamble.go.
 */
#if defined(ARCH_ANDROID32) || defined(ARCH_LINUX32) || defined(ARCH_WINDOWS32)
#include "event2/event-config.32.h"
#else
#include "event2/event-config.64.h"
#endif
