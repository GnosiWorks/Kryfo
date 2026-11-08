#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# builds the sqlcipher.dll the windows app ships next to kryfo.exe, cross on
# linux with mingw-w64: the linux app's release and options, openssl linked
# in statically, so no libcrypto dll ships.
#   build-sqlcipher.sh [sqlcipher tarball] [openssl tarball]
# downloads the pinned releases when none are given. out: out/sqlcipher.dll
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
die() { echo "error: $*" >&2; exit 1; }

sq_ver=4.19.0
sq_sum=7075f96cbabe45b4ecfc2e6b1745a625f856f695b0827a5506ce9ed85b906aa0
sq_url=https://github.com/sqlcipher/sqlcipher/archive/refs/tags/v$sq_ver.tar.gz
# 3.5 lts. sum from the release's .sha256, signature checked against
# B146 647E 45A7 B339 47AB 226B 2A2C 87D1 6169 2D40 (doc/fingerprints.txt)
os_ver=3.5.9
os_sum=603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a
os_url=https://github.com/openssl/openssl/releases/download/openssl-$os_ver/openssl-$os_ver.tar.gz

host=x86_64-w64-mingw32
CC_W="${CC_W:-$host-gcc}"
STRIP_W="${STRIP_W:-$host-strip}"
for c in "$CC_W" "$STRIP_W" perl make cc; do
  command -v "$c" >/dev/null || die "$c not found"
done

out=$here/out
work=$out/sqlcipher-build
rm -rf "$work"
mkdir -p "$work/sq" "$work/os"
sq_tar=${1:-$work/sqlcipher-$sq_ver.tar.gz}
os_tar=${2:-$work/openssl-$os_ver.tar.gz}
[ $# -ge 1 ] || curl -fsSL -o "$sq_tar" "$sq_url"
[ $# -ge 2 ] || curl -fsSL -o "$os_tar" "$os_url"
echo "$sq_sum  $sq_tar" | sha256sum -c - >/dev/null || die "sqlcipher tarball does not match the pinned sha256"
echo "$os_sum  $os_tar" | sha256sum -c - >/dev/null || die "openssl tarball does not match the pinned sha256"
tar -xzf "$sq_tar" -C "$work/sq" --strip-components=1 --no-same-owner
tar -xzf "$os_tar" -C "$work/os" --strip-components=1 --no-same-owner

export SOURCE_DATE_EPOCH=0

# openssl: libcrypto only, static. no config file, engine or provider module
# is ever loaded from disk, and no file names go into the library. the
# folder it names is one a standard user cannot make, should anything look.
(
  cd "$work/os"
  ./Configure mingw64 --cross-compile-prefix=$host- \
    --prefix=C:/Windows/System32/kryfo-no-openssl --openssldir=C:/Windows/System32/kryfo-no-openssl \
    --libdir=lib no-shared no-module no-engine no-dso no-autoload-config no-filenames \
    no-legacy no-apps no-tests no-docs no-ui-console >configure.log 2>&1 ||
    { tail -20 configure.log >&2; exit 1; }
  make -j2 build_libs >make.log 2>&1 || { tail -20 make.log >&2; exit 1; }
)
ossl=$work/os
[ -f "$ossl/libcrypto.a" ] || die "no static libcrypto"

# the amalgamation is made on the host, the same way the linux build makes it
(
  cd "$work/sq"
  ./configure --disable-tcl --disable-readline >configure.log 2>&1 ||
    { tail -20 configure.log >&2; exit 1; }
  make sqlite3.c >make.log 2>&1 || { tail -20 make.log >&2; exit 1; }
)

# the version resource. the notice is sqlcipher's own, from its licence
lic=$(head -1 "$work/sq/LICENSE.md" | tr -d '\r')
[[ "$lic" == Copyright* ]] || die "no copyright line in sqlcipher's LICENSE.md"
"$here/../../packaging/windows/version-rc.sh" "$work/version.o" sqlcipher.dll "SQLCipher for Kryfo" \
  "$lic. BSD-style license" "SQLCipher $sq_ver with OpenSSL $os_ver (Apache-2.0)"

# the linux build's feature flags (configure's defaults plus --fts5 and
# --with-tempstore=yes), the codec, and an export list of sqlite's api only
cd "$work/sq"
"$CC_W" -shared -O2 -o sqlcipher.dll sqlite3.c \
  -ffile-prefix-map="$work"=/sqlcipher \
  -DSQLITE_API='__declspec(dllexport)' -DSQLITE_THREADSAFE=1 -DSQLITE_TEMP_STORE=2 \
  -DSQLITE_ENABLE_FTS5 -DSQLITE_ENABLE_MATH_FUNCTIONS -DSQLITE_ENABLE_PERCENTILE \
  -DSQLITE_HAS_CODEC -DSQLCIPHER_CRYPTO_OPENSSL \
  -DSQLITE_EXTRA_INIT=sqlcipher_extra_init -DSQLITE_EXTRA_SHUTDOWN=sqlcipher_extra_shutdown \
  -I"$ossl/include" "$work/version.o" "$ossl/libcrypto.a" -lws2_32 -lgdi32 -lcrypt32 -ladvapi32 -luser32 \
  -static-libgcc -Wl,--exclude-libs,ALL \
  -Wl,--dynamicbase,--high-entropy-va,--nxcompat,--no-insert-timestamp >cc.log 2>&1 ||
  { tail -20 cc.log >&2; exit 1; }
"$STRIP_W" --strip-unneeded sqlcipher.dll
mkdir -p "$out"
cp sqlcipher.dll "$out/sqlcipher.dll"
cd "$out"
rm -rf "$work"

"$here/../../packaging/windows/check-pe.sh" sqlcipher.dll
ex=$("$here/../../packaging/windows/check-pe.sh" --exports sqlcipher.dll)
for want in sqlite3_key sqlite3_key_v2 sqlite3_rekey sqlite3_open_v2 sqlite3_prepare_v3 sqlite3_libversion; do
  grep -qx "$want" <<<"$ex" || die "sqlcipher.dll does not export $want"
done
# sqlite's api, and three sqlite3pager_ calls the amalgamation marks too
other=$(grep -vE '^sqlite3(_|pager_)' <<<"$ex" || true)
[ -z "$other" ] || die "sqlcipher.dll exports more than sqlite's api: $(echo $other | head -c 300)"
echo "$out/sqlcipher.dll ($(grep -c . <<<"$ex") exports)"
