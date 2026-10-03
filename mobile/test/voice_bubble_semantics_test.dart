// SPDX-License-Identifier: GPL-3.0-or-later
// a voice note tells a screen reader what it is, how long, and what a tap
// does: play while it rests
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/widgets/media_bubbles.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('voice_sem'));
  tearDown(() => dir.deleteSync(recursive: true));

  for (final disguised in [false, true]) {
    testWidgets('a resting voice note says what it is (disguised: '
        '$disguised)', (t) async {
      final sem = t.ensureSemantics();
      final f = File('${dir.path}/voice.wav')..writeAsBytesSync([0, 0, 0, 0]);
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: VoiceBubble(
                path: f.path,
                isOut: false,
                disguised: disguised,
              ),
            ),
          ),
        ),
      );
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
      expect(
        t.getSemantics(find.byType(VoiceBubble)),
        matchesSemantics(
          label: disguised
              ? '${l10n.appVoiceMessage}, ${l10n.mediaBubblesHidden}'
              : l10n.appVoiceMessage,
          value: '0:00',
          isButton: true,
          hasTapAction: true,
          onTapHint: l10n.videoViewerPlay,
        ),
      );
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
      sem.dispose();
    });
  }
}
