// SPDX-License-Identifier: GPL-3.0-or-later
// shared by the accessibility tests: contrast from colours, the text
// colours on screen, the lines sent to a screen reader, and a bare app
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/theme.dart';

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

/// wcag contrast of [a] over [b], [a] composited first when it has alpha
double ratio(Color a, Color b) {
  final top = Color.alphaBlend(a, b);
  final x = _lum(top), y = _lum(b);
  return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
}

/// every text colour drawn under [within], spans included
List<Color> inks(WidgetTester t, [Finder? within]) {
  final out = <Color>[];
  void span(InlineSpan s) {
    final c = s.style?.color;
    if (c != null) out.add(c);
    if (s is TextSpan) s.children?.forEach(span);
  }

  final f = within == null
      ? find.byType(RichText)
      : find.descendant(of: within, matching: find.byType(RichText));
  for (final w in t.widgetList<RichText>(f)) {
    span(w.text);
  }
  return out;
}

/// the lines the app hands a screen reader, as they are sent
List<String> hearAnnouncements(WidgetTester t) {
  final heard = <String>[];
  t.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
    SystemChannels.accessibility,
    (m) async {
      if (m is Map && m['type'] == 'announce') {
        heard.add((m['data'] as Map)['message'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () =>
        t.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return heard;
}

/// [home] in a bare app with the app's words, [light] or dark, at [scale]
Widget bare(
  Widget home, {
  bool light = false,
  bool still = false,
  bool reader = false,
  double scale = 1,
  Locale locale = const Locale('en'),
}) {
  HaloColors.setLight(light);
  return MaterialApp(
    locale: locale,
    theme: buildHaloTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(
        disableAnimations: still,
        accessibleNavigation: reader,
        textScaler: TextScaler.linear(scale),
      ),
      child: child!,
    ),
    home: home,
  );
}

/// every label, value and tooltip in the semantics tree a screen reader
/// gets, after merging and blocking
List<String> treeLabels(WidgetTester t) {
  final out = <String>[];
  void walk(SemanticsNode n) {
    final d = n.getSemanticsData();
    for (final s in [d.label, d.value, d.tooltip, d.hint]) {
      if (s.isNotEmpty) out.add(s);
    }
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  final root =
      t.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode;
  if (root != null) walk(root);
  return out;
}
