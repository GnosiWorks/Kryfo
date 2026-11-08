// SPDX-License-Identifier: GPL-3.0-or-later
// a composer on a computer: enter sends, shift and enter starts a new line.
// a phone keeps its keyboard's own enter
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../desktop/desktop_mode.dart' show onDesktop;

class EnterSends extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final Widget child;

  /// set by tests; the desktop flag otherwise
  final bool? desktop;

  const EnterSends({
    super.key,
    required this.controller,
    required this.onSend,
    required this.child,
    this.desktop,
  });

  static bool _isEnter(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter;

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (!_isEnter(e.logicalKey) || e is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final keys = HardwareKeyboard.instance;
    // shift: the field's own new line
    if (keys.isShiftPressed) return KeyEventResult.ignored;
    // a word still being put together by an input method is its enter
    final composing = controller.value.composing;
    if (composing.isValid && !composing.isCollapsed) {
      return KeyEventResult.ignored;
    }
    // with ctrl, alt or meta it is someone else's shortcut
    if (keys.isControlPressed || keys.isAltPressed || keys.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    // held down: one send, and no row of new lines after it
    if (e is KeyDownEvent) onSend();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    if (!(desktop ?? onDesktop)) return child;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _key,
      child: child,
    );
  }
}
