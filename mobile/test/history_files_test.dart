// SPDX-License-Identifier: GPL-3.0-or-later
// a photo or a voice note the history copy still brings shows as on its
// way, never as unavailable, and draws itself once its file lands
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devices/history_files.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/widgets/media_bubbles.dart';
import 'package:kryfo/widgets/sealed_picture.dart';

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('hist_files'));
  tearDown(() {
    historyFilesComing.clear();
    dir.deleteSync(recursive: true);
  });

  test('the list says which files still come', () {
    final c = HistoryFilesComing();
    var told = 0;
    c.addListener(() => told++);
    c.add(['/m/a.jpg', '/m/b.jpg', '/m/./c.jpg']);
    expect(c.coming('/m/c.jpg'), isTrue);
    c.only(['/m/a.jpg']);
    expect(c.coming('/m/b.jpg'), isFalse);
    expect(c.coming('/m/a.jpg'), isTrue);
    c.done('/m/a.jpg');
    expect(c.any, isFalse);
    expect(told, 3);
    c.clear();
    expect(told, 3);
  });

  testWidgets('a photo on its way waits, then is asked for again', (t) async {
    final path = '${dir.path}/p.jpg';
    historyFilesComing.add([path]);
    var failed = 0;
    await t.pumpWidget(
      _app(
        SizedBox(
          width: 200,
          child: SealedPicture(
            path: path,
            image: mediaImage(path, 200),
            errorBuilder: (_, _, _) {
              failed++;
              return Text(l10n.chatPhotoUnavailable);
            },
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.byType(MediaArriving), findsOneWidget);
    expect(find.text(l10n.chatPhotoUnavailable), findsNothing);
    // no file came: once nothing waits, it says so
    historyFilesComing.done(path);
    await t.pump();
    expect(find.byType(MediaArriving), findsNothing);
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pump();
    expect(failed, greaterThan(0));
  });

  testWidgets('a voice note on its way waits, never unavailable', (t) async {
    final path = '${dir.path}/v.ogg';
    historyFilesComing.add([path]);
    await t.pumpWidget(_app(VoiceBubble(path: path, isOut: false)));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
    expect(find.text(l10n.albumOnItsWay), findsOneWidget);
    expect(find.text(l10n.mediaBubblesAudioUnavailable), findsNothing);
    File(path).writeAsBytesSync(List.filled(64, 0));
    historyFilesComing.done(path);
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
    expect(find.text(l10n.albumOnItsWay), findsNothing);
    expect(find.text(l10n.mediaBubblesAudioUnavailable), findsNothing);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
}
