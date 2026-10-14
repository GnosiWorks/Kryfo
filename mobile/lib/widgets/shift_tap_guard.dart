// SPDX-License-Identifier: GPL-3.0-or-later
// a finger on the field moves the caret, never stretches a selection from
// it. some android keyboards leave a shift down in flutter's key state after
// their shift key is tapped, and every tap then extends from the caret.
// flutter/flutter#184744, fixed in the 3.44 engine: drop this with it
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ShiftTapGuard extends StatefulWidget {
  final TextEditingController controller;
  final Widget child;
  const ShiftTapGuard({
    super.key,
    required this.controller,
    required this.child,
  });
  @override
  State<ShiftTapGuard> createState() => _ShiftTapGuardState();
}

class _ShiftTapGuardState extends State<ShiftTapGuard> {
  // the caret when a finger came down on the field, and every caret put
  // back since: a drag stretches again from one of them before a rebuild
  final _from = <int>{};
  // the last finger to leave, so a second tap of a double tap goes through
  Offset? _upWhere;
  Timer? _upTimer;
  int _touch = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_check);
  }

  @override
  void didUpdateWidget(ShiftTapGuard old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_check);
      widget.controller.addListener(_check);
      _from.clear();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_check);
    _upTimer?.cancel();
    super.dispose();
  }

  void _down(PointerDownEvent e) {
    _touch++;
    _from.clear();
    final s = widget.controller.selection;
    final upWhere = _upWhere;
    // a double tap selects a word, shift or not
    final second =
        upWhere != null && (e.position - upWhere).distance <= kDoubleTapSlop;
    if (e.kind == PointerDeviceKind.touch &&
        defaultTargetPlatform == TargetPlatform.android &&
        !second &&
        (!s.isValid || s.isCollapsed)) {
      _from.add(s.baseOffset);
    }
  }

  // the tap or drag settles after the listener hears the finger go
  void _up(PointerEvent e) {
    _upWhere = e.position;
    _upTimer?.cancel();
    _upTimer = Timer(kDoubleTapTimeout, () => _upWhere = null);
    final touch = _touch;
    scheduleMicrotask(() {
      if (touch == _touch) _from.clear();
    });
  }

  void _check() {
    if (_from.isEmpty || !HardwareKeyboard.instance.isShiftPressed) return;
    final s = widget.controller.selection;
    if (s.isCollapsed || !_from.contains(s.baseOffset)) return;
    if (s.extentOffset < 0) return;
    _from.add(s.extentOffset);
    widget.controller.selection = TextSelection.collapsed(
      offset: s.extentOffset,
      affinity: s.affinity,
    );
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _down,
    onPointerUp: _up,
    onPointerCancel: (_) => _from.clear(),
    child: widget.child,
  );
}
