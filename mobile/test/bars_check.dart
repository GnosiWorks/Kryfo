// SPDX-License-Identifier: GPL-3.0-or-later
// a phone with a cutout, a gesture or button bar and a keyboard, and a check
// that no text, icon or field is drawn where they are
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// logical sizes: a punch-hole status bar, android's gesture handle and its
// three buttons, a keyboard
const cutoutTop = 44.0;
const gestureBar = 24.0;
const buttonBar = 48.0;
const keyboardUp = 300.0;

// a 360x780 phone in portrait, or on its side with the cutout on the left
void barsPhone(
  WidgetTester t, {
  double nav = gestureBar,
  double keyboard = 0,
  bool landscape = false,
}) {
  const ratio = 3.0;
  t.view.devicePixelRatio = ratio;
  t.view.physicalSize = landscape
      ? const Size(780 * ratio, 360 * ratio)
      : const Size(360 * ratio, 780 * ratio);
  final top = (landscape ? 24.0 : cutoutTop) * ratio;
  final left = (landscape ? cutoutTop : 0.0) * ratio;
  // on its side, the buttons stand at the right edge. the gesture handle
  // stays at the bottom
  final side = landscape && nav >= buttonBar;
  final right = side ? nav * ratio : 0.0;
  final bottom = side ? 0.0 : nav * ratio;
  final kb = keyboard * ratio;
  t.view.viewPadding = FakeViewPadding(
    top: top,
    left: left,
    right: right,
    bottom: bottom,
  );
  // what the engine reports: the keyboard takes over the bar below it
  t.view.padding = FakeViewPadding(
    top: top,
    left: left,
    right: right,
    bottom: math.max(0, bottom - kb),
  );
  t.view.viewInsets = FakeViewPadding(bottom: kb);
  addTearDown(t.view.reset);
}

// the bands nothing may be drawn in, in logical pixels
class Bars {
  const Bars(this.screen, this.top, this.bottom, this.left, this.right);
  final Size screen;
  final double top, bottom, left, right;

  static Bars of(WidgetTester t) {
    final r = t.view.devicePixelRatio;
    final p = t.view.viewPadding;
    final k = t.view.viewInsets;
    return Bars(
      t.view.physicalSize / r,
      p.top / r,
      math.max(p.bottom, k.bottom) / r,
      p.left / r,
      p.right / r,
    );
  }

  Rect get clear =>
      Rect.fromLTRB(left, top, screen.width - right, screen.height - bottom);
}

class _Scroll {
  const _Scroll(this.axis, this.atStart, this.atEnd);
  final Axis axis;
  final bool atStart, atEnd;
}

bool _hidden(RenderObject o) {
  if (o is RenderOffstage && o.offstage) return true;
  if (o is RenderOpacity && o.opacity == 0) return true;
  if (o is RenderAnimatedOpacity && o.opacity.value == 0) return true;
  if (o is RenderSliverOpacity && o.opacity == 0) return true;
  if (o is RenderSliverOffstage && o.offstage) return true;
  return false;
}

String _what(RenderObject o) {
  if (o is RenderParagraph) {
    final s = o.text.toPlainText();
    if (s.runes.length == 1 && s.runes.first >= 0xE000) {
      return 'icon U+${s.runes.first.toRadixString(16)}';
    }
    return 'text "${s.length > 40 ? '${s.substring(0, 40)}...' : s}"';
  }
  return 'field';
}

// every text, icon and field drawn in a band, with where it is. a list may
// run under a bar while there is more of it to scroll into view
List<String> underBars(WidgetTester t) {
  final bars = Bars.of(t);
  final clear = bars.clear;
  final out = <String>[];
  void visit(RenderObject o, Rect clip, _Scroll? v, _Scroll? h) {
    if (_hidden(o)) return;
    if (o is RenderParagraph || o is RenderEditable) {
      final box = o as RenderBox;
      if (!box.hasSize || box.size.isEmpty) return;
      if (o is RenderParagraph && o.text.toPlainText().trim().isEmpty) return;
      final at = MatrixUtils.transformRect(
        box.getTransformTo(null),
        Offset.zero & box.size,
      ).intersect(clip);
      if (at.width <= 0.5 || at.height <= 0.5) return;
      final fails = <String>[
        if (at.top < clear.top - 0.5 && (v == null || v.atStart)) 'top',
        if (at.bottom > clear.bottom + 0.5 && (v == null || v.atEnd)) 'bottom',
        if (at.left < clear.left - 0.5 && (h == null || h.atStart)) 'left',
        if (at.right > clear.right + 0.5 && (h == null || h.atEnd)) 'right',
      ];
      if (fails.isNotEmpty) {
        out.add('${_what(o)} at $at under the ${fails.join(' and ')} bars');
      }
      return;
    }
    var nv = v, nh = h;
    if (o is RenderViewportBase) {
      final off = o.offset;
      if (off.hasPixels) {
        final s = off is ScrollPosition
            ? _Scroll(
                axisDirectionToAxis(o.axisDirection),
                off.pixels <= off.minScrollExtent + 0.5,
                off.pixels >= off.maxScrollExtent - 0.5,
              )
            : _Scroll(axisDirectionToAxis(o.axisDirection), true, true);
        if (s.axis == Axis.vertical) {
          nv = s;
        } else {
          nh = s;
        }
      }
    }
    void child(RenderObject c) {
      var cc = clip;
      final local = o.describeApproximatePaintClip(c);
      if (local != null) {
        cc = cc.intersect(
          MatrixUtils.transformRect(o.getTransformTo(null), local),
        );
      }
      if (cc.isEmpty) return;
      visit(c, cc, nv, nh);
    }

    final name = o.runtimeType.toString();
    if (name == '_RenderTheater' || o is RenderIndexedStack) {
      o.visitChildrenForSemantics(child);
    } else {
      o.visitChildren(child);
    }
  }

  for (final view in t.binding.renderViews) {
    visit(view, Offset.zero & bars.screen, null, null);
  }
  return out;
}

// the check itself, with each offender named
void expectClearOfBars(WidgetTester t, {String? reason}) {
  final hits = underBars(t);
  expect(hits, isEmpty, reason: reason == null ? null : '$reason: $hits');
}

// how far above the bars or the keyboard a widget's lowest edge sits
double gapAboveBottom(WidgetTester t, Finder f) {
  final bars = Bars.of(t);
  return bars.screen.height - bars.bottom - t.getRect(f).bottom;
}
