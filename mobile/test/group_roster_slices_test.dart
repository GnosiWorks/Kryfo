// SPDX-License-Identifier: GPL-3.0-or-later
// an admin's group file carries the member list on each slice, read as
// that slice goes: someone removed while the file is still going out is
// not on the slices after the remove, so no other phone takes them back.
// once the admin has left, the slices carry no list at all, and the ids
// and cards on a slice are always of the same list. the databases and the
// engine are stand-ins
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloEngine, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _b = 'amber-slow-river';
const _c = 'cedar-tall-wind';
const _d = 'dune-quiet-path';
const _g = 'grp000000001';

class _Engine implements HaloEngine {
  @override
  String myXPubkey() => 'x-me';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// a relay that runs [onSend] before it takes each envelope. a peer in
// [missFirst] misses the first try of the slice listed for them, on both
// routes
class _Io extends ArrivalIo {
  void Function()? onSend;
  final missFirst = <String, int>{};
  final _missed = <String>{};

  bool _misses(String route, String peer, String cipher) {
    final i = missFirst[peer];
    if (i == null) return false;
    final env = unwrapMessage(cipher.substring('to $peer '.length));
    return env.chunkIndex == i && _missed.add('$route $peer');
  }

  @override
  Future<String> relaySend(String xPub, String cipher) async {
    if (_misses('relay', xPub.substring(2), cipher)) return 'error: down';
    onSend?.call();
    return super.relaySend(xPub, cipher);
  }

  @override
  Future<String> onionSend(String onion, String cipher) async {
    if (_misses('onion', onion.substring(2), cipher)) return 'error: down';
    return super.onionSend(onion, cipher);
  }
}

// a store whose rows take a moment, as a real one does
class _SlowRows extends ArrivalRows {
  _SlowRows() : super(HaloContainer.everyday);
  @override
  Future<Map<String, Object?>?> getContact(String haloId) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return super.getContact(haloId);
  }
}

// the slices that went to [who] by relay: index, ids and card ids
List<(int, List<String>?, Set<String?>?)> _slicesTo(_Io io, String who) => [
  for (final (to, cipher) in io.sent)
    if (to == 'relay x-$who')
      () {
        final env = unwrapMessage(cipher.substring('to $who '.length));
        return (
          env.chunkIndex!,
          env.roster,
          env.rosterParticipants == null
              ? null
              : {for (final p in env.rosterParticipants!) p['h']},
        );
      }(),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('roster_slices');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tmp.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => tmp.delete(recursive: true));

  test('a member removed mid-file is off the slices after', () async {
    final live = ArrivalRows(HaloContainer.everyday)
      ..person(_b, onion: 'o-$_b', xpub: 'x-$_b')
      ..person(_c, onion: 'o-$_c', xpub: 'x-$_c')
      ..group(_g, ['me', _b, _c], admin: 'me');
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    useEngineForTest(_Engine());
    final io = _Io();
    final app = AppState(io: io, router: router)..myId = 'me';
    useDatabasesForTest(live, Session(live));

    // three slices
    final path = '${tmp.path}/notes.bin';
    await File(path).writeAsBytes(List.filled(12288 * 2 + 10, 7));
    // c is removed while the first slice goes out
    io.onSend = () {
      if (io.sent.length == 1) live.members[_g]!.remove(_c);
    };
    final r = await app.sendMediaToGroup(
      _g,
      path,
      msgUid: 'file1',
      fileName: 'notes.bin',
    );
    expect(r, 'ok');

    final toB = <int, List<String>?>{};
    for (final (to, cipher) in io.sent) {
      if (to != 'relay x-$_b') continue;
      final env = unwrapMessage(cipher.substring('to $_b '.length));
      toB[env.chunkIndex!] = env.roster;
      final ids = {for (final p in env.rosterParticipants!) p['h']};
      expect(ids, env.roster!.toSet(), reason: 'slice ${env.chunkIndex}');
    }
    expect(toB.keys, [0, 1, 2]);
    expect(toB[0], ['me', _b, _c]);
    expect(toB[1], ['me', _b]);
    expect(toB[2], ['me', _b]);
  });

  test('the admin leaving mid-file sends no list after', () async {
    final live = ArrivalRows(HaloContainer.everyday)
      ..person(_b, onion: 'o-$_b', xpub: 'x-$_b')
      ..person(_c, onion: 'o-$_c', xpub: 'x-$_c')
      ..group(_g, ['me', _b, _c], admin: 'me');
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    useEngineForTest(_Engine());
    final io = _Io();
    final app = AppState(io: io, router: router)..myId = 'me';
    useDatabasesForTest(live, Session(live));

    final path = '${tmp.path}/notes.bin';
    await File(path).writeAsBytes(List.filled(12288 * 2 + 10, 7));
    // the group goes from this phone while the first slice goes out
    io.onSend = () {
      if (io.sent.length == 1) unawaited(live.deleteGroup(_g));
    };
    final r = await app.sendMediaToGroup(
      _g,
      path,
      msgUid: 'file2',
      fileName: 'notes.bin',
    );
    expect(r, 'ok');

    final toB = _slicesTo(io, _b);
    expect([for (final s in toB) s.$1], [0, 1, 2]);
    expect(toB[0].$2, ['me', _b, _c]);
    for (final (i, ids, cards) in toB.skip(1)) {
      expect(ids, isNull, reason: 'slice $i');
      expect(cards, isNull, reason: 'slice $i');
    }
  });

  test('slices wrapped side by side carry one list', () async {
    final live = _SlowRows()
      ..person(_b, onion: 'o-$_b', xpub: 'x-$_b')
      ..person(_c, onion: 'o-$_c', xpub: 'x-$_c')
      ..person(_d, onion: 'o-$_d', xpub: 'x-$_d')
      ..group(_g, ['me', _b, _c, _d], admin: 'me');
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    useEngineForTest(_Engine());
    final io = _Io();
    final app = AppState(io: io, router: router)..myId = 'me';
    useDatabasesForTest(live, Session(live));

    final path = '${tmp.path}/notes.bin';
    await File(path).writeAsBytes(List.filled(12288 * 2 + 10, 7));
    // b and c miss the first slice, so the rounds at the end wrap it for
    // both at once. d is removed as the last slice goes out
    io.missFirst.addAll({_b: 0, _c: 0});
    io.onSend = () {
      final last = io.sent.where((s) => s.$1 == 'relay x-$_d').length == 2;
      if (last) live.members[_g]!.remove(_d);
    };
    final r = await app.sendMediaToGroup(
      _g,
      path,
      msgUid: 'file3',
      fileName: 'notes.bin',
    );
    expect(r, 'ok');

    for (final who in [_b, _c]) {
      final got = _slicesTo(io, who);
      expect({for (final s in got) s.$1}, {0, 1, 2}, reason: who);
      for (final (i, ids, cards) in got) {
        expect(cards, ids!.toSet(), reason: '$who slice $i');
      }
      // the slice caught up on is of the list after the remove
      final late = got.lastWhere((s) => s.$1 == 0);
      expect(late.$2, ['me', _b, _c], reason: who);
    }
  });
}
