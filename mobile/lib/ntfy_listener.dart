// ntfy_listener.dart — keeps a websocket alive to the user's ntfy server
// so an external ping triggers an immediate Nostr drain. when push mode
// is not ntfy, the listener is dormant.

import 'dart:async';
import 'dart:io';
import 'push_mode.dart';

class NtfyListener {
  WebSocket? _socket;
  bool _running = false;
  int _retryMs = 1000;
  final void Function() onPing;
  final void Function(String msg) log;

  NtfyListener({required this.onPing, this.log = print});

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _loop();
  }

  Future<void> stop() async {
    _running = false;
    final s = _socket;
    _socket = null;
    if (s != null) {
      try { await s.close(); } catch (_) {}
    }
  }

  Future<void> _loop() async {
    while (_running) {
      try {
        final server = await loadNtfyServer();
        final topic = await loadNtfyTopic();
        final wsUrl = _toWs(server, topic);
        log('ntfy: connecting $wsUrl');
        _socket = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 30));
        _retryMs = 1000;
        log('ntfy: connected');

        await for (final raw in _socket!) {
          if (!_running) break;
          final s = raw is String ? raw : '';
          // ntfy emits "open" + heartbeat messages too; only fire on
          // event:message
          if (s.contains('"event":"message"')) {
            log('ntfy: ping received -> draining');
            onPing();
          }
        }
      } catch (e) {
        log('ntfy: ws error: $e');
      }
      _socket = null;
      if (!_running) break;
      await Future.delayed(Duration(milliseconds: _retryMs));
      _retryMs = (_retryMs * 2).clamp(1000, 60000);
    }
  }

  // server "https://ntfy.sh" + topic "abc" -> "wss://ntfy.sh/abc/ws"
  // server "http://localhost:8080" + topic "abc" -> "ws://localhost:8080/abc/ws"
  String _toWs(String server, String topic) {
    var s = server;
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    s = s.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
    return '$s/$topic/ws';
  }
}
