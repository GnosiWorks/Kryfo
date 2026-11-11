// SPDX-License-Identifier: GPL-3.0-or-later
// android's share menu: off by default; on, the latest everyday 1:1 chats
// by the names the chats show; never a hidden, blocked or archived chat or
// the decoy's; gone at once when turned off and the moment the app locks,
// back at the unlock; a hidden chat leaves with the next list; a pick
// lands only where it still may; a computer and an older android get none
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/screens/home_screen.dart' show ContactPreview;
import 'package:kryfo/share_targets.dart';
import 'package:kryfo/share_text.dart';
import 'package:kryfo/tools/tools_bridge.dart';

class _Io implements ShareTargetsIo {
  bool ok = true;
  final calls = <List<ShareTarget>>[];
  @override
  Future<bool> supported() async => ok;
  @override
  Future<void> publish(List<ShareTarget> list) async => calls.add(list);
  @override
  Future<void> clear() async => calls.add(const []);
}

ContactPreview _c(
  String id, {
  String? nick,
  int at = 0,
  bool hidden = false,
  bool blocked = false,
  bool archived = false,
}) => ContactPreview(
  haloId: id,
  nickname: nick,
  avatarSeed: id,
  when: DateTime.fromMillisecondsSinceEpoch(at),
  hidden: hidden,
  blocked: blocked,
  archived: archived,
);

class _World {
  var on = false;
  var locked = false;
  var everyday = true;
  var contacts = <ContactPreview>[];
  final io = _Io();
  late final targets = ShareTargets(
    io: io,
    facts: (o) => ShareFacts(
      on: o,
      locked: locked,
      everyday: everyday,
      contacts: contacts,
    ),
    loadOn: () async => on,
    salt: () async => 'salt',
    settle: const Duration(milliseconds: 20),
    android: true,
  );

  List<String> get names => [for (final t in io.calls.last) t.name];

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 60));
}

void main() {
  test(
    'off by default: what an earlier run left goes, nothing comes',
    () async {
      final w = _World()..contacts = [_c('anna-blue-fox', at: 5)];
      await w.targets.startForTest();
      await w.settle();
      expect(w.io.calls, [const <ShareTarget>[]]);
    },
  );

  test('on: the latest everyday chats by their names, four at most, never '
      'a hidden, blocked or archived one', () async {
    final w = _World()
      ..on = true
      ..contacts = [
        _c('a-a-a', nick: 'Anna', at: 1),
        _c('b-b-b', nick: 'Ben', at: 6),
        _c('c-c-c', at: 5),
        _c('h-h-h', nick: 'Hidden', at: 9, hidden: true),
        _c('x-x-x', nick: 'Blocked', at: 8, blocked: true),
        _c('r-r-r', nick: 'Archived', at: 7, archived: true),
        _c('d-d-d', nick: 'Dora', at: 4),
        _c('e-e-e', nick: 'Emil', at: 3),
      ];
    await w.targets.startForTest();
    await w.settle();
    // the name the chat shows: the nickname, else the kryfo id
    expect(w.names, ['Ben', 'c-c-c', 'Dora', 'Emil']);
    // no id in the menu names a kryfo id
    for (final t in w.io.calls.last) {
      expect(t.id, isNot(contains(t.chat)));
      expect(t.id, shareTargetId('salt', t.chat));
    }
    expect(w.io.calls.last.first.toMap()['initial'], 'B');
  });

  test('the lock takes them at once, the unlock brings them back', () async {
    final w = _World()
      ..on = true
      ..contacts = [_c('a-a-a', nick: 'Anna', at: 1)];
    await w.targets.startForTest();
    await w.settle();
    expect(w.names, ['Anna']);
    w.locked = true;
    w.targets.changed();
    // no wait for the settle: gone before the next turn of the loop
    await Future<void>.delayed(Duration.zero);
    expect(w.io.calls.last, isEmpty);
    w.locked = false;
    w.targets.changed();
    await w.settle();
    expect(w.names, ['Anna']);
  });

  test('turned off: gone at once; the decoy: none', () async {
    final w = _World()
      ..on = true
      ..contacts = [_c('a-a-a', nick: 'Anna', at: 1)];
    await w.targets.startForTest();
    await w.settle();
    w.targets.everydayOn(false);
    await Future<void>.delayed(Duration.zero);
    expect(w.io.calls.last, isEmpty);
    w.targets.everydayOn(true);
    await w.settle();
    expect(w.names, ['Anna']);
    w.everyday = false;
    w.targets.changed();
    await Future<void>.delayed(Duration.zero);
    expect(w.io.calls.last, isEmpty);
    await w.settle();
    expect(w.io.calls.last, isEmpty);
  });

  test('a chat hidden or deleted leaves the menu', () async {
    final w = _World()
      ..on = true
      ..contacts = [
        _c('a-a-a', nick: 'Anna', at: 1),
        _c('b-b-b', nick: 'Ben', at: 2),
      ];
    await w.targets.startForTest();
    await w.settle();
    expect(w.names, ['Ben', 'Anna']);
    w.contacts = [
      _c('a-a-a', nick: 'Anna', at: 1),
      _c('b-b-b', at: 2, hidden: true),
    ];
    w.targets.changed();
    await w.settle();
    expect(w.names, ['Anna']);
    w.contacts = [];
    w.targets.changed();
    await w.settle();
    expect(w.io.calls.last, isEmpty);
  });

  test('the same list is told once', () async {
    final w = _World()
      ..on = true
      ..contacts = [_c('a-a-a', nick: 'Anna', at: 1)];
    await w.targets.startForTest();
    await w.settle();
    w.targets.changed();
    w.targets.changed();
    await w.settle();
    expect(w.io.calls, hasLength(1));
  });

  test('a pick in the menu lands only where it still may', () async {
    final w = _World()
      ..on = true
      ..contacts = [_c('a-a-a', nick: 'Anna', at: 1)];
    await w.targets.startForTest();
    final id = shareTargetId('salt', 'a-a-a');
    expect(await w.targets.chatFor(id), 'a-a-a');
    expect(await w.targets.chatFor('cnothing'), isNull);
    expect(await w.targets.chatFor(null), isNull);
    w.locked = true;
    expect(await w.targets.chatFor(id), isNull);
    w.locked = false;
    w.everyday = false;
    expect(await w.targets.chatFor(id), isNull);
    w.everyday = true;
    w.contacts = [_c('a-a-a', at: 1, hidden: true)];
    expect(await w.targets.chatFor(id), isNull);
    w.contacts = [_c('a-a-a', at: 1)];
    w.targets.everydayOn(false);
    expect(await w.targets.chatFor(id), isNull);
  });

  test('an older android publishes nothing; a computer asks nothing', () async {
    final w = _World()
      ..on = true
      ..contacts = [_c('a-a-a', nick: 'Anna', at: 1)];
    w.io.ok = false;
    await w.targets.startForTest();
    await w.settle();
    expect(w.io.calls, isEmpty);
    expect(await w.targets.supported(), isFalse);

    final io = _Io();
    final desk = ShareTargets(
      io: io,
      facts: (o) => ShareFacts(
        on: true,
        locked: false,
        everyday: true,
        contacts: [_c('a-a-a', at: 1)],
      ),
      loadOn: () async => true,
      salt: () async => 'salt',
      android: false,
    );
    await desk.start();
    desk.changed();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(io.calls, isEmpty);
    expect(await desk.supported(), isFalse);
    expect(await desk.chatFor(shareTargetId('salt', 'a-a-a')), isNull);
  });

  test('the picked chat rides along with what was shared', () {
    expect(
      SharedText.from({'id': 's1', 'text': 'hi', 'chat': 'cabc'})!.chat,
      'cabc',
    );
    expect(SharedText.from({'id': 's1', 'text': 'hi'})!.chat, isNull);
    final f = SharedFiles.from({
      'id': 'f1',
      'chat': 'cabc',
      'items': [
        {'uri': 'content://x/1'},
      ],
    });
    expect(f!.chat, 'cabc');
  });
}
