// SPDX-License-Identifier: GPL-3.0-or-later
// a sticker on the wire: 'st' beside its emoji in 'm'. what an app from
// before stickers reads, what a room keeps, and every malformed value read
// as plain text.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/bidi_safe.dart';
import 'package:kryfo/dlog.dart';
import 'package:kryfo/media_resend.dart';
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/rooms.dart';
import 'package:kryfo/stickers/sticker_pack.dart';
import 'package:kryfo/stickers/sticker_wire.dart';

import 'sticker_test_util.dart';

const _sender = SenderInfo(
  haloId: 'thumb-behave-boring',
  edPub: 'ed',
  onion: 'x.onion',
  xPub: 'ab',
  avatar: 3,
);

Map<String, dynamic> _body(String wrapped) =>
    jsonDecode(wrapped.substring('halo/1:'.length)) as Map<String, dynamic>;

// what a reader takes from an envelope, to hold two readings side by side
Map<String, Object?> _read(UnwrappedMessage e) => {
  'm': e.message,
  'pow': e.powText,
  'u': e.msgUid,
  'q': e.replyTo,
  'g': e.groupId,
  'b': e.burnSeconds,
  'h': e.senderHaloId,
  'e': e.senderEdPub,
  'o': e.senderOnion,
  'x': e.senderXPub,
  'av': e.senderAvatar,
  'i': e.imageB64,
  'f': e.fileB64,
  'fn': e.fileName,
  'pv': e.preview,
  'sc': e.secure,
  'pl': e.poll,
  'pw': e.powNonce,
  'bg': e.supporterBadge,
  'r': e.reaction?.targetUid,
  'ed': e.edit?.targetUid,
  'gc': e.groupControl?.type,
};

void main() {
  test('parses pack, id and since', () {
    final w = StickerWire.parse('fokia:17:1')!;
    expect(w.ref, const StickerRef('fokia', 17));
    expect(w.since, 1);
    expect(w.value, 'fokia:17:1');
    expect(w, const StickerWire(StickerRef('fokia', 17), 1));
    expect(StickerWire.parse('a:9999:999')!.value, 'a:9999:999');
    expect(StickerWire.parse('abcdefghijklmnop:1:1'), isNotNull);
    expect(StickerWire.parse('p2:1:1'), isNotNull);
  });

  test('of takes the since from the pack', () {
    final pack = loadPack();
    expect(StickerWire.of(pack, pack.sticker(17)!).value, 'fokia:17:1');
    for (final id in pack.ids) {
      final v = StickerWire.of(pack, pack.sticker(id)!).value;
      expect(StickerWire.parse(v)?.value, v, reason: 'sticker $id');
    }
  });

  test('round trip', () async {
    final env = unwrapMessage(
      await wrapMessage('🔒', msgUid: 'u1', sticker: 'fokia:17:1'),
    );
    expect(env.message, '🔒');
    expect(env.sticker, 'fokia:17:1');
    expect(StickerWire.parse(env.sticker)!.ref, const StickerRef('fokia', 17));
    expect(env.msgUid, 'u1');
  });

  test('one key and 18 bytes over the text', () async {
    Future<String> wrap({String? sticker}) => wrapMessage(
      '🔒',
      msgUid: 'u1',
      replyTo: 'q1',
      burnSeconds: 60,
      sender: _sender,
      sticker: sticker,
    );
    final text = await wrap();
    final sticker = await wrap(sticker: 'fokia:17:1');
    expect(_body(sticker).keys.toSet(), {..._body(text).keys, 'st'});
    expect(utf8.encode(sticker).length - utf8.encode(text).length, 18);
    expect(_body(sticker)..remove('st'), _body(text));
  });

  test('a malformed value reads as text', () {
    final bad = <Object?>[
      'fokia:17',
      'FOKIA:1:1',
      'fokia:99999:1',
      'fokia:1:1:1',
      'fokia:0:1',
      'fokia:1:0',
      'fokia:01:1',
      'fokia:1:1000',
      '1fokia:1:1',
      'abcdefghijklmnopq:1:1',
      ' fokia:1:1',
      'fokia:1:1\n',
      'fokia:17:1‎',
      '',
      17,
      1.5,
      true,
      null,
      {'p': 'fokia', 'i': 17},
      ['fokia:17:1'],
    ];
    for (final v in bad) {
      expect(StickerWire.parse(v), isNull, reason: '$v');
      final env = unwrapMessage('halo/1:${jsonEncode({'m': '🔒', 'st': v})}');
      expect(env.sticker, isNull, reason: '$v');
      expect(env.message, '🔒', reason: '$v');
    }
  });

  test('an older app reads the emoji as text', () async {
    Future<String> wrap({String? sticker}) => wrapMessage(
      '🔒',
      msgUid: 'u1',
      replyTo: 'q1',
      groupId: 'g1',
      burnSeconds: 60,
      supporterBadge: 'gold',
      sender: _sender,
      sticker: sticker,
    );
    final old = _unwrap041(await wrap(sticker: 'fokia:17:1'));
    expect(old.message, '🔒');
    expect(_read(old), _read(_unwrap041(await wrap())));
  });

  test('an old envelope reads as before', () async {
    final wrapped = await wrapMessage(
      'see you at 8',
      msgUid: 'u2',
      replyTo: 'q2',
      burnSeconds: 30,
      preview: const {'title': 'x', 'url': 'https://example.org'},
      sender: _sender,
    );
    final now = unwrapMessage(wrapped);
    expect(now.sticker, isNull);
    expect(_read(now), _read(_unwrap041(wrapped)));
    expect(unwrapMessage('plain text').sticker, isNull);
  });

  test('a room frame keeps the sticker', () async {
    final pub = 'ab' * 32;
    final wrapped = await wrapMessage(
      '🔒',
      msgUid: 'u1',
      groupId: 'g1',
      supporterBadge: 'gold',
      rosterParticipants: const [
        {'h': 'a', 'o': 'b.onion', 'x': 'c'},
      ],
      sender: _sender,
      sticker: 'fokia:17:1',
    );
    final out = roomFrame(wrapped, pub)!;
    final j = _body(out);
    expect(j['st'], 'fokia:17:1');
    expect(j['m'], '🔒');
    expect(j['h'], pub);
    expect(j['x'], pub);
    for (final k in ['o', 'e', 'p', 'bg', 'rp']) {
      expect(j.containsKey(k), false, reason: k);
    }
    expect(unwrapMessage(out).sticker, 'fokia:17:1');
    expect(roomFrame('not a frame', pub), isNull);
  });

  test('a known sticker shows our own emoji', () {
    final pack = loadPack();
    final w = StickerWire.parse('fokia:17:1')!;
    expect(stickerText(w, '🔒', pack), '🔒');
    expect(stickerText(w, 'tap this link', pack), '🔒');
    expect(stickerText(w, '🔥', pack), '🔒');
    expect(stickerText(w, '', pack), '🔒');
  });

  test('an unknown sticker keeps one emoji or nothing', () {
    final pack = loadPack();
    final newer = StickerWire.parse('fokia:300:2')!;
    expect(stickerText(newer, '🦊', pack), '🦊');
    expect(stickerText(newer, 'tap this link', pack), '');
    expect(stickerText(newer, '🦊🦊', pack), '');
    expect(stickerText(newer, '', pack), '');
    // another pack, and a pack that did not load
    expect(stickerText(StickerWire.parse('other:17:1')!, '🦊', pack), '🦊');
    expect(stickerText(newer, '🦊', null), '🦊');
    expect(stickerText(StickerWire.parse('fokia:17:1')!, 'x', null), '');
  });

  test('one emoji and nothing else', () {
    final pack = loadPack();
    for (final id in pack.ids) {
      expect(isOneEmoji(pack.sticker(id)!.emoji), true, reason: 'sticker $id');
    }
    const yes = [
      '\u{1F44D}\u{1F3FD}', // thumbs up, a skin tone
      '\u{1F468}‍\u{1F469}‍\u{1F467}', // a family
      '\u{1F3F3}️‍\u{1F308}', // rainbow flag
      '❤️‍\u{1F525}', // heart on fire
      '\u{1F1E9}\u{1F1EA}', // a country flag
      '1️⃣', // keycap
      '#️⃣',
      '\u{1F3F4}\u{E0067}\u{E0062}\u{E0073}\u{E0063}\u{E0074}\u{E007F}',
      '☕',
      '❤',
    ];
    for (final e in yes) {
      expect(isOneEmoji(e), true, reason: e.runes.toString());
    }
    const no = [
      '',
      'a',
      'hi',
      '1',
      '#',
      '\u{1F512}\u{1F512}',
      '\u{1F512} ',
      ' \u{1F512}',
      '\u{1F512}a',
      '\u{1F1E9}',
      '‍',
      '\u{1F512}‍',
      '\u{1F3FD}',
      'fokia:17:1',
      '中',
      '\u{1F3F4}\u{E0067}\u{E0062}',
    ];
    for (final e in no) {
      expect(isOneEmoji(e), false, reason: e.runes.toString());
    }
  });
}

// the reader of 0.4.1, the last version before stickers, as it was. an app
// that old gets the sticker envelope and has to read it as the emoji.
const _prefix041 = 'halo/1:';

UnwrappedMessage _unwrap041(String wrapped) {
  if (!wrapped.startsWith(_prefix041)) {
    return UnwrappedMessage(unmarked(wrapped), powText: wrapped);
  }
  try {
    final sent =
        jsonDecode(wrapped.substring(_prefix041.length))
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
    );
  } catch (e) {
    dlog(
      'UNWRAP-FAIL $e raw=${wrapped.substring(0, wrapped.length < 80 ? wrapped.length : 80)}',
    );
    return UnwrappedMessage(unmarked(wrapped), powText: wrapped);
  }
}
