// SPDX-License-Identifier: GPL-3.0-or-later
// the favourites tab of the picker: the gifs kept on this phone, two
// across. a tap shows which, a second tap or its send chip sends it. hold
// one to edit: a cross on each to remove it, hold and drag to reorder.
// works with gif search off: nothing here goes to the network
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import '../picture_lock.dart' show picturesShut;
import '../theme.dart';
import '../widgets/motion.dart' show motionStill;
import '../widgets/press_scale.dart';
import '../widgets/say.dart' show sayOnce;
import 'gif_favs.dart';
import 'gif_panel.dart' show GifSendChip;
import 'gif_picture.dart';

const _side = 16.0;
const _gap = 6.0;
// tile height over width, as the approved board draws them
const _shape = 0.72;

class GifFavPanel extends StatefulWidget {
  const GifFavPanel({
    super.key,
    required this.store,
    required this.initial,
    required this.controller,
    required this.onPick,
  });

  final GifFavStore store;
  final List<GifFav> initial;
  // the sheet's own: the grid drags the sheet up before it scrolls
  final ScrollController controller;
  final ValueChanged<Uint8List> onPick;

  @override
  State<GifFavPanel> createState() => GifFavPanelState();
}

class GifFavPanelState extends State<GifFavPanel> {
  late List<GifFav> _order = List.of(widget.initial);
  bool _editing = false;
  GifFav? _selected;
  GifFav? _sending;
  // the order changed by a drag, written when it ends
  bool _moved = false;

  @visibleForTesting
  bool get editing => _editing;
  @visibleForTesting
  List<GifFav> get order => _order;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final now = await widget.store.load();
      if (mounted && !_editing) setState(() => _order = now);
    } catch (_) {
      // what came with the sheet stays
    }
  }

  void _tap(GifFav f) {
    if (_editing || _sending != null) return;
    if (_selected == f) {
      _send(f);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _selected = f);
  }

  Future<void> _send(GifFav f) async {
    if (_sending != null) return;
    HapticFeedback.lightImpact();
    setState(() => _sending = f);
    Uint8List? b;
    try {
      b = await File(f.path).readAsBytes();
    } catch (_) {
      b = null;
    }
    if (!mounted) return;
    setState(() => _sending = null);
    if (b == null || b.isEmpty) {
      showHaloToast(context, l10n.gifCouldNotGet);
      return;
    }
    widget.onPick(b);
  }

  void _edit() {
    if (_editing || _order.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _editing = true;
      _selected = null;
    });
  }

  Future<void> _done() async {
    HapticFeedback.selectionClick();
    setState(() => _editing = false);
    await _keepOrder();
  }

  Future<void> _keepOrder() async {
    if (!_moved) return;
    _moved = false;
    try {
      await widget.store.reorder(_order);
    } catch (_) {
      // the next open shows the order kept before
    }
  }

  Future<void> _remove(GifFav f) async {
    HapticFeedback.lightImpact();
    setState(() {
      _order = [..._order]..remove(f);
      if (_order.isEmpty) _editing = false;
    });
    sayOnce(context, l10n.gifFavRemoved);
    try {
      await widget.store.remove(f);
    } catch (_) {
      // a row left behind is let go on the next load, its file with it
    }
  }

  // the dragged one takes the place of [over]
  void _moveOnto(GifFav dragged, GifFav over) {
    final from = _order.indexOf(dragged);
    final to = _order.indexOf(over);
    if (from < 0 || to < 0 || from == to) return;
    HapticFeedback.selectionClick();
    setState(() {
      _order = [..._order]
        ..removeAt(from)
        ..insert(to, dragged);
      _moved = true;
    });
  }

  void _step(GifFav f, int by) {
    final i = _order.indexOf(f);
    final j = i + by;
    if (i < 0 || j < 0 || j >= _order.length) return;
    _moveOnto(f, _order[j]);
    _keepOrder();
  }

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return Column(
      children: [
        Expanded(
          child: _order.isEmpty
              ? _empty()
              : ListView(
                  controller: widget.controller,
                  padding: const EdgeInsets.only(top: 6, bottom: 16),
                  children: [
                    if (still)
                      _editing ? _editHead() : const SizedBox.shrink()
                    else
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: _editing ? _editHead() : const SizedBox.shrink(),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: _side),
                      child: LayoutBuilder(
                        builder: (_, c) => _grid(c.maxWidth),
                      ),
                    ),
                  ],
                ),
        ),
        _footer(),
      ],
    );
  }

  Widget _editHead() {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(_side + 2, 0, 6, 6),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                l10n.gifFavEditTitle,
                style: HaloType.sans(
                  size: 15,
                  weight: FontWeight.w600,
                  color: HaloColors.text,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: _done,
            style: TextButton.styleFrom(
              foregroundColor: HaloColors.amberText,
              minimumSize: const Size(48, 44),
            ),
            child: Text(
              l10n.commonDone,
              style: HaloType.sans(
                size: 14,
                weight: FontWeight.w600,
                color: HaloColors.amberText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(double width) {
    final w = ((width - _gap) / 2).floorToDouble();
    final h = (w * _shape).roundToDouble();
    final rows = (_order.length + 1) ~/ 2;
    final time = motionStill(context)
        ? Duration.zero
        : const Duration(milliseconds: 240);
    return SizedBox(
      height: rows * h + (rows - 1) * _gap,
      child: Stack(
        children: [
          for (final (i, f) in _order.indexed)
            AnimatedPositionedDirectional(
              key: ValueKey(f.id),
              duration: time,
              curve: Curves.easeOutCubic,
              start: (i % 2) * (w + _gap),
              top: (i ~/ 2) * (h + _gap),
              width: w,
              height: h,
              child: _slot(i, f, w, h),
            ),
        ],
      ),
    );
  }

  Widget _slot(int i, GifFav f, double w, double h) {
    final tile = _FavTile(
      fav: f,
      selected: _selected == f,
      sending: _sending == f,
      editing: _editing,
      onSend: () => _send(f),
      onRemove: () => _remove(f),
    );
    final actions = <CustomSemanticsAction, VoidCallback>{
      if (!_editing) CustomSemanticsAction(label: l10n.gifFavEdit): _edit,
      if (_editing && i > 0)
        CustomSemanticsAction(label: l10n.gifFavMoveEarlier): () =>
            _step(f, -1),
      if (_editing && i < _order.length - 1)
        CustomSemanticsAction(label: l10n.gifFavMoveLater): () => _step(f, 1),
      if (_editing)
        CustomSemanticsAction(label: l10n.gifFavRemove): () => _remove(f),
    };
    final shown = Semantics(
      button: !_editing,
      selected: _selected == f,
      label: l10n.gifFavTileA11y(whole(i + 1)),
      onTap: _editing ? null : () => _tap(f),
      customSemanticsActions: actions,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _tap(f),
        onLongPress: _editing ? null : _edit,
        // a computer's right click edits, as a hold does
        onSecondaryTap: _edit,
        child: tile,
      ),
    );
    if (!_editing) return shown;
    return DragTarget<GifFav>(
      onWillAcceptWithDetails: (d) {
        _moveOnto(d.data, f);
        return true;
      },
      builder: (_, _, _) => LongPressDraggable<GifFav>(
        data: f,
        delay: const Duration(milliseconds: 160),
        hapticFeedbackOnStart: true,
        onDragEnd: (_) => _keepOrder(),
        feedback: Material(
          type: MaterialType.transparency,
          child: SizedBox(
            width: w,
            height: h,
            child: Transform.scale(
              scale: motionStill(context) ? 1 : 1.05,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _FavTile(fav: f, editing: false),
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.25, child: tile),
        child: shown,
      ),
    );
  }

  Widget _empty() {
    return ListView(
      controller: widget.controller,
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
            child: Icon(Icons.star_rounded, color: HaloColors.amber, size: 28),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          l10n.gifFavEmptyTitle,
          textAlign: TextAlign.center,
          style: HaloType.sans(
            size: 15,
            weight: FontWeight.w600,
            color: HaloColors.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.gifFavEmptyLine,
          textAlign: TextAlign.center,
          style: HaloType.sans(size: 14, color: HaloColors.text),
        ),
      ],
    );
  }

  // the line under the grid: where they are kept, or how to edit
  Widget _footer() {
    final still = motionStill(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: HaloColors.line)),
      ),
      padding: EdgeInsets.fromLTRB(
        _side,
        9,
        _side,
        9 + MediaQuery.paddingOf(context).bottom,
      ),
      child: AnimatedSwitcher(
        duration: still ? Duration.zero : const Duration(milliseconds: 180),
        child: _editing
            ? Text(
                l10n.gifFavEditHint,
                key: const ValueKey('hint'),
                style: HaloType.sans(size: 12, color: HaloColors.text),
              )
            : MergeSemantics(
                key: const ValueKey('kept'),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 15,
                      color: HaloColors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.gifFavKeptShown,
                        style: HaloType.sans(size: 12, color: HaloColors.text),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _FavTile extends StatelessWidget {
  const _FavTile({
    required this.fav,
    required this.editing,
    this.selected = false,
    this.sending = false,
    this.onSend,
    this.onRemove,
  });

  final GifFav fav;
  final bool editing;
  final bool selected;
  final bool sending;
  final VoidCallback? onSend;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final time = still ? Duration.zero : const Duration(milliseconds: 180);
    final px =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context) /
                2)
            .round();
    return AnimatedScale(
      scale: (selected || editing) && !still ? 0.96 : 1,
      duration: time,
      curve: Curves.easeOutCubic,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: HaloColors.surface3,
              child: ValueListenableBuilder<bool>(
                valueListenable: picturesShut,
                builder: (_, shut, _) => shut
                    ? const SizedBox.expand()
                    : ExcludeSemantics(
                        child: still
                            ? StillFrame(
                                id: fav.path,
                                width: px,
                                load: () => File(fav.path).readAsBytes(),
                              )
                            : Image(
                                image: ResizeImage.resizeIfNeeded(
                                  px,
                                  null,
                                  FileImage(File(fav.path)),
                                ),
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                errorBuilder: (_, _, _) => Center(
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 20,
                                    color: HaloColors.text2,
                                  ),
                                ),
                              ),
                      ),
              ),
            ),
          ),
          const PositionedDirectional(start: 8, bottom: 6, child: GifBadge()),
          IgnorePointer(
            child: AnimatedContainer(
              duration: time,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? HaloColors.amber : Colors.transparent,
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
              child: selected && onSend != null
                  ? GifSendChip(
                      key: const ValueKey('send'),
                      sending: sending,
                      onTap: onSend!,
                    )
                  : const SizedBox.shrink(key: ValueKey('none')),
            ),
          ),
          PositionedDirectional(
            end: -6,
            top: -6,
            child: AnimatedScale(
              scale: editing ? 1 : 0,
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: ExcludeSemantics(
                child: PressScale(
                  onTap: editing ? onRemove : null,
                  haptic: false,
                  scale: 0.88,
                  child: SizedBox.square(
                    dimension: 44,
                    child: Center(
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: HaloColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: HaloColors.line2),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.close_rounded,
                          size: 15,
                          color: HaloColors.text,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// the star that pops on a gif as it is kept, then goes
class StarPop extends StatefulWidget {
  const StarPop({super.key});

  @override
  State<StarPop> createState() => _StarPopState();
}

class _StarPopState extends State<StarPop> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) {
            final t = _c.value;
            final grow = still
                ? 1.0
                : Curves.easeOutBack.transform((t / 0.4).clamp(0.0, 1.0));
            final fade = t < 0.65 ? 1.0 : 1 - (t - 0.65) / 0.35;
            return Opacity(
              opacity: fade.clamp(0.0, 1.0),
              child: Transform.scale(scale: 0.5 + 0.5 * grow, child: child),
            );
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.star_rounded, color: HaloColors.amber, size: 28),
          ),
        ),
      ),
    );
  }
}
