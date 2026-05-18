// message_envelope.dart — wrap outgoing plain text with optional metadata
// (ntfy endpoint + sender identity for back-pair) so the peer learns our
// push endpoint and identity over the existing encrypted channel. wrapped
// messages use the sentinel prefix "halo/1:" + JSON object so legacy plain
// messages pass through unchanged.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'push_mode.dart';

const _envelopePrefix = 'halo/1:';
const _peerEndpointPrefix = 'ntfy_peer_endpoint_';

class UnwrappedMessage {
  final String message;
  final String? endpoint;
  final String? senderHaloId; // 'h' field
  final String? senderEdPub;  // 'e' field, hex
  final String? senderOnion;  // 'o' field
  final String? senderXPub;   // 'x' field, hex
  final int? burnSeconds;     // 'b' field — seconds-from-receive
  UnwrappedMessage(
    this.message, {
    this.endpoint,
    this.senderHaloId,
    this.senderEdPub,
    this.senderOnion,
    this.senderXPub,
    this.burnSeconds,
  });
}

class SenderInfo {
  final String haloId;
  final String edPub;
  final String onion;
  final String xPub;
  const SenderInfo({
    required this.haloId,
    required this.edPub,
    required this.onion,
    required this.xPub,
  });
}

// wrap: always includes sender identity now (cheap, enables back-pair).
// endpoint is added only when push mode is ntfy.
Future<String> wrapMessage(String plain, {SenderInfo? sender, int? burnSeconds}) async {
  final mode = await loadPushMode();
  final body = <String, dynamic>{'m': plain};

  if (mode == PushMode.ntfy) {
    final topic = await loadNtfyTopic();
    final server = await loadNtfyServer();
    body['p'] = composeNtfyEndpoint(server, topic);
  }
  if (sender != null) {
    body['h'] = sender.haloId;
    body['e'] = sender.edPub;
    body['o'] = sender.onion;
    body['x'] = sender.xPub;
  }
  if (burnSeconds != null && burnSeconds > 0) {
    body['b'] = burnSeconds;
  }
  return '$_envelopePrefix${jsonEncode(body)}';
}

UnwrappedMessage unwrapMessage(String wrapped) {
  if (!wrapped.startsWith(_envelopePrefix)) {
    return UnwrappedMessage(wrapped);
  }
  try {
    final json = jsonDecode(wrapped.substring(_envelopePrefix.length))
        as Map<String, dynamic>;
    return UnwrappedMessage(
      (json['m'] as String?) ?? '',
      endpoint: json['p'] as String?,
      senderHaloId: json['h'] as String?,
      senderEdPub: json['e'] as String?,
      senderOnion: json['o'] as String?,
      senderXPub: json['x'] as String?,
      burnSeconds: (json['b'] as num?)?.toInt(),
    );
  } catch (_) {
    return UnwrappedMessage(wrapped);
  }
}

Future<void> savePeerEndpoint(String peerHaloId, String endpoint) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('$_peerEndpointPrefix$peerHaloId', endpoint);
}

Future<String?> loadPeerEndpoint(String peerHaloId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('$_peerEndpointPrefix$peerHaloId');
}
