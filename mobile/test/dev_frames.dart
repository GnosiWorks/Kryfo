// SPDX-License-Identifier: GPL-3.0-or-later
// the frames the developer chat's tests put through its rules: every
// parameter wrapMessage takes, with the person's everyday identity and
// another contact planted wherever a frame can carry them, the frames each
// call site builds, and what a frame to him must never hold
import 'dart:convert';

import 'package:kryfo/devchat/dev_frame.dart';
import 'package:kryfo/media_resend.dart' show NeedFrame;
import 'package:kryfo/message_envelope.dart';

// the person's everyday identity, planted wherever a frame can carry one
const everydayWords = 'neon-tiger-saturn';
final everydayEd = 'a1' * 32;
final everydayX = 'b2' * 32;
const everydayOnion =
    'everydayplantedonionaddressaaaaaaaaaaaaaaaaaaaaaaaaa.onion';
final everydayFc = 'c3' * 32;
const everydayFace = 17;
const everydayTier = 'planted-tier';
const everydayHandle = 'planted-handle';
// another contact of theirs
const friendId = 'amber-fox-river';
const friendOnion =
    'friendplantedonionaddressbbbbbbbbbbbbbbbbbbbbbbbbbbb.onion';
final friendX = 'd4' * 32;
final friendEd = 'e5' * 32;
final friendFc = 'f6' * 32;

// what must never come out in an anonymous chat, and never in a chat with
// three words but for the three words and keys the person chose to show
List<String> get plantedEveryday => [
  everydayWords,
  everydayEd,
  everydayX,
  everydayOnion,
  everydayFc,
  everydayTier,
  everydayHandle,
  friendId,
  friendOnion,
  friendX,
  friendEd,
  friendFc,
];

// everything a frame to him leaks, by the markers above and by shape
List<String> frameLeaks(String? text, {required bool anon}) {
  if (text == null) return const [];
  final out = <String>[];
  final low = text.toLowerCase();
  final markers = anon
      ? plantedEveryday
      : plantedEveryday.where(
          (v) => v != everydayWords && v != everydayEd && v != everydayX,
        );
  for (final v in markers) {
    if (low.contains(v.toLowerCase())) out.add('carries $v');
  }
  final j = jsonDecode(text.substring('halo/1:'.length)) as Map;
  void walk(Object? o, String at) {
    if (o is Map) {
      for (final e in o.entries) {
        if (e.key == 'av' || e.key == 'bg') out.add('$at${e.key}');
        walk(e.value, '$at${e.key}.');
      }
    } else if (o is List) {
      for (final v in o) {
        walk(v, at);
      }
    }
  }

  walk(j, '');
  if (j.containsKey('o') && j['o'] != '') out.add('an onion');
  for (final k in j.keys) {
    if (kDevNever.contains(k)) out.add('a $k frame');
  }
  return out;
}

// every named parameter wrapMessage takes, and a value for it that carries
// the everyday identity wherever the parameter can hold one
final frameParams = <String, Object>{
  'sender': SenderInfo(
    haloId: everydayWords,
    edPub: everydayEd,
    onion: everydayOnion,
    xPub: everydayX,
    avatar: everydayFace,
  ),
  'burnSeconds': 30,
  'msgUid': 'uid0000abcd',
  'reaction': const ReactionFrame(targetUid: 'uid0000prev', emoji: 'y'),
  'edit': const EditFrame(targetUid: 'uid0000prev', newText: 'edited'),
  'replyTo': 'uid0000prev',
  'groupId': 'grp-$everydayWords',
  'groupControl': GroupControl(
    type: 'create',
    name: 'weekend',
    members: [everydayWords, friendId],
    participants: [
      {'h': friendId, 'o': friendOnion, 'x': friendX},
    ],
  ),
  'imageB64': base64Encode(utf8.encode('jpeg bytes')),
  'unsend': 'uid0000prev',
  'pin': const PinFrame(targetUid: 'uid0000prev', pinned: true),
  'fileB64': base64Encode(utf8.encode('file bytes')),
  'fileName': 'notes.pdf',
  'voice': true,
  'voiceDisguised': true,
  'preview': {'t': 'Kryfo', 'u': 'https://kryfo.app'},
  'mediaId': 'uid0000abcd',
  'chunkIndex': 2,
  'chunkTotal': 5,
  'pvImg': true,
  'roster': [everydayWords, friendId],
  'rosterParticipants': [
    {'h': friendId, 'o': friendOnion, 'x': friendX},
    {'h': everydayWords, 'o': everydayOnion, 'x': everydayX},
  ],
  'powNonce': 41,
  'powBitsUsed': powBits,
  'deliveredUid': 'uid0000prev',
  'supporterBadge': everydayTier,
  'secure': true,
  'intro': IntroFrame(
    haloId: friendId,
    onion: friendOnion,
    xPub: friendX,
    edPub: friendEd,
    avatar: 3,
    fc: friendFc,
    note: 'meet $everydayWords',
  ),
  'need': const NeedFrame('uid0000abcd', [0, 3]),
  'canResend': true,
  'poll': <String, Object>{
    'o': ['yes', 'no'],
  },
  'vote': const VoteFrame(pollUid: 'uid0000poll', choices: [0], seq: 1),
  'pollClose': const PollCloseFrame(pollUid: 'uid0000poll', finalVotes: {}),
  'sticker': 'fokia:3:1',
  'supportMarker': 1,
};

// the parameters whose frames never go to him
const neverParams = {
  'groupId',
  'groupControl',
  'roster',
  'rosterParticipants',
  'intro',
  'poll',
  'vote',
  'pollClose',
};

T? _param<T>(Set<String> on, String k) =>
    on.contains(k) ? frameParams[k] as T : null;

Future<String> buildFrame(Set<String> on, {String m = 'hello marios'}) =>
    wrapMessage(
      m,
      sender: _param(on, 'sender'),
      burnSeconds: _param(on, 'burnSeconds'),
      msgUid: _param(on, 'msgUid'),
      reaction: _param(on, 'reaction'),
      edit: _param(on, 'edit'),
      replyTo: _param(on, 'replyTo'),
      groupId: _param(on, 'groupId'),
      groupControl: _param(on, 'groupControl'),
      imageB64: _param(on, 'imageB64'),
      unsend: _param(on, 'unsend'),
      pin: _param(on, 'pin'),
      fileB64: _param(on, 'fileB64'),
      fileName: _param(on, 'fileName'),
      voice: on.contains('voice'),
      voiceDisguised: on.contains('voiceDisguised'),
      preview: _param(on, 'preview'),
      mediaId: _param(on, 'mediaId'),
      chunkIndex: _param(on, 'chunkIndex'),
      chunkTotal: _param(on, 'chunkTotal'),
      pvImg: on.contains('pvImg'),
      roster: _param(on, 'roster'),
      rosterParticipants: _param(on, 'rosterParticipants'),
      powNonce: _param(on, 'powNonce'),
      powBitsUsed: _param(on, 'powBitsUsed'),
      deliveredUid: _param(on, 'deliveredUid'),
      supporterBadge: _param(on, 'supporterBadge'),
      secure: on.contains('secure'),
      intro: _param(on, 'intro'),
      need: _param(on, 'need'),
      canResend: on.contains('canResend'),
      poll: _param(on, 'poll'),
      vote: _param(on, 'vote'),
      pollClose: _param(on, 'pollClose'),
      sticker: _param(on, 'sticker'),
      supportMarker: _param(on, 'supportMarker'),
    );

// the frames the app's own code builds, as each call site builds them
final madeFrames = <String, Set<String>>{
  'text opener': {
    'sender',
    'msgUid',
    'powNonce',
    'powBitsUsed',
    'replyTo',
    'burnSeconds',
    'preview',
    'secure',
    'supporterBadge',
    'sticker',
  },
  'reply': {'sender', 'msgUid', 'replyTo', 'supporterBadge'},
  'outbox retry': {
    'sender',
    'msgUid',
    'replyTo',
    'preview',
    'supporterBadge',
    'burnSeconds',
    'powNonce',
    'powBitsUsed',
    'sticker',
  },
  'photo slice': {
    'sender',
    'msgUid',
    'imageB64',
    'mediaId',
    'chunkIndex',
    'chunkTotal',
    'burnSeconds',
    'secure',
    'powNonce',
    'powBitsUsed',
    'supporterBadge',
    'canResend',
  },
  'file slice': {
    'sender',
    'msgUid',
    'fileB64',
    'fileName',
    'mediaId',
    'chunkIndex',
    'chunkTotal',
    'supporterBadge',
    'canResend',
  },
  'voice note, disguised': {
    'sender',
    'msgUid',
    'fileB64',
    'voice',
    'voiceDisguised',
    'supporterBadge',
  },
  'voice note': {'sender', 'msgUid', 'fileB64', 'voice', 'supporterBadge'},
  'preview image': {'sender', 'msgUid', 'imageB64', 'pvImg'},
  'reaction': {'reaction'},
  'unsend': {'unsend'},
  'pin': {'pin', 'sender'},
  'edit': {'edit', 'sender'},
  'receipt': {'deliveredUid', 'sender'},
  'need': {'need', 'sender'},
  'accept ack': {'sender'},
  'introduction': {'intro', 'sender'},
  'group control': {'groupId', 'groupControl', 'sender'},
  'group text': {
    'groupId',
    'msgUid',
    'roster',
    'rosterParticipants',
    'supporterBadge',
    'sender',
  },
  'poll': {'groupId', 'msgUid', 'poll', 'sender'},
  'vote': {'vote', 'sender'},
  'poll closed': {'pollClose', 'sender'},
};

bool frameRefused(Set<String> on, {required bool anon}) =>
    on.any(neverParams.contains) ||
    (anon && on.contains('voice') && !on.contains('voiceDisguised'));

Map<String, dynamic> frameJson(String wrapped) =>
    jsonDecode(wrapped.substring('halo/1:'.length)) as Map<String, dynamic>;

// what the chat on his side reads of it, field by field
Map<String, Object?> frameRead(String wrapped) {
  final u = unwrapMessage(wrapped);
  return {
    'm': u.message,
    'u': u.msgUid,
    'q': u.replyTo,
    'b': u.burnSeconds,
    'r': u.reaction == null ? null : [u.reaction!.targetUid, u.reaction!.emoji],
    'ed': u.edit == null ? null : [u.edit!.targetUid, u.edit!.newText],
    'un': u.unsend,
    'pn': u.pin == null ? null : [u.pin!.targetUid, u.pin!.pinned],
    'dr': u.deliveredUid,
    'i': u.imageB64,
    'f': u.fileB64,
    'fn': u.fileName,
    'vo': u.voice,
    'vd': u.voiceDisguised,
    'mid': u.mediaId,
    'ci': u.chunkIndex,
    'ct': u.chunkTotal,
    'pi': u.pvImg,
    'cr': u.canResend,
    'nd': u.need == null ? null : [u.need!.mediaId, u.need!.indices],
    'sc': u.secure,
    'st': u.sticker,
    'pv': u.preview,
    'pw': u.powNonce,
    'pb': u.powBitsUsed,
  };
}
