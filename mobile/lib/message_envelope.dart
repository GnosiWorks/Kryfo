// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/foundation.dart';
// message_envelope.dart - wrap outgoing plain text with optional metadata
// (ntfy endpoint + sender identity for back-pair) so the peer learns our
// push endpoint and identity over the existing encrypted channel. wrapped
// messages use the sentinel prefix "halo/1:" + JSON object so legacy plain
// messages pass through unchanged.

import 'dart:convert';
import 'package:crypto/crypto.dart';
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
  final int? burnSeconds; // 'b' field - seconds-from-receive
  final String? msgUid; // 'u' field - stable cross-device message id
  final ReactionFrame? reaction; // 'r' field - present on reaction control msgs
  final PinFrame? pin; // 'pn' field - shared pin/unpin control msgs
  final EditFrame? edit; // 'ed' field - present on edit control msgs
  final String? replyTo; // 'q' field - msg_uid this message replies to
  final String? groupId; // 'g' field - present for group messages
  final GroupControl?
  groupControl; // 'gc' field - present on group control msgs
  final String? imageB64; // 'i' field - base64-encoded compressed jpeg
  final String? unsend; // 'un' field - recalled msg_uid
  final String? fileB64; // 'f' field - base64 file bytes
  final String? fileName; // 'fn' field - original display name
  final bool voice; // 'vo' field - true when the file is a voice note
  final bool voiceDisguised; // 'vd' field - voice note was pitch-shifted
  final Map<String, String>? preview; // 'pv' field - link preview card data
  final String? mediaId; // 'mid' - groups chunks of one big media together
  final int? chunkIndex; // 'ci' - this chunk's position, 0-based
  final int? chunkTotal; // 'ct' - how many chunks make the whole media
  final bool pvImg; // 'pi' - reassembled chunks are a preview thumbnail
  final List<String>? roster; // 'rs' - admin's full member list, self-heals
  final List<Map<String, String>>?
  rosterParticipants; // 'rp' - {h,o,x} keys for roster members
  final int? powNonce; // 'pw' - proof-of-work nonce (first-contact only)
  final int? powBitsUsed; // 'pb' - difficulty the sender solved to
  final String? supporterBadge; // 'bg' - sender's shared supporter tier
  final String? deliveredUid; // 'dr' - receipt: uid the peer just stored
  final bool secure; // 'sc' - sender asked that this not be screenshotted
  UnwrappedMessage(
    this.message, {
    this.secure = false,
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
    this.pin,
    this.groupId,
    this.groupControl,
    this.imageB64,
    this.unsend,
    this.fileB64,
    this.fileName,
    this.voice = false,
    this.voiceDisguised = false,
    this.preview,
    this.mediaId,
    this.chunkIndex,
    this.chunkTotal,
    this.pvImg = false,
    this.roster,
    this.rosterParticipants,
    this.powNonce,
    this.powBitsUsed,
    this.supporterBadge,
    this.deliveredUid,
  });
}

/// A group "control message" - when present in an envelope, the payload
/// is not a message body but a group state update (create, member add/remove,
/// rename, leave). The 'm' body should be ignored when this is present.
class GroupControl {
  final String type; // 'create' | 'add' | 'remove' | 'rename' | 'leave'
  final String? name; // present on 'create' and 'rename'
  final List<String>?
  members; // full member list on 'create'; the target kryfo id list on 'add'/'remove'
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

/// A reaction "control message" - when present in an envelope, the payload
/// is not a message body but a reaction (add or remove) on a previous one.
class ReactionFrame {
  final String targetUid; // the msg_uid this reaction applies to
  final String emoji; // '' means remove the reactor's reaction
  const ReactionFrame({required this.targetUid, required this.emoji});
}

class PinFrame {
  final String targetUid;
  final bool pinned;
  const PinFrame({required this.targetUid, required this.pinned});
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

// proof-of-work: first-contact messages carry a nonce that makes the sha256
// of (body-without-pow + nonce) start with _powBits zero bits. ~2s to grind at
// 20, milliseconds to verify. transport-independent - hashes the envelope, not
// any nostr event, so it survives a transport swap.
const int powBits = 20;

int _leadingZeroBits(List<int> hash) {
  var bits = 0;
  for (final b in hash) {
    if (b == 0) {
      bits += 8;
      continue;
    }
    var v = b;
    while (v & 0x80 == 0) {
      bits++;
      v <<= 1;
    }
    break;
  }
  return bits;
}

// grind a nonce so sha256(seed + nonce) has >= bits leading zeros. runs on the
// caller's isolate - callers should wrap in compute() to keep the ui smooth.
int grindPow(String seed, int bits) {
  var nonce = 0;
  while (true) {
    final h = sha256.convert(utf8.encode('$seed$nonce')).bytes;
    if (_leadingZeroBits(h) >= bits) return nonce;
    nonce++;
  }
}

bool verifyPow(String seed, int nonce, int bits) {
  final h = sha256.convert(utf8.encode('$seed$nonce')).bytes;
  return _leadingZeroBits(h) >= bits;
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
  PinFrame? pin,
  String? fileB64,
  String? fileName,
  bool voice = false,
  bool voiceDisguised = false,
  Map<String, String>? preview,
  String? mediaId,
  int? chunkIndex,
  int? chunkTotal,
  bool pvImg = false,
  List<String>? roster,
  List<Map<String, String>>? rosterParticipants,
  int? powNonce,
  int? powBitsUsed,
  String? deliveredUid,
  String? supporterBadge,
  bool secure = false,
}) async {
  final mode = await loadPushMode();
  final body = <String, dynamic>{'m': plain};
  if (msgUid != null) body['u'] = msgUid;
  if (reaction != null) {
    body['r'] = {'u': reaction.targetUid, 'e': reaction.emoji};
  }
  if (pin != null) {
    body['pn'] = {'u': pin.targetUid, 'p': pin.pinned ? 1 : 0};
  }
  if (edit != null) {
    body['ed'] = {'u': edit.targetUid, 'm': edit.newText};
  }
  if (replyTo != null) body['q'] = replyTo;
  if (imageB64 != null) body['i'] = imageB64;
  if (unsend != null) body['un'] = unsend;
  if (deliveredUid != null) body['dr'] = deliveredUid;
  if (fileB64 != null) body['f'] = fileB64;
  if (fileName != null) body['fn'] = fileName;
  if (voice) body['vo'] = 1;
  if (voiceDisguised) body['vd'] = 1;
  if (preview != null && preview.isNotEmpty) body['pv'] = preview;
  if (mediaId != null) body['mid'] = mediaId;
  if (chunkIndex != null) body['ci'] = chunkIndex;
  if (chunkTotal != null) body['ct'] = chunkTotal;
  if (pvImg) body['pi'] = 1;
  if (roster != null) body['rs'] = roster;
  if (rosterParticipants != null) body['rp'] = rosterParticipants;
  if (powNonce != null) body['pw'] = powNonce;
  if (powBitsUsed != null) body['pb'] = powBitsUsed;
  if (supporterBadge != null) body['bg'] = supporterBadge;
  if (secure) body['sc'] = 1;

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
    PinFrame? pin;
    final pnRaw = json['pn'];
    if (pnRaw is Map) {
      pin = PinFrame(
        targetUid: (pnRaw['u'] as String?) ?? '',
        pinned: (pnRaw['p'] as int? ?? 0) == 1,
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
    Map<String, String>? preview;
    final pvRaw = json['pv'];
    if (pvRaw is Map) {
      preview = pvRaw.map((k, v) => MapEntry(k.toString(), v.toString()));
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
      pin: pin,
      edit: edit,
      replyTo: json['q'] as String?,
      groupId: json['g'] as String?,
      groupControl: gc,
      imageB64: json['i'] as String?,
      unsend: json['un'] as String?,
      deliveredUid: json['dr'] as String?,
      secure: json['sc'] == 1,
      fileB64: json['f'] as String?,
      fileName: json['fn'] as String?,
      voice: json['vo'] == 1,
      voiceDisguised: json['vd'] == 1,
      preview: preview,
      mediaId: json['mid'] as String?,
      chunkIndex: (json['ci'] as num?)?.toInt(),
      chunkTotal: (json['ct'] as num?)?.toInt(),
      pvImg: json['pi'] == 1,
      roster: (json['rs'] as List?)?.map((e) => e.toString()).toList(),
      powNonce: (json['pw'] as num?)?.toInt(),
      supporterBadge: json['bg'] as String?,
      powBitsUsed: (json['pb'] as num?)?.toInt(),
      rosterParticipants: (json['rp'] as List?)
          ?.map(
            (e) =>
                (e as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
          )
          .toList(),
    );
  } catch (e) {
    debugPrint(
      'UNWRAP-FAIL $e raw=${wrapped.substring(0, wrapped.length < 80 ? wrapped.length : 80)}',
    );
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
