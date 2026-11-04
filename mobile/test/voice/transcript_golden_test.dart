// SPDX-License-Identifier: GPL-3.0-or-later
// voice transcripts pixel for pixel, at a phone's size and a computer's:
// the link, the words coming in, the words shown on theirs and on ours, a
// translation under the words heard, a failure, the model sheet and the
// settings page
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_mode.dart' show onDesktop;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/translate/chat_translation.dart';
import 'package:kryfo/voice/chat_transcripts.dart';
import 'package:kryfo/voice/transcript_store.dart';
import 'package:kryfo/voice/ui/model_sheet.dart';
import 'package:kryfo/voice/ui/transcript_line.dart';
import 'package:kryfo/voice/ui/voice_tx_screen.dart';

import '../narrow_settings.dart' show loadAppFonts;
import '../translate_fakes.dart';
import 'voice_tx_fakes.dart';

const _zh = '我们明天在车站见吧';
const _en = "Let's meet at the station tomorrow";

KeptTranscript _kept(String words) => KeptTranscript(
  lang: 'en',
  model: 'base',
  pieces: [TxPiece(0, 1, ' $words')],
);

Widget _app(Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: home,
);

// a voice bubble's frame with its play mark and wave drawn plain: the
// player itself needs a phone
Widget _bubble(
  String uid,
  bool out,
  ChatTranscripts c, [
  ChatTranslation? tr,
]) => Align(
  alignment: out
      ? AlignmentDirectional.centerEnd
      : AlignmentDirectional.centerStart,
  child: Container(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    constraints: const BoxConstraints(maxWidth: 304),
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
    decoration: BoxDecoration(
      color: out ? HaloColors.amber : HaloColors.surface2,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 184,
          height: 34,
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: out ? HaloColors.onAmber : HaloColors.amber,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 3,
                  color: out ? HaloColors.onAmber : HaloColors.amber,
                ),
              ),
            ],
          ),
        ),
        VoiceTranscript(
          chat: c,
          uid: uid,
          path: '/n/$uid.ogg',
          isOut: out,
          translation: tr,
        ),
      ],
    ),
  ),
);

void main() {
  setUpAll(loadAppFonts);

  for (final (name, size) in [
    ('phone', const Size(390, 844)),
    ('desk', const Size(1280, 800)),
  ]) {
    void sized(WidgetTester t) {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      onDesktop = name == 'desk';
      addTearDown(() => onDesktop = false);
    }

    testWidgets('$name: the states under a voice note', (t) async {
      sized(t);
      final store = MemoryVoiceTxStore();
      store.rows['heron'] = {
        'shown': _kept('see you at the station at three, bring the tickets'),
        'ours': _kept('on my way, ten minutes'),
        'zh': _kept(_zh),
      };
      final f = fakeVoiceHub(store: store);
      addTearDown(f.hub.dispose);
      await f.hub.ready();
      final c = ChatTranscripts(f.hub, 'heron');
      addTearDown(c.dispose);
      final tf = fakeHub(installed: true, words: {_zh: _en});
      await tf.hub.ready();
      final tr = ChatTranslation(tf.hub, 'heron');
      addTearDown(tr.dispose);
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      await t.pumpWidget(
        _app(
          Scaffold(
            backgroundColor: HaloColors.surface,
            body: SafeArea(
              child: ListView(
                children: [
                  _bubble('closed', false, c),
                  _bubble('working', false, c),
                  _bubble('shown', false, c),
                  _bubble('ours', true, c),
                  _bubble('zh', false, c, tr),
                  _bubble('failed', false, c),
                ],
              ),
            ),
          ),
        ),
      );
      await t.pump();
      await c.open('failed', '/n/failed.ogg');
      await t.pump();
      f.runner.jobs.single.end();
      await t.pump();
      await c.open('working', '/n/working.ogg');
      await t.pump();
      await t.pump();
      f.runner.jobs.last.say(' the train leaves');
      await t.pump();
      await t.pump();
      await t.tap(find.text(l10n.translateAction));
      await t.pump();
      await t.pump();
      expect(find.text(_en), findsOneWidget);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/voice_tx_${name}_states.png'),
      );
    });

    testWidgets('$name: the model sheet', (t) async {
      sized(t);
      final f = fakeVoiceHub(installed: false);
      addTearDown(f.hub.dispose);
      await t.pumpWidget(
        _app(
          Builder(
            builder: (ctx) => Scaffold(
              backgroundColor: HaloColors.surface,
              body: Center(
                child: TextButton(
                  onPressed: () => showVoiceModelSheet(ctx, f.hub),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/voice_tx_${name}_sheet.png'),
      );
    });

    testWidgets('$name: the settings page', (t) async {
      sized(t);
      final f = fakeVoiceHub(installed: true);
      addTearDown(f.hub.dispose);
      await t.pumpWidget(_app(VoiceTxScreen(hub: f.hub)));
      await t.pumpAndSettle();
      await expectLater(
        find.byType(VoiceTxScreen),
        matchesGoldenFile('goldens/voice_tx_${name}_settings.png'),
      );
    });
  }
}
