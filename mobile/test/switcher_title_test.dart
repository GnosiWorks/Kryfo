// SPDX-License-Identifier: GPL-3.0-or-later
// the app switcher's title is what flutter sends on the first frame, over
// what the screen set when it opened. it says the home screen's name as the
// launcher writes it (the phone's language), in the plain icon's colour, and
// changes with it. until android has said which icon is on, it says nothing
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/app_icon.dart';
import 'package:kryfo/app_icon_art.dart';
import 'package:kryfo/app_shell.dart';
import 'package:kryfo/l10n/l10n.dart';

class _Said {
  final all = <Map<Object?, Object?>>[];
  Map<Object?, Object?> get last => all.last;
}

_Said _listen(WidgetTester t) {
  final said = _Said();
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (c) async {
      if (c.method == 'SystemChrome.setApplicationSwitcherDescription') {
        said.all.add(c.arguments as Map<Object?, Object?>);
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
  return said;
}

final _nav = GlobalKey<NavigatorState>();

Widget _faced() => FacedShell(
  builder: (face, label) => haloAppShell(
    navigatorKey: _nav,
    home: const SizedBox(),
    lock: (n) => n,
    face: face,
    faceLabel: label,
  ),
);

void main() {
  tearDown(forgetAppFace);

  testWidgets('the switcher says the home screen\'s name', (t) async {
    final said = _listen(t);
    Widget app(AppFace? face, [String? label]) => haloAppShell(
      navigatorKey: _nav,
      home: const SizedBox(),
      lock: (n) => n,
      face: face,
      faceLabel: label,
    );
    await t.pumpWidget(app(AppFace.notes));
    expect(said.last['label'], l10n.androidIconNotes);
    expect(said.last['primaryColor'], notesArt.background);
    // a switch, or the read coming in, changes it in place
    await t.pumpWidget(app(AppFace.weather));
    expect(said.last['label'], l10n.androidIconWeather);
    expect(said.last['primaryColor'], weatherArt.background);
    await t.pumpWidget(app(AppFace.kryfo));
    expect(said.last['label'], 'Kryfo');
  });

  testWidgets('the launcher\'s own words, in the phone\'s language', (t) async {
    final said = _listen(t);
    // the app in english, the phone in german
    await t.pumpWidget(
      haloAppShell(
        navigatorKey: _nav,
        home: const SizedBox(),
        lock: (n) => n,
        face: AppFace.notes,
        faceLabel: 'Notizen',
      ),
    );
    expect(said.last['label'], 'Notizen');
  });

  testWidgets('an icon not known says nothing of kryfo', (t) async {
    final said = _listen(t);
    await t.pumpWidget(_faced());
    expect(said.last['label'], '');
    expect(said.last['label'], isNot(contains('Kryfo')));
    // not kryfo's amber either
    expect(said.last['primaryColor'], isNot(0xFFF59E0B));
  });

  testWidgets('the app follows android\'s answer as it comes in', (t) async {
    final said = _listen(t);
    await t.pumpWidget(_faced());
    expect(said.last['label'], '');
    appFaceLabel.value = 'Wetter';
    appFaceNow.value = AppFace.weather;
    await t.pump();
    expect(said.last['label'], 'Wetter');
    expect(said.last['primaryColor'], weatherArt.background);
    appFaceLabel.value = null;
    appFaceNow.value = AppFace.kryfo;
    await t.pump();
    expect(said.last['label'], 'Kryfo');
  });

  test('a read that fails keeps nothing, and the next asks again', () async {
    var asks = 0;
    AppFace? answer;
    appFaceChannel = _Asked(() {
      asks++;
      return answer;
    });
    addTearDown(() => appFaceChannel = const PlatformFaceChannel());
    expect(await readAppFace(), isNull);
    expect(appFaceNow.value, isNull);
    expect(looksKryfo, isFalse);
    answer = AppFace.kryfo;
    expect(await readAppFace(), AppFace.kryfo);
    expect(looksKryfo, isTrue);
    // once known, android is not asked again in this process
    await readAppFace();
    expect(asks, 2);
  });
}

class _Asked implements AppFaceChannel {
  final AppFace? Function() answer;
  _Asked(this.answer);
  @override
  Future<AppFace?> read() async => answer();
  @override
  Future<bool> switchTo(AppFace f) async => true;
}
