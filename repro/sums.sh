#!/bin/sh
# the release's sum files, in the folder that holds the release files:
#   repro/sums.sh <dir> <version>          writes them
#   repro/sums.sh --check <dir> <version>  checks the files against them
# SHA256SUMS: the four apks and the shim's source tarball, all required.
# SHA256SUMS-windows: the windows installer and zip, when they are there.
# SHA256SUMS-linux: the linux tarball, when it is there.
set -eu

CHECK=
[ "${1:-}" = --check ] && { CHECK=1; shift; }
[ $# -eq 2 ] || { echo "usage: $0 [--check] <dir> <version>" >&2; exit 2; }
dir=$1
v=$2
case "$v" in
  *-rc*) echo "a candidate is never published, no sums for $v" >&2; exit 2 ;;
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) echo "not a version: $v" >&2; exit 2 ;;
esac
cd "$dir"

apks="app-arm64-v8a-release.apk app-armeabi-v7a-release.apk app-universal-release.apk app-x86_64-release.apk"
src="libkryfo_signal-$v-source.tar.gz"
win="kryfo-$v-windows-x64-setup.exe kryfo-$v-windows-x64.zip"

for f in $apks $src; do
  [ -f "$f" ] || { echo "missing $f in $dir" >&2; exit 1; }
done
for f in *-rc.apk *-rc.tar.gz; do
  [ -e "$f" ] && { echo "a candidate file is in $dir: $f" >&2; exit 1; }
done

have_win=
for f in $win; do [ -f "$f" ] && have_win=1; done
if [ -n "$have_win" ]; then
  for f in $win; do [ -f "$f" ] || { echo "missing $f in $dir" >&2; exit 1; }; done
fi

# the linux beta can carry -beta in its name, one file at most
lin=$(ls kryfo-"$v"-linux-x64.tar.gz kryfo-"$v"-beta-linux-x64.tar.gz 2>/dev/null || true)
[ "$(echo "$lin" | grep -c .)" -le 1 ] || { echo "more than one linux tarball in $dir" >&2; exit 1; }

if [ -n "$CHECK" ]; then
  sha256sum --strict -c SHA256SUMS
  [ -z "$have_win" ] || sha256sum --strict -c SHA256SUMS-windows
  [ -z "$lin" ] || sha256sum --strict -c SHA256SUMS-linux
  exit 0
fi

rm -f SHA256SUMS SHA256SUMS-windows SHA256SUMS-linux
# shellcheck disable=SC2086
sha256sum $apks $src >SHA256SUMS
# shellcheck disable=SC2086
[ -z "$have_win" ] || sha256sum $win >SHA256SUMS-windows
[ -z "$lin" ] || sha256sum "$lin" >SHA256SUMS-linux
for s in SHA256SUMS SHA256SUMS-windows SHA256SUMS-linux; do
  [ -f "$s" ] || continue
  echo "== $dir/$s"
  cat "$s"
done
