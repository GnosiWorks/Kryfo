// SPDX-License-Identifier: GPL-3.0-or-later
// a field lays out what is typed in its own direction. empty, it keeps the
// screen's direction, so the hint sits where the screen's lines start.
import 'package:flutter/widgets.dart';

import '../l10n/l10n.dart';

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

  // a rebuild only when the direction turns, not on every letter
  void _check() {
    final d = writtenDir(widget.controller.text);
    if (d != _dir) setState(() => _dir = d);
  }

  @override
  Widget build(BuildContext context) => widget.builder(_dir);
}
