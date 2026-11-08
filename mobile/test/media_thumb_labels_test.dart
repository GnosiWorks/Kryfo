// SPDX-License-Identifier: GPL-3.0-or-later
// a photo or video tile has a name: its kind, who sent it, the day. search
// gives its tiles that name
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/dates.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/widgets/media_bubbles.dart';

void main() {
  final when = DateTime(2026, 3, 12, 9, 30);
  final day = dayMonthMaybeYear(when);

  test('a tile names its kind, its sender and its day', () {
    expect(mediaTileLabel(when), l10n.a11yPhotoOn(day));
    expect(mediaTileLabel(when, from: 'Ana'), l10n.a11yPhotoFrom('Ana', day));
    expect(mediaTileLabel(when, video: true), l10n.a11yVideoOn(day));
    expect(
      mediaTileLabel(when, from: 'Ana', video: true),
      l10n.a11yVideoFrom('Ana', day),
    );
    expect(mediaTileLabel(when, from: ''), l10n.a11yPhotoOn(day));
  });

  test("search's photo tiles pass the name to their button", () {
    final src = File('lib/screens/search_screen.dart').readAsStringSync();
    final thumb = src.substring(src.indexOf('class _Thumb'));
    expect(thumb, contains('label: label'));
    expect(src, contains('label: mediaTileLabel('));
  });
}
