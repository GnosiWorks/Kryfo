// SPDX-License-Identifier: GPL-3.0-or-later
// a computer's right-click menu: a small card at the mouse, nothing dimmed
// or moved behind it, kept inside the window near its edges. the menu key
// and shift+f10 open it at the focused item; arrows move, enter picks, esc
// closes. the phone keeps its long-press menus as they are
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../desktop/desktop_mode.dart' show onDesktop;
import '../l10n/l10n.dart';
import '../lock_guard.dart' show lockGuard;
import '../theme.dart';
import 'halo_sheet.dart';
import 'key_ring.dart' show KeyLead, KeyRing;
import 'message_menu.dart';

/// asks the focused item for its menu
class DeskMenuIntent extends Intent {
  const DeskMenuIntent();
}

/// the keys that open a menu at the focused item
const deskMenuKeys = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.contextMenu): DeskMenuIntent(),
  SingleActivator(LogicalKeyboardKey.f10, shift: true): DeskMenuIntent(),
};

/// where the next menu opens: the last right click, or the item a key
/// opened it on. read once, then forgotten
class DeskMenuAt {
  static Offset? _point;
  static Rect? _rect;
  static var _watching = false;

  /// sees every mouse press in the window, before any widget does
  static void watch() {
    if (_watching) return;
    _watching = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_seen);
  }

  static void _seen(PointerEvent e) {
    if (e is! PointerDownEvent) return;
    if (e.kind == PointerDeviceKind.mouse &&
        e.buttons & kSecondaryMouseButton != 0) {
      _point = e.position;
      _rect = null;
    } else {
      _point = null;
    }
  }

  /// a key opened it: at this item
  static void keyed(Rect r) {
    _rect = r;
    _point = null;
  }

  static ({Offset? point, Rect? rect}) take() {
    final r = (point: _point, rect: _rect);
    _point = null;
    _rect = null;
    return r;
  }

  @visibleForTesting
  static void forget() {
    _point = null;
    _rect = null;
  }
}

/// the item's rect in the window
Rect? deskRectOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize || !box.attached) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// the menu key and shift+f10 on whatever has focus under [child]. on a
/// phone, the child as it is
class DeskMenuKeys extends StatelessWidget {
  final VoidCallback? onMenu;
  final Widget child;
  const DeskMenuKeys({super.key, required this.onMenu, required this.child});

  @override
  Widget build(BuildContext context) {
    final go = onMenu;
    if (!onDesktop || go == null) return child;
    DeskMenuAt.watch();
    return Shortcuts(
      shortcuts: deskMenuKeys,
      child: Actions(
        actions: {
          DeskMenuIntent: CallbackAction<DeskMenuIntent>(
            onInvoke: (_) {
              final r = deskRectOf(context);
              if (r != null) DeskMenuAt.keyed(r);
              go();
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}

/// one row of the menu. no [onTap]: drawn, not pickable, its reason in [sub]
class DeskMenuItem {
  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback? onTap;
  final bool danger;
  final Color? tint;
  final bool? checked;
  // false: [onTap] closes the menu itself (a sheet's pick pops with a value)
  final bool closes;
  const DeskMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.sub,
    this.danger = false,
    this.tint,
    this.checked,
    this.closes = true,
  });
}

/// the reactions along the top, as on the phone's bar
class DeskReactions {
  final List<String> emojis;
  final String? selected;
  final void Function(String) onPick;
  const DeskReactions({
    required this.emojis,
    required this.selected,
    required this.onPick,
  });
}

/// a message menu's actions as the card shows them: those that can be
/// done, the ones that take something away last
List<List<DeskMenuItem>> deskGroupsOf(List<MenuAction> actions) {
  DeskMenuItem item(MenuAction a) => DeskMenuItem(
    icon: a.icon,
    label: a.label,
    onTap: a.onTap,
    danger: a.danger,
    tint: a.tint,
    checked: a.checked,
  );
  return [
    [
      for (final a in actions)
        if (a.onTap != null && !a.danger) item(a),
    ],
    [
      for (final a in actions)
        if (a.onTap != null && a.danger) item(a),
    ],
  ];
}

/// a sheet's rows as the menu's groups, in the same order. a pick pops the
/// menu with its value, as it popped the sheet
List<List<DeskMenuItem>> deskGroupsOfSheet(List<List<MenuSheetRow>> groups) => [
  for (final g in groups)
    [
      for (final r in g)
        DeskMenuItem(
          icon: r.icon,
          label: r.label,
          sub: r.sub,
          onTap: r.onTap,
          danger: r.danger,
          tint: r.tint,
          checked: r.toggled,
          closes: false,
        ),
    ],
];

/// a row's menu: the house sheet on a phone, the small menu at the mouse on
/// a computer. [groups] is built with the menu's own context; a row pops it
/// with its value
Future<T?> showMenuSheet<T>(
  BuildContext context, {
  required List<List<MenuSheetRow>> Function(BuildContext ctx) groups,
  String? label,
}) {
  if (onDesktop) {
    return showDeskMenu<T>(
      context,
      label: label ?? l10n.devChatOptions,
      groups: (ctx) => deskGroupsOfSheet(groups(ctx)),
    );
  }
  return showHaloSheet<T>(
    context,
    scroll: true,
    builder: (ctx) =>
        SingleChildScrollView(child: MenuSheet(groups: groups(ctx))),
  );
}

/// opens the menu at the last right click, or at the item a key asked from,
/// or else at [context]'s own box. the lock takes it down at once
Future<T?> showDeskMenu<T>(
  BuildContext context, {
  required String label,
  required List<List<DeskMenuItem>> Function(BuildContext menu) groups,
  DeskReactions? reactions,
  String? note,
}) async {
  final at = DeskMenuAt.take();
  final rect = at.point == null ? at.rect ?? deskRectOf(context) : null;
  final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  // the window's own navigator: the mouse is in the window's terms, and a
  // chat in the pane has a navigator of its own
  final nav = Navigator.of(context, rootNavigator: true);
  final route = _DeskMenuRoute<T>(
    point: at.point,
    rect: rect,
    still: still,
    label: label,
    closeLabel: l10n.commonClose,
    groups: groups,
    reactions: reactions,
    note: note,
  );
  final unguard = lockGuard.closeOnLock(() {
    if (route.isActive) route.navigator?.removeRoute(route);
  });
  try {
    return await nav.push(route);
  } finally {
    unguard();
    // a right click's menu: what it was for keeps no ring once it went
    if (at.point != null) KeyLead.pointerMenuClosed();
  }
}

/// where a menu of [menu] goes in [area]: from the point down and to the
/// end, flipped where the window ends, never past [pad] from an edge. a key
/// opens it under the item, or over it where there is no room below
@visibleForTesting
Offset deskMenuSpot({
  required Size area,
  required Size menu,
  Offset? point,
  Rect? rect,
  TextDirection dir = TextDirection.ltr,
  double pad = 8,
}) {
  final rtl = dir == TextDirection.rtl;
  double x;
  double y;
  if (point != null) {
    x = rtl ? point.dx - menu.width : point.dx;
    if (!rtl && x + menu.width > area.width - pad) x = point.dx - menu.width;
    if (rtl && x < pad) x = point.dx;
    y = point.dy;
    if (y + menu.height > area.height - pad) y = point.dy - menu.height;
  } else {
    final r =
        rect ??
        Rect.fromCenter(center: area.center(Offset.zero), width: 0, height: 0);
    x = rtl ? r.right - menu.width : r.left;
    y = r.bottom + 4;
    if (y + menu.height > area.height - pad) y = r.top - menu.height - 4;
  }
  x = x.clamp(pad, math.max(pad, area.width - pad - menu.width));
  y = y.clamp(pad, math.max(pad, area.height - pad - menu.height));
  return Offset(x, y);
}

class _DeskMenuRoute<T> extends PopupRoute<T> {
  final Offset? point;
  final Rect? rect;
  final bool still;
  final String label;
  final String closeLabel;
  final List<List<DeskMenuItem>> Function(BuildContext menu) groups;
  final DeskReactions? reactions;
  final String? note;
  _DeskMenuRoute({
    required this.point,
    required this.rect,
    required this.still,
    required this.label,
    required this.closeLabel,
    required this.groups,
    required this.reactions,
    required this.note,
  });

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => closeLabel;

  @override
  Duration get transitionDuration =>
      still ? Duration.zero : const Duration(milliseconds: 130);

  @override
  Duration get reverseTransitionDuration =>
      still ? Duration.zero : const Duration(milliseconds: 90);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> a,
    Animation<double> b,
  ) {
    void close() {
      if (isCurrent) Navigator.of(context).pop();
    }

    return Stack(
      children: [
        // a click or a right click anywhere else: the menu goes, as a
        // computer's menus do. the barrier under it is what a reader hears
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: close,
            onSecondaryTap: close,
          ),
        ),
        CustomSingleChildLayout(
          delegate: _Place(
            point: point,
            rect: rect,
            dir: Directionality.of(context),
          ),
          child: DeskMenu(
            label: label,
            groups: groups(context),
            reactions: reactions,
            note: note,
            onClose: close,
          ),
        ),
      ],
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (still) return child;
    final c = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );
    return FadeTransition(
      opacity: c,
      child: ScaleTransition(
        scale: Tween(begin: 0.96, end: 1.0).animate(c),
        child: child,
      ),
    );
  }
}

class _Place extends SingleChildLayoutDelegate {
  final Offset? point;
  final Rect? rect;
  final TextDirection dir;
  const _Place({required this.point, required this.rect, required this.dir});

  static const pad = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) =>
      BoxConstraints.loose(
        Size(
          math.max(0, c.maxWidth - 2 * pad),
          math.max(0, c.maxHeight - 2 * pad),
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size child) => deskMenuSpot(
    area: size,
    menu: child,
    point: point,
    rect: rect,
    dir: dir,
    pad: pad,
  );

  @override
  bool shouldRelayout(_Place old) =>
      old.point != point || old.rect != rect || old.dir != dir;
}

/// the card itself: the reactions on top, the groups under them with a
/// line between, a quiet note at the end
class DeskMenu extends StatelessWidget {
  final String label;
  final List<List<DeskMenuItem>> groups;
  final DeskReactions? reactions;
  final String? note;
  final VoidCallback onClose;
  const DeskMenu({
    super.key,
    required this.label,
    required this.groups,
    required this.onClose,
    this.reactions,
    this.note,
  });

  static const width = 232.0;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final g in groups)
        if (g.isNotEmpty) g,
    ];
    final r = reactions;
    var first = true;
    bool takeFirst() {
      final f = first;
      first = false;
      return f;
    }

    final rows = <Widget>[
      if (r != null) _Reactions(r: r, onClose: onClose, first: takeFirst()),
      for (var i = 0; i < shown.length; i++) ...[
        if (i > 0 || r != null)
          Container(
            height: 0.5,
            margin: const EdgeInsets.symmetric(vertical: 4),
            color: HaloColors.line,
          ),
        for (final it in shown[i])
          _Row(item: it, onClose: onClose, first: takeFirst()),
      ],
      if (note != null)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 10, 6),
          child: Text(
            note!,
            style: HaloType.sans(
              size: 12,
              color: HaloColors.text2,
              height: 1.35,
            ),
          ),
        ),
    ];
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: label,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): onClose,
          const SingleActivator(LogicalKeyboardKey.contextMenu): onClose,
          const SingleActivator(LogicalKeyboardKey.f10, shift: true): onClose,
        },
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.arrowDown): NextFocusIntent(),
            SingleActivator(LogicalKeyboardKey.arrowUp): PreviousFocusIntent(),
            SingleActivator(LogicalKeyboardKey.arrowRight): NextFocusIntent(),
            SingleActivator(LogicalKeyboardKey.arrowLeft):
                PreviousFocusIntent(),
          },
          child: FocusScope(
            autofocus: true,
            child: FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Material(
                key: const ValueKey('desk menu'),
                color: HaloColors.surface2,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: HaloColors.line, width: 0.5),
                ),
                shadowColor: Colors.transparent,
                clipBehavior: Clip.antiAlias,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 180,
                      maxWidth: width,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(4),
                      child: IntrinsicWidth(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: rows,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// the ground under a row the mouse is on or the keys are at
Color deskMenuWash({bool danger = false}) => danger
    ? HaloColors.rose.withValues(alpha: 0.07)
    : HaloColors.text.withValues(alpha: 0.06);

/// one pickable thing: a hand and a wash under the mouse, the same wash
/// and focus under the keys, so the two never show two places
class _Pick extends StatefulWidget {
  final VoidCallback? onPick;
  final bool danger;
  final bool autofocus;
  final BorderRadius radius;
  final Widget Function(bool lit) builder;
  const _Pick({
    required this.onPick,
    required this.builder,
    this.danger = false,
    this.autofocus = false,
    this.radius = const BorderRadius.all(Radius.circular(7)),
  });

  @override
  State<_Pick> createState() => _PickState();
}

class _PickState extends State<_Pick> {
  final _node = FocusNode();
  var _lit = false;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  void _set(bool v) {
    if (v != _lit) setState(() => _lit = v);
  }

  @override
  Widget build(BuildContext context) {
    final go = widget.onPick;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return FocusableActionDetector(
      focusNode: _node,
      enabled: go != null,
      autofocus: widget.autofocus && go != null,
      mouseCursor: go == null ? MouseCursor.defer : SystemMouseCursors.click,
      onFocusChange: _set,
      onShowHoverHighlight: (v) {
        // the mouse takes the keys' place: one row lit at a time
        if (v && go != null) _node.requestFocus();
      },
      actions: {
        if (go != null)
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              go();
              return null;
            },
          ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: go,
        child: AnimatedContainer(
          duration: still ? Duration.zero : const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _lit && go != null
                ? deskMenuWash(danger: widget.danger)
                : Colors.transparent,
            borderRadius: widget.radius,
          ),
          child: widget.builder(_lit),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final DeskMenuItem item;
  final VoidCallback onClose;
  final bool first;
  const _Row({required this.item, required this.onClose, required this.first});

  @override
  Widget build(BuildContext context) {
    final it = item;
    final on = it.onTap != null;
    // words in a colour take its darker twin where the theme needs it
    final ink = it.danger
        ? HaloColors.roseText
        : on
        ? HaloColors.wordsIn(it.tint ?? HaloColors.text)
        : HaloColors.text2;
    final icon = it.danger
        ? HaloColors.rose
        : on
        ? (it.tint ?? HaloColors.text2)
        : HaloColors.text2;
    void pick() {
      HapticFeedback.selectionClick();
      if (it.closes) onClose();
      it.onTap!();
    }

    return Semantics(
      button: true,
      enabled: on,
      toggled: it.checked,
      label: it.sub == null ? it.label : '${it.label}, ${it.sub}',
      onTap: on ? pick : null,
      excludeSemantics: true,
      child: _Pick(
        onPick: on ? pick : null,
        danger: it.danger,
        autofocus: first,
        builder: (_) => Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(10, 7, 12, 7),
          child: Row(
            children: [
              Icon(it.icon, size: 16, color: icon),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      it.label,
                      style: HaloType.sans(
                        size: 13.5,
                        color: ink,
                        weight: it.danger ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                    if (it.sub != null)
                      Text(
                        it.sub!,
                        style: HaloType.sans(
                          size: 11.5,
                          color: HaloColors.text2,
                          height: 1.3,
                        ),
                      ),
                  ],
                ),
              ),
              if (it.checked != null) ...[
                const SizedBox(width: 10),
                Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: it.checked!
                      ? HaloColors.amberText
                      : Colors.transparent,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Reactions extends StatelessWidget {
  final DeskReactions r;
  final VoidCallback onClose;
  final bool first;
  const _Reactions({
    required this.r,
    required this.onClose,
    required this.first,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        key: const ValueKey('desk menu reactions'),
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < r.emojis.length; i++)
            _emoji(r.emojis[i], i == 0 && first),
        ],
      ),
    );
  }

  Widget _emoji(String e, bool autofocus) {
    final picked = e == r.selected;
    void pick() {
      HapticFeedback.selectionClick();
      onClose();
      r.onPick(e);
    }

    return Semantics(
      button: true,
      selected: picked,
      label: e,
      onTap: pick,
      excludeSemantics: true,
      child: _Pick(
        onPick: pick,
        autofocus: autofocus,
        radius: const BorderRadius.all(Radius.circular(9)),
        builder: (_) => Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: picked
              ? BoxDecoration(
                  color: HaloColors.amberSoft,
                  border: Border.all(color: HaloColors.amber, width: 1),
                  borderRadius: BorderRadius.circular(9),
                )
              : null,
          child: Text(e, style: const TextStyle(fontSize: 19)),
        ),
      ),
    );
  }
}

/// a computer: something with a menu and nothing else to do, a message,
/// reachable by tab, its menu on the menu key and shift+f10. a phone, or
/// nothing to open: the child as it is
class DeskMenuFocus extends StatelessWidget {
  final VoidCallback? onMenu;
  final BorderRadius radius;
  final Widget child;
  const DeskMenuFocus({
    super.key,
    required this.onMenu,
    required this.child,
    this.radius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  Widget build(BuildContext context) {
    if (!onDesktop || onMenu == null) return child;
    return KeyRing(
      onActivate: null,
      onMenu: onMenu,
      pointer: false,
      radius: radius,
      child: child,
    );
  }
}
