// SPDX-License-Identifier: GPL-3.0-or-later
// the app switcher's title is what flutter sends on the first frame, over
// what the screen set when it opened: it says the home screen's name, in
// the plain icon's colour, and changes with it. the app passes the icon in
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/app_icon.dart';
import 'package:kryfo/app_icon_art.dart';
import 'package:kryfo/app_shell.dart';
import 'package:kryfo/l10n/l10n.dart';

import 'source_body.dart';

void main() {
  testWidgets('the switcher says the home screen\'s name', (t) async {
    final said = <Map<Object?, Object?>>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (c) async {
        if (c.method == 'SystemChrome.setApplicationSwitcherDescription') {
          said.add(c.arguments as Map<Object?, Object?>);
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final nav = GlobalKey<NavigatorState>();
    Widget app(AppFace? face) => haloAppShell(
      navigatorKey: nav,
      home: const SizedBox(),
      lock: (n) => n,
      face: face,
    );
    await t.pumpWidget(app(AppFace.notes));
    expect(said.last['label'], l10n.androidIconNotes);
    expect(said.last['label'], isNot(contains('Kryfo')));
    expect(said.last['primaryColor'], notesArt.background);
    // a switch, or the read coming in, changes it in place
    await t.pumpWidget(app(AppFace.weather));
    expect(said.last['label'], l10n.androidIconWeather);
    expect(said.last['primaryColor'], weatherArt.background);
    await t.pumpWidget(app(AppFace.kryfo));
    expect(said.last['label'], 'Kryfo');
  });

  test('the app hands the shell the icon and rebuilds with it', () {
    final app = bodyOf(sourceOf('lib/main.dart'), 'Widget build(');
    expect(app, contains('appFaceNow,'));
    expect(app, contains('face: appFaceNow.value,'));
    // read before the first frame
    final start = bodyOf(sourceOf('lib/main.dart'), 'void main(');
    expect(
      start.indexOf('await readAppFace()'),
      lessThan(start.indexOf('runApp(')),
    );
  });
}
