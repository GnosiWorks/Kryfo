// SPDX-License-Identifier: GPL-3.0-or-later
// the start error screen's ways out. besides trying again: restore a backup,
// or start fresh, which asks twice and says plainly what goes. one tap
// deletes nothing, and a store that only stalled is not offered either.
// copy stays
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/boot_failed.dart';

const _error =
    'DatabaseException(open_failed /data/user/0/app.kryfo/app_flutter/halo.db)';

Widget _framed(
  Widget home, {
  Locale locale = const Locale('en'),
  double scale = 1,
}) => MaterialApp(
  locale: locale,
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

void main() {
  late List<String> did;
  late List<MethodCall> asked;

  setUp(() {
    did = [];
    asked = [];
  });

  Future<void> show(
    WidgetTester t, {
    VoidCallback? onReopen,
    Size size = const Size(411, 891),
    double scale = 1,
    Locale locale = const Locale('en'),
  }) async {
    t.view.physicalSize = size * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (c) async {
      asked.add(c);
      return null;
    });
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await t.pumpWidget(
      _framed(
        BootFailedScreen(
          error: _error,
          onRetry: () => did.add('retry'),
          onReopen: onReopen,
          onRestore: () => did.add('restore'),
          onStartFresh: () => did.add('fresh'),
        ),
        locale: locale,
        scale: scale,
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester t, String s) async {
    await t.ensureVisible(find.text(s));
    await t.pumpAndSettle();
    await t.tap(find.text(s));
    await t.pumpAndSettle();
  }

  testWidgets('a database that will not open offers a backup or a fresh '
      'start besides trying again, and copy stays', (t) async {
    await show(t);
    expect(find.text(l10n.bootFailedKryfoCouldNotStart), findsOneWidget);
    expect(find.text(l10n.commonTryAgain), findsOneWidget);
    expect(find.text(l10n.commonCopy), findsOneWidget);
    expect(find.text(l10n.bootFailedRestoreBackup), findsOneWidget);
    expect(find.text(l10n.bootFailedStartFresh), findsOneWidget);

    await tapText(t, l10n.commonTryAgain);
    await tapText(t, l10n.bootFailedRestoreBackup);
    expect(did, ['retry', 'restore']);

    await tapText(t, l10n.commonCopy);
    final copied = asked.where((c) => c.method == 'Clipboard.setData');
    expect((copied.last.arguments as Map)['text'], _error);
  });

  testWidgets('start fresh asks twice, says what goes, and a no at either '
      'step deletes nothing', (t) async {
    await show(t);
    // no at the first question
    await tapText(t, l10n.bootFailedStartFresh);
    expect(find.text(l10n.bootFailedStartFreshTitle), findsOneWidget);
    expect(find.text(l10n.bootFailedStartFreshLine), findsOneWidget);
    await tapText(t, l10n.confirmSheetCancel);
    expect(find.text(l10n.bootFailedStartFreshTitle), findsNothing);
    expect(did, isEmpty);

    // yes, then no at the second
    await tapText(t, l10n.bootFailedStartFresh);
    await tapText(t, l10n.bootFailedStartFreshNext);
    expect(find.text(l10n.bootFailedStartFreshSure), findsOneWidget);
    expect(find.text(l10n.bootFailedStartFreshSureLine), findsOneWidget);
    await tapText(t, l10n.confirmSheetCancel);
    expect(did, isEmpty);

    // a sheet dismissed is a no too
    await tapText(t, l10n.bootFailedStartFresh);
    await t.tapAt(const Offset(20, 20));
    await t.pumpAndSettle();
    expect(find.text(l10n.bootFailedStartFreshTitle), findsNothing);
    expect(did, isEmpty);

    // yes twice: once, and only then
    await tapText(t, l10n.bootFailedStartFresh);
    await tapText(t, l10n.bootFailedStartFreshNext);
    await tapText(t, l10n.bootFailedStartFreshYes);
    expect(did, ['fresh']);
    expect(
      asked.where((c) => c.method == 'HapticFeedback.vibrate').last.arguments,
      'HapticFeedbackType.heavyImpact',
    );
  });

  testWidgets('a key store that only stalled is not offered a wipe', (t) async {
    await show(t, onReopen: () => did.add('reopen'));
    expect(find.text(l10n.bootFailedCloseAndReopen), findsOneWidget);
    expect(find.text(l10n.bootFailedRestoreBackup), findsNothing);
    expect(find.text(l10n.bootFailedStartFresh), findsNothing);
  });

  testWidgets('with no ways given the screen is as before', (t) async {
    t.view.physicalSize = const Size(822, 1782);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      _framed(BootFailedScreen(error: _error, onRetry: () {})),
    );
    await t.pumpAndSettle();
    expect(find.text(l10n.commonTryAgain), findsOneWidget);
    expect(find.text(l10n.bootFailedStartFresh), findsNothing);
  });

  for (final lang in ['de', 'ar', 'ru']) {
    testWidgets('a small phone in $lang at a large font scrolls to every '
        'way out', (t) async {
      setL10nLocale(Locale(lang));
      addTearDown(() => setL10nLocale(const Locale('en')));
      await show(
        t,
        size: const Size(360, 640),
        scale: 1.6,
        locale: Locale(lang),
      );
      expect(t.takeException(), isNull);
      await tapText(t, l10n.bootFailedStartFresh);
      expect(find.text(l10n.bootFailedStartFreshTitle), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
