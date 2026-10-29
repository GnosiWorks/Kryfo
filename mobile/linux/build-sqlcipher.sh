#!/bin/sh
# builds the sqlcipher the linux app ships in lib/, the same release and
# options as the flatpak's module. a plain sqlite is never used for the
# database: the app refuses to open one.
#   build-sqlcipher.sh [tarball]   (downloads the pinned release without one)
# EXTRA_CFLAGS and EXTRA_LDFLAGS point at openssl when the system has no
# headers for it.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
ver=4.19.0
sum=7075f96cbabe45b4ecfc2e6b1745a625f856f695b0827a5506ce9ed85b906aa0
url=https://github.com/sqlcipher/sqlcipher/archive/refs/tags/v$ver.tar.gz
out=$here/out
work=$out/sqlcipher-build
rm -rf "$work"
mkdir -p "$work"
tar=${1:-$work/v$ver.tar.gz}
if [ $# -eq 0 ]; then
  curl -fsSL -o "$tar" "$url"
fi
echo "$sum  $tar" | sha256sum -c - >/dev/null || {
  echo "sqlcipher tarball does not match the pinned sha256" >&2
  exit 1
}
tar -xzf "$tar" -C "$work" --strip-components=1
cd "$work"
# no build path or date inside the library
export SOURCE_DATE_EPOCH=0
export CFLAGS="-O2 ${EXTRA_CFLAGS:-} -ffile-prefix-map=$work=/sqlcipher -DSQLITE_HAS_CODEC -DSQLITE_EXTRA_INIT=sqlcipher_extra_init -DSQLITE_EXTRA_SHUTDOWN=sqlcipher_extra_shutdown"
export LDFLAGS="${EXTRA_LDFLAGS:-} -lcrypto"
./configure --with-tempstore=yes --fts5 --disable-tcl --disable-static \
  --disable-readline --dll-basename=libsqlcipher --soname=legacy >configure.log 2>&1 || {
  tail -20 configure.log >&2
  exit 1
}
make -j2 LDFLAGS.libsqlite3.soname=-Wl,-soname,libsqlcipher.so.0 libsqlcipher.so >make.log 2>&1 || {
  tail -20 make.log >&2
  exit 1
}
cp libsqlcipher.so "$out/libsqlcipher.so.0"
strip --strip-unneeded "$out/libsqlcipher.so.0"
cd "$out"
rm -rf "$work"
nm -D --defined-only libsqlcipher.so.0 | grep -q ' T sqlite3_key$' || {
  echo "the library has no sqlite3_key: not sqlcipher" >&2
  exit 1
}
echo "$out/libsqlcipher.so.0"
