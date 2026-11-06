// SPDX-License-Identifier: GPL-3.0-or-later
// the desktop's home: on a wide window a rail of tabs, the list beside it
// and the chat pane, with a divider between list and pane that drags; on a
// narrow one the phone's single page, the pane over the list. the pane
// keeps its pages when the window crosses from one to the other
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../back_on_top.dart';
import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/empty_chat.dart';
import '../widgets/motion.dart' show motionStill;
import '../widgets/nav_bar.dart';
import '../widgets/text_ground.dart';
import 'wide_pane.dart';

/// a window this wide turns wide, and only under [kWideLeave] turns back:
/// a resize around one width never flickers between the two
const kWideEnter = 900.0;
const kWideLeave = 840.0;

const kRailWidth = 76.0;
const kListMin = 320.0;
const kListMax = 520.0;
// a little over telegram's and whatsapp's: at 1280 the chat keeps 740
const kListStart = 460.0;
// the least the pane keeps beside the list
const kPaneMin = 380.0;

const _widthKey = 'wide_list_width';

/// wide or not at [width], having been [was] until now
bool wideAt(double width, {required bool was}) =>
    width >= (was ? kWideLeave : kWideEnter);

/// the list's width in a window [width] wide, from the one asked for
double listWidthIn(double width, double asked) {
  final most = math.max(
    kListMin,
    math.min(kListMax, width - kRailWidth - kPaneMin),
  );
  return asked.clamp(kListMin, most);
}

class WideHome extends StatefulWidget {
  final HaloTab tab;
  final ValueChanged<HaloTab> onPick;
  final VoidCallback? onMeLongPress;
  // the tabs' pages, one shown
  final Widget tabs;
  // the phone's bar, for a narrow window
  final Widget bar;
  final VoidCallback onSearch;
  // ctrl+n and ctrl+comma, as signal and telegram have them
  final VoidCallback? onAdd;
  final VoidCallback? onSettings;
  const WideHome({
    super.key,
    required this.tab,
    required this.onPick,
    this.onMeLongPress,
    required this.tabs,
    required this.bar,
    required this.onSearch,
    this.onAdd,
    this.onSettings,
  });

  @override
  State<WideHome> createState() => _WideHomeState();
}

class _WideHomeState extends State<WideHome> {
  final _pane = WidePane();
  // the list and the pane move between the two layouts with their state
  final _listKey = GlobalKey(debugLabel: 'wide list');
  final _paneKey = GlobalKey(debugLabel: 'wide pane');
  late final Widget _paneView = KeyedSubtree(
    key: _paneKey,
    child: _PaneNavigator(pane: _pane),
  );
  bool _wide = false;
  // a drag moves only the row, never rebuilds what is in it
  final _asked = ValueNotifier<double>(kListStart);

  @override
  void initState() {
    super.initState();
    widePane = _pane;
    watchOf = _watch;
    // no mark from another session's chat
    wideOnScreen.value = null;
    _loadWidth();
  }

  RouteWatch _watch(Route<dynamic> r) {
    if (r.navigator != null && r.navigator == _pane.nav) {
      return (pages: _pane.pages, stack: _pane.stack, host: _pane.host);
    }
    return (pages: pageRoutes, stack: routeStack, host: null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pane.host = ModalRoute.of(context);
  }

  @override
  void dispose() {
    // a new session's home may be up already
    if (identical(widePane, _pane)) {
      widePane = null;
      resetWatchOf();
      wideNow.value = false;
    }
    wideOnScreen.value = null;
    _pane.dispose();
    _asked.dispose();
    super.dispose();
  }

  Future<void> _loadWidth() async {
    try {
      final p = await SharedPreferences.getInstance();
      final w = p.getDouble(_widthKey);
      if (w != null && mounted) _asked.value = w;
    } catch (_) {
      // the start's width then
    }
  }

  Future<void> _saveWidth() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble(_widthKey, _asked.value);
    } catch (_) {}
  }

  void _setWide(bool v) {
    _wide = v;
    if (wideNow.value == v) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _wide == v) wideNow.value = v;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pane = _paneView;
    final list = KeyedSubtree(key: _listKey, child: widget.tabs);
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): _BackIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, control: true): _FindIntent(),
        SingleActivator(LogicalKeyboardKey.keyN, control: true): _AddIntent(),
        SingleActivator(LogicalKeyboardKey.comma, control: true):
            _SettingsIntent(),
      },
      child: Actions(
        actions: {
          _BackIntent: _BackAction(_pane),
          // the open chat's own search first
          _FindIntent: CallbackAction<_FindIntent>(
            onInvoke: (_) {
              if (!_pane.find()) widget.onSearch();
              return null;
            },
          ),
          _AddIntent: CallbackAction<_AddIntent>(
            onInvoke: (_) {
              widget.onAdd?.call();
              return null;
            },
          ),
          _SettingsIntent: CallbackAction<_SettingsIntent>(
            onInvoke: (_) {
              widget.onSettings?.call();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: HaloColors.surface,
            body: LayoutBuilder(
              builder: (context, box) {
                final wide = wideAt(box.maxWidth, was: _wide);
                _setWide(wide);
                return wide
                    ? _wideLayout(context, box, list, pane)
                    : _narrowLayout(list, pane);
              },
            ),
          ),
        ),
      ),
    );
  }

  // the phone's page: the list and its bar, the pane over them while it
  // shows a page
  Widget _narrowLayout(Widget list, Widget pane) {
    return ValueListenableBuilder<int>(
      valueListenable: _pane.depth,
      builder: (_, depth, _) {
        final covered = depth > 0;
        return Stack(
          children: [
            Positioned.fill(
              child: ExcludeFocus(
                excluding: covered,
                child: ExcludeSemantics(
                  excluding: covered,
                  child: IgnorePointer(
                    ignoring: covered,
                    child: Column(
                      children: [
                        Expanded(child: list),
                        widget.bar,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(ignoring: !covered, child: pane),
            ),
          ],
        );
      },
    );
  }

  Widget _wideLayout(
    BuildContext context,
    BoxConstraints box,
    Widget list,
    Widget pane,
  ) {
    final mq = MediaQuery.of(context);
    final rail = FocusTraversalGroup(
      child: WideRail(
        tab: widget.tab,
        onPick: widget.onPick,
        onMeLongPress: widget.onMeLongPress,
      ),
    );
    final side = Expanded(child: FocusTraversalGroup(child: pane));
    return ValueListenableBuilder<double>(
      valueListenable: _asked,
      builder: (context, asked, _) {
        final w = listWidthIn(box.maxWidth, asked);
        return _wideRow(box, mq, w, rail, list, side);
      },
    );
  }

  Widget _wideRow(
    BoxConstraints box,
    MediaQueryData mq,
    double w,
    Widget rail,
    Widget list,
    Widget side,
  ) {
    return Stack(
      children: [
        Row(
          children: [
            rail,
            // the whole height: a row centres a child it leaves loose, and a
            // short tab (tools) would sit in the middle of the list
            SizedBox(
              width: w,
              height: box.maxHeight,
              child: FocusTraversalGroup(
                child: MediaQuery(
                  data: mq.copyWith(size: Size(w, box.maxHeight)),
                  child: list,
                ),
              ),
            ),
            Container(width: 1, color: HaloColors.line),
            side,
          ],
        ),
        PositionedDirectional(
          start: kRailWidth + w - 5,
          top: 0,
          bottom: 0,
          width: 11,
          child: ListDivider(
            width: w,
            fit: (v) => listWidthIn(box.maxWidth, v),
            onWidth: (v) => _asked.value = listWidthIn(box.maxWidth, v),
            onDone: _saveWidth,
          ),
        ),
      ],
    );
  }
}

// the pane's navigator, the size of its own box: what it shows reads the
// pane's width, not the window's
class _PaneNavigator extends StatefulWidget {
  final WidePane pane;
  const _PaneNavigator({required this.pane});

  @override
  State<_PaneNavigator> createState() => _PaneNavigatorState();
}

class _PaneNavigatorState extends State<_PaneNavigator> {
  // the same navigator widget each time: a new one makes every page in it
  // build again, at each move of the divider
  late final Widget _nav = HeroControllerScope(
    controller: widget.pane.heroes,
    child: Navigator(
      key: widget.pane.key,
      observers: widget.pane.observers,
      onGenerateInitialRoutes: (_, _) => [
        PageRouteBuilder<void>(
          opaque: false,
          pageBuilder: (_, _, _) => const TextGround(child: WideEmpty()),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      // its own node: a page's barrier would block the list's semantics
      builder: (context, box) => Semantics(
        container: true,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(size: box.biggest),
          child: _nav,
        ),
      ),
    );
  }
}

/// the pane with nothing open: a calm word on a wide window, nothing on a
/// narrow one, where the list shows through
class WideEmpty extends StatelessWidget {
  const WideEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: wideNow,
      builder: (_, wide, _) => !wide
          ? const SizedBox.expand()
          : ColoredBox(
              color: HaloColors.surface,
              child: Semantics(
                container: true,
                child: EmptyChat(
                  icon: Icons.forum_outlined,
                  title: l10n.wideSelectChat,
                  line: l10n.wideSelectChatLine,
                ),
              ),
            ),
    );
  }
}

/// the tabs down the window's edge, the phone's bar turned on its side
class WideRail extends StatelessWidget {
  final HaloTab tab;
  final ValueChanged<HaloTab> onPick;
  final VoidCallback? onMeLongPress;
  const WideRail({
    super.key,
    required this.tab,
    required this.onPick,
    this.onMeLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: kRailWidth,
      decoration: BoxDecoration(
        color: HaloColors.surface,
        border: BorderDirectional(
          end: BorderSide(color: HaloColors.line, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              for (final t in shownTabs)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Tooltip(
                    message: navTabLabel(t),
                    excludeFromSemantics: true,
                    waitDuration: const Duration(milliseconds: 500),
                    child: SizedBox(
                      width: kRailWidth - 8,
                      child: NavTab(
                        tab: t,
                        on: t == tab,
                        onTap: () => onPick(t),
                        onLongPress: t == HaloTab.me ? onMeLongPress : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepIntent extends Intent {
  final int by;
  const _StepIntent(this.by);
}

class _BackIntent extends Intent {
  const _BackIntent();
}

class _FindIntent extends Intent {
  const _FindIntent();
}

class _AddIntent extends Intent {
  const _AddIntent();
}

class _SettingsIntent extends Intent {
  const _SettingsIntent();
}

// esc closes the pane's page, and only while it shows one: else the key
// is left to whoever else wants it
class _BackAction extends Action<_BackIntent> {
  _BackAction(this.pane);
  final WidePane pane;

  @override
  bool isEnabled(_BackIntent intent) => pane.depth.value > 0;

  @override
  Object? invoke(_BackIntent intent) => pane.back();
}

/// the line between list and pane: dragged, or moved with the arrow keys,
/// it sets the list's width. a double click puts it back
class ListDivider extends StatefulWidget {
  final double width;
  // the width the window allows for one asked for
  final double Function(double) fit;
  final ValueChanged<double> onWidth;
  final VoidCallback onDone;
  const ListDivider({
    super.key,
    required this.width,
    required this.fit,
    required this.onWidth,
    required this.onDone,
  });

  @override
  State<ListDivider> createState() => _ListDividerState();
}

class _ListDividerState extends State<ListDivider> {
  bool _hover = false;
  bool _ring = false;
  bool _drag = false;
  double _at = 0;

  // towards the pane is wider, whichever side the pane is on
  double get _dir => Directionality.of(context) == TextDirection.rtl ? -1 : 1;

  void _step(int by) {
    widget.onWidth(widget.width + 16 * by);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final lit = _hover || _ring || _drag;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      container: true,
      label: l10n.wideListWidth,
      slider: true,
      value: '${widget.width.round()}',
      increasedValue: '${widget.fit(widget.width + 16).round()}',
      decreasedValue: '${widget.fit(widget.width - 16).round()}',
      onIncrease: () => _step(1),
      onDecrease: () => _step(-1),
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.resizeColumn,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _ring = v),
        includeFocusSemantics: false,
        shortcuts: {
          SingleActivator(LogicalKeyboardKey.arrowRight): _StepIntent(
            rtl ? -1 : 1,
          ),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _StepIntent(
            rtl ? 1 : -1,
          ),
        },
        actions: {
          _StepIntent: CallbackAction<_StepIntent>(
            onInvoke: (i) => _step(i.by),
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // the line moves from the press on, no jump past the slop
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragStart: (_) => setState(() {
            _drag = true;
            _at = widget.width;
          }),
          onHorizontalDragUpdate: (d) {
            _at += d.delta.dx * _dir;
            widget.onWidth(_at);
          },
          onHorizontalDragEnd: (_) {
            setState(() => _drag = false);
            widget.onDone();
          },
          onHorizontalDragCancel: () => setState(() => _drag = false),
          onDoubleTap: () {
            widget.onWidth(kListStart);
            widget.onDone();
          },
          child: Center(
            child: AnimatedContainer(
              duration: motionStill(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: lit ? 3 : 1,
              decoration: BoxDecoration(
                color: lit
                    ? HaloColors.amber.withValues(alpha: _drag ? 0.9 : 0.6)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// the open chat's row: a raised ground and a bar of the accent at its
/// start, as telegram and whatsapp desktop mark it. the ground steps up
/// from the list's in both themes and the words keep their contrast on
/// it; the bar is the accent's own tone for words, 4.5:1 on every ground
Color wideMarkGround() => HaloColors.surface3;

Color wideMarkBar() => HaloColors.amberText;

/// a row of the list with the mark of the chat open in the pane
class WideMark extends StatelessWidget {
  final String id;
  final Widget child;
  const WideMark({super.key, required this.id, required this.child});

  @override
  Widget build(BuildContext context) {
    if (widePane == null) return child;
    return ListenableBuilder(
      listenable: Listenable.merge([wideOnScreen, wideNow]),
      builder: (context, child) {
        final on = wideNow.value && wideOnScreen.value == id;
        return Semantics(
          selected: on,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: on ? 1 : 0,
                  duration: motionStill(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: Container(
                    key: const ValueKey('wide-mark'),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: wideMarkGround(),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: wideMarkBar(),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              child!,
            ],
          ),
        );
      },
      child: child,
    );
  }
}
