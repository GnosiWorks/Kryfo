// SPDX-License-Identifier: GPL-3.0-or-later
// the 1:1 chat's finish: the long-press menu folds back before it goes, a
// reply raises the keyboard, a reply or a reaction from the menu waits for
// the copy to land, the composer lays out what is typed in its own
// direction, the full date grows in, a reaction chip toggles, the mic says
// how it works and the group mic takes a tap off its icon, unsend can be
// kept, the forward sheet shows real faces, a blocked chat never shows the
// composer first, a dismissed banner folds, the send button only fades with
// less movement, and the record bar slides back down before it goes
import 'dart:io';

import 'package:flutter/material.dart' hide Curve;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show HaloEngine, appState, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/widgets/chat_parts.dart' show ReactionChip;
import 'package:kryfo/widgets/kryfo_avatar.dart';
import 'package:kryfo/widgets/media_bubbles.dart' show HoldToTalkMic;
import 'package:kryfo/widgets/menu_backdrop.dart';
import 'package:kryfo/widgets/voice_parts.dart'
    show RecordBarEntry, VoiceRecordBar;
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';

const _peer = 'amber-slow-river';
const _friend = 'quiet-green-fox';

class _Db extends DevTestDb {
  _Db(super.mem);

  bool keyMoved = false;
  final reactions = <String, List<MapEntry<String, String>>>{};

  Map<String, Object?>? _contact(String id) {
    for (final r in mem.rows('contacts')) {
      if (r['halo_id'] == id) return r;
    }
    return null;
  }

  Map<String, Object?>? _row(String uid) {
    for (final r in mem.rows('messages')) {
      if (r['msg_uid'] == uid) return r;
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
  Future<bool> keyChanged(String haloId) async => keyMoved;
  @override
  Future<void> setKeyChanged(String haloId, bool changed) async =>
      keyMoved = changed;
  @override
  Future<String?> getAtmosphere(String peerId) async => null;
  @override
  Future<void> clearUnread(String peerId) async {}
  @override
  Future<void> dropHeld(String peerId) async {}
  @override
  Future<int> countMessagesFrom(String peerId, {bool inGroups = false}) async =>
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
  }) async => _thread(peerId);
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
  ) async => {
    for (final u in msgUids)
      if (reactions[u] case final r?) u: List.of(r),
  };
  @override
  Future<void> addReaction(
    String msgUid,
    String reactor,
    String emoji, {
    int? at,
  }) async {
    final r = reactions.putIfAbsent(msgUid, () => []);
    r.removeWhere((e) => e.key == reactor);
    r.add(MapEntry(reactor, emoji));
  }

  @override
  Future<void> removeReaction(String msgUid, String reactor) async =>
      reactions[msgUid]?.removeWhere((e) => e.key == reactor);
  @override
  Future<void> queueFrame(
    String msgUid,
    String kind,
    String peerId,
    String body,
  ) async {}
  @override
  Future<List<Map<String, Object?>>> pinnedIn({
    String? peerId,
    String? groupId,
  }) async => [];
  @override
  Future<bool> messageExists(String msgUid) async => _row(msgUid) != null;
  @override
  Future<bool> isSent(String msgUid) async => _row(msgUid)?['sent'] == 1;
  @override
  Future<({bool sent, bool delivered})> sendState(String msgUid) async =>
      (sent: _row(msgUid)?['sent'] == 1, delivered: false);
}

// the relay: nothing is answered
class _Engine implements HaloEngine {
  @override
  String myEdPubkey() => 'ed-me';
  @override
  String myXPubkey() => 'x-me';
  @override
  void nostrSubscribeBg(String peerXPubHex) {}
  @override
  void nostrUnsubscribeBg(String peerXPubHex) {}
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

void _mock(String channel, Future<Object?> Function(MethodCall c)? h) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), h);

void main() {
  late MemDb mem;
  late _Db db;
  late Directory docs;

  Future<void> world({
    bool blocked = false,
    String text = 'are you there',
  }) async {
    mem = MemDb();
    await devChatTables(mem, now: 1);
    await mem.insert('contacts', {
      'halo_id': _peer,
      'onion': '',
      'xpub': 'ab' * 32,
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 1,
      'blocked': blocked ? 1 : 0,
    });
    await mem.insert('contacts', {
      'halo_id': _friend,
      'onion': '',
      'xpub': 'cd' * 32,
      'first_seen': 1,
      'last_seen': 2,
      'accepted': 1,
      'back_paired': 1,
      'avatar': 7,
    });
    await mem.insert('messages', {
      'peer_id': _peer,
      'direction': 'in',
      'plaintext': text,
      'msg_uid': 'u-in',
      'sent_at': DateTime.now().millisecondsSinceEpoch - 600000,
    });
    await mem.insert('messages', {
      'peer_id': _peer,
      'direction': 'out',
      'plaintext': 'on my way',
      'msg_uid': 'u-out',
      'sent': 1,
      'sent_at': DateTime.now().millisecondsSinceEpoch - 500000,
    });
    db = _Db(mem);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
    appState.sendModeForTest = 'balanced';
    useEngineForTest(_Engine());
    // the menu opens only over an unlocked app
    lockState.openForTest();
    docs = Directory.systemTemp.createTempSync('chat_polish');
    _mock('plugins.flutter.io/path_provider', (_) async => docs.path);
    _mock('com.llfbandit.record/messages', (_) async => null);
    await world();
  });

  tearDown(() {
    _mock('plugins.flutter.io/path_provider', null);
    _mock('com.llfbandit.record/messages', null);
    docs.deleteSync(recursive: true);
  });

  Widget chat() => const ChatScreen(
    peerHaloId: _peer,
    peerOnion: '',
    peerXPub:
        'abababababababababababababababababababababababababababababababab',
    avatarSeed: _peer,
  );

  Finder bubble(String text) =>
      find.textContaining(text, findRichText: true).first;

  Future<void> openMenu(WidgetTester t, String text) async {
    await t.longPress(bubble(text));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(MenuBackdrop), findsOneWidget);
  }

  for (final still in [false, true]) {
    testWidgets('the long-press menu folds back before it goes'
        '${still ? ', as a fade' : ''}', (t) async {
      await devOpen(t, chat(), still: still);
      await openMenu(t, 'are you there');
      // a tap outside: the dim is still there, on its way out
      await t.tapAt(const Offset(250, 60));
      await t.pump(const Duration(milliseconds: 60));
      expect(find.byType(MenuBackdrop), findsOneWidget);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(MenuBackdrop), findsNothing);
      await devClose(t);
    });
  }

  testWidgets('the face in the header says where it leads', (t) async {
    final sem = t.ensureSemantics();
    await devOpen(t, chat());
    final face = find.bySemanticsLabel(l10n.chatViewContact);
    expect(face, findsOneWidget);
    expect(
      t.getSemantics(face),
      matchesSemantics(
        label: l10n.chatViewContact,
        isButton: true,
        hasTapAction: true,
      ),
    );
    await devClose(t);
    sem.dispose();
  });

  testWidgets('reply from the menu raises the keyboard', (t) async {
    await devOpen(t, chat());
    await openMenu(t, 'are you there');
    await t.tap(find.byIcon(Icons.reply_rounded).last);
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    final field = t.state<EditableTextState>(find.byType(EditableText).last);
    expect(field.widget.focusNode.hasFocus, isTrue);
    await devClose(t);
  });

  // the copy goes back to where the row was: a reply bar or a reaction's
  // room that moved the row under it would make the row jump when it shows
  testWidgets('a reply from the menu waits for the copy to land', (t) async {
    await devOpen(t, chat());
    final before = t.getTopLeft(bubble('on my way'));
    await openMenu(t, 'on my way');
    await t.tap(find.byIcon(Icons.reply_rounded).last);
    await t.pump();
    await t.pump(const Duration(milliseconds: 250));
    expect(find.byType(MenuBackdrop), findsOneWidget);
    expect(t.getTopLeft(bubble('on my way')), before);
    final field = t.state<EditableTextState>(find.byType(EditableText).last);
    expect(field.widget.focusNode.hasFocus, isFalse);
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(MenuBackdrop), findsNothing);
    expect(field.widget.focusNode.hasFocus, isTrue);
    await devClose(t);
  });

  testWidgets('a reaction from the menu lands after the copy', (t) async {
    await devOpen(t, chat());
    final before = t.getTopLeft(bubble('on my way'));
    await openMenu(t, 'on my way');
    await t.tap(find.text('👍').last);
    await t.pump();
    await t.pump(const Duration(milliseconds: 250));
    expect(t.getTopLeft(bubble('on my way')), before);
    expect(db.reactions['u-out'], isNull);
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(MenuBackdrop), findsNothing);
    expect(find.byType(ReactionChip), findsOneWidget);
    expect(
      db.reactions['u-out']!.any((e) => e.key == '' && e.value == '👍'),
      isTrue,
    );
    await devClose(t);
  });

  testWidgets('the composer lays out persian in its own direction', (t) async {
    await devOpen(t, chat());
    await t.enterText(find.byType(TextField).last, 'سلام دوست من');
    await t.pump();
    expect(
      t.widget<TextField>(find.byType(TextField).last).textDirection,
      TextDirection.rtl,
    );
    await devClose(t);
  });

  testWidgets('the full date grows in under a tapped bubble', (t) async {
    await devOpen(t, chat());
    await t.tap(bubble('are you there'));
    await t.pump(const Duration(milliseconds: 16));
    final date = find.byKey(const ValueKey('full-date'));
    expect(date, findsOneWidget);
    expect(
      find.ancestor(of: date, matching: find.byType(SizeTransition)),
      findsWidgets,
    );
    await devClose(t);
  });

  testWidgets('a tap on their reaction puts the same one on from here', (
    t,
  ) async {
    db.reactions['u-in'] = [const MapEntry(_peer, '👍')];
    await devOpen(t, chat());
    final two = find.descendant(
      of: find.byType(ReactionChip),
      matching: find.text('2'),
    );
    expect(find.byType(ReactionChip), findsOneWidget);
    expect(two, findsNothing);
    await t.tap(find.byType(ReactionChip));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(two, findsOneWidget);
    expect(
      db.reactions['u-in']!.any((e) => e.key == '' && e.value == '👍'),
      isTrue,
    );
    await devClose(t);
  });

  testWidgets('a short tap on the mic says to hold it', (t) async {
    // a chat no other test types in, so no draft comes back with it
    await devOpen(
      t,
      const ChatScreen(
        peerHaloId: _friend,
        peerOnion: '',
        peerXPub:
            'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd',
        avatarSeed: _friend,
      ),
    );
    await t.tap(find.byIcon(Icons.mic_none_rounded));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Hold to record a voice note'), findsOneWidget);
    await t.pump(const Duration(seconds: 4));
    await devClose(t);
  });

  // the group composer's mic: a finger-sized target, not the bare icon
  testWidgets('the group mic takes a tap beside its icon', (t) async {
    await devOpen(
      t,
      Scaffold(
        body: Center(
          child: HoldToTalkMic(
            disguise: false,
            onToggleDisguise: () {},
            onComplete: (_, _, _) {},
          ),
        ),
      ),
    );
    final mic = find.byType(HoldToTalkMic);
    expect(t.getSize(mic).width, greaterThanOrEqualTo(36));
    expect(t.getSize(mic).height, greaterThanOrEqualTo(40));
    // off the icon, toward the start and the top
    await t.tapAt(t.getTopLeft(mic) + const Offset(4, 4));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Hold to record a voice note'), findsOneWidget);
    await t.pump(const Duration(seconds: 4));
    await devClose(t);
  });

  testWidgets('unsend asks first and can be kept', (t) async {
    await devOpen(t, chat());
    await openMenu(t, 'on my way');
    await t.tap(find.text('Unsend'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Keep'), findsOneWidget);
    await t.tap(find.text('Keep'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(
      mem.rows('messages').where((r) => r['msg_uid'] == 'u-out'),
      hasLength(1),
    );
    expect(bubble('on my way'), findsOneWidget);
    await devClose(t);
  });

  testWidgets('the forward sheet shows the face each contact chose', (t) async {
    await devOpen(t, chat());
    await openMenu(t, 'are you there');
    await t.tap(find.text('Forward'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    final face = find.byWidgetPredicate(
      (w) => w is KryfoAvatar && w.seed == _friend,
    );
    expect(face, findsOneWidget);
    expect(t.widget<KryfoAvatar>(face).choice, 7);
    await devClose(t);
  });

  testWidgets('a blocked chat never draws the composer first', (t) async {
    await world(blocked: true);
    t.view.physicalSize = const Size(1000, 1800);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(devApp(chat()));
    expect(find.byType(TextField), findsNothing);
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 16));
      expect(find.byType(TextField), findsNothing);
    }
    await t.pump(const Duration(seconds: 1));
    expect(find.byType(TextField), findsNothing);
    await devClose(t);
  });

  testWidgets('the security code notice folds away when dismissed', (t) async {
    db.keyMoved = true;
    await devOpen(t, chat());
    // the notice grows in once its state is read
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Security code changed'), findsOneWidget);
    await t.tap(find.text('Ok'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));
    expect(find.text('Security code changed'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Security code changed'), findsNothing);
    await devClose(t);
  });

  testWidgets('with less movement the send button only fades in', (t) async {
    await devOpen(
      t,
      const ChatScreen(
        peerHaloId: _friend,
        peerOnion: '',
        peerXPub:
            'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd',
        avatarSeed: _friend,
      ),
      still: true,
    );
    final field = find.byType(TextField).last;
    final above = find
        .ancestor(of: field, matching: find.byType(ScaleTransition))
        .evaluate()
        .toSet();
    await t.enterText(field, 'hi');
    await t.pump();
    await t.pump(const Duration(milliseconds: 16));
    // nothing between them is part way grown
    final grows = find
        .ancestor(
          of: find.byIcon(Icons.arrow_upward),
          matching: find.byType(ScaleTransition),
        )
        .evaluate()
        .where(
          (e) =>
              !above.contains(e) &&
              (e.widget as ScaleTransition).scale.value != 1.0,
        );
    expect(grows, isEmpty);
    await t.enterText(field, '');
    await t.pump(const Duration(milliseconds: 400));
    await devClose(t);
  });

  testWidgets('the record bar slides back down before it goes', (t) async {
    late RecordBarEntry bar;
    await t.pumpWidget(
      devApp(
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () {
                bar = RecordBarEntry(
                  (leaving) => Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: VoiceRecordBar(
                      time: '0:03',
                      cancel: false,
                      drag: 0,
                      disguise: false,
                      levels: const [],
                      releaseLabel: 'Release to cancel',
                      slideLabel: 'Slide to cancel',
                      hiddenLabel: 'Voice hidden',
                      closeLabel: 'Close',
                      onClose: () {},
                      leaving: leaving,
                    ),
                  ),
                );
                Overlay.of(context).insert(bar.entry);
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('go'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(VoiceRecordBar), findsOneWidget);
    bar.leave();
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));
    expect(find.byType(VoiceRecordBar), findsOneWidget);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(VoiceRecordBar), findsNothing);
  });
}
