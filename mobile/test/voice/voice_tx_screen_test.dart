// SPDX-License-Identifier: GPL-3.0-or-later
// settings > voice transcription: the switch and what turning it off does,
// the speech model's size, download and removal, and the privacy note in a
// phone's words and a computer's
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_mode.dart' show onDesktop;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/translate/lang_names.dart' show packSize;
import 'package:kryfo/voice/transcript_store.dart';
import 'package:kryfo/voice/ui/voice_tx_screen.dart';
import 'package:kryfo/voice/voice_transcripts.dart' show kVoiceModelSize;
import 'package:kryfo/widgets/halo_rows.dart';

import 'voice_tx_fakes.dart';

Widget _framed(Widget home) => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  void tall(WidgetTester t) {
    t.view.physicalSize = const Size(720, 3200);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
  }

  testWidgets('on by default; off says what it does and deletes them', (
    t,
  ) async {
    tall(t);
    final store = MemoryVoiceTxStore();
    store.rows['heron'] = {
      'u1': const KeptTranscript(
        lang: 'en',
        model: 'base',
        pieces: [TxPiece(0, 1, ' words')],
      ),
    };
    final f = fakeVoiceHub(store: store);
    addTearDown(f.hub.dispose);
    await t.pumpWidget(_framed(VoiceTxScreen(hub: f.hub)));
    await t.pumpAndSettle();
    expect(find.text(l10n.voiceSettingsTitle), findsOneWidget);
    expect(find.text(l10n.voiceOffDeletes), findsOneWidget);
    final row = t.widget<HaloRow>(find.byKey(const ValueKey('voice-tx-on')));
    expect(row.toggled, isTrue);
    await t.tap(find.byKey(const ValueKey('voice-tx-on')));
    await t.pumpAndSettle();
    expect(
      t.widget<HaloRow>(find.byKey(const ValueKey('voice-tx-on'))).toggled,
      isFalse,
    );
    expect(store.settings.on, isFalse);
    expect(store.rows, isEmpty);
    expect(store.dropped, 1);
  });

  testWidgets('the model: its size, a download from its button only, then '
      'removed with what was made kept', (t) async {
    tall(t);
    final store = MemoryVoiceTxStore();
    final f = fakeVoiceHub(installed: false, store: store);
    addTearDown(f.hub.dispose);
    await t.pumpWidget(_framed(VoiceTxScreen(hub: f.hub)));
    await t.pumpAndSettle();
    final size = packSize(kVoiceModelSize);
    expect(find.text(l10n.translateNotDownloaded(size)), findsOneWidget);
    expect(f.backend.started, isEmpty);
    await t.tap(find.text(l10n.translateDownload(size)));
    await t.pump();
    expect(f.backend.started, ['base']);
    f.backend.finish();
    await t.pump(const Duration(milliseconds: 100));
    await t.pumpAndSettle();
    expect(find.text(l10n.translateInstalledShown(size)), findsOneWidget);
    store.rows['heron'] = {
      'u1': const KeptTranscript(
        lang: 'en',
        model: 'base',
        pieces: [TxPiece(0, 1, ' words')],
      ),
    };
    await t.tap(find.byKey(const ValueKey('voice-model-remove')));
    await t.pumpAndSettle();
    expect(find.text(l10n.voiceModelRemoveTitle), findsOneWidget);
    expect(find.text(l10n.voiceModelRemoveLine), findsOneWidget);
    await t.tap(find.text(l10n.commonRemove).last);
    await t.pumpAndSettle();
    expect(f.backend.have, isFalse);
    expect(find.text(l10n.translateNotDownloaded(size)), findsOneWidget);
    // the transcripts already made stay
    expect(store.rows['heron']!.keys, ['u1']);
  });

  testWidgets('tor not up: said in the model\'s own words', (t) async {
    tall(t);
    final f = fakeVoiceHub(installed: false);
    addTearDown(f.hub.dispose);
    f.backend.startAnswer = 'error: tor: not up';
    await t.pumpWidget(_framed(VoiceTxScreen(hub: f.hub)));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.translateDownload(packSize(kVoiceModelSize))));
    await t.pumpAndSettle();
    expect(find.text(l10n.voiceModelFailNoTor), findsOneWidget);
  });

  testWidgets('the privacy note: a phone\'s words, a computer\'s', (t) async {
    tall(t);
    final f = fakeVoiceHub();
    addTearDown(f.hub.dispose);
    await t.pumpWidget(_framed(VoiceTxScreen(hub: f.hub)));
    await t.pumpAndSettle();
    expect(
      find.text('${l10n.voiceModelPrivacy} ${l10n.voiceKeptNote}'),
      findsOneWidget,
    );
    onDesktop = true;
    addTearDown(() => onDesktop = false);
    await t.pumpWidget(_framed(VoiceTxScreen(hub: f.hub, key: UniqueKey())));
    await t.pumpAndSettle();
    expect(
      find.text('${l10n.voiceModelPrivacyDesk} ${l10n.voiceKeptNoteDesk}'),
      findsOneWidget,
    );
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('$locale at twice the text size fits', (t) async {
      tall(t);
      setL10nLocale(locale);
      addTearDown(() => setL10nLocale(const Locale('en')));
      final f = fakeVoiceHub(installed: false);
      addTearDown(f.hub.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: buildHaloTheme(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(
              ctx,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: VoiceTxScreen(hub: f.hub),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text(l10n.voiceOnRow), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
