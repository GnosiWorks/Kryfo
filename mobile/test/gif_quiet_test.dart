// SPDX-License-Identifier: GPL-3.0-or-later
// a gif and a voice note just appear: no share beside the bubble, none on
// the strip, on the sending side or the one it comes to. a photo still
// shows its share
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/media_progress.dart';
import 'package:kryfo/message_envelope.dart';

import 'source_body.dart';

Widget _frame(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  tearDown(() {
    for (final u in ['g1', 'p1', 'v1']) {
      mediaProgressEnd(u);
    }
    incomingMediaDone('chat');
    stopMediaSweeper();
  });

  test('a gif is told by the name its bytes gave it, in the picture lane', () {
    expect(quietMedia('/m/u1.gif'), isTrue);
    expect(quietMedia('/m/u1.GIF'), isTrue);
    expect(quietMedia('/m/u1.jpg'), isFalse);
    // a gif sent as a file keeps its file card and its share
    expect(quietMedia('/m/f_u1.gif', fileName: 'party.gif'), isFalse);
    // a voice note shows none either, whatever its name
    expect(quietMedia('/m/u1.gif', voice: true), isTrue);
    expect(quietMedia('/m/v1.wav', fileName: 'voice.wav', voice: true), isTrue);
    expect(quietMedia('/m/v1.wav', fileName: 'voice.wav'), isFalse);
  });

  testWidgets('a voice note: no percentage beside it, no strip, on either '
      'side', (t) async {
    mediaProgressStart('v1', chatKey: 'chat', quiet: true);
    mediaProgressUpdate('v1', 0.42);
    await t.pumpWidget(
      _frame(
        const Column(
          children: [
            SendProgressLabel(msgUid: 'v1'),
            IncomingMediaBanner(chatKey: 'chat'),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('42'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(transfersNow().sending, 0);
    mediaProgressEnd('v1');
  });

  test('a voice note coming through the files service or in slices puts '
      'no share on the strip', () {
    final files = sourceOf('lib/app/state_files.dart');
    expect(files, contains('if (!env.gif && !env.voice) {'));
    expect('quiet: env.gif || env.voice,'.allMatches(files).length, 2);
    expect(
      sourceOf('lib/app/state_arrivals.dart'),
      contains('if (!env.voice && !env.gif) {'),
    );
  });

  testWidgets('ours: no percentage beside a gif, a photo keeps its own', (
    t,
  ) async {
    mediaProgressStart('g1', chatKey: 'chat', quiet: true);
    mediaProgressUpdate('g1', 0.42);
    mediaProgressStart('p1', chatKey: 'other');
    mediaProgressUpdate('p1', 0.42);
    await t.pumpWidget(
      _frame(
        const Column(
          children: [
            SendProgressLabel(msgUid: 'g1'),
            IncomingMediaBanner(chatKey: 'chat'),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('42'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(mediaQuiet('g1'), isTrue);
    expect(transfersNow().sending, 1);

    await t.pumpWidget(
      _frame(
        const Column(
          children: [
            SendProgressLabel(msgUid: 'p1'),
            IncomingMediaBanner(chatKey: 'other'),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('42%'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // the end of a send lets go of its quiet too
    mediaProgressEnd('g1');
    expect(mediaQuiet('g1'), isFalse);
  });

  test(
    'the gif mark rides every slice, and an older frame reads as none',
    () async {
      final w = await wrapMessage(
        '',
        msgUid: 'g1',
        mediaId: 'g1',
        chunkIndex: 0,
        chunkTotal: 3,
        imageB64: base64Encode([0x47, 0x49, 0x46]),
        gif: true,
      );
      expect(unwrapMessage(w).gif, isTrue);
      final old = await wrapMessage(
        '',
        msgUid: 'p1',
        imageB64: base64Encode([1, 2, 3]),
      );
      expect(unwrapMessage(old).gif, isFalse);
      expect(old.contains('"gf"'), isFalse);
    },
  );
}
