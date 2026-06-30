// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';

// fast-mode transport: a persistent wss link to the halo relay. it carries the
// same opaque libsignal ciphertext the tor path does - the relay can't read it,
// only route it. fast path for speed; pair with the nostr mailbox as the
// durable fallback so nothing is lost if the peer is offline past the relay's
// queue window.
class RelayClient {
  final String url; // wss://your-relay/ws
  final String myXpub; // our routing key
  final void Function(String fromXpub, String b64cipher) onMessage;

  WebSocket? _ws;
  bool _closed = false;
  int _backoff = 1;
  Timer? _retry;

  RelayClient({
    required this.url,
    required this.myXpub,
    required this.onMessage,
  });

  Future<void> start() async {
    _closed = false;
    await _connect();
  }

  Future<void> _connect() async {
    if (_closed) return;
    try {
      final ws = await WebSocket.connect(url);
      ws.pingInterval = const Duration(seconds: 30);
      _ws = ws;
      _backoff = 1;
      ws.add(jsonEncode({'type': 'hello', 'key': myXpub}));
      ws.listen(
        _onFrame,
        onDone: _reconnectLater,
        onError: (_) => _reconnectLater(),
        cancelOnError: true,
      );
    } catch (_) {
      _reconnectLater();
    }
  }

  void _onFrame(dynamic raw) {
    if (raw is! String) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (m['type'] == 'msg') {
        final from = m['key'] as String? ?? '';
        final payload = m['payload'] as String? ?? '';
        if (from.isNotEmpty && payload.isNotEmpty) onMessage(from, payload);
      }
    } catch (_) {}
  }

  // true = handed to a live socket. false = not connected, so the caller should
  // lean on the nostr mailbox fallback for durability.
  bool send(String toXpub, String b64cipher) {
    final ws = _ws;
    if (ws == null || ws.readyState != WebSocket.open) return false;
    ws.add(jsonEncode({'type': 'send', 'to': toXpub, 'payload': b64cipher}));
    return true;
  }

  bool get connected => _ws?.readyState == WebSocket.open;

  void _reconnectLater() {
    _ws = null;
    if (_closed) return;
    _retry?.cancel();
    final wait = _backoff;
    _backoff = (_backoff * 2).clamp(1, 60);
    _retry = Timer(Duration(seconds: wait), _connect);
  }

  Future<void> stop() async {
    _closed = true;
    _retry?.cancel();
    await _ws?.close();
    _ws = null;
  }
}
