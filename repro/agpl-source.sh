#!/bin/bash
# the source of the AGPL-3.0 crates the shim links (libsignal's), from the
# vendor dir a release build used, as one tarball with the same bytes on
# every machine: AGPL section 6 wants it offered beside the apks.
# usage: agpl-source.sh <vendor dir> <out dir>
set -euo pipefail
VENDOR=$1
OUT=$2
crates=()
for d in "$VENDOR"/*/; do
  grep -qE '^license = "AGPL-3\.0(-only)?"' "$d/Cargo.toml" 2>/dev/null && crates+=("$(basename "$d")")
done
[ ${#crates[@]} -gt 0 ] || { echo "no AGPL crates in $VENDOR" >&2; exit 1; }
printf '%s\n' "${crates[@]}" | grep -q '^libsignal-protocol-' || { echo "libsignal-protocol is not in $VENDOR" >&2; exit 1; }
tag=$(sed -n 's/^source = "git+https:\/\/github.com\/signalapp\/libsignal?tag=\(v[0-9.]*\)#.*/\1/p' \
  "$VENDOR/../../Cargo.lock" | head -1)
[ -n "$tag" ] || { echo "no libsignal tag in Cargo.lock" >&2; exit 1; }
name="libsignal-$tag-source"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/$name"
for c in "${crates[@]}"; do cp -a "$VENDOR/$c" "$tmp/$name/"; done
cat >"$tmp/$name/README" <<EOR
the AGPL-3.0 crates linked into Kryfo's libkryfo_signal.so, exactly as the
release build compiled them (cargo vendor of mobile/native/kryfo_signal's
Cargo.lock). libsignal $tag is also at https://github.com/signalapp/libsignal,
and the rest of the source is Kryfo's repository at the release tag.

$(printf '%s\n' "${crates[@]}")
EOR
tar -C "$tmp" --sort=name --mtime=@1700000000 --owner=0 --group=0 --numeric-owner \
  --mode=u+rw,go+r,go-w -cf - "$name" | gzip -n -9 >"$OUT/$name.tar.gz"
echo "$OUT/$name.tar.gz: ${#crates[@]} crates, $(wc -c <"$OUT/$name.tar.gz") bytes"
