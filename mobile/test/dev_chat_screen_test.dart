// SPDX-License-Identifier: GPL-3.0-or-later
// the developer chat's own screen, before its first message and at it. his
// first line is the app's: stored nowhere, fetched from nowhere. the note
// says who he will see and the pill writes anonymously instead, making
// nothing until a message goes. every kind of message asks for the start
// once, before anything of it is saved, and the choice is fixed from then
// on. nothing reaches the engine before the user writes. his header has no
// nickname, no contact page, no block and no hide, and an anonymous chat's
// voice is always disguised. an anonymous chat restored without the name it
// was made with reads, and a new chat takes its place once asked. less
// movement and right to left are kept
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/devchat/dev_lane.dart' show DevRefusal, DevSealRefused;
import 'package:kryfo/devchat/dev_start.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show HaloEngine, appState, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/screens/chat_screen.dart' show grindPowForTest;
import 'package:kryfo/screens/contact_screen.dart' show ContactScreen;
import 'package:kryfo/screens/dev_about_sheet.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/stickers/sticker_sheet.dart' show StickerButton;
import 'package:kryfo/widgets/dev_avatar.dart';
import 'package:kryfo/widgets/dev_note.dart';
import 'package:kryfo/widgets/kryfo_avatar.dart';
import 'package:kryfo/widgets/voice_parts.dart' show DisguiseToggle;
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';
import 'sticker_test_util.dart' show useLibrary;

const _dev = 'dev:m1';

// the engine as a list of what was asked of it
class _SpyEngine implements HaloEngine {
  final calls = <String>[];

  @override
  dynamic noSuchMethod(Invocation i) {
    calls.add(i.memberName.toString());
    return super.noSuchMethod(i);
  }
}

// a phone's database as the chat screen reads and writes it, kept in maps
class _ChatDb extends DevTestDb {
  _ChatDb(super.mem, [super.container]);

  Map<String, Object?>? _contact(String id) {
    for (final r in mem.rows('contacts')) {
      if (r['halo_id'] == id) return r;
    }
    return null;
  }

  List<Map<String, Object?>> _thread(String peer) => [
    for (final r in mem.rows('messages'))
      if (r['peer_id'] == peer && r['group_id'] == null)
        {...r, 'rowid': r['id']},
  ];

  bool _flag(String id, String col) => _contact(id)?[col] == 1;

  @override
  Future<Map<String, Object?>?> getContact(String haloId) async =>
      _contact(haloId);
  @override
  Future<bool> isAccepted(String haloId) async => _flag(haloId, 'accepted');
  @override
  Future<bool> isBackPaired(String peerId) async =>
      _flag(peerId, 'back_paired');
  @override
  Future<bool> isBlocked(String haloId) async => _flag(haloId, 'blocked');
  @override
  Future<bool> isMuted(String haloId) async => _flag(haloId, 'muted');
  @override
  Future<bool> isVerified(String haloId) async => _flag(haloId, 'verified');
  @override
  Future<bool> keyChanged(String haloId) async => false;
  @override
  Future<String?> getAtmosphere(String peerId) async => null;
  @override
  Future<void> clearUnread(String peerId) async {}
  @override
  Future<int> countMessagesFrom(String peerId) async =>
      _thread(peerId).where((r) => r['direction'] == 'in').length;
  @override
  Future<int> countMessagesTo(String peerId) async =>
      _thread(peerId).where((r) => r['direction'] == 'out').length;
  @override
  Future<List<Map<String, Object?>>> vouchesFor(String haloId) async => [];
  @override
  Future<Map<String, Object?>?> shieldFor(String haloId) async => null;
  @override
  Future<void> purgeExpiredBurns() async {}
  @override
  Future<List<Map<String, Object?>>> messagesFor(String peerId) async =>
      _thread(peerId);
  @override
  Future<List<Map<String, Object?>>> messagesPage(
    String peerId, {
    int? beforeRowid,
    int limit = 60,
  }) async {
    final rows = [
      for (final r in _thread(peerId))
        if (beforeRowid == null || (r['id'] as int) < beforeRowid) r,
    ];
    return rows.length > limit ? rows.sublist(rows.length - limit) : rows;
  }

  @override
  Future<List<Map<String, Object?>>> messagesAfter(
    String peerId,
    int afterRowid,
  ) async => [
    for (final r in _thread(peerId))
      if ((r['id'] as int) > afterRowid) r,
  ];
  @override
  Future<Map<String, List<MapEntry<String, String>>>> loadReactionsFor(
    List<String> msgUids,
  ) async => {};
  @override
  Future<List<Map<String, Object?>>> pinnedIn({
    String? peerId,
    String? groupId,
  }) async => [];
  @override
  Future<bool> messageExists(String msgUid) async =>
      mem.rows('messages').any((r) => r['msg_uid'] == msgUid);
  @override
  Future<void> setPowNonce(String msgUid, int nonce) async {}
  @override
  Future<int?> powNonceOf(String msgUid) async => null;
  @override
  Future<void> markSent(String msgUid) async {}
  @override
  Future<bool> isSent(String msgUid) async => false;
  @override
  Future<({bool sent, bool delivered})> sendState(String msgUid) async =>
      (sent: false, delivered: false);

  @override
  Future<void> saveMessage(
    String peerId,
    String direction,
    String plaintext, {
    int? burnAt,
    int? burnSecs,
    String? msgUid,
    String? replyTo,
    String? groupId,
    String? mediaPath,
    String? filePath,
    String? fileName,
    bool voiceDisguised = false,
    bool saved = false,
    int sent = 1,
    String? preview,
    bool secure = false,
    String? poll,
    String? sticker,
    int? sentAt,
  }) async {
    await mem.insert('messages', {
      'peer_id': peerId,
      'direction': direction,
      'plaintext': plaintext,
      'sent_at': sentAt ?? DateTime.now().millisecondsSinceEpoch,
      'msg_uid': msgUid,
      'media_path': mediaPath,
      'file_path': filePath,
      'file_name': fileName,
      'voice_disguised': voiceDisguised ? 1 : 0,
      'sent': sent,
      'sticker': ?sticker,
    });
  }
}

// when the chat was made: his first line is dated then
final _made = DateTime(2026, 9, 20, 9, 30).millisecondsSinceEpoch;

late MemDb _mem;
late _SpyEngine _engine;
late Directory _tmp;

// a phone with the dev chat fresh, the everyday one or a decoy's. a decoy
// keeps what is sent in it, so nothing past the seal needs the engine
Future<void> _world({HaloContainer container = HaloContainer.everyday}) async {
  forgetDevChoices();
  // an opener grinds its proof of work in an isolate, which a widget test's
  // clock never waits for
  grindPowForTest = (_) => 0;
  _mem = MemDb(except: {'devchat'});
  await devChatTables(_mem, now: _made);
  final db = _ChatDb(_mem, container);
  if (container.quiet) {
    final everyday = MemDb(except: {'devchat'});
    await devChatTables(everyday);
    useDatabasesForTest(DevTestDb(everyday), Session(db));
  } else {
    useDatabasesForTest(db, Session(db));
  }
  await appState.refreshContacts();
}

// a chat started before, with [out] messages of it unanswered
Future<void> _started({bool anon = false, int out = 0}) async {
  await DevChat(
    () async => _mem,
    shred: (_) async {},
  ).begin(currentDevKey!, anon: anon ? _madeName : null);
  for (var i = 0; i < out; i++) {
    await _mem.insert('messages', {
      'peer_id': _dev,
      'direction': 'out',
      'plaintext': 'note $i',
      'sent_at': _made + (i + 1) * 60000,
      'msg_uid': 'u$i',
      'sent': 1,
    });
  }
  await appState.refreshContacts();
}

const _madeName = DevAnon(id: 'made-for-this', edPriv: 'e', xPriv: 'x');

// an anonymous chat as a backup or a move brings it: two messages of it,
// and not the name it was made with
Future<void> _restored() async {
  await _world();
  await _started(anon: true, out: 2);
  await scrubDevAnon(_mem);
  await appState.refreshContacts();
}

// the start as the app would make it, watched: with what name, how many
// rows the chat had and what the engine had been asked when it was asked
final _begun = <bool>[];
final _rowsAtStart = <int>[];
final _callsAtStart = <int>[];
var _answer = DevStart.ok;

Future<DevStart> _spyBegin({required bool anon}) async {
  _begun.add(anon);
  _rowsAtStart.add(_mem.rows('messages').length);
  _callsAtStart.add(_engine.calls.length);
  if (_answer != DevStart.ok) return _answer;
  final ok = await DevChat(
    () async => _mem,
    shred: (_) async {},
  ).begin(currentDevKey!, anon: anon ? _madeName : null);
  await appState.refreshContacts();
  return ok ? DevStart.ok : DevStart.none;
}

DevChatRow? _row() {
  final r = _mem.rows('devchat');
  return r.isEmpty ? null : DevChatRow.of(r.first);
}

List<Map<String, Object?>> _sent() => [
  for (final r in _mem.rows('messages'))
    if (r['direction'] == 'out') r,
];

bool get _hasDevContact =>
    _mem.rows('contacts').any((r) => r['halo_id'] == _dev);

// the chat, pushed the way the app opens it
Future<void> _open(
  WidgetTester t, {
  String? text,
  bool still = false,
  Locale locale = const Locale('en'),
  double scale = 1,
  Size size = const Size(1000, 1800),
  double ratio = 2,
}) async {
  await devOpen(
    t,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(devChatRoute(_dev, initialText: text)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    still: still,
    locale: locale,
    scale: scale,
    size: size,
    ratio: ratio,
  );
  await t.tap(find.text('open'));
  await _beat(t);
}

// a tap's frame, the time it takes, and the frame that tidies up after
Future<void> _beat(WidgetTester t, [int ms = 700]) async {
  await t.pump();
  await t.pump(Duration(milliseconds: ms));
  await t.pump();
}

// real files are read and written on the way out: frames run between
// them until [done] holds, then a few more for what trails it
Future<void> _io(WidgetTester t, bool Function() done) async {
  var left = 6;
  for (var i = 0; i < 160 && left > 0; i++) {
    if (done()) left--;
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 60));
  }
  expect(done(), isTrue, reason: 'the send never got that far');
}

// the pickers' timers run out before the next test
Future<void> _close(WidgetTester t) async {
  await devClose(t);
  await t.pump(const Duration(seconds: 3));
}

Future<void> _type(WidgetTester t, String text) async {
  await t.enterText(find.byType(TextField).last, text);
  // the mic makes way for the send button
  await _beat(t, 300);
}

// the send button, once there is text
Future<void> _send(WidgetTester t) async {
  await t.tap(find.byIcon(Icons.arrow_upward));
  await _beat(t, 900);
}

Finder get _pill => find.text(l10n.devWriteAnonymously);

Future<void> _chooseAnon(WidgetTester t) async {
  await t.tap(_pill);
  await _beat(t, 400);
}

DisguiseToggle _toggle(WidgetTester t) =>
    t.widget<DisguiseToggle>(find.byType(DisguiseToggle));

void _mock(String channel, Future<Object?> Function(MethodCall c)? h) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), h);

// a second of a tone, as the recorder writes it: 16 kHz, mono, 16 bit
Uint8List _wav() {
  const rate = 16000, n = 16000;
  final b = ByteData(44 + n * 2);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + n * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, rate, Endian.little);
  b.setUint32(28, rate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  b.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    final v = 8000 * math.sin(2 * math.pi * 220 * i / rate);
    b.setInt16(44 + i * 2, v.round(), Endian.little);
  }
  return b.buffer.asUint8List();
}

// the smallest clip the stripper walks: a type box and its data
Uint8List _mp4() {
  Uint8List box(String type, List<int> body) {
    final size = 8 + body.length;
    return Uint8List.fromList([
      size >> 24,
      (size >> 16) & 0xff,
      (size >> 8) & 0xff,
      size & 0xff,
      ...type.codeUnits,
      ...body,
    ]);
  }

  return Uint8List.fromList([
    ...box('ftyp', [...'isom'.codeUnits, 0, 0, 2, 0, ...'isom'.codeUnits]),
    ...box('mdat', 'the clip itself'.codeUnits),
  ]);
}

// one pixel, as the picker hands back a photo it made smaller
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

String _file(String name, List<int> bytes) {
  final f = File('${_tmp.path}/$name')..writeAsBytesSync(bytes);
  return f.path;
}

var _notes = 0;

// the mic hands a finished recording over, as it does when let go: a
// second of a tone, where the recorder writes
Future<void> _speak(WidgetTester t, bool Function() done) async {
  final path = _file('vn_${_notes++}.wav', _wav());
  final mic = t.widget(
    find.ancestor(
      of: find.byIcon(Icons.mic_none_rounded),
      matching: find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_HoldToTalkMic',
      ),
    ),
  );
  (mic as dynamic).onComplete(path, 1200, false);
  await _io(t, done);
}

Future<void> _attach(WidgetTester t, String tile, bool Function() done) async {
  await t.tap(find.byIcon(Icons.add_photo_alternate_outlined));
  await _beat(t, 500);
  await t.tap(find.text(tile));
  await _beat(t, 300);
  await _io(t, done);
}

// the kinds of message the chat sends, each the way it leaves, and how
// many rows each makes
typedef _Kind = Future<void> Function(WidgetTester t, bool Function() done);
final _kinds = <String, (_Kind, int)>{
  'words': (
    (t, _) async {
      await _type(t, 'a bug on the lock screen');
      await _send(t);
    },
    1,
  ),
  'sticker': (
    (t, _) async {
      // the packs, as the app has them once loaded
      useLibrary();
      await t.tap(find.byType(StickerButton));
      await _beat(t, 900);
      // the cells draw once the packs' pictures are in
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await _beat(t, 300);
      await t.tap(find.bySemanticsLabel(l10n.stickerA11y('😂')).first);
      // the flight lands on its bubble
      for (var i = 0; i < 30; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
    },
    1,
  ),
  'photos': ((t, done) => _attach(t, l10n.chatGallery, done), 2),
  'video': ((t, done) => _attach(t, l10n.chatVideo, done), 1),
  'file': ((t, done) => _attach(t, l10n.chatFile2, done), 1),
  'voice': (_speak, 1),
};

// the words the chat brought, in the language on screen
Set<String> _ours() => {
  l10n.devWelcome,
  l10n.devPinned,
  l10n.devAnonymous,
  l10n.devWriteAnonymously,
  l10n.devUseMyWords,
  l10n.devWhoSeesWhat,
  l10n.devWhoWords,
  l10n.devWhoAnon,
  l10n.devWhoNothingYet,
  l10n.devWhoChoiceStays,
  l10n.devKeyCheckFailed,
  l10n.devLockLine,
  l10n.devNamelessLine,
  l10n.devStartNewChat,
  l10n.devStartNewLine,
};

final _bad = <String>[];

// every word of ours whole, inside its box and on the screen. the header's
// one line ends in an ellipsis by design, so [skip] can leave it out
void _fits(WidgetTester t, String page, {Set<String> skip = const {}}) {
  expect(t.takeException(), isNull, reason: page);
  final ours = _ours().difference(skip);
  final width = t.view.physicalSize.width / t.view.devicePixelRatio;
  var seen = 0;
  for (final e in find.byType(RichText).evaluate()) {
    final p = e.renderObject! as RenderParagraph;
    final s = p.text.toPlainText();
    if (!ours.contains(s) || !p.attached || !p.hasSize) continue;
    seen++;
    final w = p.size.width;
    if (p.didExceedMaxLines) _bad.add('$page, cut short: $s');
    if (p.getMaxIntrinsicHeight(w) > p.size.height + 0.5) {
      _bad.add('$page, clipped: $s');
    }
    final word = p.getMinIntrinsicWidth(double.infinity);
    if (word > w + 0.5) {
      _bad.add('$page, a word broken (${word.round()} in ${w.round()}): $s');
    }
    final left = p.localToGlobal(Offset.zero).dx;
    if (left < -0.5 || left + w > width + 0.5) _bad.add('$page, off: $s');
  }
  expect(seen, greaterThan(0), reason: page);
}

Future<void> _loadFonts() async {
  const families = {
    'Fraunces': ['Fraunces.ttf'],
    'Instrument Sans': ['InstrumentSans.ttf'],
    'JetBrains Mono': ['JetBrainsMono.ttf'],
    'Noto Serif Cyrillic': ['NotoSerif-Cyrillic.ttf'],
    'Noto Sans Cyrillic': ['NotoSans-Cyrillic.ttf'],
    'Noto Sans Vietnamese': ['NotoSans-Vietnamese.ttf'],
    'Noto Naskh Arabic': ['NotoNaskhArabic-Kryfo.ttf'],
    'Noto Sans Arabic': ['NotoSansArabic-Kryfo.ttf'],
  };
  for (final e in families.entries) {
    final loader = FontLoader(e.key);
    for (final f in e.value) {
      loader.addFont(
        File(
          'assets/fonts/$f',
        ).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    }
    await loader.load();
  }
}

void main() {
  setUpAll(_loadFonts);

  setUp(() {
    // the menus, the pickers and the mic all wait for an open lock
    lockState.openForTest();
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
    appState.sendModeForTest = 'balanced';
    useDevKeysForTest([devCard('m1')]);
    _engine = _SpyEngine();
    useEngineForTest(_engine);
    _begun.clear();
    _rowsAtStart.clear();
    _callsAtStart.clear();
    _bad.clear();
    _answer = DevStart.ok;
    devBeginForTest = _spyBegin;
    forgetDevChoices();
    _tmp = Directory.systemTemp.createTempSync('devchat_ui');
    _mock('plugins.flutter.io/path_provider', (_) async => _tmp.path);
    // the mic's recorder is made with the composer and let go with it
    _mock('com.llfbandit.record/messages', (_) async => null);
    // a voice bubble reads its length with a player this host has not
    _mock('com.ryanheise.just_audio.methods', (c) async {
      // a player that never comes up reads no length and holds nothing
      if (c.method == 'init') return Completer<Object?>().future;
      return <String, Object?>{};
    });
    // the pickers hand back files of this phone
    _mock('plugins.flutter.io/image_picker', (c) async {
      switch (c.method) {
        case 'pickMultiImage':
          return [_file('one.png', _png), _file('two.png', _png)];
        case 'pickVideo':
          return _file('clip.mp4', _mp4());
      }
      return null;
    });
    _mock('miguelruivo.flutter.plugins.filepicker', (c) async {
      if (c.method != 'any') return null;
      final bytes = 'what went wrong, step by step'.codeUnits;
      return [
        {'name': 'notes.txt', 'path': _file('notes.txt', bytes), 'size': 29},
      ];
    });
  });

  tearDown(() {
    useDevKeysForTest(null);
    devBeginForTest = null;
    forgetDevChoices();
    setL10nLocale(const Locale('en'));
    for (final c in [
      'plugins.flutter.io/path_provider',
      'com.llfbandit.record/messages',
      'plugins.flutter.io/image_picker',
      'miguelruivo.flutter.plugins.filepicker',
      'com.ryanheise.just_audio.methods',
    ]) {
      _mock(c, null);
    }
    try {
      _tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('before the first message', () {
    testWidgets('his first line, the note and his header, and nothing sent '
        'or listened for, whatever is typed, chosen or left', (t) async {
      await _world();
      await _open(t);
      // his first line, from the app itself: nothing stored, nothing asked
      expect(find.text(l10n.devWelcome), findsOneWidget);
      expect(_mem.rows('messages'), isEmpty);
      // the note offers the pill and warns about nothing
      expect(_pill, findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DevNote),
          matching: find.textContaining('Marios'),
        ),
        findsNothing,
      );
      // his header: the ring that flew in, one title, the key built in
      expect(find.text(l10n.devRowTitle), findsOneWidget);
      expect(find.text(l10n.devPinned), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Hero && w.tag == kDevFaceHero),
        findsOneWidget,
      );
      expect(find.byType(DevAvatar), findsOneWidget);
      expect(find.byType(KryfoAvatar), findsNothing);
      expect(find.textContaining(_dev), findsNothing);
      // typed, chosen twice, typed again
      await _type(t, 'hello, a bug report');
      await _chooseAnon(t);
      await t.tap(find.text(l10n.devUseMyWords));
      await _beat(t);
      await _type(t, 'hello, a longer bug report');
      // and left
      await t.tap(find.byTooltip(l10n.commonBack));
      await _beat(t);
      expect(find.text(l10n.devWelcome), findsNothing);
      expect(_engine.calls, isEmpty);
      expect(_begun, isEmpty);
      expect(_row()!.state, DevState.fresh);
      expect(_row()!.anonId, isNull);
      expect(_hasDevContact, isFalse);
      expect(_mem.rows('messages'), isEmpty);
      await devClose(t);
    });

    testWidgets('his first line is the app\'s, in the language on screen, '
        'and it is only copied', (t) async {
      await _world();
      await _open(t, locale: const Locale('de'));
      // not stored and not fetched: the build's own words, in German
      expect(l10n.devWelcome, isNot(contains('Tell me anything')));
      expect(l10n.devWelcome, contains('Marios'));
      expect(find.text(l10n.devWelcome), findsOneWidget);
      expect(_mem.rows('messages'), isEmpty);
      // his side of the chat
      final w = t.getCenter(find.text(l10n.devWelcome));
      expect(w.dx, lessThan(250));
      // a long press offers copy and nothing else
      await t.longPress(find.text(l10n.devWelcome));
      await _beat(t, 500);
      expect(find.text(l10n.commonCopy), findsOneWidget);
      for (final gone in [
        l10n.chatPin,
        l10n.commonSave,
        l10n.chatForward,
        l10n.commonShare,
        l10n.commonEdit,
        l10n.chatUnsend,
      ]) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
      expect(find.text('❤️'), findsNothing);
      await t.tap(find.text(l10n.commonCopy));
      await _beat(t, 500);
      // copied, and still nothing kept or sent
      expect(_mem.rows('messages'), isEmpty);
      expect(_engine.calls, isEmpty);
      await _close(t);
    });

    testWidgets('the pill writes anonymously, makes nothing, stays chosen '
        'and says who sees what', (t) async {
      await _world();
      await _open(t);
      await _chooseAnon(t);
      // filled, checked, and the way back beside it
      expect(find.text(l10n.devAnonymous), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text(l10n.devUseMyWords), findsOneWidget);
      // the header says nothing of it before anything is sent
      expect(find.text(l10n.devPinned), findsOneWidget);
      expect(find.byType(DevAnonChip), findsNothing);
      // no keys made, nothing written
      expect(_begun, isEmpty);
      expect(_row()!.state, DevState.fresh);
      expect(_row()!.anonId, isNull);
      // left and opened again, the choice is still there
      await t.tap(find.byTooltip(l10n.commonBack));
      await _beat(t);
      await t.tap(find.text('open'));
      await _beat(t);
      expect(find.text(l10n.devAnonymous), findsOneWidget);
      // who sees what
      await t.tap(find.byTooltip(l10n.devWhoSeesWhat));
      await _beat(t, 900);
      for (final s in [
        l10n.devWhoWords,
        l10n.devWhoAnon,
        l10n.devWhoNothingYet,
        l10n.devWhoChoiceStays,
      ]) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      expect(_engine.calls, isEmpty);
      expect(_begun, isEmpty);
      await _close(t);
    });

    testWidgets('his header has no nickname, contact page, block or hide, '
        'and a tap opens his sheet', (t) async {
      await _world();
      await _open(t);
      await t.tap(find.text(l10n.devRowTitle));
      await _beat(t, 900);
      expect(find.byType(DevAboutSheet), findsOneWidget);
      expect(find.byType(ContactScreen), findsNothing);
      await t.tapAt(const Offset(250, 40));
      await _beat(t, 900);
      await t.tap(find.byTooltip(l10n.devChatOptions));
      await _beat(t, 900);
      for (final s in [
        l10n.chatSharedPhotos,
        l10n.chatMuteNotifications,
        l10n.chatUnpin,
        l10n.chatArchiveChat,
        l10n.contactDeleteChat,
      ]) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      for (final s in [
        l10n.chatViewContact,
        l10n.chatNoteOnThisContact,
        l10n.chatBlockContact,
        l10n.chatHide,
        l10n.chatShowInList,
        l10n.chatIntroduceTo,
        l10n.chatClearConversation,
        l10n.chatWallpaper,
      ]) {
        expect(find.text(s), findsNothing, reason: s);
      }
      expect(_engine.calls, isEmpty);
      await _close(t);
    });
  });

  group('the first message', () {
    testWidgets('typed, it starts the chat with the three words, once, '
        'before it is saved', (t) async {
      await _world();
      await _open(t);
      await _type(t, 'the lock screen flickers');
      await _send(t);
      expect(_begun, [false]);
      expect(_rowsAtStart, [0]);
      // nothing had been asked of the engine when it started
      expect(_callsAtStart, [0]);
      expect(_row()!.state, DevState.everyday);
      expect(_hasDevContact, isTrue);
      expect(_sent().map((r) => r['plaintext']), ['the lock screen flickers']);
      // the note went with it, and his first line stays first
      expect(find.byType(DevNote), findsNothing);
      expect(
        t.getCenter(find.text(l10n.devWelcome)).dy,
        lessThan(t.getCenter(find.text('the lock screen flickers')).dy),
      );
      expect(find.text(l10n.devPinned), findsOneWidget);
      // the next one asks nothing
      await _type(t, 'and the pin pad too');
      await _send(t);
      expect(_begun, [false]);
      expect(_sent(), hasLength(2));
      await _close(t);
    });

    testWidgets('a forward waits in the composer and asks for the start as '
        'words do', (t) async {
      await _world();
      await _open(t, text: 'from another chat');
      expect(find.text('from another chat'), findsOneWidget);
      expect(find.byType(DevNote), findsOneWidget);
      expect(_begun, isEmpty);
      await _send(t);
      expect(_begun, [false]);
      expect(_rowsAtStart, [0]);
      expect(_sent().single['plaintext'], 'from another chat');
      await _close(t);
    });

    testWidgets('written anonymously, it starts anonymous and the choice is '
        'fixed from then on', (t) async {
      await _world();
      await _open(t);
      await _chooseAnon(t);
      await _type(t, 'an idea for groups');
      await _send(t);
      expect(_begun, [true]);
      expect(_rowsAtStart, [0]);
      expect(_row()!.state, DevState.anon);
      expect(_row()!.anonId, 'made-for-this');
      // no way to switch back: the note and its pill are gone
      expect(find.byType(DevNote), findsNothing);
      expect(find.text(l10n.devUseMyWords), findsNothing);
      expect(_pill, findsNothing);
      // the header says so
      await _beat(t, 400);
      expect(find.byType(DevAnonChip), findsOneWidget);
      expect(find.text(l10n.devPinned), findsNothing);
      // and says so again after the chat is left and opened
      await t.tap(find.byTooltip(l10n.commonBack));
      await _beat(t);
      await t.tap(find.text('open'));
      await _beat(t);
      expect(find.byType(DevAnonChip), findsOneWidget);
      expect(find.byType(DevNote), findsNothing);
      expect(_toggle(t).locked, isTrue);
      await _type(t, 'and one more');
      await _send(t);
      expect(_begun, [true]);
      expect(_row()!.state, DevState.anon);
      await _close(t);
    });

    testWidgets('a key that does not check out saves nothing and says so, '
        'until a try that works', (t) async {
      await _world();
      await _open(t);
      _answer = DevStart.keyFailed;
      await _type(t, 'is this thing on');
      await _send(t);
      expect(find.text(l10n.devKeyCheckFailed), findsOneWidget);
      expect(_mem.rows('messages'), isEmpty);
      expect(_row()!.state, DevState.fresh);
      // what was typed is still there, and so is the note
      expect(find.text('is this thing on'), findsOneWidget);
      expect(find.byType(DevNote), findsOneWidget);
      _answer = DevStart.ok;
      await _send(t);
      expect(_begun, [false, false]);
      expect(find.text(l10n.devKeyCheckFailed), findsNothing);
      expect(_sent(), hasLength(1));
      await _close(t);
    });

    testWidgets('the lock line comes at five unanswered, not two', (t) async {
      // two, where a stranger's chat would stop
      await _world();
      await _started(out: 2);
      await _open(t);
      expect(find.text(l10n.devLockLine), findsNothing);
      expect(find.text(l10n.chatWaitingForThemTo), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      await _close(t);
      // five, in his own words
      await _world();
      await _started(out: kDevCap);
      await _open(t);
      await _beat(t, 1500);
      expect(find.text(l10n.devLockLine), findsOneWidget);
      expect(find.text(l10n.chatWaitingForThemTo), findsNothing);
      expect(find.byType(TextField).hitTestable(), findsNothing);
      expect(find.byType(DevNote), findsNothing);
      await _close(t);
    });

    for (final kind in _kinds.keys) {
      for (final anon in [false, true]) {
        final how = anon ? 'anonymously' : 'with the three words';
        testWidgets('$kind, $how: the start is asked once, before anything '
            'of it is saved', (t) async {
          await _world(container: HaloContainer.decoy);
          await _open(t);
          if (anon) await _chooseAnon(t);
          final (send, rows) = _kinds[kind]!;
          await send(t, () => _sent().length >= rows);
          expect(_begun, [anon], reason: kind);
          expect(_rowsAtStart, [0], reason: kind);
          expect(_sent(), hasLength(rows), reason: kind);
          expect(_row()!.state, anon ? DevState.anon : DevState.everyday);
          expect(find.byType(DevNote), findsNothing, reason: kind);
          // a decoy keeps it: nothing reached the engine
          expect(_engine.calls, isEmpty, reason: kind);
          await _close(t);
        });
      }
    }

    testWidgets('a kind of message whose start fails saves nothing', (t) async {
      await _world(container: HaloContainer.decoy);
      await _open(t);
      _answer = DevStart.keyFailed;
      for (final kind in ['sticker', 'photos', 'video', 'file', 'voice']) {
        final (send, rows) = _kinds[kind]!;
        // each photo asks, as each goes on its own
        final asked = _begun.length + rows;
        await send(t, () => _begun.length >= asked);
        expect(_mem.rows('messages'), isEmpty, reason: kind);
        expect(find.text(l10n.devKeyCheckFailed), findsOneWidget);
      }
      expect(_begun, List.filled(6, false));
      expect(_row()!.state, DevState.fresh);
      // what was copied or recorded for the send went with it
      final left = Directory(_tmp.path)
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.contains('/media') ||
                f.uri.pathSegments.last.startsWith('vn_'),
          );
      expect(left, isEmpty);
      await _close(t);
    });

    test('every way a message leaves the chat asks for the start first', () {
      final src = File('lib/screens/chat_screen.dart').readAsStringSync();
      final head = RegExp(
        r'^  (?:Future<[\w?]+>|void|bool) (_\w+)\(',
        multiLine: true,
      );
      final heads = head.allMatches(src).toList();
      final body = <String, String>{
        for (var i = 0; i < heads.length; i++)
          heads[i][1]!: src.substring(
            heads[i].start,
            i + 1 < heads.length ? heads[i + 1].start : src.length,
          ),
      };
      final out = RegExp(
        r"_Msg\(\s*'out'|saveMessage\(\s*widget\.peerHaloId,\s*'out'",
      );
      final makers = <String>{};
      for (final e in body.entries) {
        final m = out.firstMatch(e.value);
        if (m == null) continue;
        makers.add(e.key);
        final ask = e.value.indexOf('_ensureDevStarted()');
        expect(ask, isNonNegative, reason: e.key);
        expect(ask, lessThan(m.start), reason: e.key);
      }
      expect(
        makers,
        containsAll([
          '_sendBody',
          '_sendVoice',
          '_sendOneImage',
          '_sendFileFrom',
        ]),
      );
      // a failed one tried again asks too
      for (final r in ['_retry', '_retryImage', '_retryMedia']) {
        expect(body[r], contains('_ensureDevStarted()'), reason: r);
      }
      // the camera, the gallery, a gif, a clip and a file end in those
      for (final p in [
        '_openCamera',
        '_pickAndSendMultiple',
        '_pickAndSendGif',
        '_pickAndSendVideo',
        '_pickAndSendFile',
      ]) {
        expect(body[p], isNot(contains('saveMessage(')), reason: p);
        expect(
          body[p]!.contains('_sendOneImage(') ||
              body[p]!.contains('_sendFileFrom('),
          isTrue,
          reason: p,
        );
      }
    });
  });

  group('voice in an anonymous chat', () {
    testWidgets('the disguise shows on and locked, and a tap only says so', (
      t,
    ) async {
      await _world();
      await _open(t);
      expect(_toggle(t).on, isFalse);
      expect(_toggle(t).locked, isFalse);
      await _chooseAnon(t);
      expect(_toggle(t).on, isTrue);
      expect(_toggle(t).locked, isTrue);
      expect(_toggle(t).label, l10n.devVoiceDisguised);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      await t.tap(find.byType(DisguiseToggle));
      await _beat(t, 300);
      expect(find.text(l10n.devVoiceDisguised), findsOneWidget);
      expect(_toggle(t).on, isTrue);
      // the three words again: the toggle is the person's own once more
      await t.tap(find.text(l10n.devUseMyWords));
      await _beat(t);
      expect(_toggle(t).locked, isFalse);
      expect(_toggle(t).on, isFalse);
      expect(_begun, isEmpty);
      await _close(t);
    });

    for (final anon in [true, false]) {
      final how = anon
          ? 'written anonymously a voice note goes out disguised'
          : 'with the three words it goes as it was recorded';
      testWidgets(how, (t) async {
        await _world(container: HaloContainer.decoy);
        await _open(t);
        if (anon) await _chooseAnon(t);
        await _speak(t, () => _sent().isNotEmpty);
        final note = _sent().single;
        expect(note['voice_disguised'], anon ? 1 : 0);
        final kept = File(note['file_path']! as String).readAsBytesSync();
        expect(listEquals(kept, _wav()), !anon);
        await _close(t);
      });
    }
  });

  group('motion and direction', () {
    testWidgets('less movement: the note is there at once, swaps at once and '
        'goes at once', (t) async {
      await _world();
      await _open(t, still: true);
      final note = find.byType(DevNote);
      expect(note, findsOneWidget);
      for (final s in t.widgetList<AnimatedSwitcher>(
        find.descendant(of: note, matching: find.byType(AnimatedSwitcher)),
      )) {
        expect(s.duration, Duration.zero);
      }
      for (final c in t.widgetList<AnimatedContainer>(
        find.descendant(of: note, matching: find.byType(AnimatedContainer)),
      )) {
        expect(c.duration, Duration.zero);
      }
      final size = t.widget<SizeTransition>(
        find.descendant(of: note, matching: find.byType(SizeTransition)).first,
      );
      expect(size.sizeFactor.value, 1);
      await t.tap(_pill);
      await t.pump();
      await t.pump();
      expect(find.text(l10n.devAnonymous), findsOneWidget);
      expect(find.text(l10n.devUseMyWords), findsOneWidget);
      await _type(t, 'quietly');
      await t.tap(find.byIcon(Icons.arrow_upward));
      await t.pump();
      await t.pump();
      await t.pump();
      expect(find.byType(DevNote), findsNothing);
      expect(find.byType(DevAnonChip), findsOneWidget);
      await _close(t);
    });

    testWidgets('with movement the note rises in and folds away as the first '
        'message goes', (t) async {
      await _world();
      await _open(t);
      await _type(t, 'hello');
      await t.tap(find.byIcon(Icons.arrow_upward));
      await t.pump();
      await t.pump(const Duration(milliseconds: 80));
      // on its way out
      expect(find.byType(DevNote), findsOneWidget);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(DevNote), findsNothing);
      await _close(t);
    });

    for (final code in ['fa', 'ar']) {
      testWidgets('$code: the note and his first line mirror, and Marios '
          'stays in Latin letters', (t) async {
        await _world();
        await _open(t, locale: Locale(code));
        final mid = t.view.physicalSize.width / t.view.devicePixelRatio / 2;
        expect(
          Directionality.of(t.element(find.byType(DevNote))),
          TextDirection.rtl,
        );
        // his line on the incoming side, which is the right in this script
        expect(t.getCenter(find.text(l10n.devWelcome)).dx, greaterThan(mid));
        // the pill at the start of the line, the right, the (i) at its end
        expect(
          t.getCenter(_pill).dx,
          greaterThan(t.getCenter(find.byTooltip(l10n.devWhoSeesWhat)).dx),
        );
        for (final s in [l10n.devWelcome, l10n.devRowTitle]) {
          expect(s, contains('Marios'));
        }
        await _chooseAnon(t);
        expect(find.text(l10n.devAnonymous), findsOneWidget);
        expect(t.takeException(), isNull);
        await _close(t);
      });
    }

    for (final code in ['de', 'ru', 'fr', 'es', 'pt', 'vi', 'fa', 'ar']) {
      testWidgets('$code at the biggest font on a small phone: the note, its '
          'sheet and the chat\'s lines fit', (t) async {
        const small = Size(1080, 2220);
        const scale = 1.6;
        final locale = Locale(code);
        // at the size most phones use, the header's line is whole too
        await _world();
        await _open(t, locale: locale, size: small, ratio: 3);
        _fits(t, '$code, note at 1');
        await _chooseAnon(t);
        _fits(t, '$code, anonymous at 1');
        await _close(t);

        await _world();
        await _open(t, locale: locale, scale: scale, size: small, ratio: 3);
        final head = {l10n.devPinned};
        _fits(t, '$code, note', skip: head);
        await _chooseAnon(t);
        _fits(t, '$code, anonymous', skip: head);
        await t.tap(find.byTooltip(l10n.devWhoSeesWhat));
        await _beat(t, 900);
        _fits(t, '$code, who sees what', skip: head);
        await _close(t);

        // the line when his key does not check out
        await _world();
        await _open(t, locale: locale, scale: scale, size: small, ratio: 3);
        _answer = DevStart.keyFailed;
        await _type(t, 'x');
        await _send(t);
        _fits(t, '$code, key', skip: {l10n.devPinned});
        await _close(t);

        // the lock line
        _answer = DevStart.ok;
        await _world();
        await _started(anon: true, out: kDevCap);
        await _open(t, locale: locale, scale: scale, size: small, ratio: 3);
        _fits(t, '$code, lock', skip: {l10n.devPinned});
        expect(find.text(l10n.devLockLine), findsOneWidget);
        await _close(t);

        // the chat that only reads, and the sheet that starts a new one
        await _restored();
        await _open(t, locale: locale, scale: scale, size: small, ratio: 3);
        expect(find.text(l10n.devNamelessLine), findsOneWidget);
        _fits(t, '$code, nameless', skip: {l10n.devPinned});
        await t.tap(find.text(l10n.devStartNewChat));
        await _beat(t, 900);
        _fits(t, '$code, start new', skip: {l10n.devPinned});
        await _close(t);
        expect(_bad, isEmpty);
      });
    }
  });

  group('a chat restored without its made name', () {
    testWidgets('it reads, says why in place of the composer, and a new '
        'chat takes its place once asked', (t) async {
      await _restored();
      await _open(t);
      expect(find.text('note 0'), findsOneWidget);
      expect(find.text(l10n.devNamelessLine), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(DevNote), findsNothing);
      // asked first: keep leaves all of it
      await t.tap(find.text(l10n.devStartNewChat));
      await _beat(t, 900);
      expect(find.text(l10n.devStartNewLine), findsOneWidget);
      await t.tap(find.text(l10n.confirmSheetKeep));
      await _beat(t, 900);
      expect(_row()!.state, DevState.anon);
      expect(_sent(), hasLength(2));
      expect(find.text(l10n.devNamelessLine), findsOneWidget);
      // yes: it goes, and a fresh chat opens in its place
      await t.tap(find.text(l10n.devStartNewChat));
      await _beat(t, 900);
      await t.tap(find.text(l10n.devStartNewChat).last);
      await _beat(t, 1200);
      expect(_row()!.state, DevState.fresh);
      expect(_mem.rows('messages'), isEmpty);
      expect(_hasDevContact, isFalse);
      expect(find.text('note 0'), findsNothing);
      expect(find.text(l10n.devNamelessLine), findsNothing);
      expect(find.text(l10n.devWelcome), findsOneWidget);
      expect(find.byType(DevNote), findsOneWidget);
      expect(_pill, findsOneWidget);
      // nothing asked of the engine or started on the way
      expect(_engine.calls, isEmpty);
      expect(_begun, isEmpty);
      await _close(t);
    });

    testWidgets('it takes no forward', (t) async {
      await _restored();
      expect(appState.devRow!.nameless, isTrue);
      expect(devForwardTarget, isNull);
    });
  });

  group('the start', () {
    // a start that answers when told to, and counts what it was asked
    Completer<DevStart>? gate;
    var asked = 0;
    Object? thrown;
    Future<DevStart> begin({required bool anon}) async {
      asked++;
      final e = thrown;
      if (e != null) throw e;
      return gate!.future;
    }

    setUp(() {
      asked = 0;
      thrown = null;
      gate = Completer<DevStart>();
    });

    DevOpening opening([String memo = 'everyday|dev:m1']) =>
        DevOpening(memo: memo, started: false, anon: false, begin: begin);

    test('asked by many at once, it starts once', () async {
      final o = opening();
      final a = o.ensure(), b = o.ensure();
      expect(o.busy, isTrue);
      // the choice holds still while it runs
      expect(o.choose(anon: true), isFalse);
      gate!.complete(DevStart.ok);
      expect(await a, DevStart.ok);
      expect(await b, DevStart.ok);
      expect(asked, 1);
      expect(o.started, isTrue);
      expect(await o.ensure(), DevStart.ok);
      expect(asked, 1);
      // and after it the choice is fixed
      expect(o.choose(anon: true), isFalse);
      expect(o.anon, isFalse);
    });

    test('a key that did not check out is told from any other failure', () {
      expect(devKeyFailed(const DevKeyCheckFailed()), isTrue);
      expect(devKeyFailed(StateError('no store')), isFalse);
      // the lane's own refusal at the key check counts, its others do not
      expect(devKeyFailed(DevSealRefused(DevRefusal.keyCheck)), isTrue);
      expect(devKeyFailed(DevSealRefused(DevRefusal.noStore)), isFalse);
      expect(devKeyFailed(DevSealRefused(DevRefusal.frame)), isFalse);
      // a photo, a file or a voice note stopped at the seal says so too
      final media = File('lib/media_send.dart').readAsStringSync();
      expect(media, contains('devKeyFailed(e) ? kDevKeyFailed'));
      final chat = File('lib/screens/chat_screen.dart').readAsStringSync();
      expect(chat, contains('result == kDevKeyFailed'));
    });

    test('a failed key or a broken start leaves it unstarted', () async {
      final o = opening();
      gate!.complete(DevStart.keyFailed);
      expect(await o.ensure(), DevStart.keyFailed);
      expect(o.started, isFalse);
      thrown = const DevKeyCheckFailed();
      expect(await o.ensure(), DevStart.keyFailed);
      thrown = StateError('half way');
      expect(await o.ensure(), DevStart.none);
      expect(o.started, isFalse);
      expect(asked, 3);
      expect(o.busy, isFalse);
    });

    test('the choice waits for the chat in memory, and a delete forgets '
        'it', () async {
      final o = opening();
      expect(o.choose(anon: true), isTrue);
      expect(o.choose(anon: true), isFalse);
      // the same chat opened again, not another container's
      expect(opening().anon, isTrue);
      expect(opening('decoy|dev:m1').anon, isFalse);
      forgetDevChoices();
      expect(opening().anon, isFalse);
      // started, it is the chat's own and no longer waits
      final p = opening();
      p.choose(anon: true);
      gate!.complete(DevStart.ok);
      await p.ensure();
      expect(p.anon, isTrue);
      expect(opening().anon, isFalse);
      // started on another screen
      final q = opening();
      q.sync(started: true, anon: true);
      expect(q.started, isTrue);
      expect(q.anon, isTrue);
    });
  });
}
