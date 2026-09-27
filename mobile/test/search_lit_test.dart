// SPDX-License-Identifier: GPL-3.0-or-later
// an in-chat search marks its hits the same way in both chats: every hit,
// whatever its case, amber on a tint in their bubble and amber on ink in
// ours, and the bubble with the hit in view gets its ring.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/chat_parts.dart';

void main() {
  test('every hit is marked, whatever its case', () {
    final s = searchLit('Ramen? RAMEN. ramen!', 'ramen', onAmber: false);
    final lit = [
      for (final x in s)
        if (x.style != null) x.text,
    ];
    expect(lit, ['Ramen', 'RAMEN', 'ramen']);
    expect(s.map((x) => x.text).join(), 'Ramen? RAMEN. ramen!');
  });

  test('their bubble: amber on its tint', () {
    final s = searchLit('see you at eight', 'eight', onAmber: false);
    final hit = s.firstWhere((x) => x.style != null);
    expect(hit.style!.color, HaloColors.amber);
    expect(
      hit.style!.backgroundColor,
      HaloColors.amber.withValues(alpha: 0.22),
    );
  });

  test('ours: amber on ink, where amber alone would vanish', () {
    final s = searchLit('see you at eight', 'eight', onAmber: true);
    final hit = s.firstWhere((x) => x.style != null);
    expect(hit.style!.backgroundColor, HaloColors.onAmber);
  });

  test('right-to-left words are marked the same', () {
    final s = searchLit('سلام دوست من سلام', 'سلام', onAmber: false);
    expect(s.where((x) => x.style != null), hasLength(2));
    expect(s.map((x) => x.text).join(), 'سلام دوست من سلام');
  });

  test('nothing looked for, nothing marked', () {
    final s = searchLit('plain', '', onAmber: false);
    expect(s, hasLength(1));
    expect(s.single.style, isNull);
  });

  test('a hit that lowercasing moves off the text is left plain', () {
    // the capital dotted i grows a character when lowercased
    final s = searchLit('İstanbul', 'stanbul', onAmber: false);
    expect(s.map((x) => x.text).join(), 'İstanbul');
  });

  test('only the hit in view gets the ring and the glow', () {
    expect(searchRing(false), isNull);
    expect(searchGlow(false), isNull);
    expect(searchRing(true), isA<Border>());
    expect(searchGlow(true), hasLength(1));
  });
}
