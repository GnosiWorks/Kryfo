// SPDX-License-Identifier: GPL-3.0-or-later
// wraps outgoing text with its metadata as "halo/1:" + json, so plain
// messages without the prefix pass through unchanged.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'bidi_safe.dart';
import 'dlog.dart';
import 'media_resend.dart';
import 'stickers/sticker_wire.dart' show StickerWire;

const _envelopePrefix = 'halo/1:';

class UnwrappedMessage {
  final String message;
  final String? senderHaloId; // 'h' field
  final String? senderEdPub; // 'e' field, hex
  final String? senderOnion; // 'o' field
  final String? senderXPub; // 'x' field, hex
  final int? senderAvatar; // 'av' - the face they picked, drawn from a number
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
  final IntroFrame? intro; // 'in' - a contact's card, vouched by the sender
  final NeedFrame? need; // 'nd' - slices of a file the receiver never got
  final bool canResend; // 'cr' - on a slice: this sender answers an 'nd'
  final Object? poll; // 'pl' - the options of a poll; the question is 'm'
  final VoteFrame? vote; // 'vt' - a vote on a poll
  final PollCloseFrame? pollClose; // 'pc' - the creator closed a poll
  final String? sticker; // 'st' - pack:id:since, drawn from our own pack
  final int? supportMarker; // 'sp' - written in a chat with the developer
  // 'm' as it was sent, before the direction controls came out: the
  // proof of work was done over these characters
  final String? powText;
  UnwrappedMessage(
    this.message, {
    this.powText,
    this.secure = false,
    this.senderHaloId,
    this.senderEdPub,
    this.senderOnion,
    this.senderXPub,
    this.senderAvatar,
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
    this.intro,
    this.need,
    this.canResend = false,
    this.poll,
    this.vote,
    this.pollClose,
    this.sticker,
    this.supportMarker,
  });
}

/// a group state update. the 'm' body is ignored when this is present.
class GroupControl {
  final String type; // 'create' | 'add' | 'remove' | 'rename' | 'leave'
  final String? name; // present on 'create' and 'rename'
  final List<String>?
  members; // full member list on 'create'; the target kryfo id list on 'add'/'remove'
  // keys for members the receiver may not have as contacts, on 'create' and
  // 'add'. receivers make contact stubs from it so group sends work.
  final List<Map<String, String>>? participants;
  const GroupControl({
    required this.type,
    this.name,
    this.members,
    this.participants,
  });
}

/// a reaction added or removed on an earlier message
class ReactionFrame {
  final String targetUid; // the msg_uid this reaction applies to
  final String emoji; // '' means remove the reactor's reaction
  const ReactionFrame({required this.targetUid, required this.emoji});
}

// a vote on a poll. choices are option numbers; none takes the vote back.
// seq only goes up for one voter on one poll: the highest one held wins.
class VoteFrame {
  final String pollUid;
  final List<Object?> choices;
  final int seq;
  const VoteFrame({
    required this.pollUid,
    required this.choices,
    required this.seq,
  });
}

// the creator closed a poll. carries the votes as the creator had them, so
// every phone shows the same final result.
class PollCloseFrame {
  final String pollUid;
  final Object? finalVotes;
  const PollCloseFrame({required this.pollUid, this.finalVotes});
}

class PinFrame {
  final String targetUid;
  final bool pinned;
  const PinFrame({required this.targetUid, required this.pinned});
}

// a third person's card, vouched for by the sender: what a group invite
// carries plus the introducer's note. no nickname ever rides here.
class IntroFrame {
  final String haloId;
  final String onion;
  final String xPub;
  final String? edPub;
  final int? avatar;
  final String? fc; // their first-contact address, if the sender has one
  final String? note;
  const IntroFrame({
    required this.haloId,
    required this.onion,
    required this.xPub,
    this.edPub,
    this.avatar,
    this.fc,
    this.note,
  });
}

class SenderInfo {
  final String haloId;
  final String edPub;
  final String onion;
  final String xPub;
  final int? avatar;
  const SenderInfo({
    required this.haloId,
    required this.edPub,
    required this.onion,
    required this.xPub,
    this.avatar,
  });
}

class EditFrame {
  final String targetUid;
  final String newText;
  const EditFrame({required this.targetUid, required this.newText});
}

// first-contact messages carry a nonce so sha256(body + nonce) starts with
// powBits zero bits: about 2s to grind, milliseconds to verify. it hashes the
// envelope, not a transport event, so it survives a transport swap.
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

// since when a grind is running. the chat shows a line under the composer
// while it is set, as a slow phone can take a minute.
final ValueNotifier<DateTime?> powBusy = ValueNotifier(null);

// runs on the caller's isolate: wrap it in compute() to keep the ui smooth
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
  IntroFrame? intro,
  NeedFrame? need,
  bool canResend = false,
  Map<String, Object>? poll,
  VoteFrame? vote,
  PollCloseFrame? pollClose,
  String? sticker,
  int? supportMarker,
}) async {
  final body = <String, dynamic>{'m': plain};
  if (sticker != null) body['st'] = sticker;
  if (supportMarker != null) body['sp'] = supportMarker;
  if (poll != null) body['pl'] = poll;
  if (vote != null) {
    body['vt'] = {'u': vote.pollUid, 'c': vote.choices, 's': vote.seq};
  }
  if (pollClose != null) {
    body['pc'] = {'u': pollClose.pollUid, 'f': pollClose.finalVotes};
  }
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
  if (intro != null) {
    final card = <String, dynamic>{
      'h': intro.haloId,
      'o': intro.onion,
      'x': intro.xPub,
    };
    if (intro.edPub != null) card['e'] = intro.edPub;
    if (intro.avatar != null) card['av'] = intro.avatar;
    if (intro.fc != null && intro.fc!.isNotEmpty) card['fc'] = intro.fc;
    if (intro.note != null && intro.note!.isNotEmpty) card['n'] = intro.note;
    body['in'] = card;
  }
  if (replyTo != null) body['q'] = replyTo;
  if (imageB64 != null) body['i'] = imageB64;
  if (unsend != null) body['un'] = unsend;
  if (deliveredUid != null) body['dr'] = deliveredUid;
  if (need != null) body['nd'] = need.toJson();
  if (canResend) body['cr'] = 1;
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

  if (sender != null) {
    body['h'] = sender.haloId;
    if (sender.avatar != null) body['av'] = sender.avatar;
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
    return UnwrappedMessage(unmarked(wrapped), powText: wrapped);
  }
  try {
    final sent =
        jsonDecode(wrapped.substring(_envelopePrefix.length))
            as Map<String, dynamic>;
    // every word in it without direction controls (bidi_safe.dart), the
    // images and files as they came
    final json =
        unmarkedJson(sent, skip: const {'i', 'f'}) as Map<String, dynamic>;
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
    IntroFrame? intro;
    final inRaw = json['in'];
    if (inRaw is Map) {
      final h = inRaw['h'] as String?;
      final o = inRaw['o'] as String?;
      final x = inRaw['x'] as String?;
      // a card without keys is nothing we could ever message. drop it here so
      // the receiver never sees a half card.
      if (h != null && h.isNotEmpty && o != null && x != null && x.isNotEmpty) {
        intro = IntroFrame(
          haloId: h,
          onion: o,
          xPub: x,
          edPub: inRaw['e'] as String?,
          avatar: (inRaw['av'] as num?)?.toInt(),
          fc: inRaw['fc'] as String?,
          note: inRaw['n'] as String?,
        );
      }
    }
    VoteFrame? vote;
    final vtRaw = json['vt'];
    if (vtRaw is Map &&
        vtRaw['u'] is String &&
        vtRaw['c'] is List &&
        vtRaw['s'] is num) {
      vote = VoteFrame(
        pollUid: vtRaw['u'] as String,
        choices: vtRaw['c'] as List,
        seq: (vtRaw['s'] as num).toInt(),
      );
    }
    PollCloseFrame? pollClose;
    final pcRaw = json['pc'];
    if (pcRaw is Map && pcRaw['u'] is String) {
      pollClose = PollCloseFrame(
        pollUid: pcRaw['u'] as String,
        finalVotes: pcRaw['f'],
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
      powText: sent['m'] as String?,
      senderHaloId: json['h'] as String?,
      senderAvatar: (json['av'] as num?)?.toInt(),
      senderEdPub: json['e'] as String?,
      senderOnion: json['o'] as String?,
      senderXPub: json['x'] as String?,
      burnSeconds: (json['b'] as num?)?.toInt(),
      msgUid: json['u'] as String?,
      reaction: reaction,
      pin: pin,
      edit: edit,
      intro: intro,
      replyTo: json['q'] as String?,
      groupId: json['g'] as String?,
      groupControl: gc,
      imageB64: json['i'] as String?,
      unsend: json['un'] as String?,
      deliveredUid: json['dr'] as String?,
      need: NeedFrame.fromJson(json['nd']),
      canResend: json['cr'] == 1,
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
      poll: json['pl'],
      vote: vote,
      pollClose: pollClose,
      // the raw value: one with direction controls in it is no sticker
      sticker: StickerWire.parse(sent['st'])?.value,
      supportMarker: switch (json['sp']) {
        final num n => n.toInt(),
        _ => null,
      },
    );
  } catch (e) {
    dlog(
      'UNWRAP-FAIL $e raw=${wrapped.substring(0, wrapped.length < 80 ? wrapped.length : 80)}',
    );
    return UnwrappedMessage(unmarked(wrapped), powText: wrapped);
  }
}
