// SPDX-License-Identifier: GPL-3.0-or-later
// a pdf read inside kryfo: its pages one under the other, pinched or
// buttoned in and out, a pill that says where you are, small pages to jump
// by, and a search where the phone reads the words (android 15 and later).
// pages are drawn by the phone's own renderer into memory only, and the
// lock closes the document and drops every page (pdf_pages.dart)
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../file_kind.dart';
import '../file_save.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart' show percent, whole;
import '../pdf_pages.dart';
import '../picture_lock.dart' show picturesShut;
import '../theme.dart';
import 'file_actions.dart';
import 'ease_size.dart';
import 'file_viewer_parts.dart';
import 'media_bubbles.dart' show humanFileSize;
import 'motion.dart' show kHouseCurve, motionStill;

Future<void> openPdfFile(
  BuildContext context, {
  required String path,
  required String? name,
  required FileFacts facts,
  bool kept = false,
  String? from,
  Object? heroTag,
  int? size,
}) => openFileViewer(
  context,
  secure: kept,
  (_) => PdfViewer(
    path: path,
    name: name,
    facts: facts,
    kept: kept,
    from: from,
    heroTag: heroTag,
    size: size,
  ),
);

const _gap = 12.0;
const _side = 12.0;
const _most = 5.0;

class PdfViewer extends StatefulWidget {
  final String path;
  final String? name;
  final FileFacts facts;
  final bool kept;
  final String? from;
  final Object? heroTag;
  final int? size;
  const PdfViewer({
    super.key,
    required this.path,
    required this.name,
    required this.facts,
    this.kept = false,
    this.from,
    this.heroTag,
    this.size,
  });

  @override
  State<PdfViewer> createState() => PdfViewerState();
}

class PdfViewerState extends State<PdfViewer>
    with SingleTickerProviderStateMixin {
  PdfDoc? _doc;
  PdfTrouble? _trouble;
  final _zoom = TransformationController();
  late final AnimationController _ease = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  Animation<Matrix4>? _to;

  // pages drawn, by page and how sharp: the newest few kept
  final Map<(int, int), ui.Image> _drawn = {};
  final List<(int, int)> _order = [];
  final Set<(int, int)> _asked = {};
  Future<void> _queue = Future.value();
  // the pages in view and next to it, so the queue skips what scrolled away
  Set<int> _near = {};
  int _page = 0;
  bool _pill = false;
  Timer? _pillOff;

  // the viewport and the pages laid out in it
  Size _view = Size.zero;
  List<double> _tops = const [];
  List<double> _heights = const [];
  double _total = 0;

  // the search
  bool _finding = false;
  final _words = TextEditingController();
  List<int>? _hits;
  int _hit = 0;

  @visibleForTesting
  int get page => _page;
  @visibleForTesting
  double get scale => _zoom.value.getMaxScaleOnAxis();
  @visibleForTesting
  int get pagesKept => _drawn.length;

  @override
  void initState() {
    super.initState();
    picturesShut.addListener(_lock);
    _ease.addListener(() {
      final to = _to;
      if (to != null) _zoom.value = to.value;
    });
    _zoom.addListener(_moved);
    _open();
  }

  @override
  void dispose() {
    picturesShut.removeListener(_lock);
    _pillOff?.cancel();
    _zoom.dispose();
    _ease.dispose();
    _words.dispose();
    _drop();
    unawaited(_doc?.close());
    super.dispose();
  }

  Future<void> _open() async {
    try {
      final d = await PdfDoc.open(widget.path);
      if (!mounted) {
        await d.close();
        return;
      }
      setState(() {
        _doc = d;
        _trouble = null;
      });
    } on PdfOpenFailed catch (e) {
      if (mounted && !picturesShut.value) setState(() => _trouble = e.why);
    }
  }

  // the lock: the document closes and its pages go; after it, it opens
  // again where it was
  void _lock() {
    if (picturesShut.value) {
      _drop();
      final d = _doc;
      _doc = null;
      unawaited(d?.close());
      if (mounted) setState(() {});
    } else if (mounted && _doc == null) {
      _open();
    }
  }

  void _drop() {
    for (final i in _drawn.values) {
      i.dispose();
    }
    _drawn.clear();
    _order.clear();
    _asked.clear();
  }

  // ---- layout

  void _layout(Size view) {
    final d = _doc;
    if (d == null || view == _view && _tops.length == d.pages) return;
    _view = view;
    final w = view.width - _side * 2;
    final tops = <double>[];
    final hs = <double>[];
    var y = _gap;
    for (final s in d.sizes) {
      final h = s.width <= 0 ? w * 1.414 : w * s.height / s.width;
      tops.add(y);
      hs.add(h);
      y += h + _gap;
    }
    _tops = tops;
    _heights = hs;
    _total = math.max(y, view.height);
  }

  int _pageAt(double y) {
    for (var i = _tops.length - 1; i >= 0; i--) {
      if (y >= _tops[i] - _gap / 2) return i;
    }
    return 0;
  }

  // where the view is in the pages' own space
  Rect _seen() {
    final inv = Matrix4.inverted(_zoom.value);
    final a = MatrixUtils.transformPoint(inv, Offset.zero);
    final b = MatrixUtils.transformPoint(
      inv,
      Offset(_view.width, _view.height),
    );
    return Rect.fromPoints(a, b);
  }

  void _moved() {
    if (_tops.isEmpty) return;
    final seen = _seen();
    final p = _pageAt(seen.center.dy);
    if (p != _page || !_pill) {
      setState(() {
        _page = p;
        _pill = true;
      });
    }
    _pillOff?.cancel();
    _pillOff = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _pill = false);
    });
  }

  // ---- pages

  int _sharp(double scale) => scale > 2.6
      ? 3
      : scale > 1.6
      ? 2
      : 1;

  ui.Image? _imageFor(int page, int sharp) {
    final exact = _drawn[(page, sharp)];
    if (exact != null) return exact;
    _ask(page, sharp);
    // a softer one while the sharper one is drawn
    for (var s = 3; s >= 0; s--) {
      final i = _drawn[(page, s)];
      if (i != null) return i;
    }
    return null;
  }

  void _ask(int page, int sharp) {
    final key = (page, sharp);
    if (_asked.contains(key) || _drawn.containsKey(key)) return;
    _asked.add(key);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final width = sharp == 0
        ? (64 * dpr).round()
        : ((_view.width - _side * 2) * dpr * sharp).round();
    _queue = _queue.then((_) async {
      final d = _doc;
      if (!mounted || d == null || d.closed) {
        _asked.remove(key);
        return;
      }
      // scrolled away before its turn
      if (sharp > 0 && !_near.contains(page)) {
        _asked.remove(key);
        return;
      }
      final img = await d.page(page, width);
      _asked.remove(key);
      if (img == null) return;
      if (!mounted || _doc != d) {
        img.dispose();
        return;
      }
      setState(() {
        _drawn[key] = img;
        _order.remove(key);
        _order.add(key);
        // the oldest pages go: the thumbnails count less
        while (_order.length > 18) {
          final old = _order.removeAt(0);
          _drawn.remove(old)?.dispose();
        }
      });
    });
  }

  // ---- zoom and jumps

  void _zoomTo(Matrix4 m) {
    if (motionStill(context)) {
      _zoom.value = m;
      return;
    }
    _to = Matrix4Tween(
      begin: _zoom.value,
      end: m,
    ).animate(CurvedAnimation(parent: _ease, curve: kHouseCurve));
    _ease.forward(from: 0);
  }

  /// the zoom times [k], about the middle of the view
  void zoomBy(double k) {
    final now = scale;
    final want = (now * k).clamp(1.0, _most);
    if ((want - now).abs() < 0.01) return;
    HapticFeedback.selectionClick();
    final c = Offset(_view.width / 2, _view.height / 2);
    final inv = Matrix4.inverted(_zoom.value);
    final at = MatrixUtils.transformPoint(inv, c);
    final m = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(want, want, 1, 1)
      ..translateByDouble(-at.dx, -at.dy, 0, 1);
    _zoomTo(_clamped(m));
  }

  // kept inside the pages: no grey beyond the first or the last
  Matrix4 _clamped(Matrix4 m) {
    final s = m.getMaxScaleOnAxis();
    final t = m.getTranslation();
    final minX = _view.width - _view.width * s;
    final minY = _view.height - _total * s;
    final x = t.x.clamp(math.min(minX, 0.0), 0.0).toDouble();
    final y = t.y.clamp(math.min(minY, 0.0), 0.0).toDouble();
    return Matrix4.identity()
      ..translateByDouble(x, y, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  /// page [i] to the top of the view, at the zoom it has
  void jumpTo(int i) {
    if (i < 0 || i >= _tops.length) return;
    final s = scale;
    final t = _zoom.value.getTranslation();
    final m = Matrix4.identity()
      ..translateByDouble(t.x, -(_tops[i] - _gap) * s, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
    _zoomTo(_clamped(m));
  }

  Offset? _tapAt;
  void _doubleTap() {
    if (scale > 1.05) {
      _zoomTo(
        _clamped(
          Matrix4.identity()..translateByDouble(
            0,
            _zoom.value.getTranslation().y / scale,
            0,
            1,
          ),
        ),
      );
      return;
    }
    final c = _tapAt ?? Offset(_view.width / 2, _view.height / 2);
    final at = MatrixUtils.transformPoint(Matrix4.inverted(_zoom.value), c);
    final m = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(2.2, 2.2, 1, 1)
      ..translateByDouble(-at.dx, -at.dy, 0, 1);
    _zoomTo(_clamped(m));
  }

  // ---- search

  Future<void> _find() async {
    final d = _doc;
    if (d == null) return;
    final hits = await d.find(_words.text);
    if (!mounted) return;
    setState(() {
      _hits = hits;
      _hit = 0;
    });
    if (hits.isNotEmpty) jumpTo(hits.first);
  }

  void _step(int by) {
    final h = _hits;
    if (h == null || h.isEmpty) return;
    setState(() => _hit = (_hit + by) % h.length);
    jumpTo(h[_hit]);
  }

  // ---- build

  @override
  Widget build(BuildContext context) {
    final facts = widget.facts;
    final shown = safeFileName(widget.name, facts: facts);
    final d = _doc;
    final sub = [
      if (widget.from != null) l10n.fileFrom(widget.from!),
      if (widget.size != null) humanFileSize(widget.size!),
      if (d != null) l10n.filePages(d.pages, whole(d.pages)),
    ].join(' · ');
    final kept = widget.kept;
    return ColoredBox(
      color: HaloColors.ink,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            FileViewerHead(
              shown: shown,
              facts: facts,
              sub: sub,
              heroTag: widget.heroTag,
              actions: [
                if (d?.canFind ?? false)
                  ViewerIconButton(
                    icon: Icons.search_rounded,
                    label: l10n.fileSearchIn,
                    on: _finding,
                    onTap: () => setState(() {
                      _finding = !_finding;
                      if (!_finding) _hits = null;
                    }),
                  ),
              ],
            ),
            EaseSize(
              duration: const Duration(milliseconds: 220),
              child: _finding
                  ? _findRow()
                  : const SizedBox(width: double.infinity),
            ),
            Expanded(child: _body(context)),
            if (d != null && d.pages > 1) _thumbs(d),
            FileViewerBar(
              onForward: canForwardFile(widget.path, widget.name, kept: kept)
                  ? () => forwardFile(context, widget.path, widget.name)
                  : null,
              onSave: kept
                  ? null
                  : () => saveReceivedFile(context, widget.path, widget.name),
              onOpenWith: kept
                  ? null
                  : () => openFileOutside(context, widget.path, widget.name),
            ),
          ],
        ),
      ),
    );
  }

  Widget _findRow() {
    final h = _hits;
    final line = h == null
        ? null
        : h.isEmpty
        ? l10n.chatNoMatches
        : l10n.filePageOf(whole(h[_hit] + 1), whole(_doc?.pages ?? 0));
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 8, 8),
      color: HaloColors.surface,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _words,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _find(),
              style: HaloType.sans(size: 14.5, color: HaloColors.text),
              cursorColor: HaloColors.amber,
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.fileSearchHint,
                hintStyle: HaloType.sans(size: 14.5, color: HaloColors.text2),
                border: InputBorder.none,
              ),
            ),
          ),
          if (line != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: Text(
                line,
                style: HaloType.mono(size: 11, color: HaloColors.text),
              ),
            ),
          ViewerIconButton(
            icon: Icons.keyboard_arrow_up_rounded,
            label: l10n.chatPreviousMatch,
            onTap: (h?.length ?? 0) > 1 ? () => _step(-1) : null,
          ),
          const SizedBox(width: 4),
          ViewerIconButton(
            icon: Icons.keyboard_arrow_down_rounded,
            label: l10n.chatNextMatch,
            onTap: (h?.length ?? 0) > 1 ? () => _step(1) : null,
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final t = _trouble;
    if (t != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                t == PdfTrouble.locked
                    ? Icons.lock_outline_rounded
                    : Icons.description_outlined,
                size: 34,
                color: HaloColors.amber,
              ),
              const SizedBox(height: 12),
              Text(
                t == PdfTrouble.locked
                    ? l10n.filePdfLocked
                    : l10n.filePdfUnreadable,
                textAlign: TextAlign.center,
                style: HaloType.sans(size: 14, color: HaloColors.text),
              ),
            ],
          ),
        ),
      );
    }
    final d = _doc;
    if (d == null) return const SizedBox.expand();
    return LayoutBuilder(
      builder: (context, box) {
        _layout(box.biggest);
        final s = scale;
        final sharp = _sharp(s);
        return Stack(
          children: [
            GestureDetector(
              onDoubleTapDown: (e) => _tapAt = e.localPosition,
              onDoubleTap: _doubleTap,
              child: InteractiveViewer.builder(
                transformationController: _zoom,
                minScale: 1,
                maxScale: _most,
                boundaryMargin: EdgeInsets.zero,
                onInteractionEnd: (_) => setState(() {}),
                builder: (context, q) {
                  final top = math.min(
                    math.min(q.point0.y, q.point1.y),
                    math.min(q.point2.y, q.point3.y),
                  );
                  final bottom = math.max(
                    math.max(q.point0.y, q.point1.y),
                    math.max(q.point2.y, q.point3.y),
                  );
                  final pad = box.maxHeight;
                  final near = <int>{};
                  for (var i = 0; i < _tops.length; i++) {
                    if (_tops[i] + _heights[i] >= top - pad &&
                        _tops[i] <= bottom + pad) {
                      near.add(i);
                    }
                  }
                  _near = near;
                  return SizedBox(
                    width: box.maxWidth,
                    height: _total,
                    child: Stack(
                      children: [
                        for (final i in near)
                          Positioned(
                            left: _side,
                            top: _tops[i],
                            width: box.maxWidth - _side * 2,
                            height: _heights[i],
                            child: _PageTile(
                              index: i,
                              image: _imageFor(i, sharp),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // where you are, while you move
            PositionedDirectional(
              top: 10,
              start: 0,
              end: 0,
              child: IgnorePointer(
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _pill ? 1 : 0,
                    duration: still
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    child: _Pill(
                      l10n.filePageOf(whole(_page + 1), whole(d.pages)),
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              bottom: 12,
              start: 0,
              end: 0,
              child: Center(child: _zoomBar(s)),
            ),
          ],
        );
      },
    );
  }

  bool get still => motionStill(context);

  Widget _zoomBar(double s) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: HaloColors.surface2,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: HaloColors.line),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ViewerIconButton(
          icon: Icons.remove_rounded,
          label: l10n.fileZoomOut,
          onTap: s > 1.01 ? () => zoomBy(1 / 1.25) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            percent(s),
            style: HaloType.mono(size: 12, color: HaloColors.text),
          ),
        ),
        ViewerIconButton(
          icon: Icons.add_rounded,
          label: l10n.fileZoomIn,
          onTap: s < _most - 0.01 ? () => zoomBy(1.25) : null,
        ),
      ],
    ),
  );

  Widget _thumbs(PdfDoc d) => Container(
    height: 76,
    color: HaloColors.surface,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      itemCount: d.pages,
      itemBuilder: (_, i) {
        final s = d.sizes[i];
        final w = s.height <= 0
            ? 42.0
            : (60 * s.width / s.height).clamp(30.0, 84.0);
        final on = i == _page;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Semantics(
            button: true,
            selected: on,
            label: l10n.filePage(whole(i + 1)),
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                jumpTo(i);
              },
              child: AnimatedContainer(
                duration: still
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                width: w,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: on ? HaloColors.amber : HaloColors.line,
                    width: on ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _thumbImage(i),
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _thumbImage(int i) {
    final img = _drawn[(i, 0)] ?? _drawn[(i, 1)];
    if (img == null) {
      _ask(i, 0);
      return const SizedBox.expand();
    }
    return RawImage(image: img, fit: BoxFit.cover);
  }
}

class _PageTile extends StatelessWidget {
  final int index;
  final ui.Image? image;
  const _PageTile({required this.index, required this.image});

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: l10n.filePage(whole(index + 1)),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: image == null
          ? const SizedBox.expand()
          : RawImage(image: image, fit: BoxFit.fill),
    ),
  );
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xD112100D),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: HaloType.mono(size: 11.5, color: const Color(0xFFF5F1EA)),
    ),
  );
}
