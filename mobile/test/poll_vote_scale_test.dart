// SPDX-License-Identifier: GPL-3.0-or-later
// a poll's vote button at 2x text: it grows round its word instead of
// cutting it, and stays a finger's height at 1x
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/polls.dart';
import 'package:kryfo/widgets/poll_card.dart';

import 'a11y_fakes.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('the vote button holds its word at ${scale}x', (t) async {
      final m = t.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      addTearDown(
        () => m.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      t.view.physicalSize = const Size(720, 1600);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        bare(
          Scaffold(
            body: Center(
              child: PollCard(
                question: 'Dinner?',
                poll: const PollSpec(options: ['Ramen', 'Tacos'], multi: true),
                votes: const {},
                me: 'me',
                mine: false,
                isOut: false,
                onVote: (_) {},
                nameOf: (id) => id,
              ),
            ),
          ),
          still: true,
          scale: scale,
        ),
      );
      await t.tap(find.text('Ramen'));
      await t.pumpAndSettle();
      final button = find.ancestor(
        of: find.text(l10n.pollVote),
        matching: find.byType(Container),
      );
      final box = t.getRect(button.first);
      final word = t.getRect(find.text(l10n.pollVote));
      expect(box.height, greaterThanOrEqualTo(38));
      expect(word.top, greaterThanOrEqualTo(box.top));
      expect(word.bottom, lessThanOrEqualTo(box.bottom));
      expect(t.takeException(), isNull);
    });
  }
}
