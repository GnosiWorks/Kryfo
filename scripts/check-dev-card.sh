#!/bin/bash
# the developer card a final release pins carries the post-quantum prekey,
# so a new dev chat can start on it. reads mobile/lib/devchat/dev_key.dart
# on stdin (git show <ref>:mobile/lib/devchat/dev_key.dart | this -) and
# checks the bundle of the one key in kDevKeys that is current
set -euo pipefail
[ "${1:-}" = "-" ] || { echo "usage: git show <ref>:mobile/lib/devchat/dev_key.dart | check-dev-card.sh -" >&2; exit 2; }
python3 -I -c '
import base64, json, re, sys
src = sys.stdin.read()
at = src.index("const kDevKeys")
body = src[at:src.index("];", at)]
current = []
for k in re.findall(r"DevKey\((.*?)\n  \),", body, re.S):
    if re.search(r"status:\s*DevKeyStatus\.(previous|retired)", k):
        continue
    m = re.search(r"bundle:\s*\x27([A-Za-z0-9+/=]+)\x27", k)
    if not m:
        sys.exit("a current dev key without a bundle")
    current.append(json.loads(base64.b64decode(m.group(1))))
if len(current) != 1:
    sys.exit("not exactly one current dev key")
card = current[0]
for f in ("kyberPreKeyId", "kyberPreKeyPublic", "kyberPreKeySignature"):
    if f not in card:
        sys.exit("the current dev card has no kyber prekey: a new dev chat cannot start on it")
print("ok  the current dev card carries the kyber prekey")
'
