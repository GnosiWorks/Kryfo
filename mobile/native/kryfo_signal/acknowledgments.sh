#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# writes mobile/assets/licences/rust.json, the licences screen's list of the
# crates linked into the android library and their licence texts, with
# cargo-about 0.8.2 (the version libsignal pins) over this Cargo.lock. run
# it after any change to Cargo.lock: test/licences_test.dart fails until the
# file names the lock it was made from.
#   --check   make it again and fail when the committed file differs
set -euo pipefail
cd "$(dirname "$0")"
OUT=../../assets/licences/rust.json

v=$(cargo about --version 2>/dev/null || true)
if [[ "$v" != "cargo-about 0.8.2" ]]; then
  echo "error: needs cargo-about 0.8.2 (cargo install cargo-about --version 0.8.2 --locked)" >&2
  exit 1
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
CARGO_NET_GIT_FETCH_WITH_CLI=true cargo about generate --locked --format json \
  -c about.toml -o "$tmp/about.json"

# one entry per crate, each licence text once, both in a fixed order
python3 -I - "$tmp/about.json" Cargo.lock Cargo.toml "$tmp/rust.json" <<'EOF'
import hashlib, json, re, sys

about, lock, manifest, out = sys.argv[1:]
a = json.load(open(about))
lock_bytes = open(lock, 'rb').read()
# the manifest names libsignal by its commit and says which tag that is
tag = re.search(r'^# libsignal (v[0-9.]+), named by its commit', open(manifest).read(), re.M).group(1)
expr = {(c['package']['name'], c['package']['version']): c['license'] for c in a['crates']}
uses = {}
for l in a['licenses']:
    for u in l['used_by']:
        c = u['crate']
        uses.setdefault((c['name'], c['version']), []).append((l['id'], l['text']))
texts, index, crates = [], {}, []
for key in sorted(uses):
    ids = []
    for t in uses[key]:
        if t not in index:
            index[t] = len(texts)
            texts.append({'id': t[0], 'text': t[1]})
        if index[t] not in ids:
            ids.append(index[t])
    crates.append({'name': key[0], 'version': key[1], 'licence': expr[key], 'texts': ids})
missing = sorted(set(expr) - set(uses))
if missing:
    sys.exit('no licence text for ' + ', '.join('%s %s' % k for k in missing))
doc = {
    'lock': hashlib.sha256(lock_bytes).hexdigest(),
    'libsignal': tag,
    'crates': crates,
    'licences': texts,
}
with open(out, 'w') as f:
    json.dump(doc, f, indent=1, sort_keys=True)
    f.write('\n')
EOF

if [[ "${1:-}" == "--check" ]]; then
  cmp -s "$tmp/rust.json" "$OUT" || { echo "$OUT is out of date: run acknowledgments.sh" >&2; exit 1; }
  echo "$OUT is up to date"
else
  mkdir -p "$(dirname "$OUT")"
  cp "$tmp/rust.json" "$OUT"
  echo "wrote $OUT ($(python3 -I -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["crates"]))' "$OUT") crates)"
fi
