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
# distributed under the MPL 2.0 license"), the repo's own text. the packs on
# our mirror are those gzips byte for byte, one direction a pack, picked from
# firefox's translations-models records. one row a checked direction, named
# by the first bytes of the model's sha256; a pair in models.json that is
# not here, or with another model, fails until its licence is checked too
tm = json.loads(read('translate/models.json'))
if not tm['source'].startswith('https://storage.googleapis.com/moz-fx-translations-data--303e-prod-translations-data/'):
    sys.exit('translate/models.json: a source whose licence is not checked here')
langs = {'ar': 'Arabic', 'de': 'German', 'en': 'English', 'es': 'Spanish', 'fa': 'Persian',
         'fr': 'French', 'hi': 'Hindi', 'id': 'Indonesian', 'it': 'Italian', 'pl': 'Polish',
         'pt': 'Portuguese', 'ru': 'Russian', 'tr': 'Turkish', 'uk': 'Ukrainian',
         'vi': 'Vietnamese', 'zh': 'Chinese', 'zh_hant': 'Traditional Chinese'}
checked = [
    ('ar', 'en', '7b7af0282dc5f4d8805b9a298c2fa828967e3f09ca10f1942ebeea0b2cfc12fa'),
    ('de', 'en', '3e6f7c2c2425d10824797270b382bee718ff34af2cab9308841c82ca46dc6f20'),
    ('en', 'ar', 'ae659d7045fc2e5d6ba50583586a5d94ee4358d92c019847e37b57a0e627faa8'),
    ('en', 'de', '8df29d9494d19f47fd5d97c6a73474c6f657e9f81c1a607c431d02befdf3810f'),
    ('en', 'es', '3b1c399511c01c84c36fae5c0524df44096288efdc8236e182b5c97d7ad2244c'),
    ('en', 'fa', '456ad3952bcc59d208c76baba4dcef340ee4239416bd760d6fec27f9a16228f8'),
    ('en', 'fr', '6322e296d4fecfe395a8d5723da4ec37ecbe6d7613bb1dfcf4b28e2a47498b68'),
    ('en', 'hi', '18682fa6aa1c1b2f78a6fcbcb354755094d623e65436ef7821720c5213e11a49'),
    ('en', 'id', 'f81f13eef703a4e0650ffc3138a0f4bab7b6c8bfd173ef1b7bda68d16b8bc7e8'),
    ('en', 'it', '248f47568788ecc351da7e5e07064d4153b4f71e011364ae2c931ffeec4d1cc2'),
    ('en', 'pl', 'b0b59716bcc8f46b8dc6ab5c32a2732acaad42a5a6d9ae9b472526a1bb0d71d4'),
    ('en', 'pt', '07892fd2544ee79dcb643615d8f2debb9793fae16842e87c328e27a3dd26a770'),
    ('en', 'ru', '184cb5cda528eeefc0f75f5d0035d787b71d74af135e3c5608d01ae02ecfb920'),
    ('en', 'tr', 'ea3cd4ee09de190df265c78d84260e277a9a8a3ddff05eb55d72afe7fc0fdbf4'),
    ('en', 'uk', 'ed8bb4a811e1c45a259e91052080d25e5c8b4e2df0e59cb1521c04a57855ef97'),
    ('en', 'vi', '04fa6044593a404c2aa02b3096f203880852df6f8f41e5eb966ed9f2b4366737'),
    ('en', 'zh', '4e5accc141373565ddc8fa1565bceaa8d0c3482a82cab8131c719ebcc6c2157c'),
    ('en', 'zh_hant', '559ab90d723a58c1f1e2ab7cc12137bc667af5ba3e325e3eb30b5cdc930db520'),
    ('es', 'en', '4aed7734152ae0045d1a69ae49c86cfda18f53c61f90e95e1d1de1c7c7c3b033'),
    ('fa', 'en', 'aa326306c177e11129de5bfeba518abc499c0b6005492766748a9c9ea6f4c712'),
    ('fr', 'en', '15f997bc0d13808b0b0fbd0786e684a3c8a52adcd8071844b76123fdacbf2b90'),
    ('hi', 'en', 'c82fd6ed3794b79fb9dde0718a22324502a408a9eca73497b5d0a4b8024ec6de'),
    ('id', 'en', 'eeed3d8c2c78ec7011b31b2419e1d2dfdf2a7cc0ee0dbb1fcd164c934cb5d328'),
    ('it', 'en', '21b70978ce2f3b4da7a06b5de86a09abe3acd30b9eee1b2ebb3582b9bad790bf'),
    ('pl', 'en', '06dbab3baa3bbceab746bc6a3bba807878f38536382c03acddf59d3edf3b5d94'),
    ('pt', 'en', '7b854f1ec5a485dd33efd7c1bc01dd7d5a57f566957c5e47722af333f0ce9157'),
    ('ru', 'en', 'aa0efa194b3dbd2da129ba0b8db8ef139126cb0914e57072f62061294746f1e2'),
    ('tr', 'en', 'bd18594ac5a7f1d9997e7ea5bd80272082219cf8b1ce604766e4f207eb86abbf'),
    ('uk', 'en', '2e7b8bc9d2569d8b4ae244e964cdc343a0aa3735cc83ecb664be84a37cb45f48'),
    ('vi', 'en', 'de4bf2b9ffb4d910e32720ec3a43655fb6f4062ce5219332f824fc1bdca7a5f4'),
    ('zh', 'en', '5cd149601802fc8a18124a1c1306144dbbedc058630c4ddb2d53aa76fa9c7c06'),
    ('zh_hant', 'en', '0aee91790894458f5d367551f6edcd4c9cb97852c34f221bcbf9f4701ebcf0cd'),
]
models = {(f, t): m for f, t, m in checked}
for p in tm['pairs']:
    model = [x for x in p['files'] if x['kind'] == 'model']
    if len(model) != 1:
        sys.exit('translate/models.json: %s-%s has no one model file' % (p['from'], p['to']))
    if models.get((p['from'], p['to'])) != model[0]['sha256']:
        sys.exit('translate/models.json: %s-%s is a model whose licence is not checked here' % (p['from'], p['to']))
for f, t, m in checked:
    translation.append(part('Translation model, %s to %s' % (langs[f], langs[t]), m[:8], 'MPL-2.0', [root]))
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
