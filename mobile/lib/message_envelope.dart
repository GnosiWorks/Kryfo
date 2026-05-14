// message_envelope.dart — wrap outgoing plain text with optional metadata
// (currently: ntfy endpoint advertisement) so the peer learns our push
// endpoint over the existing encrypted channel. wrapped messages use the
// sentinel prefix "halo/1:" followed by a JSON object so legacy plain
// messages pass through unchanged.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'push_mode.dart';

const _envelopePrefix = 'halo/1:';
const _peerEndpointPrefix = 'ntfy_peer_endpoint_';

class UnwrappedMessage {
  final String message;
  final String? endpoint;
  UnwrappedMessage(this.message, this.endpoint);
}

// wrap: only advertise endpoint when our push mode is ntfy. otherwise
// return plain so we don't leak metadata to peers we haven't opted in to
// being woken by.
Future<String> wrapMessage(String plain) async {
  final mode = await loadPushMode();
  if (mode != PushMode.ntfy) return plain;

  final topic = await loadNtfyTopic();
  final server = await loadNtfyServer();
  final endpoint = composeNtfyEndpoint(server, topic);

  final body = jsonEncode({'m': plain, 'p': endpoint});
  return '$_envelopePrefix$body';
}

UnwrappedMessage unwrapMessage(String wrapped) {
  if (!wrapped.startsWith(_envelopePrefix)) {
    return UnwrappedMessage(wrapped, null);
  }
  try {
    final json = jsonDecode(wrapped.substring(_envelopePrefix.length))
        as Map<String, dynamic>;
    final m = (json['m'] as String?) ?? '';
    final p = json['p'] as String?;
    return UnwrappedMessage(m, p);
  } catch (_) {
    // malformed — treat as plain
    return UnwrappedMessage(wrapped, null);
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
