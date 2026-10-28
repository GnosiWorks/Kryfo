#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# writes mobile/assets/licences/engine.json, the licences screen's list of
# what libhalo.so is built from (go, the go modules in vendor/modules.txt,
# tor, openssl, libevent and zlib from go-libtor, and libopus from opus/)
# and of the third-party data files the app ships (each
# mobile/assets/<dir>/LICENSE* file), with their licence texts. run it
# after vendor.sh, opus/vendor.sh, a go update or a new data licence:
# test/licences_test.dart fails until the file matches the tree.
# go-libtor ships no licence text for openssl and zlib, so licences/ keeps
# theirs, from the commits in go-libtor's lock.json.
#   --check   make it again and fail when the committed file differs
set -euo pipefail
cd "$(dirname "$0")"
OUT=../mobile/assets/licences/engine.json

want=$(sed -n 's/^go //p' go.mod)
have=$(go env GOVERSION 2>/dev/null || true)
[[ "$have" == "go$want" ]] || { echo "error: needs go $want (have ${have:-none})" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
python3 -I - "$(go env GOROOT)" "$want" "$tmp/engine.json" <<'EOF'
import hashlib, json, os, re, sys

goroot, gover, out = sys.argv[1:]
libtor = 'vendor/github.com/alexballas/go-libtor'

def read(p):
    with open(p, encoding='utf-8') as f:
        return f.read()

def sha(p):
    with open(p, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()

def define(path, name):
    m = re.search(r'#\s*define %s "([^"]+)"' % name, read(path))
    if not m:
        sys.exit('no %s in %s' % (name, path))
    return m.group(1)

# what a licence file is, from its words. None for a patent grant or a
# notice, which is shipped but names no licence
def kind(text):
    t = ' '.join(text.split())
    if t.startswith('Additional IP Rights Grant (Patents)'):
        return None
    rules = [
        ('Apache-2.0', 'Apache License' in t and 'Version 2.0' in t),
        ('Unlicense', t.startswith('This is free and unencumbered software released into the public domain')),
        ('CC0-1.0', 'CC0 1.0 Universal' in t),
        ('MPL-2.0', 'Mozilla Public License' in t and '2.0' in t),
        ('GPL-3.0', 'GNU GENERAL PUBLIC LICENSE Version 3' in t),
        ('MIT', 'Permission is hereby granted, free of charge' in t),
        ('ISC', re.search(r'Permission to use, copy, modify, and(/or)? distribute this software for any purpose', t) is not None),
        ('Zlib', "This software is provided 'as-is'" in t and 'must not be misrepresented' in t),
        ('BSD-3-Clause', 'Redistribution and use in source and binary forms' in t
            and re.search(r'Neither the name|names of (its|the) contributors|name of the author may not', t, re.I) is not None),
        ('BSD-2-Clause', 'Redistribution and use in source and binary forms' in t),
    ]
    for k, hit in rules:
        if hit:
            return k
    return '?'

licences, index = [], {}
def text_id(path):
    t = read(path)
    if t not in index:
        index[t] = len(licences)
        licences.append({'id': kind(t), 'text': t})
    return index[t]

def part(name, version, files, licence=None):
    texts = list(dict.fromkeys(text_id(f) for f in files))
    if licence is None:
        ids = []
        for i in texts:
            k = licences[i]['id']
            if k == '?':
                sys.exit('%s: cannot tell the licence of one of %s' % (name, files))
            if k and k not in ids:
                ids.append(k)
        licence = ', '.join(ids)
    return {'name': name, 'version': version, 'licence': licence, 'texts': texts}

lic_file = re.compile(r'(?i)^(licen[cs]e|copying|notice|patents|unlicense)')
def licence_files(d):
    fs = sorted(os.path.join(d, f) for f in os.listdir(d)
                if lic_file.match(f) and os.path.isfile(os.path.join(d, f)))
    sub = os.path.join(d, 'licenses')
    if os.path.isdir(sub):
        fs += sorted(os.path.join(sub, f) for f in os.listdir(sub))
    return fs

parts, modules = [], []
cur = None
for line in read('vendor/modules.txt').splitlines():
    if line.startswith('# '):
        f = line[2:].split()
        cur = None
        if len(f) >= 2 and f[1] != '=>':
            cur = [f[0], f[1], 0]
            modules.append(cur)
    elif line and not line.startswith('#') and cur:
        cur[2] += 1
for name, version, packages in modules:
    if packages == 0:
        continue
    files = licence_files('vendor/' + name)
    if not files:
        sys.exit('no licence file in vendor/' + name)
    parts.append(part(name, version, files))

parts.append(part('Go', gover, [os.path.join(goroot, 'LICENSE'), os.path.join(goroot, 'PATENTS')]))
tor_ext = '%s/linux/tor/src/ext' % libtor
parts.append(part('tor', define('%s/tor_config/orconfig.android64.h' % libtor, 'VERSION'),
    ['%s/linux/tor/LICENSE' % libtor, tor_ext + '/equix/LICENSE',
     tor_ext + '/equix/hashx/LICENSE', tor_ext + '/mulodi/LICENSE.TXT'], 'BSD-3-Clause'))
parts.append(part('OpenSSL', define('%s/linux/openssl/include/openssl/opensslv.h' % libtor, 'OPENSSL_VERSION_STR'),
    ['licences/openssl-LICENSE.txt'], 'Apache-2.0'))
parts.append(part('libevent', define('%s/linux/libevent/include/event2/event-config.64.h' % libtor, 'EVENT__VERSION'),
    ['%s/linux/libevent/LICENSE' % libtor], 'BSD-3-Clause'))
parts.append(part('zlib', define('%s/linux/zlib/zlib.h' % libtor, 'ZLIB_VERSION'),
    ['licences/zlib-LICENSE'], 'Zlib'))
parts.append(part('libopus', read('opus/libopus/VERSION').strip(),
    ['opus/libopus/COPYING'], 'BSD-3-Clause'))
parts.sort(key=lambda p: p['name'].lower())

# LICENSE-OpenCC.txt names OpenCC
data = []
assets = '../mobile/assets'
for d in sorted(os.listdir(assets)):
    if d == 'licences' or not os.path.isdir(os.path.join(assets, d)):
        continue
    for f in sorted(os.listdir(os.path.join(assets, d))):
        if not lic_file.match(f):
            continue
        p = os.path.join(assets, d, f)
        name = re.sub(r'(?i)^(licen[cs]e|copying)[-_.]?', '', os.path.splitext(f)[0]) or d
        e = part(name, None, [p])
        e['file'] = 'assets/%s/%s' % (d, f)
        e['sha256'] = sha(p)
        data.append(e)

doc = {
    'modules': sha('vendor/modules.txt'),
    'libtor': sha('%s/lock.json' % libtor),
    'go': gover,
    'parts': parts,
    'data': data,
    'licences': licences,
}
with open(out, 'w') as f:
    json.dump(doc, f, indent=1, sort_keys=True)
    f.write('\n')
EOF

if [[ "${1:-}" == "--check" ]]; then
  cmp -s "$tmp/engine.json" "$OUT" || { echo "$OUT is out of date: run engine/acknowledgments.sh" >&2; exit 1; }
  echo "$OUT is up to date"
else
  cp "$tmp/engine.json" "$OUT"
  echo "wrote $OUT ($(python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); print(len(d["parts"]), "parts,", len(d["data"]), "data")' "$OUT"))"
fi
