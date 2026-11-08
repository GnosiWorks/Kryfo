// SPDX-License-Identifier: GPL-3.0-or-later
// the battery ask on a system with no battery page, or one whose
// permission check throws: no error reaches the app, a short line says so,
// and the ask is not shown again at the next start
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/miui_autostart.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _perm = MethodChannel('flutter.baseflow.com/permissions/methods');
const _platform = MethodChannel('halo/platform');

void main() {
  late List<String> asked;
  late Future<void> shown;

  Future<void> start(WidgetTester t, {bool checkThrows = false}) async {
    asked = [];
    SharedPreferences.setMockInitialValues({});
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    m.setMockMethodCallHandler(_platform, (c) async {
      if (c.method == 'phoneMaker') {
        return {'manufacturer': 'Waydroid', 'brand': 'waydroid'};
      }
      return null;
    });
    m.setMockMethodCallHandler(_perm, (c) async {
      asked.add(c.method);
      if (c.method == 'checkPermissionStatus') {
        if (checkThrows) throw PlatformException(code: 'error');
        return 0;
      }
      if (c.method == 'requestPermissions') {
        // android has no activity for the battery page
        throw PlatformException(code: 'error', message: 'no activity');
      }
      return null;
    });
    addTearDown(() {
      m.setMockMethodCallHandler(SystemChannels.platform, null);
      m.setMockMethodCallHandler(_platform, null);
      m.setMockMethodCallHandler(_perm, null);
    });
    late BuildContext ctx;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    shown = maybeShowBackgroundPrompt(ctx);
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.commonAllow));
    await t.pump();
  }

  testWidgets('no battery page: a line, no error, not asked again', (t) async {
    await start(t);
    await shown;
    await t.pump();
    expect(find.text(l10n.homeCouldnTOpenIt), findsOneWidget);
    expect(asked, contains('requestPermissions'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('battery_opt_prompt_seen'), isTrue);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a check that throws is a no, and asks once', (t) async {
    await start(t, checkThrows: true);
    await shown;
    await t.pump();
    expect(find.text(l10n.homeCouldnTOpenIt), findsOneWidget);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });
}
