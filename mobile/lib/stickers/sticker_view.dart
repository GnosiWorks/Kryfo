// SPDX-License-Identifier: GPL-3.0-or-later
// a sticker on screen. one ticker for each sticker that plays. it stops
// when the sticker scrolls off, under the app lock and under a covering
// route (both mute it through TickerMode), and a phone set to remove
// animations gets the still frame and no ticker at all. with the app out of
// front nothing runs either: a phone can go on drawing frames for an app
// behind another user or another app. only time it was seen playing moves
// it on, and below the display's rate it asks for no frame between the
// ones it draws.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'sticker_pack.dart';
import 'sticker_player.dart';

/// whether the app is in front, and word when that changes. stickers move
/// only while it is
abstract final class AppFront {
  static bool get now {
    final s = WidgetsBinding.instance.lifecycleState;
    return s == null || s == AppLifecycleState.resumed;
  }

  static Listenable get changes => _Front.it;
}

// one observer for every sticker on screen
class _Front extends ChangeNotifier with WidgetsBindingObserver {
  _Front() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final it = _Front();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => notifyListeners();
}

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
    this.start = 0,
    this.fps = 60,
    this.budget,
    this.order = 0,
    this.play = true,
    this.loops,
    this.replay = 0,
    this.label,
  });

  final Sticker sticker;
  final double size;
  // ms at rest before the first loop, so two copies do not move in step
  final int delay;
  // ms already played when it first draws: a copy taking over from another
  // goes on from the same frame
  final double start;
  // at most this many new frames a second: a 120 hz phone does not double
  // the work of a subtle loop
  final int fps;
  final StickerBudget? budget;
  // place in the budget's queue
  final int order;
  // false: always the still frame (tab icons, thumbnails)
  final bool play;
  // after this many loops it rests on the still and nothing runs, so a chat
  // left open does not draw all night. null: it loops (the picker)
  final int? loops;
  // a new value plays it again from the start (a tap)
  final int replay;
  final String? label;

  // frames drawn by all stickers, for the tests
  @visibleForTesting
  static int frames = 0;

  @override
  State<StickerView> createState() => _StickerViewState();
}

// the longest gap between two frames that counts as played: a longer one
// was the app away or a stall, and nobody saw it move
const _maxGap = Duration(milliseconds: 100);

class _StickerViewState extends State<StickerView>
    with SingleTickerProviderStateMixin {
  // ms into the loop; -1 draws the still
  final _clock = ValueNotifier<double>(-1);
  Ticker? _ticker;
  // time it was seen playing: kept while stopped offscreen or muted, so it
  // picks up where it was, and what its loops are counted in
  Duration _played = Duration.zero;
  // _played at the last frame drawn
  Duration _last = const Duration(days: -1);
  // the frame the played time was last counted at; null after a stop or a
  // mute, so the time away is not counted
  Duration? _stamp;
  // between frames drawn below the display's rate no frame is asked for:
  // this wakes the ticker just before the next one is due
  Timer? _rest;
  ValueListenable<TickerModeData>? _mode;
  bool _reduce = false;
  bool _slot = false;
  bool _parked = false;
  // its loops are played: resting until a replay
  bool _done = false;
  late int _delay = widget.delay;
  RenderSticker? _box;

  bool get _wants =>
      widget.play && widget.sticker.animated && !_reduce && !_done;

  @override
  void initState() {
    super.initState();
    AppFront.changes.addListener(_frontChanged);
    if (widget.start > 0 && widget.play && widget.sticker.animated) {
      _played = Duration(microseconds: (widget.start * 1000).round());
      _clock.value = loopTime(widget.sticker, widget.start, _delay);
    }
  }

  // out of front it holds where it is, slot and all, with no ticker and no
  // timer; back in front the next paint starts it from there
  void _frontChanged() {
    if (!mounted) return;
    if (!AppFront.now) {
      _hold();
    } else if (_wants) {
      _box?.markNeedsPaint();
    }
  }

  void _hold() {
    _rest?.cancel();
    _rest = null;
    _stamp = null;
    final t = _ticker;
    if (t != null && t.isActive) t.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _watchMode();
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
  void activate() {
    super.activate();
    _watchMode();
  }

  // a muted ticker keeps its clock running: the time under a covering page
  // or the lock is not played time
  void _watchMode() {
    final m = TickerMode.getValuesNotifier(context);
    if (identical(m, _mode)) return;
    _mode?.removeListener(_modeChanged);
    _mode = m..addListener(_modeChanged);
  }

  void _modeChanged() => _stamp = null;

  @override
  void didUpdateWidget(StickerView old) {
    super.didUpdateWidget(old);
    if (old.sticker != widget.sticker ||
        old.budget != widget.budget ||
        old.play != widget.play) {
      old.budget?._giveBack(this);
      _slot = false;
      _stop();
      _played = Duration.zero;
      _last = const Duration(days: -1);
      _done = false;
      _delay = widget.delay;
      _clock.value = -1;
      _box?.markNeedsPaint();
    } else if (old.replay != widget.replay) {
      // again from the rest pose, at once
      _stop();
      _played = Duration.zero;
      _last = const Duration(days: -1);
      _done = false;
      _delay = 0;
      _box?.markNeedsPaint();
    }
  }

  @override
  void dispose() {
    AppFront.changes.removeListener(_frontChanged);
    widget.budget?._giveBack(this);
    _rest?.cancel();
    _mode?.removeListener(_modeChanged);
    _ticker?.dispose();
    _clock.dispose();
    super.dispose();
  }

  void _stop() {
    _hold();
    if (_slot) {
      _slot = false;
      widget.budget?._giveBack(this);
    }
  }

  bool get _running => (_ticker?.isActive ?? false) || _rest != null;

  // the box was painted: a parked or waiting sticker asks to play
  void _painted(RenderSticker box) {
    _box = box;
    if (!_wants) return;
    if (_parked || !_running) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _resume());
    }
  }

  void _resume() {
    if (!mounted || !_wants || !AppFront.now) return;
    if (_running) return;
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
    if (_rest != null || !AppFront.now) return;
    final t = _ticker ??= createTicker(_tick);
    if (!t.isActive) t.start();
  }

  void _tick(Duration _) {
    if (!AppFront.now) {
      _hold();
      return;
    }
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    final box = _box;
    if (box != null && !box.onScreen) {
      // scrolled off: nothing draws it, so nothing runs. the next paint
      // (it scrolled back) starts it again from here
      _parked = true;
      _stop();
      box.markNeedsPaint();
      return;
    }
    final seen = _stamp;
    _stamp = now;
    if (seen != null) {
      final gap = now - seen;
      _played += gap > _maxGap ? _maxGap : gap;
    }
    final period = 1000000 / widget.fps;
    if ((_played - _last).inMicroseconds < period * 0.9) return;
    _last = _played;
    final ms = _played.inMicroseconds / 1000;
    final n = widget.loops;
    final loop = widget.sticker.loopMs;
    if (n != null && loop > 0 && ms - _delay >= n * loop) {
      // every loop ends at rest, so the still takes over without a jump
      _done = true;
      _stop();
      _clock.value = -1;
      return;
    }
    StickerView.frames++;
    _clock.value = loopTime(widget.sticker, ms, _delay);
    _restUntilNext(period);
  }

  // at the display's own rate it keeps ticking. slower, it stops until
  // half a display frame before the next one, which then lands on its vsync
  void _restUntilNext(double period) {
    final hz = View.maybeOf(context)?.display.refreshRate ?? 60;
    final frame = 1000000 / (hz > 0 ? hz : 60);
    if (period < frame * 1.5) return;
    _ticker!.stop();
    _rest = Timer(Duration(microseconds: (period - frame / 2).round()), () {
      _rest = null;
      final t = _ticker;
      if (mounted && _wants && !_parked && t != null && !t.isActive) {
        _start();
      }
    });
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

  // a quote strip sizes itself by its children's intrinsics
  @override
  double computeMinIntrinsicWidth(double height) => _extent;

  @override
  double computeMaxIntrinsicWidth(double height) => _extent;

  @override
  double computeMinIntrinsicHeight(double width) => _extent;

  @override
  double computeMaxIntrinsicHeight(double width) => _extent;

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
