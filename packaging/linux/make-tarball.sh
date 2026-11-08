#!/bin/sh
# the linux tarball from a checked bundle (mobile/linux/check-bundle.sh):
#   packaging/linux/make-tarball.sh <bundle> <out.tar.gz>
# one folder named like the file (kryfo-0.6.0-beta-linux-x64), with the
# bundle, install.sh and the menu entry. owners, dates and order are fixed,
# so one bundle gives one file
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
bundle=$(cd "$1" && pwd)
out=$2
name=$(basename "$out" .tar.gz)
case "$name" in
  kryfo-*-linux-x64) ;;
  *) echo "name the file kryfo-<version>-linux-x64.tar.gz" >&2; exit 1 ;;
esac
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/$name"
cp -a "$bundle/kryfo" "$bundle/lib" "$bundle/data" "$work/$name/"
cp "$here/install.sh" "$work/$name/"
chmod 755 "$work/$name/install.sh"
cp "$root/packaging/flatpak/app.kryfo.Kryfo.desktop" "$work/$name/"
cp "$root/LICENSE" "$work/$name/"
tar --sort=name --owner=0 --group=0 --numeric-owner --mtime=@1700000000 \
  -C "$work" -cf - "$name" | gzip -n -9 >"$out"
echo "$out"
