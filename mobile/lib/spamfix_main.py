import sys
s = open('main.dart', encoding='utf-8').read()
orig = s

def swap(name, old, new, marker):
    global s
    if marker in s:
        print(f'{name}: already applied'); return
    if s.count(old) != 1:
        print(f'{name}: MISS ({s.count(old)})'); sys.exit(1)
    s = s.replace(old, new, 1); print(f'{name}: ok')

# helper: is this wire a prekey message? back-pair can only rebuild from a
# prekey - a whisper with no matching session is just undeliverable, so
# attempting back-pair on it only spams 'failed'. skip cleanly.
swap(
    'isprekey-helper',
    "Future<String?> signalDecrypt(",
    """bool _isPreKeyWire(String wireB64) {
  try {
    final w = base64Decode(wireB64);
    return w.isNotEmpty && w[0] == CiphertextMessage.prekeyType;
  } catch (_) {
    return false;
  }
}

Future<String?> signalDecrypt(""",
    marker='bool _isPreKeyWire(',
)

# onion back-pair: guard
swap(
    'onion-prekey-guard',
    '''          if (!handled) {
            final paired = await backPairFromCipher(cipher);
            handled = paired != null;
            debugPrint('drain: back-pair ${paired != null ? "ok $paired" : "failed"}');
          }''',
    '''          if (!handled && _isPreKeyWire(cipher)) {
            final paired = await backPairFromCipher(cipher);
            handled = paired != null;
            debugPrint('drain: back-pair ${paired != null ? "ok $paired" : "failed"}');
          }''',
    marker="if (!handled && _isPreKeyWire(cipher)) {",
)

# relay back-pair: same guard
swap(
    'relay-prekey-guard',
    """          if (wrapped == null) {
            final paired = await backPairFromCipher(m.cipher);
            debugPrint(
              'nostr: back-pair ${paired != null ? "ok $paired" : "failed"}',
            );""",
    """          if (wrapped == null && _isPreKeyWire(m.cipher)) {
            final paired = await backPairFromCipher(m.cipher);
            debugPrint(
              'nostr: back-pair ${paired != null ? "ok $paired" : "failed"}',
            );""",
    marker="if (wrapped == null && _isPreKeyWire(m.cipher)) {",
)

if s != orig:
    open('main.dart', 'w', encoding='utf-8').write(s)
print('main spam ok')
