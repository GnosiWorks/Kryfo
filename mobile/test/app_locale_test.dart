// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/app_locale.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/widgets/language_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('every language with a file has a name, and english is there', () {
    expect(availableLanguages, contains('en'));
    for (final t in availableLanguages) {
      expect(kLanguageNames[t], isNotNull, reason: t);
    }
    for (final l in AppLocalizations.supportedLocales) {
      expect(
        kLanguageNames.keys.map(localeOf),
        contains(l),
        reason: '$l has a file but no place in the sheet',
      );
    }
  });

  test('traditional chinese is its own file, not simplified', () {
    final hant = lookupAppLocalizations(localeOf('zh_Hant'));
    final hans = lookupAppLocalizations(localeOf('zh'));
    expect(hant.localeName, 'zh_Hant');
    expect(hant.navBarSupport, isNot(hans.navBarSupport + '\u0000'));
    expect(
      hant.gettingMessagesGettingMessages,
      isNot(hans.gettingMessagesGettingMessages),
    );
  });

  test('nothing saved is match phone', () async {
    await loadAppLocale();
    expect(appLocalePref, 'system');
    expect(availableLanguages, contains(currentLanguage));
  });

  test('a saved language that has no file falls back to the phone', () async {
    SharedPreferences.setMockInitialValues({kAppLocaleKey: 'xx'});
    await loadAppLocale();
    expect(appLocalePref, 'xx');
    expect(currentLanguage, systemLanguage);
  });

  test('a pick is saved and redraws', () async {
    final before = localeRevision.value;
    await setAppLocale('en');
    expect(localeRevision.value, before + 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kAppLocaleKey), 'en');
    expect(languageValue(), 'English');
    await setAppLocale('system');
    expect(languageValue(), 'Match phone (${kLanguageNames[systemLanguage]})');
  });

  testWidgets('the button opens the sheet, match phone first', (t) async {
    await loadAppLocale();
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: LanguageChip())),
      ),
    );
    expect(find.text(kLanguageNames[currentLanguage]!), findsOneWidget);
    await t.tap(find.byType(LanguageChip));
    await t.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Match phone'), findsOneWidget);
    expect(
      t.getTopLeft(find.text('Match phone')).dy,
      lessThan(t.getTopLeft(find.text('English').last).dy),
    );
    // from onboarding there is no line about landing on the chats
    expect(find.textContaining('opens on your chats'), findsNothing);
  });
}
