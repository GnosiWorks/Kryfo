// SPDX-License-Identifier: GPL-3.0-or-later
// the makers that close apps beyond android's battery exemption get a guide
// to their own switch: xiaomi, huawei and honor, oppo and realme, vivo,
// samsung and oneplus. any other phone only gets the exemption. every
// language says each guide, and in its own words.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/battery_brand.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/miui_autostart.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('which maker', () {
    final cases = {
      ('Xiaomi', 'Redmi'): PhoneBrand.xiaomi,
      ('Xiaomi', 'POCO'): PhoneBrand.xiaomi,
      ('HUAWEI', 'HUAWEI'): PhoneBrand.huawei,
      ('HONOR', 'HONOR'): PhoneBrand.huawei,
      // an honor made under huawei
      ('HUAWEI', 'HONOR'): PhoneBrand.huawei,
      ('OPPO', 'OPPO'): PhoneBrand.oppo,
      ('realme', 'realme'): PhoneBrand.oppo,
      ('vivo', 'vivo'): PhoneBrand.vivo,
      ('vivo', 'iQOO'): PhoneBrand.vivo,
      ('samsung', 'samsung'): PhoneBrand.samsung,
      // oneplus phones run oppo's system but keep their own names
      ('OnePlus', 'OnePlus'): PhoneBrand.oneplus,
      ('OPPO', 'OnePlus'): PhoneBrand.oneplus,
      ('Google', 'google'): PhoneBrand.other,
      ('motorola', 'motorola'): PhoneBrand.other,
      ('', ''): PhoneBrand.other,
    };
    for (final e in cases.entries) {
      test('${e.key.$1} / ${e.key.$2}', () {
        expect(brandOf(e.key.$1, e.key.$2), e.value);
      });
    }
  });

  test('each strict maker has its own guide, any other phone none', () {
    final guides = {
      for (final b in PhoneBrand.values)
        if (b != PhoneBrand.other) b: brandGuide(b),
    };
    expect(guides.values, everyElement(isNotNull));
    expect(guides.values.toSet(), hasLength(guides.length));
    expect(brandGuide(PhoneBrand.other), isNull);
    expect(
      brandGuide(PhoneBrand.xiaomi),
      l10n.miuiAutostartXiaomiTurnsOffBackground,
    );
    expect(brandGuide(PhoneBrand.huawei), contains('Manage automatically'));
  });

  test('every language has the guides, none left in english', () {
    const keys = [
      'batteryGuideHuawei',
      'batteryGuideOppo',
      'batteryGuideVivo',
      'batteryGuideSamsung',
      'batteryGuideOnePlus',
    ];
    final en =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map;
    final arbs = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.arb'))
        .toList();
    expect(arbs, hasLength(15));
    for (final f in arbs) {
      final m = jsonDecode(f.readAsStringSync()) as Map;
      for (final k in keys) {
        final s = m[k] as String?;
        expect(s, isNotNull, reason: '${f.path} $k');
        expect(s, contains('Kryfo'), reason: '${f.path} $k');
        if (!f.path.endsWith('app_en.arb')) {
          expect(s, isNot(en[k]), reason: '${f.path} $k');
        }
      }
    }
  });

  testWidgets('a huawei phone is shown its guide and its page opens', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({'battery_opt_prompt_seen': true});
    final asked = <String>[];
    const ch = MethodChannel('halo/platform');
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(ch, (c) async {
      asked.add(c.method);
      return switch (c.method) {
        'phoneMaker' => {'manufacturer': 'HUAWEI', 'brand': 'HONOR'},
        'openAutostartSettings' => true,
        _ => null,
      };
    });
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(ch, null),
    );
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => maybeShowBackgroundPrompt(ctx),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    expect(find.text(l10n.batteryGuideHuawei), findsOneWidget);
    await t.tap(find.text(l10n.miuiAutostartOpenSettings));
    await t.pumpAndSettle();
    expect(asked, contains('openAutostartSettings'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('miui_autostart_prompt_seen'), isTrue);
  });

  testWidgets('a phone of no strict maker is not shown a guide', (t) async {
    SharedPreferences.setMockInitialValues({'battery_opt_prompt_seen': true});
    const ch = MethodChannel('halo/platform');
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      ch,
      (c) async => c.method == 'phoneMaker'
          ? {'manufacturer': 'Google', 'brand': 'google'}
          : null,
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(ch, null),
    );
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => maybeShowBackgroundPrompt(ctx),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    expect(find.text(l10n.miuiAutostartOpenSettings), findsNothing);
  });
}
