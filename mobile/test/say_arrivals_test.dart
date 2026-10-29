// SPDX-License-Identifier: GPL-3.0-or-later
// new messages to a screen reader: the count once per batch, only with a
// reader on, never under the lock and never from behind another page
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/widgets/say.dart';

import 'a11y_fakes.dart';

final _here = GlobalKey();

Future<BuildContext> _chat(WidgetTester t, {bool reader = true}) async {
  await t.pumpWidget(bare(SizedBox(key: _here), reader: reader, still: true));
  return _here.currentContext!;
}

void main() {
  setUp(() => lockState.openForTest());
  tearDown(() => lockState.openForTest());

  testWidgets('a batch is heard as its count, once', (t) async {
    final heard = hearAnnouncements(t);
    final c = await _chat(t);
    sayArrivals(c, 1);
    sayArrivals(c, 3);
    sayArrivals(c, 0);
    await t.pump();
    expect(heard, [l10n.a11yNewMessages(1), l10n.a11yNewMessages(3)]);
  });

  testWidgets('without a screen reader nothing is said', (t) async {
    final heard = hearAnnouncements(t);
    final c = await _chat(t, reader: false);
    sayArrivals(c, 2);
    await t.pump();
    expect(heard, isEmpty);
  });

  testWidgets('under the lock nothing is said', (t) async {
    final heard = hearAnnouncements(t);
    final c = await _chat(t);
    lockState.openForTest(enabled: true);
    lockState.lock();
    sayArrivals(c, 2);
    await t.pump();
    expect(heard, isEmpty);
  });

  testWidgets('with a page on top nothing is said', (t) async {
    final heard = hearAnnouncements(t);
    final c = await _chat(t);
    Navigator.of(
      c,
    ).push(MaterialPageRoute<void>(builder: (_) => const SizedBox()));
    await t.pumpAndSettle();
    sayArrivals(c, 2);
    await t.pump();
    expect(heard, isEmpty);
  });

  testWidgets('with the app away nothing is said', (t) async {
    final heard = hearAnnouncements(t);
    final c = await _chat(t);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    addTearDown(
      () => t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
    );
    sayArrivals(c, 2);
    await t.pump();
    expect(heard, isEmpty);
  });

  test('the words are the count, never the message', () {
    expect(l10n.a11yNewMessages(1), 'New message');
    expect(l10n.a11yNewMessages(3), '3 new messages');
  });
}
