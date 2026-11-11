// SPDX-License-Identifier: GPL-3.0-or-later
// a field lays out what is typed in its own direction. empty, it keeps the
// screen's direction, so the hint sits where the screen's lines start. its
// han characters are drawn in the glyphs their chinese wants: the builder
// runs again when that turns too (hanLocaleOf)
import 'package:flutter/widgets.dart';

import '../cjk_locale.dart';
import '../l10n/l10n.dart';

/// the locale a field's style takes for [text]: null for text with no han
Locale? hanLocaleOf(String text) =>
    cjkLocaleFor(text, fallback: cjkTextLocaleNow);

class WrittenDir extends StatefulWidget {
  final TextEditingController controller;
  final Widget Function(TextDirection? dir) builder;
  const WrittenDir({
    super.key,
    required this.controller,
    required this.builder,
  });
  @override
  State<WrittenDir> createState() => _WrittenDirState();
}

class _WrittenDirState extends State<WrittenDir> {
  late TextDirection? _dir = writtenDir(widget.controller.text);
  late Locale? _han = hanLocaleOf(widget.controller.text);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_check);
  }

  @override
  void didUpdateWidget(WrittenDir old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_check);
      widget.controller.addListener(_check);
      _check();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_check);
    super.dispose();
  }

  // a rebuild only when the direction or the glyphs turn, not on every
  // letter
  void _check() {
    final t = widget.controller.text;
    final d = writtenDir(t);
    final h = hanLocaleOf(t);
    if (d != _dir || h != _han) {
      setState(() {
        _dir = d;
        _han = h;
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(_dir);
}
