// SPDX-License-Identifier: GPL-3.0-or-later
// the windows beta's four: frames that do not wait for input (the runner's
// ui thread), enter sends on a computer, the add page's qr at a phone's
// reading size, and the first close to the tray said once
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_run.dart';
import 'package:kryfo/desktop/desktop_start.dart' show trayWords;
import 'package:kryfo/desktop/desktop_toasts.dart' show joinComApartment;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/my_kryfo_screen.dart'
    show kDeskQrSide, kWayCardMaxWidth;
import 'package:kryfo/widgets/enter_sends.dart';

class _Tray implements TrayHost {
  @override
  Future<void> show() async {}
  @override
  Future<void> hide() async {}
  @override
  Future<bool?> shown() async => true;
}

String _src(String path) => File(path).readAsStringSync();

Widget _field(
  TextEditingController c,
  List<String> sent, {
  required bool desktop,
}) => MaterialApp(
  home: Scaffold(
    body: EnterSends(
      controller: c,
      desktop: desktop,
      onSend: () => sent.add(c.text),
      child: TextField(controller: c, autofocus: true, minLines: 1, maxLines: 4),
    ),
  ),
);

void main() {
  group('frames', () {
    test('dart runs on its own thread, and no timer asks for frames', () {
      final main = _src('windows/runner/main.cpp');
      expect(
        main,
        contains(
          'set_ui_thread_policy(flutter::UIThreadPolicy::RunOnSeparateThread)',
        ),
      );
      final win = _src('windows/runner/flutter_window.cpp');
      expect(win, isNot(contains('kFrameTimer')));
      expect(win, isNot(contains('PumpFrames')));
      expect(win, isNot(contains('"frames"')));
      expect(_src('lib/desktop/desktop_start.dart'), isNot(contains('askFrames')));
    });

    test('the toast plugin\'s thread joins com before it starts', () {
      final toasts = _src('lib/desktop/desktop_toasts.dart');
      final at = toasts.indexOf('joinComApartment();');
      expect(at, greaterThan(0));
      expect(at, lessThan(toasts.indexOf('return super.initialize(')));
      // a computer without the dll, or a phone: nothing thrown
      joinComApartment(open: (_) => throw ArgumentError('no ole32'));
      joinComApartment(open: (_) => DynamicLibrary.process());
    });
  });

  group('enter sends on a computer', () {
    testWidgets('enter sends and adds no line', (tester) async {
      final c = TextEditingController();
      final sent = <String>[];
      await tester.pumpWidget(_field(c, sent, desktop: true));
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(sent, ['hello']);
      expect(c.text, 'hello');
      await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
      expect(sent, ['hello', 'hello']);
    });

    testWidgets('shift and enter is the field\'s own', (tester) async {
      final c = TextEditingController();
      final sent = <String>[];
      await tester.pumpWidget(_field(c, sent, desktop: true));
      await tester.enterText(find.byType(TextField), 'a');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      final r = await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(sent, isEmpty);
      // not taken here: the text input makes the new line
      expect(r, isFalse);
    });

    testWidgets('a word still being composed keeps its enter', (tester) async {
      final c = TextEditingController();
      final sent = <String>[];
      await tester.pumpWidget(_field(c, sent, desktop: true));
      c.value = const TextEditingValue(
        text: 'ni',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(sent, isEmpty);
    });

    testWidgets('a phone keeps its keyboard\'s enter', (tester) async {
      final c = TextEditingController();
      final sent = <String>[];
      await tester.pumpWidget(_field(c, sent, desktop: false));
      expect(find.byType(EnterSends), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'x');
      final r = await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(sent, isEmpty);
      expect(r, isFalse);
    });

    test('both composers use it', () {
      for (final f in [
        'lib/screens/chat_screen.dart',
        'lib/screens/group_chat_screen.dart',
      ]) {
        expect(_src(f), contains('EnterSends('), reason: f);
      }
    });
  });

  group('the add page on a computer', () {
    test('the qr is a phone\'s reading size, the cards capped', () {
      expect(kDeskQrSide, inInclusiveRange(240, 280));
      expect(kWayCardMaxWidth, lessThanOrEqualTo(640));
      final page = _src('lib/screens/my_kryfo_screen.dart');
      expect(page, contains('onDesktop ? Center(child: frame) : frame'));
      // no camera on a computer: no scan button there
      expect(page, contains('if (!onDesktop) ...['));
      expect(l10n.myKryfoPointYourPhonesAtDesk, contains('their phone'));
    });
  });

  group('the first close to the tray', () {
    test('the words carry the line only when asked', () {
      expect(trayWords().containsKey('hint'), isFalse);
      expect(trayWords(locked: true).containsKey('hint'), isFalse);
      expect(trayWords(hint: true)['hint'], l10n.desktopTrayStillRunning);
    });

    test('said once: kept in the vault after the runner says so', () async {
      final kv = <String, String>{};
      final run = DesktopRun(
        tray: _Tray(),
        place: null,
        read: (k) => kv[k],
        write: (k, v) async => kv[k] = v,
      );
      expect(run.trayHinted, isFalse);
      await run.markHinted();
      expect(run.trayHinted, isTrue);
      expect(jsonDecode(kv[runEntry]!)['hinted'], isTrue);
      // the tray switch is untouched
      expect(run.trayOn, isTrue);
    });

    test('a locked vault keeps quiet and is asked again later', () async {
      final run = DesktopRun(
        tray: _Tray(),
        place: null,
        read: (_) => throw StateError('locked'),
        write: (_, _) async => throw StateError('locked'),
      );
      expect(run.trayHinted, isFalse);
      await run.markHinted();
    });

    test('the runner says it once, from the tray, then tells dart', () {
      final win = _src('windows/runner/flutter_window.cpp');
      expect(win, contains('hint_ = word("hint");'));
      expect(win, contains('tray_.Balloon(hint_)'));
      expect(win, contains('InvokeMethod("hinted"'));
      expect(_src('lib/desktop/desktop_start.dart'), contains("'hinted'"));
    });

    test('every language has its own words, english without dashes', () {
      final en =
          jsonDecode(_src('lib/l10n/app_en.arb')) as Map<String, dynamic>;
      final line = en['desktopTrayStillRunning'] as String;
      expect(line, 'Kryfo is still running in the tray. Quit from the tray icon.');
      expect(line, isNot(matches(RegExp('[‒-―-]'))));
      final arbs = Directory('lib/l10n')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.arb'))
          .toList();
      expect(arbs.length, greaterThanOrEqualTo(16));
      for (final f in arbs) {
        if (f.path.endsWith('app_en.arb')) continue;
        final m = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        final w = m['desktopTrayStillRunning'] as String?;
        expect(w, isNotNull, reason: f.path);
        expect(w, isNot(line), reason: f.path);
        expect(w, contains('Kryfo'), reason: f.path);
      }
    });
  });

  test('the uninstaller takes the start with the computer along', () {
    final iss = _src('../packaging/windows/kryfo.iss');
    for (final key in [
      r'Software\Microsoft\Windows\CurrentVersion\Run',
      r'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run',
    ]) {
      final line = iss
          .split('\n')
          .firstWhere((l) => l.contains('Subkey: "$key";'), orElse: () => '');
      expect(line, contains('ValueName: "$runValueName"'), reason: key);
      expect(line, contains('ValueType: none'), reason: key);
      expect(line, contains('uninsdeletevalue'), reason: key);
      expect(line, contains('dontcreatekey'), reason: key);
    }
  });

  test('the installer pins the same tor.exe as tor-pin.txt', () {
    final pin = RegExp(
      r'^TOR_EXE_SHA256=([0-9a-f]{64})$',
      multiLine: true,
    ).firstMatch(_src('../packaging/windows/tor-pin.txt'))!.group(1);
    final iss = RegExp(
      r'^#define TorExeSha256 "([0-9a-f]{64})"$',
      multiLine: true,
    ).firstMatch(_src('../packaging/windows/kryfo.iss'))!.group(1);
    expect(iss, pin);
  });
}
