#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# runs the shim's rust tests for arm64 under qemu with glibc heap tagging,
# where a read past an allocation traps the way it does on an mte phone,
# then for 32-bit arm under qemu-arm. the tests have to pass and the canary
# (one byte past a box) has to fault with SEGV_MTESERR (code 9), or the
# check proves nothing. needs docker, network for apt, and target/vendor
# from build-android.sh. usage: mobile/native/kryfo_signal/mtecheck.sh
set -euo pipefail
cd "$(dirname "$0")"
CRATE="$(pwd)"
[[ -f target/vendor.toml ]] || { echo "no target/vendor: run build-android.sh once" >&2; exit 1; }
rustup target add aarch64-unknown-linux-gnu armv7-unknown-linux-gnueabihf >/dev/null
SYSROOT="$(rustc --print sysroot)"
mkdir -p target/mtecheck
docker run --rm -v "$CRATE:$CRATE:ro" -v "$CRATE/target/mtecheck:/out" -v "$SYSROOT:/rust:ro" \
  -e CRATE="$CRATE" -e OWNER="$(id -u):$(id -g)" \
  debian:bookworm-20250630-slim bash -c '
set -e
apt-get update -qq >/dev/null
apt-get install -y -qq gcc libc6-dev protobuf-compiler qemu-user \
  gcc-aarch64-linux-gnu libc6-dev-arm64-cross \
  gcc-arm-linux-gnueabihf libc6-dev-armhf-cross >/dev/null 2>&1
export PATH=/rust/bin:$PATH CARGO_HOME=/tmp/cargo CARGO_TARGET_DIR=/tmp/target
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc
export CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABIHF_LINKER=arm-linux-gnueabihf-gcc
cd "$CRATE"
cargo=(cargo --frozen --config "$CRATE/target/vendor.toml")
# the test binary cargo built, from its json output
built() {
  "${cargo[@]}" test -q --no-run --message-format=json "$@" |
    sed -n "s/.*\"executable\":\"\([^\"]*\)\".*/\1/p" | tail -1
}
a64=$(built --target aarch64-unknown-linux-gnu)
canary=$(built --target aarch64-unknown-linux-gnu --features mtecheck)
arm=$(built --target armv7-unknown-linux-gnueabihf)

# the fault code is only in the siginfo, so a preloaded handler prints it.
# rust leaves a SIGSEGV handler alone when one is already set
cat >/tmp/si.c <<EOC
#include <signal.h>
#include <stdio.h>
#include <unistd.h>
static void h(int s, siginfo_t *i, void *u) {
  char b[48];
  int n = snprintf(b, sizeof b, "fault: signal %d code %d\n", s, i->si_code);
  write(2, b, n);
  _exit(70);
}
__attribute__((constructor)) static void on(void) {
  struct sigaction a = {0};
  a.sa_sigaction = h;
  a.sa_flags = SA_SIGINFO;
  sigaction(SIGSEGV, &a, 0);
}
EOC
aarch64-linux-gnu-gcc -shared -fPIC -o /tmp/si.so /tmp/si.c
mte() { qemu-aarch64 -cpu max -L /usr/aarch64-linux-gnu -E GLIBC_TUNABLES=glibc.mem.tagging=3 "$@"; }

echo "== arm64 with heap tagging"
time mte "$a64" --test-threads=1
echo "== the canary, has to trap"
if mte -E LD_PRELOAD=/tmp/si.so "$canary" --test-threads=1 --exact tests::mte_canary >/tmp/canary.log 2>&1; then
  tail -5 /tmp/canary.log
  echo "fail: the canary did not trap, the check proves nothing"
  exit 1
fi
grep -m1 "fault: signal 11 code 9$" /tmp/canary.log || { tail -20 /tmp/canary.log; echo "fail: no mte fault"; exit 1; }
echo "== 32-bit arm"
time qemu-arm -L /usr/arm-linux-gnueabihf "$arm" --test-threads=1
cp "$a64" /out/kryfo_signal-tests-aarch64-linux-gnu
cp "$arm" /out/kryfo_signal-tests-armv7-linux-gnueabihf
chown -R "$OWNER" /out
echo "ok: the tests pass on arm64 with heap tagging and on 32-bit arm, the canary traps"
'
