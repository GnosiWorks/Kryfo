// SPDX-License-Identifier: GPL-3.0-or-later
// the sticker picker: a house sheet with a tab per set (recent, then each
// pack), a grid that plays a few at a time, and a long press that shows one
// big, sliding from sticker to sticker while the finger stays down.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../container.dart';
import '../dlog.dart';
import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/menu_backdrop.dart';
import '../widgets/motion.dart' show houseSpring;
import '../widgets/press_scale.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/stroke_icon.dart';
import 'sticker_pack.dart';
import 'sticker_recents.dart';
import 'sticker_view.dart';

// a sticker: a rounded square with its corner peeled, and a smile
const stickerGlyph = [
  'M13 20H8a4 4 0 0 1-4-4V8a4 4 0 0 1 4-4h8a4 4 0 0 1 4 4v5',
  'M20 13l-7 7',
  'M20 13h-3.5a3.5 3.5 0 0 0-3.5 3.5V20',
  'M8.6 12.4c1.3 1.3 3.4 1.4 4.8.3',
  'M9.4 9.1v.01',
  'M14.4 9.1v.01',
];

// a clock: the recent tab
final _clockGlyph = [svgCircle(12, 12, 8), 'M12 8v4l2.6 2.2'];

const _holdFor = Duration(milliseconds: 320);
const _gridSlots = 6;
// a sticker in the picker plays this many loops, as in a chat, then rests
// on its still. every opening of the sheet plays them fresh
const kStickerPickLoops = 3;
const _gap = 6.0;
const _side = 12.0;
const _headerHeight = 40.0;

/// the button inside a composer's field that opens the sheet
class StickerButton extends StatelessWidget {
  const StickerButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      label: l10n.stickerOpen,
      onTap: onTap,
      scale: 0.86,
      // the sheet clicks as it opens
      haptic: false,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: StrokeIcon(stickerGlyph, size: 22, color: HaloColors.text2),
        ),
      ),
    );
  }
}

/// what the picker hands back: the sticker, and where it was drawn when it
/// was picked, so it can fly from there to its bubble
class StickerPick {
  const StickerPick(this.ref, {this.from = Rect.zero, this.at = -1});
  final StickerRef ref;
  // global rect of the drawn sticker; empty when it could not be found
  final Rect from;
  // ms into its loop at that moment; -1 when it showed its still
  final double at;
}

/// opens the picker. the pick comes back with the recents already updated;
/// sending it is the caller's.
Future<StickerPick?> showStickerSheet(
  BuildContext context, {
  required HaloContainer container,
}) {
  HapticFeedback.selectionClick();
  FocusScope.of(context).unfocus();
  return showHaloSheet<StickerPick>(
    context,
    scroll: true,
    builder: (_) => StickerSheet(recents: StickerRecents(container)),
  );
}

class StickerSheet extends StatefulWidget {
  const StickerSheet({super.key, required this.recents, this.library});
  final StickerRecents recents;
  // for tests: packs already in hand
  final StickerLibrary? library;

  @override
  State<StickerSheet> createState() => StickerSheetState();
}

class StickerSheetState extends State<StickerSheet>
    with TickerProviderStateMixin {
  StickerLibrary? _lib;
  List<StickerRef> _recent = const [];
  bool _ready = false;
  bool _failed = false;
  bool _routeDone = false;
  Animation<double>? _route;
  final _budget = StickerBudget(_gridSlots);
  final _keys = <String, GlobalKey>{};
  ScrollController? _scroll;
  bool _jumping = false;
  int _tab = 0;
  // where each section starts in the grid, one per tab
  List<double> _starts = const [];

  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final AnimationController _pill = AnimationController.unbounded(
    vsync: this,
  );

  OverlayEntry? _previewEntry;
  final _previewKey = GlobalKey<_StickerPreviewState>();
  _Shown? _shown;

  bool get _reduce => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  bool get previewOpen => _previewEntry != null;

  @visibleForTesting
  List<StickerRef> get recent => _recent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final a = ModalRoute.of(context)?.animation;
    if (a != _route) {
      _route?.removeStatusListener(_routeStatus);
      _route = a;
      _routeDone = a == null || a.status == AnimationStatus.completed;
      a?.addStatusListener(_routeStatus);
    }
  }

  // stickers start only once the sheet is up, so the rise stays light
  void _routeStatus(AnimationStatus s) {
    final done = s == AnimationStatus.completed;
    if (done != _routeDone && mounted) setState(() => _routeDone = done);
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final lib = widget.library ?? await StickerLibrary.load();
      var recent = <StickerRef>[];
      try {
        recent = await widget.recents.load();
      } catch (e) {
        dlog('sticker recents: $e');
      }
      if (!mounted) return;
      setState(() {
        _lib = lib;
        _recent = _known(lib, recent);
        _ready = true;
        _tab = 0;
      });
      _pill.value = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_reduce) {
          _in.value = 1;
        } else {
          _in.forward(from: 0);
        }
      });
    } catch (e) {
      dlog('sticker pack: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  // recents from any pack that can draw them and offers them
  List<StickerRef> _known(StickerLibrary lib, List<StickerRef> list) => [
    for (final r in list)
      if ((lib.pack(r.pack)?.offered.contains(r.id) ?? false) &&
          lib.sticker(r) != null)
        r,
  ];

  // the grid's sections in order, the same as the tabs: recent, then each
  // pack with something to offer
  List<_Section> _sections() {
    final lib = _lib;
    if (lib == null) return const [];
    return [
      if (_recent.isNotEmpty)
        _Section(null, [
          for (final r in _recent)
            if (lib.sticker(r) case final s?) ('r:${r.key}', r, s),
        ]),
      for (final p in lib.packs)
        _Section(p, [
          for (final id in p.offered)
            if (p.sticker(id) case final s?)
              ('p:${p.name}:$id', StickerRef(p.name, id), s),
        ]),
    ]..removeWhere((s) => s.items.isEmpty);
  }

  @override
  void dispose() {
    _route?.removeStatusListener(_routeStatus);
    _scroll?.removeListener(_scrolled);
    _previewEntry?.remove();
    _previewEntry = null;
    _in.dispose();
    _pill.dispose();
    super.dispose();
  }

  // ---- tabs

  void _moveTab(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    if (_reduce) {
      _pill.value = i.toDouble();
    } else {
      _pill
          .animateWith(houseSpring(_pill.value, i.toDouble(), _pill.velocity))
          .whenCompleteOrCancel(() {
            if (mounted && _tab == i) _pill.value = i.toDouble();
          });
    }
  }

  Future<void> _tapTab(int i) async {
    HapticFeedback.selectionClick();
    _moveTab(i);
    final sc = _scroll;
    if (sc == null || !sc.hasClients || i >= _starts.length) return;
    final to = math.min(_starts[i], sc.position.maxScrollExtent);
    _jumping = true;
    try {
      if (_reduce) {
        sc.jumpTo(to);
      } else {
        await sc.animateTo(
          to,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    } finally {
      _jumping = false;
    }
  }

  void _scrolled() {
    final sc = _scroll;
    if (_jumping || sc == null || !sc.hasClients || _starts.length < 2) return;
    // the last section whose start has scrolled up to the top; one that
    // cannot get there counts once the end is reached
    final max = sc.position.maxScrollExtent;
    var tab = 0;
    for (var i = 1; i < _starts.length; i++) {
      final edge = math.min(_starts[i], max) - 1;
      if (edge > 0 && sc.offset >= edge) tab = i;
    }
    _moveTab(tab);
  }

  // ---- picking

  // a cell tap names its cell; send in the preview names none
  void _pick(StickerRef ref, {String? cell}) {
    HapticFeedback.lightImpact();
    final drawn = _drawn(
      cell == null ? _previewKey.currentContext : _keys[cell]?.currentContext,
      _lib?.sticker(ref),
    );
    final pick = StickerPick(
      ref,
      from: drawn == null
          ? Rect.zero
          : drawn.localToGlobal(Offset.zero) & drawn.size,
      at: drawn?.time ?? -1.0,
    );
    _closePreviewNow();
    unawaited(
      widget.recents.add(ref).catchError((Object e) {
        dlog('sticker recents: $e');
        return <StickerRef>[];
      }),
    );
    if (mounted) Navigator.of(context).pop(pick);
  }

  // the sticker as drawn under [c], found in its render tree
  RenderSticker? _drawn(BuildContext? c, Sticker? s) {
    if (s == null) return null;
    RenderSticker? found;
    void visit(RenderObject o) {
      if (found != null) return;
      if (o is RenderSticker && identical(o.sticker, s)) {
        found = o;
        return;
      }
      o.visitChildren(visit);
    }

    final root = c?.findRenderObject();
    if (root != null) visit(root);
    final box = found;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box;
  }

  Future<void> _removeRecent(StickerRef ref) async {
    HapticFeedback.selectionClick();
    _previewKey.currentState?.close();
    try {
      final now = await widget.recents.remove(ref);
      if (mounted && _lib != null) {
        final had = _recent.isNotEmpty;
        setState(() => _recent = _known(_lib!, now));
        // the recent tab went: the rest move up one
        if (had && _recent.isEmpty) {
          _tab = math.max(0, _tab - 1);
          _pill.value = _tab.toDouble();
        }
      }
    } catch (e) {
      dlog('sticker recents: $e');
    }
  }

  // ---- the preview

  Rect? _cellRect(String key) {
    final box = _keys[key]?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _openPreview(_Shown s, {required bool held}) {
    if (_previewEntry != null) return;
    HapticFeedback.mediumImpact();
    _shown = s;
    final from = _cellRect(s.key) ?? Rect.zero;
    _previewEntry = OverlayEntry(
      builder: (_) => _StickerPreview(
        key: _previewKey,
        shown: s,
        from: from,
        held: held,
        onSend: () => _pick(_shown!.ref),
        onRemove: () => _removeRecent(_shown!.ref),
        onClose: () => _previewKey.currentState?.close(),
        rectOf: () => _cellRect(_shown!.key),
        onGone: _previewGone,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_previewEntry!);
    setState(() {});
  }

  void _slide(Offset global) {
    final cur = _shown;
    if (_previewEntry == null || cur == null) return;
    for (final e in _keys.entries) {
      if (e.key == cur.key) continue;
      final r = _cellRect(e.key);
      if (r == null || !r.contains(global)) continue;
      final s = _shownFor(e.key);
      if (s == null) return;
      HapticFeedback.selectionClick();
      _shown = s;
      _previewKey.currentState?.swap(s);
      return;
    }
  }

  void _lift() => _previewKey.currentState?.settle();

  void _previewGone() {
    _previewEntry?.remove();
    _previewEntry = null;
    _shown = null;
    if (mounted) setState(() {});
  }

  void _closePreviewNow() {
    if (_previewEntry == null) return;
    _previewEntry!.remove();
    _previewEntry = null;
    _shown = null;
  }

  _Shown? _shownFor(String key) {
    final ref = StickerRef.parse(key.substring(2));
    final s = ref == null ? null : _lib?.sticker(ref);
    if (s == null) return null;
    return _Shown(key, ref!, s, key.startsWith('r:'));
  }

  // ---- building

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // back closes the preview first
      canPop: _previewEntry == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _previewKey.currentState?.close();
      },
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.92,
        builder: (context, controller) {
          if (!identical(controller, _scroll)) {
            _scroll?.removeListener(_scrolled);
            _scroll = controller..addListener(_scrolled);
          }
          final sections = _ready ? _sections() : const <_Section>[];
          return Column(
            children: [
              const SheetHandle(),
              if (_ready) _tabs(sections),
              Expanded(child: _body(controller, sections)),
            ],
          );
        },
      ),
    );
  }

  Widget _tabs(List<_Section> sections) {
    const size = 36.0, step = 44.0;
    Widget tab(int i, String label, Widget icon) => Semantics(
      button: true,
      selected: _tab == i,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _tapTab(i),
        child: SizedBox(
          width: step,
          height: 44,
          child: Center(child: ExcludeSemantics(child: icon)),
        ),
      ),
    );
    return SizedBox(
      height: 44,
      child: Stack(
        children: [
          // the pill slides behind the tab in view
          AnimatedBuilder(
            animation: _pill,
            builder: (_, _) => PositionedDirectional(
              start: _side + (step - size) / 2 + _pill.value * step,
              top: 4,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: HaloColors.amberSoft,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          PositionedDirectional(
            start: _side,
            top: 0,
            child: Row(
              children: [
                for (final (i, sec) in sections.indexed)
                  if (sec.pack case final p?)
                    // a pack is its first sticker's still
                    tab(
                      i,
                      p.title,
                      StickerView(
                        sticker: sec.items[0].$3,
                        size: 28,
                        play: false,
                      ),
                    )
                  else
                    tab(
                      i,
                      l10n.stickerRecent,
                      StrokeIcon(
                        _clockGlyph,
                        size: 21,
                        color: _tab == i ? HaloColors.amber : HaloColors.text2,
                      ),
                    ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(height: 0.5, color: HaloColors.line),
          ),
        ],
      ),
    );
  }

  Widget _body(ScrollController controller, List<_Section> sections) {
    if (_failed) {
      return ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
        children: [
          Text(
            l10n.stickerCouldNotLoad,
            textAlign: TextAlign.center,
            style: HaloType.sans(size: 14, color: HaloColors.text2),
          ),
          const SizedBox(height: 16),
          Center(
            child: PressScale(
              label: l10n.commonTryAgain,
              onTap: _load,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: HaloColors.surface3,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  l10n.commonTryAgain,
                  style: HaloType.sans(size: 13.5, color: HaloColors.text),
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (!_ready) {
      // the pack loads in a few ms: an empty sheet, then the grid pops in
      return ListView(controller: controller);
    }
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth < 400 ? 4 : 5;
        final cell = (box.maxWidth - 2 * _side - (cols - 1) * _gap) / cols;
        // each section is its header and its rows: where the tabs scroll to
        final starts = <double>[];
        var at = 0.0;
        for (final sec in sections) {
          starts.add(at);
          final rows = (sec.items.length + cols - 1) ~/ cols;
          at += _headerHeight + rows * cell + math.max(0, rows - 1) * _gap;
        }
        _starts = starts;
        var n = 0;
        Widget grid(List<(String, StickerRef, Sticker)> items, int section) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: _side),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: _gap,
                crossAxisSpacing: _gap,
              ),
              delegate: SliverChildListDelegate([
                for (final (i, (key, ref, s)) in items.indexed)
                  _pop(n++, _cell(key, ref, s, section * 1000 + i, cell)),
              ]),
            ),
          );
        }

        return TickerMode(
          enabled: _routeDone && _previewEntry == null,
          child: CustomScrollView(
            controller: controller,
            slivers: [
              for (final (i, sec) in sections.indexed) ...[
                _header(sec.pack?.title ?? l10n.stickerRecent),
                grid(sec.items, i),
              ],
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 16 + MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(String text) => SliverToBoxAdapter(
    child: SizedBox(
      height: _headerHeight,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(_side + 4, 14, 16, 0),
        child: Semantics(
          header: true,
          child: Text(
            text,
            style: HaloType.sans(
              size: 12.5,
              weight: FontWeight.w600,
              color: HaloColors.text2,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _cell(String key, StickerRef ref, Sticker s, int order, double cell) {
    final gk = _keys.putIfAbsent(key, GlobalKey.new);
    final shown = _Shown(key, ref, s, key[0] == 'r');
    return _Cell(
      key: gk,
      sticker: s,
      size: cell - 12,
      order: order,
      budget: _budget,
      label: l10n.stickerA11y(s.emoji),
      onTap: () => _pick(shown.ref, cell: key),
      onHold: () => _openPreview(shown, held: true),
      onHoldForReader: () => _openPreview(shown, held: false),
      onSlide: _slide,
      onLift: _lift,
    );
  }

  // the first screenful pops in, one after another, like the attach grid
  Widget _pop(int i, Widget child) {
    if (i > 15) return child;
    final start = (i * 0.07).clamp(0.0, 0.5);
    final curve = Interval(start, start + 0.5, curve: Curves.easeOutBack);
    final fade = Interval(start, start + 0.4, curve: Curves.easeOut);
    return AnimatedBuilder(
      animation: _in,
      builder: (_, c) {
        final v = curve.transform(_in.value);
        return Opacity(
          opacity: fade.transform(_in.value),
          child: Transform.scale(scale: 0.82 + 0.18 * v, child: c),
        );
      },
      child: child,
    );
  }
}

// one run of the grid under its header: recent (no pack), or a pack. an
// item is its cell's key, the sticker's ref and the sticker
class _Section {
  const _Section(this.pack, this.items);
  final StickerPack? pack;
  final List<(String, StickerRef, Sticker)> items;
}

// what the preview shows: which cell, which sticker
class _Shown {
  final String key;
  final StickerRef ref;
  final Sticker sticker;
  final bool recent;
  const _Shown(this.key, this.ref, this.sticker, this.recent);
}

class _Cell extends StatefulWidget {
  const _Cell({
    super.key,
    required this.sticker,
    required this.size,
    required this.order,
    required this.budget,
    required this.label,
    required this.onTap,
    required this.onHold,
    required this.onHoldForReader,
    required this.onSlide,
    required this.onLift,
  });

  final Sticker sticker;
  final double size;
  final int order;
  final StickerBudget budget;
  final String label;
  final VoidCallback onTap;
  final VoidCallback onHold;
  final VoidCallback onHoldForReader;
  final void Function(Offset global) onSlide;
  final VoidCallback onLift;

  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends State<_Cell> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sticker;
    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onTap,
      onLongPress: widget.onHoldForReader,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          TapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                TapGestureRecognizer.new,
                (t) => t
                  ..onTapDown = ((_) => _set(true))
                  ..onTapUp = ((_) => _set(false))
                  ..onTapCancel = (() => _set(false))
                  ..onTap = widget.onTap,
              ),
          // a shorter hold than flutter's 500 ms, which feels slow here
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(duration: _holdFor),
                (r) => r
                  ..onLongPressStart = ((_) {
                    _set(false);
                    widget.onHold();
                  })
                  ..onLongPressMoveUpdate = ((d) =>
                      widget.onSlide(d.globalPosition))
                  ..onLongPressEnd = ((_) => widget.onLift())
                  ..onLongPressCancel = (() => _set(false)),
              ),
        },
        child: ExcludeSemantics(
          child: AnimatedScale(
            scale: _down ? 0.9 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Center(
              child: StickerView(
                sticker: s,
                size: widget.size,
                fps: 30,
                budget: widget.budget,
                order: widget.order,
                loops: kStickerPickLoops,
                delay: s.loopMs == 0
                    ? 0
                    : (widget.order % 1000) * 370 % s.loopMs,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StickerPreview extends StatefulWidget {
  const _StickerPreview({
    super.key,
    required this.shown,
    required this.from,
    required this.held,
    required this.onSend,
    required this.onRemove,
    required this.onClose,
    required this.rectOf,
    required this.onGone,
  });

  final _Shown shown;
  final Rect from;
  // the finger is still down: no pills yet, sliding swaps
  final bool held;
  final VoidCallback onSend;
  final VoidCallback onRemove;
  final VoidCallback onClose;
  final Rect? Function() rectOf;
  final VoidCallback onGone;

  @override
  State<_StickerPreview> createState() => _StickerPreviewState();
}

class _StickerPreviewState extends State<_StickerPreview>
    with TickerProviderStateMixin {
  late _Shown _shown = widget.shown;
  late Rect _from = widget.from;
  late bool _settled = !widget.held;
  bool _closing = false;
  // a tap on the big one plays it again once it rests
  int _replay = 0;

  // 0 at the cell, 1 in the middle; the spring overshoots a little
  late final AnimationController _grow = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _dim = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 200),
  );
  late final AnimationController _pills = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  bool get _reduce => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_reduce || _from.isEmpty) {
        _grow.value = 1;
        _dim.value = 0;
        _dim.animateTo(1, duration: const Duration(milliseconds: 150));
      } else {
        _grow.animateWith(houseSpring(0, 1)).whenCompleteOrCancel(() {
          if (mounted && !_closing) _grow.value = 1;
        });
      }
      if (_settled) _pills.forward();
    });
  }

  @override
  void dispose() {
    _grow.dispose();
    _dim.dispose();
    _pills.dispose();
    super.dispose();
  }

  void swap(_Shown s) {
    if (_closing) return;
    setState(() {
      _shown = s;
      _from = widget.rectOf() ?? _from;
    });
  }

  void _again() {
    HapticFeedback.selectionClick();
    setState(() => _replay++);
  }

  void settle() {
    if (_settled || _closing) return;
    setState(() => _settled = true);
    _pills.forward();
  }

  // back into its cell, and the page comes back
  Future<void> close() async {
    if (_closing) return;
    setState(() => _closing = true);
    _from = widget.rectOf() ?? _from;
    unawaited(_pills.reverse());
    if (_reduce || _from.isEmpty) {
      await _dim.animateTo(0, duration: const Duration(milliseconds: 150));
    } else {
      unawaited(_dim.animateTo(0, duration: const Duration(milliseconds: 220)));
      await _grow.animateWith(houseSpring(_grow.value, 0, _grow.velocity));
    }
    widget.onGone();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width, h = mq.size.height;
    final side = math.min(240.0, w * 0.62);
    final target = Rect.fromCenter(
      center: Offset(w / 2, h * 0.44),
      width: side,
      height: side,
    );
    final swapTime = _reduce
        ? Duration.zero
        : const Duration(milliseconds: 120);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _settled ? widget.onClose : null,
            child: FadeTransition(opacity: _dim, child: const MenuBackdrop()),
          ),
        ),
        AnimatedBuilder(
          animation: _grow,
          builder: (_, child) {
            final t = _grow.value;
            final r = Rect.lerp(_from, target, t)!;
            final k = r.width / side;
            return Positioned.fromRect(
              rect: target,
              child: Opacity(
                // the cell's own copy is under it, so a fade only at the
                // very end of the way back
                opacity: _closing ? t.clamp(0.0, 0.2) / 0.2 : 1,
                child: Transform(
                  transform: Matrix4.identity()
                    ..translateByDouble(
                      r.center.dx - target.center.dx,
                      r.center.dy - target.center.dy,
                      0,
                      1,
                    )
                    ..scaleByDouble(k, k, 1, 1),
                  alignment: Alignment.center,
                  child: child,
                ),
              ),
            );
          },
          child: AnimatedSwitcher(
            duration: swapTime,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(
                scale: Tween(begin: 0.85, end: 1.0).animate(a),
                child: c,
              ),
            ),
            child: GestureDetector(
              key: ValueKey(_shown.key),
              onTap: _settled && !_closing ? _again : null,
              child: StickerView(
                sticker: _shown.sticker,
                size: side,
                loops: kStickerPickLoops,
                replay: _replay,
                label: l10n.stickerA11y(_shown.sticker.emoji),
              ),
            ),
          ),
        ),
        // the buttons come once the finger is off the glass
        if (_settled)
          Positioned(
            left: 16,
            right: 16,
            top: target.bottom + 22,
            child: FadeTransition(
              opacity: _pills,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.25), end: Offset.zero)
                    .animate(
                      CurvedAnimation(parent: _pills, curve: Curves.easeOut),
                    ),
                child: IgnorePointer(
                  ignoring: !_settled || _closing,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _pill(
                        l10n.commonSend,
                        HaloColors.amber,
                        HaloColors.onAmber,
                        widget.onSend,
                      ),
                      if (_shown.recent)
                        _pill(
                          l10n.stickerRemoveRecent,
                          HaloColors.surface3,
                          HaloColors.text,
                          widget.onRemove,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _pill(String text, Color bg, Color fg, VoidCallback onTap) {
    return PressScale(
      label: text,
      onTap: onTap,
      haptic: false,
      scale: 0.92,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          text,
          style: HaloType.sans(size: 14, weight: FontWeight.w600, color: fg),
        ),
      ),
    );
  }
}
