// SPDX-License-Identifier: GPL-3.0-or-later
// page titles and section heads are headings, so a screen reader can jump
// from one to the next
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/page_head.dart';

import 'a11y_fakes.dart';

void main() {
  testWidgets('a page bar title and a page section are headings', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(
      bare(
        const Scaffold(
          body: Column(
            children: [
              PageBar(title: 'Pinned'),
              PageSection('Older'),
            ],
          ),
        ),
        still: true,
      ),
    );
    for (final words in ['Pinned', 'Older']) {
      final n = t.getSemantics(find.text(words));
      expect(n.flagsCollection.isHeader, isTrue, reason: words);
    }
    h.dispose();
  });

  test("home's section heads are headings", () {
    final src = File('lib/screens/home_screen.dart').readAsStringSync();
    final head = src.substring(src.indexOf('class _SectionHead'));
    expect(
      head.substring(0, head.indexOf('class _HeadAction')),
      contains('header: true'),
    );
  });
}
