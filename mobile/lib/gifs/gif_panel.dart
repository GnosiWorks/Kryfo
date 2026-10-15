// SPDX-License-Identifier: GPL-3.0-or-later
// the gifs tab of the picker: a search field, the route it goes by, and two
// columns of results. trending while the field is empty. a tap shows which
// one, a second tap or its send chip sends it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../image_strip.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import '../theme.dart';
import '../widgets/motion.dart' show motionStill;
import '../widgets/press_scale.dart';
import '../widgets/stroke_icon.dart';
import 'gif_picture.dart';
import 'gif_source.dart';
import '../widgets/shift_tap_guard.dart';

/// how the phone reaches our server, as the transport screen names it
enum GifRoute { onion, relay, fast }

GifRoute gifRouteOf(String sendMode) => switch (sendMode) {
  'balanced' => GifRoute.relay,
  'fast' => GifRoute.fast,
  _ => GifRoute.onion,
};

const _gap = 8.0;
const _side = 16.0;
// a pause in typing before the question goes
const _debounce = Duration(milliseconds: 450);

final _searchGlyph = [svgCircle(11, 11, 7), 'M20 20l-3.5-3.5'];

class GifPanel extends StatefulWidget {
  const GifPanel({
    super.key,
    required this.source,
    required this.controller,
    required this.route,
    required this.onPick,
    this.onSearchFocus,
  });

  final GifSource source;
  // the sheet's own: the grid drags the sheet up before it scrolls
  final ScrollController controller;
  final GifRoute route;
  // the full gif's bytes, checked to be a gif
  final ValueChanged<Uint8List> onPick;
  final VoidCallback? onSearchFocus;

  @override
  State<GifPanel> createState() => GifPanelState();
}

class GifPanelState extends State<GifPanel> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  Timer? _wait;
  // bumped with every new question: an older answer is dropped
  int _gen = 0;
  String _shown = '';
  List<GifItem> _items = const [];
  String? _provider;
  String _brand = kGifBrand;
  int? _next;
  bool _loading = true;
  bool _more = false;
  bool _moreFailed = false;
  GifError _error = GifError.none;
  String? _selected;
  String? _sending;

  @visibleForTesting
  String? get selected => _selected;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scrolled);
    _focus.addListener(() {
      if (_focus.hasFocus) widget.onSearchFocus?.call();
    });
    _ask('');
  }

  @override
  void didUpdateWidget(GifPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_scrolled);
      widget.controller.addListener(_scrolled);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scrolled);
    _wait?.cancel();
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _typed(String _) {
    _wait?.cancel();
    final q = _field.text.trim();
    setState(() {});
    if (q == _shown) return;
    _wait = Timer(_debounce, () => _ask(q));
  }

  void _clear() {
    HapticFeedback.selectionClick();
    _field.clear();
    _wait?.cancel();
    setState(() {});
    if (_shown.isNotEmpty) _ask('');
  }

  Future<void> _ask(String q) async {
    final gen = ++_gen;
    setState(() {
      _shown = q;
      _loading = true;
      _error = GifError.none;
      _items = const [];
      _next = null;
      _provider = null;
      _more = false;
      _moreFailed = false;
      _selected = null;
    });
    final p = q.isEmpty
        ? await widget.source.trending()
        : await widget.source.search(q);
    if (!mounted || gen != _gen) return;
    setState(() {
      _loading = false;
      _error = p.error;
      _items = p.items;
      _next = p.next;
      if (p.error == GifError.none) {
        _provider = p.provider;
        _brand = p.brand;
      }
    });
    final sc = widget.controller;
    if (sc.hasClients && sc.position.pixels > 0) sc.jumpTo(0);
  }

  void _scrolled() {
    final sc = widget.controller;
    if (!sc.hasClients || _next == null || _more || _moreFailed) return;
    if (sc.position.extentAfter < 700) _loadMore();
  }

  Future<void> _loadMore() async {
    final next = _next;
    if (next == null || _more) return;
    final gen = _gen;
    setState(() {
      _more = true;
      _moreFailed = false;
    });
    final p = _shown.isEmpty
        ? await widget.source.trending(offset: next, provider: _provider)
        : await widget.source.search(_shown, offset: next, provider: _provider);
    if (!mounted || gen != _gen) return;
    setState(() {
      _more = false;
      if (p.error != GifError.none) {
        _moreFailed = true;
        return;
      }
      final seen = {for (final i in _items) i.id};
      _items = [
        ..._items,
        for (final i in p.items)
          if (seen.add(i.id)) i,
      ];
      _next = p.items.isEmpty ? null : p.next;
    });
  }

  void _tap(GifItem g) {
    if (_sending != null) return;
    if (_selected == g.id) {
      _send(g);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _selected = g.id);
  }

  Future<void> _send(GifItem g) async {
    if (_sending != null) return;
    HapticFeedback.lightImpact();
    setState(() => _sending = g.id);
    final b = await widget.source.bytes(g.full.url);
    if (!mounted) return;
    setState(() => _sending = null);
    if (b == null || pictureKind(b) != PictureKind.gif) {
      showHaloToast(context, l10n.gifCouldNotGet);
      return;
    }
    widget.onPick(b);
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _searchField(),
          const SizedBox(height: 8),
          _routeLine(),
          const SizedBox(height: 4),
          Expanded(child: _grid()),
          _attribution(inset > 0),
        ],
      ),
    );
  }

  Widget _searchField() {
    final hasText = _field.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _side),
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        decoration: BoxDecoration(
          color: HaloColors.surface3,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HaloColors.line),
        ),
        padding: const EdgeInsetsDirectional.only(start: 14, end: 4),
        child: Row(
          children: [
            ExcludeSemantics(
              child: StrokeIcon(
                _searchGlyph,
                size: 18,
                color: HaloColors.text2,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ShiftTapGuard(
                controller: _field,
                child: TextField(
                  controller: _field,
                  focusNode: _focus,
                  onChanged: _typed,
                  onSubmitted: (v) {
                    _wait?.cancel();
                    final q = v.trim();
                    if (q != _shown) _ask(q);
                  },
                  textInputAction: TextInputAction.search,
                  // counted in code points, as the relay counts: an emoji
                  // with a skin tone is two
                  inputFormatters: const [CodePointLimit(kGifQueryMax)],
                  // nothing typed here is learned by the keyboard
                  enableSuggestions: false,
                  autocorrect: false,
                  enableIMEPersonalizedLearning: false,
                  style: HaloType.sans(size: 15),
                  cursorColor: HaloColors.amber,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: l10n.gifSearchHint,
                    hintStyle: HaloType.sans(size: 15, color: HaloColors.text2),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: hasText ? 1 : 0,
              duration: motionStill(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 150),
              child: IgnorePointer(
                ignoring: !hasText,
                child: IconButton(
                  tooltip: l10n.gifClear,
                  onPressed: _clear,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: HaloColors.text2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _routeLine() {
    final (label, tint, icon) = switch (widget.route) {
      GifRoute.onion => (
        l10n.settingsOnion3Hops,
        HaloColors.violet,
        Icons.lock_rounded,
      ),
      GifRoute.relay => (
        l10n.settingsRelay1Hop,
        HaloColors.amber,
        Icons.swap_horiz_rounded,
      ),
      GifRoute.fast => (
        l10n.settingsFast,
        HaloColors.amber,
        Icons.bolt_rounded,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _side),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: MergeSemantics(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 12, color: tint),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        style: HaloType.mono(size: 11, color: tint, letter: 0),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                l10n.gifServiceNeverSeesYou,
                style: HaloType.sans(size: 12, color: HaloColors.text2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid() {
    final slivers = <Widget>[
      if (_shown.isEmpty && _error == GifError.none)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              _side + 2,
              10,
              _side,
              8,
            ),
            child: Semantics(
              header: true,
              child: Text(
                l10n.gifTrending,
                style: HaloType.sans(
                  size: 12.5,
                  weight: FontWeight.w600,
                  color: HaloColors.text2,
                ),
              ),
            ),
          ),
        )
      else
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
    ];
    if (_loading) {
      slivers.add(_masonry(_skeleton.length, _skeleton, (i) => _Skeleton(i)));
    } else if (_error != GifError.none && _error != GifError.refused) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: _message(switch (_error) {
            GifError.offline => l10n.gifOffline,
            GifError.busy => l10n.gifBusy,
            _ => l10n.gifUnreachable,
          }, retry: () => _ask(_shown)),
        ),
      );
    } else if (_items.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: _message(l10n.gifNothingFound),
        ),
      );
    } else {
      slivers.add(
        _masonry(_items.length, [
          for (final g in _items) g.ratio,
        ], (i) => _tile(i, _items[i])),
      );
      if (_more || _moreFailed) {
        slivers.add(SliverToBoxAdapter(child: _moreRow()));
      }
    }
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));
    return CustomScrollView(
      controller: widget.controller,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: slivers,
    );
  }

  static const _skeleton = [1.2, 0.75, 1.0, 1.3, 0.9, 1.1, 0.8, 1.25];

  Widget _masonry(int n, List<double> ratios, Widget Function(int) build) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: _side),
      sliver: SliverGrid(
        gridDelegate: MasonryDelegate(ratios, _gap),
        delegate: SliverChildBuilderDelegate((_, i) => build(i), childCount: n),
      ),
    );
  }

  Widget _tile(int i, GifItem g) {
    return _GifTile(
      key: ValueKey(g.id),
      item: g,
      index: i,
      source: widget.source,
      selected: _selected == g.id,
      sending: _sending == g.id,
      onTap: () => _tap(g),
      onSend: () => _send(g),
    );
  }

  Widget _moreRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Center(
        child: _moreFailed
            ? PressScale(
                label: l10n.commonTryAgain,
                onTap: _loadMore,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '${l10n.gifCouldNotLoadMore} · ${l10n.commonTryAgain}',
                    textAlign: TextAlign.center,
                    style: HaloType.sans(size: 13, color: HaloColors.amber),
                  ),
                ),
              )
            : SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: HaloColors.amber,
                  value: motionStill(context) ? 0.7 : null,
                  semanticsLabel: l10n.gifLoading,
                ),
              ),
      ),
    );
  }

  Widget _message(String text, {VoidCallback? retry}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: HaloType.sans(size: 14, color: HaloColors.text2),
          ),
          if (retry != null) ...[
            const SizedBox(height: 14),
            PressScale(
              label: l10n.commonTryAgain,
              onTap: retry,
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
          ],
        ],
      ),
    );
  }

  // the provider's name as its terms ask, and under it that it never sees
  // who searched. small, so the keyboard leaves the grid room
  Widget _attribution(bool keyboard) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: HaloColors.line)),
      ),
      padding: EdgeInsets.fromLTRB(
        _side,
        8,
        _side,
        8 + (keyboard ? 0 : MediaQuery.paddingOf(context).bottom),
      ),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.gifPoweredBy(_brand),
              style: HaloType.sans(
                size: 12,
                weight: FontWeight.w600,
                color: HaloColors.text,
                height: 1.3,
              ),
            ),
            Text(
              l10n.gifNeverSeesYou(_brand),
              style: HaloType.sans(
                size: 11.5,
                color: HaloColors.text2,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// two columns, each tile in the shorter one. the tops only ever grow, so
/// the first and last tile at an offset are found by a walk
class MasonryDelegate extends SliverGridDelegate {
  MasonryDelegate(this.ratios, this.gap);
  final List<double> ratios;
  final double gap;

  @override
  SliverGridLayout getLayout(SliverConstraints c) {
    final w = ((c.crossAxisExtent - gap) / 2).clamp(1.0, double.infinity);
    final reversed = axisDirectionIsReversed(c.crossAxisDirection);
    final tops = <double>[], heights = <double>[], xs = <double>[];
    final col = [0.0, 0.0];
    for (final r in ratios) {
      final i = col[0] <= col[1] ? 0 : 1;
      final h = w * r;
      tops.add(col[i]);
      heights.add(h);
      final x = i * (w + gap);
      xs.add(reversed ? c.crossAxisExtent - w - x : x);
      col[i] += h + gap;
    }
    return _MasonryLayout(tops, heights, xs, w);
  }

  @override
  bool shouldRelayout(MasonryDelegate old) =>
      old.gap != gap ||
      old.ratios.length != ratios.length ||
      !_same(old.ratios, ratios);

  static bool _same(List<double> a, List<double> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _MasonryLayout extends SliverGridLayout {
  const _MasonryLayout(this.tops, this.heights, this.xs, this.w);
  final List<double> tops, heights, xs;
  final double w;

  @override
  int getMinChildIndexForScrollOffset(double offset) {
    for (var i = 0; i < tops.length; i++) {
      if (tops[i] + heights[i] > offset) return i;
    }
    return tops.isEmpty ? 0 : tops.length - 1;
  }

  @override
  int getMaxChildIndexForScrollOffset(double offset) {
    var last = 0;
    for (var i = 0; i < tops.length; i++) {
      if (tops[i] >= offset) break;
      last = i;
    }
    return last;
  }

  @override
  SliverGridGeometry getGeometryForChildIndex(int i) {
    if (i >= tops.length) {
      return SliverGridGeometry(
        scrollOffset: tops.isEmpty ? 0 : tops.last,
        crossAxisOffset: 0,
        mainAxisExtent: 0,
        crossAxisExtent: w,
      );
    }
    return SliverGridGeometry(
      scrollOffset: tops[i],
      crossAxisOffset: xs[i],
      mainAxisExtent: heights[i],
      crossAxisExtent: w,
    );
  }

  @override
  double computeMaxScrollOffset(int childCount) {
    var end = 0.0;
    for (var i = 0; i < childCount && i < tops.length; i++) {
      final b = tops[i] + heights[i];
      if (b > end) end = b;
    }
    return end;
  }
}

class _Skeleton extends StatefulWidget {
  const _Skeleton(this.i);
  final int i;

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionStill(context)) {
      _pulse.value = 0.5;
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.value = (widget.i * 0.13) % 1;
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: Tween(begin: 0.45, end: 1.0).animate(_pulse),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: HaloColors.surface3,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _GifTile extends StatefulWidget {
  const _GifTile({
    super.key,
    required this.item,
    required this.index,
    required this.source,
    required this.selected,
    required this.sending,
    required this.onTap,
    required this.onSend,
  });

  final GifItem item;
  final int index;
  final GifSource source;
  final bool selected;
  final bool sending;
  final VoidCallback onTap;
  final VoidCallback onSend;

  @override
  State<_GifTile> createState() => _GifTileState();
}

class _GifTileState extends State<_GifTile> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await widget.source.bytes(widget.item.preview.url);
    if (!mounted) return;
    setState(() {
      _bytes = b;
      _failed = b == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final time = still ? Duration.zero : const Duration(milliseconds: 180);
    final b = _bytes;
    final px =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context) /
                2)
            .round();
    final Widget picture;
    if (b != null && still) {
      picture = StillFrame(id: widget.item.id, load: () async => b, width: px);
    } else if (b != null) {
      picture = Image.memory(
        b,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        cacheWidth: px,
        errorBuilder: (_, _, _) => _broken(),
      );
    } else if (_failed) {
      picture = _broken();
    } else {
      picture = const SizedBox.expand();
    }
    return Semantics(
      button: true,
      selected: widget.selected,
      label: l10n.gifTileA11y(whole(widget.index + 1)),
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: widget.selected && !still ? 0.97 : 1,
          duration: time,
          curve: Curves.easeOutCubic,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ColoredBox(
                  color: HaloColors.surface3,
                  child: AnimatedOpacity(
                    opacity: b == null && !_failed ? 0 : 1,
                    duration: time,
                    child: ExcludeSemantics(child: picture),
                  ),
                ),
              ),
              IgnorePointer(
                child: AnimatedContainer(
                  duration: time,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: widget.selected
                          ? HaloColors.amber
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                end: 6,
                bottom: 6,
                child: AnimatedSwitcher(
                  duration: time,
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.8, end: 1.0).animate(a),
                      child: c,
                    ),
                  ),
                  child: widget.selected
                      ? _SendChip(
                          key: const ValueKey('send'),
                          sending: widget.sending,
                          onTap: widget.onSend,
                        )
                      : const SizedBox.shrink(key: ValueKey('none')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _broken() => Center(
    child: Icon(
      Icons.image_not_supported_outlined,
      size: 20,
      color: HaloColors.text2,
    ),
  );
}

class _SendChip extends StatelessWidget {
  const _SendChip({super.key, required this.sending, required this.onTap});
  final bool sending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      label: l10n.commonSend,
      onTap: sending ? null : onTap,
      haptic: false,
      scale: 0.92,
      child: Container(
        constraints: const BoxConstraints(minHeight: 32, minWidth: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: HaloColors.amber,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sending) ...[
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: HaloColors.onAmber,
                  value: motionStill(context) ? 0.7 : null,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              l10n.commonSend,
              style: HaloType.sans(
                size: 12.5,
                weight: FontWeight.w600,
                color: HaloColors.onAmber,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// the on this phone tab: gifs saved here, picked through the system picker
class GifPhonePanel extends StatelessWidget {
  const GifPhonePanel({
    super.key,
    required this.controller,
    required this.onChoose,
  });
  final ScrollController controller;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: HaloColors.amberSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.gif_box_outlined,
              color: HaloColors.amber,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          l10n.gifPhoneLine,
          textAlign: TextAlign.center,
          style: HaloType.sans(size: 14, color: HaloColors.text2),
        ),
        const SizedBox(height: 18),
        Center(
          child: PressScale(
            label: l10n.gifPhoneChoose,
            onTap: onChoose,
            child: Container(
              constraints: const BoxConstraints(minHeight: 46),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: HaloColors.amber,
                borderRadius: BorderRadius.circular(13),
              ),
              child: ExcludeSemantics(
                child: Text(
                  l10n.gifPhoneChoose,
                  textAlign: TextAlign.center,
                  style: HaloType.sans(
                    size: 14,
                    weight: FontWeight.w600,
                    color: HaloColors.onAmber,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// a field's text kept to [max] code points; what is typed past it is not
/// taken. a pair of surrogates is never split
class CodePointLimit extends TextInputFormatter {
  const CodePointLimit(this.max);
  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.runes.length <= max) return newValue;
    if (oldValue.text.runes.length <= max) {
      // a paste that would go past: keep what fits of it
      final cut = String.fromCharCodes(newValue.text.runes.take(max));
      return TextEditingValue(
        text: cut,
        selection: TextSelection.collapsed(offset: cut.length),
      );
    }
    return oldValue;
  }
}
