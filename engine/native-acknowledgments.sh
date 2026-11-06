#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# writes mobile/assets/licences/native.json, the licences screen's lists for
# the two libraries built beside the engine: libkryfo_voice (whisper.cpp and
# ggml, the YaRN rope in ggml, the speech model's weights) and
# libkryfo_translate (bergamot and what its tree builds in, and the models it
# downloads). the texts come from the pinned sources the fetch scripts check,
# the weights' text from voice/licences/. run it after a new whisper.lock,
# bergamot.lock or model:
# test/licences_test.dart fails until the file matches the tree.
#   --check   make it again and fail when the committed file differs
set -euo pipefail
cd "$(dirname "$0")"
OUT=../mobile/assets/licences/native.json

whisper="$(voice/native/fetch-whisper.sh)"
bergamot="$(translate/native/fetch-bergamot.sh)"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
python3 -I - "$whisper" "$bergamot" "$tmp/native.json" <<'EOF'
import hashlib, io, json, os, re, sys, tarfile

whisper, bergamot, out = sys.argv[1:]

def read(p):
    with open(p, encoding='utf-8') as f:
        return f.read()

def sha(p):
    with open(p, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()

def lock(path):
    return dict(re.findall(r'^(\w+)=(\S+)$', read(path), re.M))

licences, index = [], {}
def add(text):
    if text not in index:
        index[text] = len(licences)
        licences.append(text)
    return index[text]

def part(name, version, licence, texts):
    if not texts or not all(t.strip() for t in texts):
        sys.exit('%s: no licence text' % name)
    return {'name': name, 'version': version, 'licence': licence,
            'texts': list(dict.fromkeys(add(t) for t in texts))}

# voice
wl = lock('voice/native/whisper.lock')
wlic = read(os.path.join(whisper, 'LICENSE'))
if 'The ggml authors' not in wlic:
    sys.exit('whisper.cpp LICENSE does not name the ggml authors')
# the one line ggml's rope code carries, as it is in the source
ops = read(os.path.join(whisper, 'ggml/src/ggml-cpu/ops.cpp'))
yarn = re.findall(r'^// (MIT licensed\. Copyright \(c\) 2023 Jeffrey Quesnelle and Bowen Peng\.)$', ops, re.M)
if len(yarn) != 1:
    sys.exit('ggml-cpu/ops.cpp: the YaRN notice is not there once')
models = json.loads(read('voice/models.json'))
if [m['id'] for m in models['models']] != ['base']:
    sys.exit('voice/models.json: the list names the base model only')
weights = read('voice/licences/weights-LICENSE')
voice = [
    part('whisper.cpp and ggml', wl['WHISPER_VERSION'], 'MIT', [wlic]),
    part('YaRN rope scaling, in ggml', None, 'MIT', [yarn[0], wlic]),
    part('Whisper base speech model', models['models'][0]['file'], 'MIT', [weights]),
]

# translation: the lock's commits name the versions
pins = {}
for line in read('translate/native/bergamot.lock').splitlines():
    f = line.split()
    if len(f) == 5 and not line.startswith('#'):
        pins[f[0]] = f
# the root LICENSE is left out of the unpacked tree: read it from the
# tarball, checked again against the lock
name, repo, commit, want, _ = pins['translations']
tar = 'translate/native/.third_party/dl/translations-%s.tar.gz' % commit
if sha(tar) != want:
    sys.exit('%s: sha256 differs from bergamot.lock' % tar)
with tarfile.open(tar) as t:
    root = t.extractfile('translations-%s/LICENSE' % commit).read().decode('utf-8')

m = os.path.join(bergamot, 'inference/marian-fork/src/3rd_party')
def f(*p):
    return read(os.path.join(bergamot, *p))
def m3(*p):
    return read(os.path.join(m, *p))
def short(n):
    return pins[n][2][:8]
zlib = re.match(r'/\* (zlib\.h .*?)\*/', m3('zlib/zlib.h'), re.S)
if not zlib or 'Jean-loup Gailly and Mark Adler' not in zlib.group(1):
    sys.exit('zlib.h: no notice')
translation = [
    part('Bergamot translator', short('translations'), 'MPL-2.0', [root]),
    part('Marian', None, 'MIT', [f('inference/marian-fork/LICENSE.md')]),
    part('ssplit-cpp', short('ssplit-cpp'), 'Apache-2.0', [f('inference/3rd_party/ssplit-cpp/LICENSE.md')]),
    part('SentencePiece', short('sentencepiece'), 'Apache-2.0', [m3('sentencepiece/LICENSE')]),
    part('Abseil, in SentencePiece', None, 'Apache-2.0', [m3('sentencepiece/third_party/absl/LICENSE')]),
    part('Darts-clone, in SentencePiece', None, 'BSD-2-Clause', [m3('sentencepiece/third_party/darts_clone/LICENSE')]),
    part('esaxx, in SentencePiece', None, 'MIT', [m3('sentencepiece/third_party/esaxx/LICENSE')]),
    part('Protocol Buffers lite, in SentencePiece', None, 'BSD-3-Clause', [m3('sentencepiece/third_party/protobuf-lite/LICENSE')]),
    part('intgemm', short('intgemm'), 'MIT', [m3('intgemm/LICENSE')]),
    part('simd_utils', short('simd_utils'), 'BSD-2-Clause', [m3('simd_utils/LICENSE')]),
    part('ruy', short('ruy'), 'Apache-2.0', [m3('ruy/LICENSE')]),
    part('cpuinfo', short('cpuinfo'), 'BSD-2-Clause', [m3('ruy/third_party/cpuinfo/LICENSE'), m3('ruy/third_party/cpuinfo/deps/clog/LICENSE')]),
    part('PCRE2', '10.45', 'BSD-3-Clause WITH PCRE2-exception', [f('pcre2/LICENCE.md')]),
    part('CLI11', None, 'BSD-3-Clause', [m3('CLI/LICENSE')]),
    part('cnpy', None, 'MIT', [m3('cnpy/LICENSE')]),
    part('faiss', None, 'MIT', [m3('faiss/LICENSE')]),
    part('mio', None, 'MIT', [m3('mio/LICENSE')]),
    part('pathie', None, 'BSD-2-Clause', [m3('pathie-cpp/LICENSE')]),
    part('phf', None, 'MIT', [m3('phf/LICENSE')]),
    part('spdlog', None, 'MIT', [m3('spdlog/LICENSE')]),
    part('yaml-cpp', None, 'MIT', [m3('yaml-cpp/LICENSE')]),
    part('zlib', '1.2.11', 'Zlib', [zlib.group(1)]),
    part('zstr', None, 'MIT', [m3('zstr/LICENSE')]),
]
# the models: mozilla publishes every model file of its translations bucket
# under the mpl 2.0 (mozilla/translations readme, "the model files are
# distributed under the MPL 2.0 license"), the repo's own text. a new pair
# fails here until its licence is checked too
tm = json.loads(read('translate/models.json'))
if not tm['source'].startswith('https://storage.googleapis.com/moz-fx-translations-data--303e-prod-translations-data/'):
    sys.exit('translate/models.json: a source whose licence is not checked here')
langs = {'en': 'English', 'zh': 'Chinese'}
pairs = sorted((p['from'], p['to']) for p in tm['pairs'])
if pairs != [('en', 'zh'), ('zh', 'en')]:
    sys.exit('translate/models.json: a pair whose licence is not checked here')
for p in tm['pairs']:
    model = [x for x in p['files'] if x['kind'] == 'model']
    if len(model) != 1:
        sys.exit('translate/models.json: %s-%s has no one model file' % (p['from'], p['to']))
    translation.append(part('Translation model, %s to %s' % (langs[p['from']], langs[p['to']]),
                            model[0]['sha256'][:8], 'MPL-2.0', [root]))
translation.sort(key=lambda p: p['name'].lower())

doc = {
    'whisper': sha('voice/native/whisper.lock'),
    'models': sha('voice/models.json'),
    'weights': sha('voice/licences/weights-LICENSE'),
    'bergamot': sha('translate/native/bergamot.lock'),
    'translationModels': sha('translate/models.json'),
    'voice': voice,
    'translation': translation,
    'licences': licences,
}
with open(out, 'w') as o:
    json.dump(doc, o, indent=1, sort_keys=True, ensure_ascii=False)
    o.write('\n')
EOF

if [[ "${1:-}" == "--check" ]]; then
  cmp -s "$tmp/native.json" "$OUT" || { echo "$OUT is out of date: run engine/native-acknowledgments.sh" >&2; exit 1; }
  echo "$OUT is up to date"
else
  cp "$tmp/native.json" "$OUT"
  echo "wrote $OUT ($(python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); print(len(d["voice"]), "voice,", len(d["translation"]), "translation")' "$OUT"))"
fi
