// SPDX-License-Identifier: GPL-3.0-or-later
// a sticker on screen. one ticker for each sticker that plays. it stops
// when the sticker scrolls off, under the app lock and under a covering
// route (both mute it through TickerMode), and a phone set to remove
// animations gets the still frame and no ticker at all.
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'sticker_pack.dart';
import 'sticker_player.dart';

/// how many stickers of one surface may play at once. the rest show their
/// still until a slot frees; slots go in visual order.
class StickerBudget {
  StickerBudget(this.slots);
  final int slots;
  final _playing = <_StickerViewState>{};
  final _waiting = <_StickerViewState>[];

  int get playing => _playing.length;

  bool _ask(_StickerViewState s) {
    if (_playing.contains(s)) return true;
    if (_playing.length < slots) {
      _waiting.remove(s);
      _playing.add(s);
      return true;
    }
    if (!_waiting.contains(s)) {
      _waiting.add(s);
      _waiting.sort((a, b) => a.widget.order.compareTo(b.widget.order));
    }
    return false;
  }

  void _giveBack(_StickerViewState s) {
    _waiting.remove(s);
    if (!_playing.remove(s)) return;
    while (_playing.length < slots && _waiting.isNotEmpty) {
      final next = _waiting.removeAt(0);
      _playing.add(next);
      next._granted();
    }
  }
}

class StickerView extends StatefulWidget {
  const StickerView({
    super.key,
    required this.sticker,
    required this.size,
    this.delay = 0,
    this.fps = 60,
    this.budget,
    this.order = 0,
    this.play = true,
    this.label,
  });

  final Sticker sticker;
  final double size;
  // ms at rest before the first loop, so two copies do not move in step
  final int delay;
  // at most this many new frames a second: a 120 hz phone does not double
  // the work of a subtle loop
  final int fps;
  final StickerBudget? budget;
  // place in the budget's queue
  final int order;
  // false: always the still frame (tab icons, thumbnails)
  final bool play;
  final String? label;

  // frames drawn by all stickers, for the tests
  @visibleForTesting
  static int frames = 0;

  @override
  State<StickerView> createState() => _StickerViewState();
}

class _StickerViewState extends State<StickerView>
    with SingleTickerProviderStateMixin {
  // ms into the loop; -1 draws the still
  final _clock = ValueNotifier<double>(-1);
  Ticker? _ticker;
  // time banked while stopped offscreen, so it picks up where it was
  Duration _carry = Duration.zero;
  Duration _last = const Duration(days: -1);
  bool _reduce = false;
  bool _slot = false;
  bool _parked = false;
  RenderSticker? _box;

  bool get _wants => widget.play && widget.sticker.animated && !_reduce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (r != _reduce) {
      _reduce = r;
      if (_reduce) {
        _stop();
        _clock.value = -1;
      } else {
        _box?.markNeedsPaint();
      }
    }
  }

  @override
  void didUpdateWidget(StickerView old) {
    super.didUpdateWidget(old);
    if (old.sticker != widget.sticker ||
        old.budget != widget.budget ||
        old.play != widget.play) {
      old.budget?._giveBack(this);
      _slot = false;
      _stop();
      _carry = Duration.zero;
      _last = const Duration(days: -1);
      _clock.value = -1;
      _box?.markNeedsPaint();
    }
  }

  @override
  void dispose() {
    widget.budget?._giveBack(this);
    _ticker?.dispose();
    _clock.dispose();
    super.dispose();
  }

  void _stop() {
    final t = _ticker;
    if (t != null && t.isActive) t.stop();
    if (_slot) {
      _slot = false;
      widget.budget?._giveBack(this);
    }
  }

  // the box was painted: a parked or waiting sticker asks to play
  void _painted(RenderSticker box) {
    _box = box;
    if (!_wants) return;
    if (_parked || _ticker == null || !_ticker!.isActive) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _resume());
    }
  }

  void _resume() {
    if (!mounted || !_wants) return;
    if (_ticker?.isActive ?? false) return;
    final b = widget.budget;
    if (b != null && !_slot) {
      _slot = b._ask(this);
      if (!_slot) return;
    }
    _start();
  }

  // may come while the tree is being torn down: start after the frame
  void _granted() {
    _slot = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted && _wants && _slot) _start();
      })
      ..ensureVisualUpdate();
  }

  void _start() {
    _parked = false;
    final t = _ticker ??= createTicker(_tick);
    if (!t.isActive) t.start();
  }

  void _tick(Duration elapsed) {
    final box = _box;
    if (box != null && !box.onScreen) {
      // scrolled off: nothing draws it, so nothing runs. the next paint
      // (it scrolled back) starts it again from here
      _carry += elapsed;
      _parked = true;
      _stop();
      box.markNeedsPaint();
      return;
    }
    final total = _carry + elapsed;
    final gap = Duration(microseconds: 900000 ~/ widget.fps);
    if (total - _last < gap) return;
    _last = total;
    StickerView.frames++;
    _clock.value = loopTime(
      widget.sticker,
      total.inMicroseconds / 1000,
      widget.delay,
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = _StickerBox(
      sticker: widget.sticker,
      size: widget.size,
      clock: _clock,
      painted: _painted,
    );
    if (widget.label == null) return box;
    return Semantics(image: true, label: widget.label, child: box);
  }
}

class _StickerBox extends LeafRenderObjectWidget {
  const _StickerBox({
    required this.sticker,
    required this.size,
    required this.clock,
    required this.painted,
  });

  final Sticker sticker;
  final double size;
  final ValueNotifier<double> clock;
  final void Function(RenderSticker) painted;

  @override
  RenderSticker createRenderObject(BuildContext context) =>
      RenderSticker(sticker, size, clock, painted);

  @override
  void updateRenderObject(BuildContext context, RenderSticker r) {
    r
      ..sticker = sticker
      ..extent = size
      ..clock = clock
      ..painted = painted;
  }
}

/// draws one sticker in its own layer, so a frame repaints the sticker
/// and not the bubble or the grid around it
class RenderSticker extends RenderBox {
  RenderSticker(this._sticker, this._extent, this._clock, this.painted);

  Sticker _sticker;
  double _extent;
  ValueNotifier<double> _clock;
  void Function(RenderSticker) painted;
  Float64List? _values;

  Sticker get sticker => _sticker;
  set sticker(Sticker v) {
    if (identical(v, _sticker)) return;
    _sticker = v;
    _values = null;
    markNeedsPaint();
  }

  set extent(double v) {
    if (v == _extent) return;
    _extent = v;
    markNeedsLayout();
  }

  set clock(ValueNotifier<double> v) {
    if (identical(v, _clock)) return;
    if (attached) {
      _clock.removeListener(markNeedsPaint);
      v.addListener(markNeedsPaint);
    }
    _clock = v;
    markNeedsPaint();
  }

  /// ms into the loop of the frame drawn last; -1 is the still
  double get time => _clock.value;

  /// false once a paint has left it out: scrolled off, or offstage
  bool get onScreen => layer?.attached ?? true;

  @override
  bool get isRepaintBoundary => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _clock.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _clock.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void performLayout() {
    size = constraints.constrain(Size.square(_extent));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = context.canvas;
    final k = size.shortestSide / kStickerBox;
    c.save();
    c.translate(
      offset.dx + (size.width - size.shortestSide) / 2,
      offset.dy + (size.height - size.shortestSide) / 2,
    );
    c.scale(k);
    c.clipRect(const Rect.fromLTWH(0, 0, kStickerBox, kStickerBox));
    final t = _clock.value;
    if (t < 0 || !_sticker.animated) {
      c.drawPicture(_sticker.still);
    } else {
      _values = evaluateSticker(_sticker, t, _values);
      paintSticker(c, _sticker, _values);
    }
    c.restore();
    painted(this);
  }
}
