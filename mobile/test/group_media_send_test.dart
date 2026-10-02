// SPDX-License-Identifier: GPL-3.0-or-later
// a group file goes slice by slice to each member. a slice one member missed
// while the others got it goes to that member again, a stop stops it between
// slices, and the progress strip ends with the send however it ends. the
// members are stand-ins that take or refuse what they are given
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/group_media_send.dart';
import 'package:kryfo/jpeg_strip.dart';
import 'package:kryfo/media_progress.dart';
import 'package:kryfo/media_send.dart';

import 'source_body.dart';

class _Members {
  // member -> slices it took
  final got = <String, Set<int>>{};
  // every slice offered, in order, as (member, slice)
  final offered = <(String, int)>[];
  // refuses this offer when true
  bool Function(String m, int i, int n) refuse = (_, _, _) => false;
  void Function(String m, int i)? onOffer;

  Future<bool> deliver(String m, String wrapped) async {
    final i = int.parse(wrapped);
    offered.add((m, i));
    onOffer?.call(m, i);
    final n = offered.where((o) => o == (m, i)).length;
    if (refuse(m, i, n)) return false;
    got.putIfAbsent(m, () => {}).add(i);
    return true;
  }
}

void main() {
  late Directory tmp;
  late String path;
  var uid = 0;
  late String msgUid;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('group_slices');
    path = '${tmp.path}/clip.mp4';
    // five slices
    await File(path).writeAsBytes(List.filled(12288 * 4 + 10, 7));
    msgUid = 'm${uid++}';
  });
  tearDown(() async {
    groupMediaOwed.clear();
    await tmp.delete(recursive: true);
  });

  Future<String> send(_Members g, List<String> to) => sendGroupSlices(
    path: path,
    msgUid: msgUid,
    members: to,
    wrap: (slice, i, total) async => '$i',
    deliver: g.deliver,
    progressKey: 'group:g1',
    gap: Duration.zero,
    retryPause: Duration.zero,
  );

  test('every member gets every slice once when all goes well', () async {
    final g = _Members();
    expect(await send(g, ['b', 'c', 'd']), 'ok');
    for (final m in ['b', 'c', 'd']) {
      expect(g.got[m], {0, 1, 2, 3, 4});
    }
    expect(g.offered.length, 15);
  });

  test('a slice one member missed goes to that member again', () async {
    final g = _Members()..refuse = (m, i, n) => m == 'b' && i == 3 && n == 1;
    expect(await send(g, ['b', 'c', 'd']), 'ok');
    expect(g.got['b'], {0, 1, 2, 3, 4});
    // and to nobody else: the others had it the first time
    expect(g.offered.where((o) => o.$2 == 3).length, 4);
    expect(g.offered.where((o) => o == ('c', 3)).length, 1);
  });

  test('a member that took nothing is caught up once it can take', () async {
    // no session yet on the way through, there by the rounds at the end
    final g = _Members()..refuse = (m, i, n) => m == 'b' && n == 1;
    expect(await send(g, ['b', 'c']), 'ok');
    expect(g.got['b'], {0, 1, 2, 3, 4});
    expect(g.got['c'], {0, 1, 2, 3, 4});
  });

  test('a member out of reach is tried a few at a time', () async {
    final g = _Members()..refuse = (m, i, n) => m == 'b';
    expect(await send(g, ['b', 'c']), 'ok');
    expect(g.got['c'], {0, 1, 2, 3, 4});
    expect(g.got['b'], isNull);
    final toB = g.offered.where((o) => o.$1 == 'b').length;
    expect(toB, 5 + kGroupCatchUpPasses * kGroupMemberMisses);
  });

  group('a member still short when the send ends', () {
    // the row reads sent by then, so what is owed goes from the outbox
    Future<String> owedTo(_Members g, List<String> to) => sendGroupSlices(
      path: path,
      msgUid: msgUid,
      members: to,
      wrap: (slice, i, total) async => '$i',
      deliver: g.deliver,
      gap: Duration.zero,
      retryPause: Duration.zero,
      onShort: (short) => noteGroupShort(
        msgUid,
        tried: to,
        short: short,
        resend: (owed) => owedTo(g, owed),
        now: 0,
      ),
    );

    test('gets the file once its session is there', () async {
      var healed = false;
      final g = _Members()..refuse = (m, i, n) => m == 'b' && !healed;
      expect(await owedTo(g, ['b', 'c']), 'ok');
      expect(g.got['b'], isNull);
      expect(groupMediaOwed[msgUid]?.members, {'b'});

      final before = g.offered.length;
      await resendGroupOwed(now: kGroupOwedGap - 1);
      expect(g.offered.length, before);

      // still no session: kept, and tried later than the first time
      await resendGroupOwed(now: kGroupOwedGap);
      expect(g.offered.length, greaterThan(before));
      final owed = groupMediaOwed[msgUid]!;
      expect(owed.members, {'b'});
      expect(owed.nextAt - kGroupOwedGap, greaterThan(kGroupOwedGap));

      healed = true;
      await resendGroupOwed(now: owed.nextAt);
      expect(g.got['b'], {0, 1, 2, 3, 4});
      expect(groupMediaOwed, isEmpty);
      // and the ones that had it are sent nothing again
      expect(g.offered.where((o) => o.$1 == 'c').length, 5);
    });

    test('is sent only the slices it still lacks', () async {
      var healed = false;
      final g = _Members()..refuse = (m, i, n) => m == 'b' && i >= 2 && !healed;
      expect(await owedTo(g, ['b', 'c']), 'ok');
      expect(g.got['b'], {0, 1});
      healed = true;
      final before = g.offered.length;
      await resendGroupOwed(now: kGroupOwedGap);
      expect(g.offered.sublist(before), [('b', 2), ('b', 3), ('b', 4)]);
      expect(groupMediaOwed, isEmpty);
    });

    test('is let go with its row, and after a day', () async {
      var asked = 0;
      Future<String> gone(List<String> to) async {
        asked++;
        return 'gone';
      }

      noteGroupShort('x', tried: ['b'], short: ['b'], resend: gone, now: 0);
      await resendGroupOwed(now: kGroupOwedGap);
      expect(asked, 1);
      expect(groupMediaOwed, isEmpty);

      noteGroupShort('y', tried: ['b'], short: ['b'], resend: gone, now: 0);
      await resendGroupOwed(now: kGroupOwedFor + 1);
      expect(asked, 1);
      expect(groupMediaOwed, isEmpty);
    });

    test('waits longer each try, ten minutes at most', () async {
      var asked = 0;
      noteGroupShort(
        'x',
        tried: ['b'],
        short: ['b'],
        resend: (_) async {
          asked++;
          return 'error: no session';
        },
        now: 0,
      );
      var at = 0;
      for (var k = 0; k < 80; k++) {
        at = groupMediaOwed['x']!.nextAt;
        await resendGroupOwed(now: at);
        final gap = groupMediaOwed['x']!.nextAt - at;
        expect(gap, inInclusiveRange(kGroupOwedGap, kGroupOwedGapMost));
      }
      expect(asked, 80);
    });
  });

  test('a member that went quiet halfway is tried a few at a time', () async {
    final g = _Members()..refuse = (m, i, n) => m == 'b' && i >= 2;
    expect(await send(g, ['b', 'c']), 'ok');
    expect(g.got['b'], {0, 1});
    final toB = g.offered.where((o) => o.$1 == 'b').length;
    expect(toB, 5 + kGroupCatchUpPasses * kGroupMemberMisses);
  });

  test('the rounds at the end run for every member at once', () async {
    var open = 0;
    var most = 0;
    var rounds = false;
    var stripInRounds = false;
    final g = _Members()..refuse = (m, i, n) => i == 4 && n == 1 && m != 'd';
    Future<bool> slow(String m, String w) async {
      final i = int.parse(w);
      final late = g.offered.where((o) => o == (m, i)).isNotEmpty;
      rounds = rounds || (late && i == 4);
      if (rounds) {
        stripInRounds = stripInRounds || mediaSendProgress.containsKey(msgUid);
        open++;
        most = most > open ? most : open;
        await Future.delayed(const Duration(milliseconds: 20));
        open--;
      }
      return g.deliver(m, w);
    }

    final r = await sendGroupSlices(
      path: path,
      msgUid: msgUid,
      members: ['b', 'c', 'd'],
      wrap: (slice, i, total) async => '$i',
      deliver: slow,
      progressKey: 'group:g1',
      gap: Duration.zero,
      retryPause: Duration.zero,
    );
    expect(r, 'ok');
    expect(g.got['b'], {0, 1, 2, 3, 4});
    expect(g.got['c'], {0, 1, 2, 3, 4});
    expect(most, 2);
    // every slice has reached someone: the strip and its stop are gone
    expect(stripInRounds, isFalse);
  });

  test('a photo goes out cleaned, the saved file with it', () async {
    final raw = File('test/fixtures/gallery_gps.jpg').readAsBytesSync();
    final pic = '${tmp.path}/old.jpg';
    await File(pic).writeAsBytes(raw);
    final slices = <int, String>{};
    final r = await sendGroupSlices(
      path: pic,
      msgUid: msgUid,
      members: ['b'],
      photo: true,
      wrap: (slice, i, total) async {
        slices[i] = slice;
        return '$i';
      },
      deliver: (m, w) async => true,
      gap: Duration.zero,
      retryPause: Duration.zero,
    );
    expect(r, 'ok');
    final sent = <int>[
      for (var i = 0; i < slices.length; i++) ...base64Decode(slices[i]!),
    ];
    final out = Uint8List.fromList(sent);
    expect(jpegHasExif(raw), isTrue);
    expect(jpegHasExif(out), isFalse);
    expect(File(pic).readAsBytesSync(), out);
  });

  test('a photo that cannot be cleaned does not go', () async {
    final raw = File('test/fixtures/gallery_gps.jpg').readAsBytesSync();
    final pic = '${tmp.path}/cut.jpg';
    await File(pic).writeAsBytes(raw.sublist(0, raw.length - 200));
    final g = _Members();
    final r = await sendGroupSlices(
      path: pic,
      msgUid: msgUid,
      members: ['b'],
      photo: true,
      wrap: (slice, i, total) async => '$i',
      deliver: g.deliver,
      gap: Duration.zero,
      retryPause: Duration.zero,
    );
    expect(r, startsWith('error'));
    expect(g.offered, isEmpty);
    expect(mediaInflight.contains(msgUid), isFalse);
  });

  test('a slice nobody took ends the send, to resume from there', () async {
    final g = _Members()..refuse = (m, i, n) => i == 2;
    expect(await send(g, ['b', 'c']), 'error: chunk 2 undeliverable');
    expect(g.offered.where((o) => o.$2 == 2).length, 2 * kGroupSliceTries);
    // the retry sends only what is missing, and only to who misses it
    final again = _Members();
    expect(await send(again, ['b', 'c']), 'ok');
    expect(again.offered.map((o) => o.$2).toSet(), {2, 3, 4});
  });

  test('a stop ends the send between slices', () async {
    final g = _Members()
      ..onOffer = (m, i) {
        if (i == 1) cancelMediaSend(msgUid);
      };
    expect(await send(g, ['b', 'c']), 'cancelled');
    expect(g.offered.map((o) => o.$2).toSet(), {0, 1});
    // and the stop is not left behind for a later send of the same row
    expect(mediaCancelled.contains(msgUid), isFalse);
  });

  test('the strip ends with the send, whichever way it ends', () async {
    var seen = false;
    final g = _Members()
      ..onOffer = (m, i) =>
          seen = seen || mediaSendProgress.containsKey(msgUid);
    expect(await send(g, ['b']), 'ok');
    expect(seen, isTrue);
    expect(mediaSendProgress.containsKey(msgUid), isFalse);

    msgUid = 'm${uid++}';
    final bad = _Members()..refuse = (m, i, n) => i == 1;
    expect(await send(bad, ['b']), startsWith('error'));
    expect(mediaSendProgress.containsKey(msgUid), isFalse);

    msgUid = 'm${uid++}';
    final stopped = _Members()..onOffer = (m, i) => cancelMediaSend(msgUid);
    expect(await send(stopped, ['b']), 'cancelled');
    expect(mediaSendProgress.containsKey(msgUid), isFalse);
  });

  test('a second send of the same row is turned away while one runs', () async {
    final g = _Members();
    final first = send(g, ['b']);
    expect(mediaInflight.contains(msgUid), isTrue);
    expect(await send(_Members(), ['b']), 'busy');
    var free = false;
    final waiting = whenMediaFree(msgUid).then((_) => free = true);
    expect(await first, 'ok');
    await waiting;
    expect(free, isTrue);
    expect(mediaInflight.contains(msgUid), isFalse);
    // nothing in flight: at once
    await whenMediaFree(msgUid);
  });

  test('nobody to send to is no send', () async {
    expect(await send(_Members(), []), startsWith('error'));
    expect(mediaInflight.contains(msgUid), isFalse);
  });

  // the group's own code around the sender
  group('the group chat', () {
    final app = sourceOf('lib/main.dart');
    final screen = sourceOf('lib/screens/group_chat_screen.dart');

    test('sends through it, never to itself', () {
      final body = bodyOf(app, 'Future<String> sendMediaToGroup(');
      expect(body, contains('sendGroupSlices('));
      expect(body, contains('m != myId && m != room?.pub'));
    });

    test('what a member is owed goes again from the outbox', () {
      final body = bodyOf(app, 'Future<String> sendMediaToGroup(');
      expect(body, contains('noteGroupShort('));
      expect(body, contains('onlyTo: owed'));
      expect(
        bodyOf(app, 'Future<void> drainOutbox('),
        contains('resendGroupOwed()'),
      );
      final unsend = bodyOf(app, 'Future<void> unsendInGroup(');
      expect(unsend, contains('groupMediaOwed.remove(targetMsgUid)'));
    });

    test('the outbox tells an open group its row moved', () {
      final body = bodyOf(app, 'Future<void> _drainGroupMedia(');
      expect("_bumpChatRev('group:\$groupId')".allMatches(body).length, 2);
    });

    test('a send that ends after the screen went tells the one now open', () {
      final body = bodyOf(screen, 'Future<void> _finishGroupMediaSend(');
      expect(body, contains("if (result == 'cancelled') return;"));
      expect(body, contains("appState.chatChanged('group:"));
      expect(body, contains('_watch.busy('));
    });

    test('a strip with no send behind it is only cleared', () {
      final body = bodyOf(screen, 'Future<void> _stopGroupSending(');
      final guard = body.indexOf('if (!mediaInflight.contains(uid))');
      expect(guard, greaterThan(0));
      expect(body.indexOf('deleteMessage'), greaterThan(guard));
      expect(body, contains('whenMediaFree(uid)'));
    });
  });
}
