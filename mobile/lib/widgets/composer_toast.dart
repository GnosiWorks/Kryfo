// SPDX-License-Identifier: GPL-3.0-or-later
// a toast just above the composer, for a tap there that cannot go from
// here. the app's toast card, rising from the composer instead of under the
// header; it leaves on its own, on a tap, or for the next one
import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart' show HaloToastBox;

/// what the composer's toast says next
class ComposerToastLine extends ChangeNotifier {
  String? _line;
  int _said = 0;

  String? get line => _line;
  int get said => _said;

  void say(String line) {
    _line = line;
    _said++;
    notifyListeners();
  }
}

class ComposerToast extends StatefulWidget {
  final ComposerToastLine line;
  const ComposerToast({super.key, required this.line});

  @override
  State<ComposerToast> createState() => _ComposerToastState();
}

class _ComposerToastState extends State<ComposerToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _timer;
  String? _shown;
  int _seen = 0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _seen = widget.line.said;
    widget.line.addListener(_said);
  }

  @override
  void didUpdateWidget(ComposerToast old) {
    super.didUpdateWidget(old);
    if (!identical(old.line, widget.line)) {
      old.line.removeListener(_said);
      _seen = widget.line.said;
      widget.line.addListener(_said);
    }
  }

  void _said() {
    final l = widget.line.line;
    if (!mounted || l == null || widget.line.said == _seen) return;
    _seen = widget.line.said;
    setState(() => _shown = l);
    _c.forward();
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 3500), _leave);
  }

  void _leave() {
    _timer?.cancel();
    if (mounted) _c.reverse();
  }

  @override
  void dispose() {
    widget.line.removeListener(_said);
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    if (shown == null) return const SizedBox.shrink();
    final still = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = _c.value;
        if (t == 0) return const SizedBox.shrink();
        if (still) return Opacity(opacity: t, child: child);
        // in: up from the composer with a little overshoot. out: down
        final e = _c.status == AnimationStatus.reverse
            ? Curves.easeIn.transform(t)
            : Curves.easeOutBack.transform(t);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - e) * 14),
            child: Transform.scale(scale: 0.96 + 0.04 * e, child: child),
          ),
        );
      },
      child: GestureDetector(
        onTap: _leave,
        child: Semantics(
          container: true,
          liveRegion: true,
          child: ConstrainedBox(
            key: const ValueKey('composer-toast'),
            constraints: const BoxConstraints(maxWidth: 360),
            child: HaloToastBox(shown),
          ),
        ),
      ),
    );
  }
}
