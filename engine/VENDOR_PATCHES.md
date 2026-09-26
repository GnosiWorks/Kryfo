# hand patches in engine/vendor

three files under `vendor/github.com/alexballas/go-libtor/` differ from
upstream. `go mod vendor` silently drops them, and the 32-bit engine then
builds fine but never connects. don't run it. if the vendor tree has to be
rebuilt, re-apply these and build with `HALO_FULL=1 ./build.sh`, go's build
cache doesn't track these headers.

## openssl: bignum word size

`openssl_config/openssl/configuration.h` and
`linux/openssl/include/openssl/configuration.h`.

upstream hard-codes `SIXTY_FOUR_BIT_LONG`. on armeabi-v7a `unsigned long` is
four bytes, so every bignum operation is wrong. the patch defines
`THIRTY_TWO_BIT` when `ARCH_ANDROID32`, `ARCH_LINUX32` or `ARCH_WINDOWS32` is
set (go-libtor sets these in `libtor/libtor_preamble.go`), like go-libtor's own
`openssl_config/crypto/bn_conf.h`.

## libevent: generated config

`linux/libevent/include/event2/event-config.h` was generated on a 64-bit box
(eight-byte `long`, `size_t`, `time_t`, `pthread_t` and pointers), and it wins
over go-libtor's per-target configs, which are not on the include path.

the generated file is kept as `event-config.64.h`, `event-config.32.h` has the
five sizes set to 4 and `_FILE_OFFSET_BITS 64`, and `event-config.h` switches
on the same `ARCH_*32` defines. the 64-bit build is unchanged.

## check

    cd engine
    HALO_FULL=1 ./build.sh

on a 32-bit phone, settings > transport: tor leaves "starting" and reaches
100%.

reported upstream to alexballas/go-libtor.
