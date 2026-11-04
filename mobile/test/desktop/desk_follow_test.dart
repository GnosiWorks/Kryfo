// SPDX-License-Identifier: GPL-3.0-or-later
// the desktop review's leftovers: the five pages still full width on a
// computer sit in the reading column, and the tray step's line under its
// card sits flush with the card, as the words above it do
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/desk_run_section.dart';

class _Run extends ChangeNotifier implements DesktopRunView {
  @override
  bool get trayOn => false;
  @override
  bool? get trayShown => true;
  @override
  Future<void> setTray(bool on) async {}
  @override
  bool get canStart => false;
  @override
  StartAnswer? get start => StartAnswer.off;
  @override
  bool get startRefused => false;
  @override
  Future<StartAnswer> setStart(bool on) async => StartAnswer.off;
  @override
  Future<void> refresh() async {}
}

void main() {
  test('auto-get, linked devices, PIN lock, restore and translation pages '
      'put every body in the reading column', () {
    for (final f in [
      'auto_get_screen',
      'linked_devices_screen',
      'pins_screen',
      'restore_screen',
      'translation_screen',
    ]) {
      final s = File('lib/screens/$f.dart').readAsStringSync();
      final bodies = RegExp(r'\bbody: ').allMatches(s).length;
      final desk = RegExp(r'\bbody: DeskPage\(').allMatches(s).length;
      expect(bodies, greaterThan(0), reason: f);
      expect(desk, bodies, reason: f);
    }
  });

  for (final (inset, left) in [(0.0, 0.0), (12.0, 12.0)]) {
    testWidgets('the line under the tray card sits $left in', (t) async {
      onDesktop = true;
      addTearDown(() => onDesktop = false);
      setL10nLocale(const Locale('en'));
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.only(left: 100),
              child: SizedBox(
                width: 500,
                child: DeskRunSection(run: _Run(), edge: 0, lineInset: inset),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final line = find.text(l10n.desktopTrayOffLine);
      expect(line, findsOneWidget);
      expect(t.getTopLeft(line).dx, 100 + left);
    });
  }
}
