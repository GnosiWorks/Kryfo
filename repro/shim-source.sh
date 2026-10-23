#!/bin/bash
# the complete source of libkryfo_signal.so: the shim's own crate and every
# crate it links for the three android targets (the 121 that
# mobile/assets/licences/rust.json lists), from the vendor dir a release build
# used, as one tarball with the same bytes on every machine. AGPL and GPL
# section 6 want it offered beside the apks.
# usage: shim-source.sh <vendor dir> <out dir>
set -euo pipefail
VENDOR=$(cd "$1" && pwd)
OUT=$2
CRATE=$(cd "$VENDOR/../.." && pwd)
APP=$(cd "$CRATE/../.." && pwd)
LIST="$APP/assets/licences/rust.json"
[ -f "$CRATE/Cargo.lock" ] && [ -f "$LIST" ] || { echo "no Cargo.lock or rust.json beside $VENDOR" >&2; exit 1; }

# the list must be the one made from this Cargo.lock
read -r lock tag n < <(python3 -I -c '
import json, sys
d = json.load(open(sys.argv[1]))
print(d["lock"], d["libsignal"], len(d["crates"]))' "$LIST")
[ "$lock" = "$(sha256sum "$CRATE/Cargo.lock" | cut -c1-64)" ] ||
  { echo "rust.json was not made from this Cargo.lock: run acknowledgments.sh" >&2; exit 1; }
mapfile -t crates < <(python3 -I -c '
import json, sys
for c in json.load(open(sys.argv[1]))["crates"]:
    print("%s-%s" % (c["name"], c["version"]))' "$LIST")
for c in "${crates[@]}"; do
  [ -d "$VENDOR/$c" ] || { echo "$c is not in $VENDOR" >&2; exit 1; }
done
agpl=()
for c in "${crates[@]}"; do
  grep -qE '^license = "AGPL-3\.0(-only)?"' "$VENDOR/$c/Cargo.toml" && agpl+=("$c")
done
printf '%s\n' "${agpl[@]}" | grep -q '^libsignal-protocol-' || { echo "libsignal-protocol is not in $VENDOR" >&2; exit 1; }

version=$(sed -n 's/^version: \([0-9.]*\).*/\1/p' "$APP/pubspec.yaml")
[ -n "$version" ] || { echo "no version in $APP/pubspec.yaml" >&2; exit 1; }
name="libkryfo_signal-$version-source"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/$name/kryfo_signal" "$tmp/$name/vendor"
# the crate as the repository holds it, without target/
git -C "$CRATE" ls-files -z . | (cd "$CRATE" && xargs -0 cp -a --parents -t "$tmp/$name/kryfo_signal")
for c in "${crates[@]}"; do cp -a "$VENDOR/$c" "$tmp/$name/vendor/"; done
# not every crate ships its licence file, so every text once, with its crates
python3 -I -c '
import json, sys
d = json.load(open(sys.argv[1]))
users = {}
for c in d["crates"]:
    for i in c["texts"]:
        users.setdefault(i, []).append("%s %s" % (c["name"], c["version"]))
with open(sys.argv[2], "w") as f:
    for i, l in enumerate(d["licences"]):
        f.write("=" * 78 + "\n" + l["id"] + ": " + ", ".join(users.get(i, [])) + "\n\n")
        f.write(l["text"].rstrip("\n") + "\n\n")' "$LIST" "$tmp/$name/LICENCES"
cat >"$tmp/$name/README" <<EOR
the complete source of libkryfo_signal.so in Kryfo $version, exactly as the
release build compiled it.

kryfo_signal/ is the library's own crate (GPL-3.0-or-later), as it is in
Kryfo's repository at the release tag. build-android.sh there is how the
release builds it.

vendor/ holds every crate the library links for the three android targets,
${n} of them, as cargo vendor --versioned-dirs fetched them for
kryfo_signal/Cargo.lock. ${#agpl[@]} are libsignal's ($tag, AGPL-3.0, also at
https://github.com/signalapp/libsignal); the others are under MIT,
Apache-2.0, MPL-2.0, BSD and similar licences. each crate's Cargo.toml names
its licence, and LICENCES holds every licence text with the crates under it.
crates used only to build (build scripts and their dependencies) and crates
for other platforms are not part of the library. Cargo.lock names them, with
versions and checksums.

libsignal's crates:
$(printf '%s\n' "${agpl[@]}")
EOR
tar -C "$tmp" --sort=name --mtime=@1700000000 --owner=0 --group=0 --numeric-owner \
  --mode=u+rw,go+r,go-w -cf - "$name" | gzip -n -9 >"$OUT/$name.tar.gz"
echo "$OUT/$name.tar.gz: ${#crates[@]} crates, $(wc -c <"$OUT/$name.tar.gz") bytes"
