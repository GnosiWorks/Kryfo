// SPDX-License-Identifier: GPL-3.0-or-later
// a long message in a group keeps the 1:1 bubble cap: ours sits at the end
// with a gap at the start, theirs at the start beside the avatar and name,
// mirrored right to left, and a large text size wraps instead of clipping
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart' show HaloDb, useDatabasesForTest;
import 'package:kryfo/screens/group_chat_screen.dart';
import 'package:kryfo/polls.dart' show PollVote;
import 'package:kryfo/session.dart';
import 'package:kryfo/widgets/kryfo_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart' show app, phone;

const _group = 'g1';
const _mine =
    'mine: a long line of words that would run from one edge of the '
    'screen to the other if nothing held the bubble back at all';
const _theirs =
    'theirs: a long line of words that would run from one edge of the '
    'screen to the other if nothing held the bubble back at all';

class _GroupDb implements HaloDb {
  final rows = <Map<String, Object?>>[];

  void add(String text, {required bool out}) {
    final id = rows.length + 1;
    rows.add({
      'rowid': id,
      'id': id,
      'peer_id': out ? 'me' : 'amber',
      'group_id': _group,
      'direction': out ? 'out' : 'in',
      'plaintext': text,
      'msg_uid': 'uid$id',
      'sent': 1,
      'sent_at': DateTime.now()
          .subtract(Duration(minutes: 10 - id))
          .millisecondsSinceEpoch,
    });
  }

  @override
  HaloContainer get container => HaloContainer.everyday;

  @override
  Future<Map<String, Object?>?> getGroup(String groupId) async => {
    'group_id': _group,
    'name': 'Friends',
    'is_admin': 0,
  };
  @override
  Future<String?> getGroupAtmosphere(String groupId) async => null;
  @override
  Future<List<String>> getGroupMembers(String groupId) async => ['amber'];
  @override
  Future<Set<String>> blockedIds() async => {};
  @override
  Future<List<Map<String, Object?>>> groupMessagesPage(
    String groupId, {
    int? beforeRowid,
    int? beforeAt,
    int limit = 60,
  }) async => beforeRowid == null ? [...rows] : [];
  @override
  Future<List<Map<String, Object?>>> loadGroupMessages(String groupId) async =>
      [...rows];
  @override
  Future<List<Map<String, Object?>>> groupMessagesAfter(
    String groupId,
    int afterRowid,
  ) async => [
    for (final r in rows)
      if ((r['rowid'] as int) > afterRowid) r,
  ];
  @override
  Future<Map<String, List<MapEntry<String, String>>>> loadReactionsFor(
    List<String> msgUids,
  ) async => {};
  @override
  Future<Map<String, Map<String, PollVote>>> pollVotesFor(
    List<String> uids,
  ) async => {};
  @override
  Future<Map<String, ({int have, int of, int gaveUp})>> groupFileReach(
    String groupId,
  ) async => {};
  @override
  Future<List<Map<String, Object?>>> pinnedIn({
    String? peerId,
    String? groupId,
  }) async => [];
  @override
  Future<Map<String, Object?>?> shieldFor(String haloId) async => null;
  @override
  Future<bool> isAccepted(String haloId) async => true;
  @override
  Future<void> markRoomSeen(String groupId) async {}
  @override
  Future<void> clearGroupUnread(String groupId) async {}
  @override
  Future<List<Map<String, Object?>>> loadGroups() async => [];
  @override
  Future<({bool sent, bool delivered})> sendState(String msgUid) async =>
      (sent: true, delivered: true);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

Future<void> _open(
  WidgetTester t, {
  Locale locale = const Locale('en'),
  double scale = 1,
  List<bool> outs = const [false, true],
}) async {
  phone(t);
  final db = _GroupDb();
  for (final out in outs) {
    db.add(out ? _mine : _theirs, out: out);
  }
  useDatabasesForTest(db, Session(db));
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  await t.pumpWidget(
    app(const GroupChatScreen(groupId: _group), locale: locale),
  );
  for (var i = 0; i < 20; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

// the drawn bubble around these words: the box its padding wraps
Rect _bubble(WidgetTester t, String words) {
  final inner = find.ancestor(
    of: find.text(words, findRichText: true),
    matching: find.byType(IntrinsicWidth),
  );
  final box = find.ancestor(of: inner.first, matching: find.byType(Container));
  return t.getRect(box.first);
}

Future<void> _close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  const width = 360.0;
  const cap = width * 0.78;

  testWidgets('a long message of ours is no wider than the 1:1 cap and '
      'sits at the end', (t) async {
    await _open(t);
    final b = _bubble(t, _mine);
    expect(b.width, lessThanOrEqualTo(cap + 0.5));
    expect(b.width, greaterThan(cap - 40), reason: 'it still fills its cap');
    expect(b.right, greaterThan(width - 20), reason: 'at the end side');
    expect(b.left, greaterThan(width - cap - 20), reason: 'a gap at the start');
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('right to left, ours keeps the cap at the left end', (t) async {
    await _open(t, locale: const Locale('ar'));
    final b = _bubble(t, _mine);
    expect(b.width, lessThanOrEqualTo(cap + 0.5));
    expect(b.left, lessThan(20), reason: 'the end side is the left');
    expect(b.right, lessThan(cap + 20), reason: 'a gap at the right');
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('theirs keeps the cap beside the avatar and a whole name row', (
    t,
  ) async {
    await _open(t);
    final b = _bubble(t, _theirs);
    final face = t.getRect(find.byType(KryfoAvatar).first);
    final name = t.getRect(find.text('amber').last);
    expect(b.width, lessThanOrEqualTo(cap + 0.5));
    expect(
      b.left,
      greaterThanOrEqualTo(face.right),
      reason: 'room for the face',
    );
    expect(name.left, greaterThanOrEqualTo(face.right));
    expect(name.bottom, lessThanOrEqualTo(b.top + 0.5), reason: 'above it');
    expect(name.width, greaterThan(0));
    expect(width - b.right, greaterThan(20), reason: 'a gap at the end');
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('right to left, theirs keeps the cap at the right', (t) async {
    await _open(t, locale: const Locale('ar'));
    final b = _bubble(t, _theirs);
    final face = t.getRect(find.byType(KryfoAvatar).first);
    expect(b.width, lessThanOrEqualTo(cap + 0.5));
    expect(b.right, lessThanOrEqualTo(face.left));
    expect(b.left, greaterThan(20), reason: 'a gap at the left');
    expect(t.takeException(), isNull);
    await _close(t);
  });

  test('a photo, album or poll keeps its own width on a narrow screen', () {
    expect(groupBubbleCap(360), closeTo(280.8, 0.01));
    expect(groupBubbleCap(300, own: 260), 260);
    expect(groupBubbleCap(300, own: 240), 240);
    expect(groupBubbleCap(800, own: 260), closeTo(624, 0.01));
  });

  testWidgets('a large text size wraps inside the cap with nothing clipped', (
    t,
  ) async {
    // one at a time: two tall bubbles do not fit one screen
    for (final out in [true, false]) {
      await _open(t, scale: 2, outs: [out]);
      final words = out ? _mine : _theirs;
      final b = _bubble(t, words);
      final text = t.getRect(find.text(words, findRichText: true));
      expect(b.width, lessThanOrEqualTo(cap + 0.5));
      expect(text.bottom, lessThanOrEqualTo(b.bottom));
      expect(text.right, lessThanOrEqualTo(b.right));
      expect(t.takeException(), isNull);
      await _close(t);
    }
  });
}
