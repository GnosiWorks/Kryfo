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
  final String? senderEdPub; // 'e' field, hex
  final String? senderOnion; // 'o' field
  final String? senderXPub; // 'x' field, hex
  final int? burnSeconds; // 'b' field — seconds-from-receive
  final String? msgUid; // 'u' field — stable cross-device message id
  final ReactionFrame? reaction; // 'r' field — present on reaction control msgs
  final EditFrame? edit; // 'ed' field — present on edit control msgs
  final String? replyTo; // 'q' field — msg_uid this message replies to
  final String? groupId; // 'g' field — present for group messages
  final GroupControl?
  groupControl; // 'gc' field — present on group control msgs
  final String? imageB64; // 'i' field — base64-encoded compressed jpeg
  final String? unsend; // 'un' field - recalled msg_uid
  UnwrappedMessage(
    this.message, {
    this.endpoint,
    this.senderHaloId,
    this.senderEdPub,
    this.senderOnion,
    this.senderXPub,
    this.burnSeconds,
    this.msgUid,
    this.reaction,
    this.edit,
    this.replyTo,
    this.groupId,
    this.groupControl,
    this.imageB64,
    this.unsend,
  });
}

/// A group "control message" — when present in an envelope, the payload
/// is not a message body but a group state update (create, member add/remove,
/// rename, leave). The 'm' body should be ignored when this is present.
class GroupControl {
  final String type; // 'create' | 'add' | 'remove' | 'rename' | 'leave'
  final String? name; // present on 'create' and 'rename'
  final List<String>?
  members; // full member list on 'create'; the target halo id list on 'add'/'remove'
  // participants carries full SenderInfo (halo_id + onion + xpub) for each
  // member the receiver might not already have as a contact. populated on
  // 'create' (every member) and 'add' (each newly added member). receivers
  // auto-create contact stubs from this so subsequent group sends work.
  final List<Map<String, String>>? participants;
  const GroupControl({
    required this.type,
    this.name,
    this.members,
    this.participants,
  });
}

/// A reaction "control message" — when present in an envelope, the payload
/// is not a message body but a reaction (add or remove) on a previous one.
class ReactionFrame {
  final String targetUid; // the msg_uid this reaction applies to
  final String emoji; // '' means remove the reactor's reaction
  const ReactionFrame({required this.targetUid, required this.emoji});
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
class EditFrame {
  final String targetUid;
  final String newText;
  const EditFrame({required this.targetUid, required this.newText});
}

Future<String> wrapMessage(
  String plain, {
  SenderInfo? sender,
  int? burnSeconds,
  String? msgUid,
  ReactionFrame? reaction,
  EditFrame? edit,
  String? replyTo,
  String? groupId,
  GroupControl? groupControl,
  String? imageB64,
  String? unsend,
}) async {
  final mode = await loadPushMode();
  final body = <String, dynamic>{'m': plain};
  if (msgUid != null) body['u'] = msgUid;
  if (reaction != null) {
    body['r'] = {'u': reaction.targetUid, 'e': reaction.emoji};
  }
  if (edit != null) {
    body['ed'] = {'u': edit.targetUid, 'm': edit.newText};
  }
  if (replyTo != null) body['q'] = replyTo;
  if (imageB64 != null) body['i'] = imageB64;
  if (unsend != null) body['un'] = unsend;

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
  if (groupId != null) body['g'] = groupId;
  if (groupControl != null) {
    final gc = <String, dynamic>{'t': groupControl.type};
    if (groupControl.name != null) gc['n'] = groupControl.name;
    if (groupControl.members != null) gc['m'] = groupControl.members;
    if (groupControl.participants != null) gc['p'] = groupControl.participants;
    body['gc'] = gc;
  }
  return '$_envelopePrefix${jsonEncode(body)}';
}

UnwrappedMessage unwrapMessage(String wrapped) {
  if (!wrapped.startsWith(_envelopePrefix)) {
    return UnwrappedMessage(wrapped);
  }
  try {
    final json =
        jsonDecode(wrapped.substring(_envelopePrefix.length))
            as Map<String, dynamic>;
    ReactionFrame? reaction;
    final rRaw = json['r'];
    if (rRaw is Map) {
      reaction = ReactionFrame(
        targetUid: (rRaw['u'] as String?) ?? '',
        emoji: (rRaw['e'] as String?) ?? '',
      );
    }
    EditFrame? edit;
    final edRaw = json['ed'];
    if (edRaw is Map) {
      edit = EditFrame(
        targetUid: (edRaw['u'] as String?) ?? '',
        newText: (edRaw['m'] as String?) ?? '',
      );
    }
    GroupControl? gc;
    final gcRaw = json['gc'];
    if (gcRaw is Map) {
      final membersRaw = gcRaw['m'];
      final partsRaw = gcRaw['p'];
      List<Map<String, String>>? parts;
      if (partsRaw is List) {
        parts = [];
        for (final e in partsRaw) {
          if (e is Map) {
            parts.add(e.map((k, v) => MapEntry(k.toString(), v.toString())));
          }
        }
      }
      gc = GroupControl(
        type: (gcRaw['t'] as String?) ?? '',
        name: gcRaw['n'] as String?,
        members: membersRaw is List
            ? membersRaw.map((e) => e.toString()).toList()
            : null,
        participants: parts,
      );
    }
    return UnwrappedMessage(
      (json['m'] as String?) ?? '',
      endpoint: json['p'] as String?,
      senderHaloId: json['h'] as String?,
      senderEdPub: json['e'] as String?,
      senderOnion: json['o'] as String?,
      senderXPub: json['x'] as String?,
      burnSeconds: (json['b'] as num?)?.toInt(),
      msgUid: json['u'] as String?,
      reaction: reaction,
      edit: edit,
      replyTo: json['q'] as String?,
      groupId: json['g'] as String?,
      groupControl: gc,
      imageB64: json['i'] as String?,
      unsend: json['un'] as String?,
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
