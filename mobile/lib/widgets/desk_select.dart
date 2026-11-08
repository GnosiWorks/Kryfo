// SPDX-License-Identifier: GPL-3.0-or-later
// a bubble's words on a computer: a mouse drag selects them and ctrl+c
// copies what is selected. a click is still the bubble's click, a right
// click still opens the bubble's menu, unless it lands on words already
// selected: then it offers to copy them. only a mouse selects: touch on a
// computer's screen swipes and holds as the phone does. the phone gets the
// words as they are.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;

import '../desktop/desktop_mode.dart' show onDesktop;

class DeskSelectable extends StatefulWidget {
  final Widget child;
  // the bubble's menu, for a right click on the words. null: no menu
  final VoidCallback? onMenu;
  // the bubble's click, for a click on the words that selects nothing
  final VoidCallback? onTap;
  // false: the words are not selectable here
  final bool enabled;
  const DeskSelectable({
    super.key,
    required this.child,
    this.onMenu,
    this.onTap,
    this.enabled = true,
  });

  @override
  State<DeskSelectable> createState() => _DeskSelectableState();
}

class _DeskSelectableState extends State<DeskSelectable> {
  final _focus = FocusNode(debugLabel: 'bubble words');
  // the words keep their state as the selection comes and goes
  final _words = GlobalKey();
  // a mouse is over the words: only then can they be selected
  bool _mouse = false;
  bool _has = false;
  // the right click landed on words that were selected
  bool _onWords = false;
  Offset? _downAt;
  // the selection is in the tree: a click lands on it, not on the bubble
  bool _built = false;

  bool get _on => _mouse || _has;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _hover(bool v) {
    if (v == _mouse) return;
    final was = _on;
    _mouse = v;
    if (_on != was) setState(() {});
  }

  void _down(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.mouse) return;
    if (e.buttons & kSecondaryMouseButton != 0) {
      _onWords = _has;
      // with no selection in the tree yet the bubble's own right click
      // takes it
      if (!_onWords && _built) widget.onMenu?.call();
      return;
    }
    if (e.buttons & kPrimaryMouseButton != 0 && _built) _downAt = e.position;
  }

  void _up(PointerUpEvent e) {
    final at = _downAt;
    _downAt = null;
    if (e.kind != PointerDeviceKind.mouse) return;
    final click = at != null && (e.position - at).distance < kTouchSlop;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _has) return;
      // a click that selected nothing is the bubble's, and the focus goes
      // back where it was, so typing goes on in the composer
      if (click) widget.onTap?.call();
      if (_focus.hasFocus) {
        _focus.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
      }
    });
  }

  void _selected(SelectedContent? c) {
    final has = (c?.plainText ?? '').isNotEmpty;
    if (has == _has) return;
    final was = _on;
    _has = has;
    if (_on != was && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!onDesktop || !widget.enabled) {
      _built = false;
      return widget.child;
    }
    final words = KeyedSubtree(key: _words, child: widget.child);
    _built = _on;
    return MouseRegion(
      onEnter: (_) => _hover(true),
      onExit: (_) => _hover(false),
      child: Listener(
        onPointerDown: _down,
        onPointerUp: _up,
        child: !_on
            ? words
            : SelectionArea(
                focusNode: _focus,
                onSelectionChanged: _selected,
                // the copy menu only over selected words: elsewhere the
                // bubble's menu is up already
                contextMenuBuilder: (context, state) => _onWords
                    ? AdaptiveTextSelectionToolbar.selectableRegion(
                        selectableRegionState: state,
                      )
                    : const SizedBox.shrink(),
                child: words,
              ),
      ),
    );
  }
}
