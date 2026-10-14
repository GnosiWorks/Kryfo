// SPDX-License-Identifier: GPL-3.0-or-later
// a hero whose flight keeps the page's text style. the shuttle flies in the
// overlay, outside any Material, where text falls back to the app's error
// style with its yellow double underline.

import 'package:flutter/material.dart';

class HaloHero extends StatelessWidget {
  final Object tag;
  final CreateRectTween? createRectTween;
  final HeroFlightShuttleBuilder? flightShuttleBuilder;
  final Widget child;
  const HaloHero({
    super.key,
    required this.tag,
    this.createRectTween,
    this.flightShuttleBuilder,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Hero(
    tag: tag,
    createRectTween: createRectTween,
    flightShuttleBuilder: (flight, a, dir, from, to) {
      final page = DefaultTextStyle.of(to);
      return Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(
          style: page.style,
          textAlign: page.textAlign,
          softWrap: page.softWrap,
          overflow: page.overflow,
          maxLines: page.maxLines,
          textWidthBasis: page.textWidthBasis,
          textHeightBehavior: page.textHeightBehavior,
          // the destination's shuttle first, as the framework picks
          child:
              (_given(to) ?? _given(from))?.call(flight, a, dir, from, to) ??
              _plainFlight(a, dir, from, to),
        ),
      );
    },
    child: child,
  );
}

// the shuttle a hero was given, a HaloHero's own or a plain hero's
HeroFlightShuttleBuilder? _given(BuildContext hero) {
  Widget? parent;
  hero.visitAncestorElements((e) {
    parent = e.widget;
    return false;
  });
  final p = parent;
  return p is HaloHero
      ? p.flightShuttleBuilder
      : (hero.widget as Hero).flightShuttleBuilder;
}

// the framework's own shuttle: the destination's child, its padding eased
// from one page to the other
Widget _plainFlight(
  Animation<double> a,
  HeroFlightDirection dir,
  BuildContext from,
  BuildContext to,
) {
  final child = (to.widget as Hero).child;
  final toData = MediaQuery.maybeOf(to);
  final fromData = MediaQuery.maybeOf(from);
  if (toData == null || fromData == null) return child;
  final pad = dir == HeroFlightDirection.push
      ? EdgeInsetsTween(begin: fromData.padding, end: toData.padding)
      : EdgeInsetsTween(begin: toData.padding, end: fromData.padding);
  return AnimatedBuilder(
    animation: a,
    builder: (_, _) => MediaQuery(
      data: toData.copyWith(padding: pad.evaluate(a)),
      child: child,
    ),
  );
}
