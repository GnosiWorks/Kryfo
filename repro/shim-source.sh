#!/bin/bash
# the complete source of libkryfo_signal.so: the shim's own crate and every
# crate its Cargo.lock names (what it links and what builds it: build scripts,
# proc macros and their dependencies), from the vendor dir a release build
# used, as one tarball with the same bytes on every machine. it builds with
# `cargo build --offline` and nothing else. AGPL and GPL section 6 want it
# offered beside the apks.
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
# the vendor dir must be exactly what Cargo.lock names, each crate with the
# checksums cargo vendor wrote, so cargo builds from it offline
mapfile -t crates < <(python3 -I - "$CRATE/Cargo.lock" <<'EOP'
import re, sys
lock = open(sys.argv[1]).read()
for n, v in sorted(re.findall(r'^\[\[package\]\]\nname = "([^"]+)"\nversion = "([^"]+)"\nsource = ', lock, re.M)):
    print('%s-%s' % (n, v))
EOP
)
[ ${#crates[@]} -gt 0 ] || { echo "no crates in $CRATE/Cargo.lock" >&2; exit 1; }
for c in "${crates[@]}"; do
  [ -f "$VENDOR/$c/.cargo-checksum.json" ] || { echo "$c is not in $VENDOR, or has no checksums" >&2; exit 1; }
done
extra=$(comm -13 <(printf '%s\n' "${crates[@]}" | LC_ALL=C sort) <(ls "$VENDOR" | LC_ALL=C sort))
[ -z "$extra" ] || { echo "$VENDOR holds crates Cargo.lock does not name: $extra" >&2; exit 1; }
CONFIG="$VENDOR/../vendor.toml"
[ -f "$CONFIG" ] || { echo "no vendor.toml beside $VENDOR" >&2; exit 1; }
agpl=()
for c in "${crates[@]}"; do
  grep -qE '^license = "AGPL-3\.0(-only)?"' "$VENDOR/$c/Cargo.toml" && agpl+=("$c")
done
printf '%s\n' "${agpl[@]}" | awk '/^libsignal-protocol-/ { f = 1 } END { exit !f }' || { echo "libsignal-protocol is not in $VENDOR" >&2; exit 1; }

version=$(sed -n 's/^version: \([0-9.]*\).*/\1/p' "$APP/pubspec.yaml")
[ -n "$version" ] || { echo "no version in $APP/pubspec.yaml" >&2; exit 1; }
name="libkryfo_signal-$version-source"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/$name/kryfo_signal" "$tmp/$name/vendor"
# the crate as the repository holds it, without target/
git -C "$CRATE" ls-files -z . | (cd "$CRATE" && xargs -0 cp -a --parents -t "$tmp/$name/kryfo_signal")
for c in "${crates[@]}"; do cp -a "$VENDOR/$c" "$tmp/$name/vendor/"; done
# cargo vendor's source config, pointed at vendor/ (cargo reads a path in
# .cargo/config.toml from the folder that holds .cargo)
mkdir "$tmp/$name/.cargo"
sed -E 's|^directory = .*|directory = "vendor"|' "$CONFIG" >"$tmp/$name/.cargo/config.toml"
grep -qx 'directory = "vendor"' "$tmp/$name/.cargo/config.toml" || { echo "no directory line in $CONFIG" >&2; exit 1; }
# every crate with its licence: the texts the licences screen shows for the
# ones the library links, the crate's own licence files for the rest, and for
# the few that ship none, the text of a licence their expression allows
python3 -I - "$LIST" "$VENDOR" "$tmp/$name/LICENCES" "${crates[@]}" <<'EOP'
import json, os, re, sys
listf, vendor, out, *crates = sys.argv[1:]
d = json.load(open(listf))
shown = {'%s-%s' % (c['name'], c['version']): [d['licences'][i] for i in c['texts']] for c in d['crates']}
canon = {}
for c in d['crates']:
    for i in c['texts']:
        canon.setdefault(d['licences'][i]['id'], d['licences'][i]['text'])
lic_file = re.compile(r'(?i)^(licen[cs]e|copying|notice|unlicense)')
texts, users, index, rows = [], [], {}, []
def add(text, crate):
    if text not in index:
        index[text] = len(texts)
        texts.append(text)
        users.append([])
    if crate not in users[index[text]]:
        users[index[text]].append(crate)
for c in crates:
    m = re.search(r'^license\s*=\s*"([^"]+)"', open(os.path.join(vendor, c, 'Cargo.toml')).read(), re.M)
    expr = m.group(1) if m else 'see the crate'
    rows.append('%s  %s' % (c, expr))
    if c in shown:
        for l in shown[c]:
            add(l['text'], c)
        continue
    files = sorted(f for f in os.listdir(os.path.join(vendor, c))
                   if lic_file.match(f) and os.path.isfile(os.path.join(vendor, c, f)))
    for f in files:
        add(open(os.path.join(vendor, c, f), encoding='utf-8', errors='replace').read(), c)
    if not files:
        ids = [i for i in re.split(r'[()\s]+', expr) if i in canon]
        if not ids:
            sys.exit('%s ships no licence text and %s is not one the list has' % (c, expr))
        add(canon[ids[0]], c)
with open(out, 'w') as f:
    f.write('every crate in vendor/ and its licence, as its Cargo.toml names it\n\n')
    f.write('\n'.join(rows) + '\n\n')
    for t, u in zip(texts, users):
        f.write('=' * 78 + '\n' + ', '.join(u) + '\n\n' + t.rstrip('\n') + '\n\n')
EOP
cat >"$tmp/$name/README" <<EOR
the complete source of libkryfo_signal.so in Kryfo $version, exactly as the
release build compiled it.

kryfo_signal/ is the library's own crate (GPL-3.0-or-later), as it is in
Kryfo's repository at the release tag. build-android.sh there is how the
release builds it.

vendor/ holds every crate kryfo_signal/Cargo.lock names, ${#crates[@]} of them,
as cargo vendor --locked --versioned-dirs fetched them, each with the
checksums cargo checks: the ${n} the library links for the three android
targets and the ones that only build it (build scripts, proc macros and their
dependencies) or serve other platforms. ${#agpl[@]} are libsignal's ($tag,
AGPL-3.0, also at https://github.com/signalapp/libsignal); the others are
under MIT, Apache-2.0, MPL-2.0, BSD and similar licences. LICENCES names each
crate's licence and holds every licence text with the crates under it.
.cargo/config.toml points cargo at vendor/, so nothing is fetched.

to build it offline you need rust $(sed -n 's/^channel = "\(.*\)"$/\1/p' "$CRATE/rust-toolchain.toml") with the three android targets
kryfo_signal/rust-toolchain.toml names, and protoc. for this machine:

  cd kryfo_signal && cargo build --offline --release

for android, the way the release does it (with the android ndk 28.2.13676358
as well):

  mkdir -p kryfo_signal/target
  cp -a vendor kryfo_signal/target/vendor
  cp .cargo/config.toml kryfo_signal/target/vendor.toml
  sha256sum kryfo_signal/Cargo.lock | cut -c1-64 >kryfo_signal/target/vendor.lock
  KS_OFFLINE=1 JNI_LIBS_DIR=\$PWD/out kryfo_signal/build-android.sh

libsignal's crates:
$(printf '%s\n' "${agpl[@]}")
EOR
tar -C "$tmp" --sort=name --mtime=@1700000000 --owner=0 --group=0 --numeric-owner \
  --mode=u+rw,go+r,go-w -cf - "$name" | gzip -n -9 >"$OUT/$name.tar.gz"
echo "$OUT/$name.tar.gz: ${#crates[@]} crates, $(wc -c <"$OUT/$name.tar.gz") bytes"
