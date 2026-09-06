// SPDX-License-Identifier: GPL-3.0-or-later
// kryfo motion library - tor warmup, send pills, typing/cursor/breath utilities.
// matches the design language: fraunces serif, jetbrains mono, gentle curves,
// breathing motion. one vocabulary, used throughout.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

const kInk = Color(0xFF0D0B09);
const kSurface = Color(0xFF161310);
const kSurface2 = Color(0xFF201C17);
const kSurface3 = Color(0xFF2A251F);
const kLine = Color(0xFF2F2922);
const kLine2 = Color(0xFF3D3629);
const kText = Color(0xFFF5F1EA);
const kText2 = Color(0xFFC8BFB2);
const kText3 = Color(0xFF948A7E);
const kAmber = Color(0xFFF59E0B);
const kAmberSoft = Color(0x24F59E0B);
const kGreen = Color(0xFF34D399);
// the onion route's own colour, so three hops read differently from one
const kViolet = Color(0xFFA78BFA);
// the relay route's colour. cool enough never to read as tor's violet or
// amber's "still working on it".
const kCyan = Color(0xFF4BB8C9);
const kGreenSoft = Color(0x2434D399);

enum TorStatus { off, starting, bootstrapped, publishing, reachable }

enum PrivacyMode { fast, normal, private }

// shared screen transition - a calm rise-and-fade, one way in across the app.
Route<T> haloRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 360),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, anim, _, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

TorStatus parseTorStatus(String raw) {
  final parts = raw.split('|');
  if (parts.isEmpty) return TorStatus.off;
  switch (parts[0]) {
    case 'starting':
      return TorStatus.starting;
    case 'bootstrapped':
      return TorStatus.bootstrapped;
    case 'publishing':
      return TorStatus.publishing;
    case 'reachable':
      return TorStatus.reachable;
    default:
      return TorStatus.off;
  }
}

int parseBootstrapPct(String raw) {
  final parts = raw.split('|');
  if (parts.length < 2) return 0;
  return int.tryParse(parts[1]) ?? 0;
}

// === TOR WARMUP GRAPH ===
// 4 onions on a zig-zag wave (SELF/GUARD/MIDDLE/HSDIR), curve fills as
// we progress, active onion glows with expanding rings, on REACHABLE
// everything turns green and breathes in sequence. plain-language copy
// teaches the user what's happening while they wait.

class TorWarmupGraph extends StatefulWidget {
  final TorStatus status;
  final int bootstrapPct;
  const TorWarmupGraph({
    super.key,
    required this.status,
    this.bootstrapPct = 0,
  });
  @override
  State<TorWarmupGraph> createState() => _TorWarmupGraphState();
}

class _TorWarmupGraphState extends State<TorWarmupGraph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  int _phase = 0;
  Timer? _phaseTimer;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _phase = _targetPhase(widget.status);
  }

  @override
  void didUpdateWidget(TorWarmupGraph old) {
    super.didUpdateWidget(old);
    final target = _targetPhase(widget.status);
    if (target != _phase) _walkTo(target);
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  int _targetPhase(TorStatus s) {
    switch (s) {
      case TorStatus.off:
        return 0;
      case TorStatus.starting:
        return 1;
      case TorStatus.bootstrapped:
        return 2;
      case TorStatus.publishing:
        return 3;
      case TorStatus.reachable:
        return 4;
    }
  }

  void _walkTo(int target) {
    _phaseTimer?.cancel();
    if (_phase == target) return;
    final stepDur = _phase < target
        ? const Duration(milliseconds: 1100)
        : const Duration(milliseconds: 200);
    _phaseTimer = Timer(stepDur, () {
      if (!mounted) return;
      setState(() {
        if (_phase < target) {
          _phase++;
        } else if (_phase > target) {
          _phase--;
        }
      });
      _walkTo(target);
    });
  }

  int get _activeIdx {
    if (_phase == 0 || _phase == 4) return -1;
    return _phase - 1;
  }

  double get _progress {
    switch (_phase) {
      case 0:
        return 0;
      case 1:
        return 0.0;
      case 2:
        return 0.33;
      case 3:
        return 0.66;
      case 4:
        return 1.0;
      default:
        return 0;
    }
  }

  List<int> get _lit {
    if (_phase == 0) return const [];
    if (_phase == 4) return const [0, 1, 2, 3];
    return List.generate(_phase - 1, (i) => i);
  }

  String get _label {
    switch (widget.status) {
      case TorStatus.off:
        return 'STANDBY';
      case TorStatus.starting:
        return 'CONNECTING';
      case TorStatus.bootstrapped:
        return 'BUILDING';
      case TorStatus.publishing:
        return 'PUBLISHING';
      case TorStatus.reachable:
        return 'READY';
    }
  }

  String get _italic {
    switch (widget.status) {
      case TorStatus.off:
        return 'preparing to connect';
      case TorStatus.starting:
        return 'finding a private path';
      case TorStatus.bootstrapped:
        return 'carving the path';
      case TorStatus.publishing:
        return 'announcing your arrival';
      case TorStatus.reachable:
        return "you're anonymous";
    }
  }

  String get _help {
    switch (widget.status) {
      case TorStatus.off:
        return 'tor is starting in the background. this graph lights up as the connection forms.';
      case TorStatus.starting:
        return 'making a fresh route through anonymous relays.';
      case TorStatus.bootstrapped:
        return 'bouncing through relays so no one can trace this back to you.';
      case TorStatus.publishing:
        return "telling the network you're online \u2014 without revealing where.";
      case TorStatus.reachable:
        return 'your ip is hidden. only people with your kryfo can reach you.';
    }
  }

  String get _circuit {
    switch (widget.status) {
      case TorStatus.off:
        return '\u2014';
      case TorStatus.starting:
        return 'building';
      case TorStatus.bootstrapped:
      case TorStatus.publishing:
        return 'open';
      case TorStatus.reachable:
        return 'live';
    }
  }

  int _displayPct() {
    if (widget.bootstrapPct > 0) return widget.bootstrapPct;
    switch (_phase) {
      case 0:
        return 0;
      case 1:
        return 15;
      case 2:
        return 45;
      case 3:
        return 78;
      case 4:
        return 100;
      default:
        return 0;
    }
  }

  bool get _green => widget.status == TorStatus.reachable;
  bool get _standby => _phase == 0;
  Color get _accent =>
      _standby ? const Color(0xFFE5E5E5) : (_green ? kGreen : kAmber);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SizedBox(
            height: 110,
            child: AnimatedBuilder(
              animation: _ctl,
              builder: (ctx, _) => ColorFiltered(
                colorFilter: _standby
                    ? const ColorFilter.mode(Color(0xFFE5E5E5), BlendMode.srcIn)
                    : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                child: CustomPaint(
                  painter: _ZigZagWarmupPainter(
                    activeIdx: _activeIdx,
                    lit: _lit,
                    progress: _progress,
                    green: _green,
                    t: _ctl.value,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _label,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 11,
              letterSpacing: 4,
              fontWeight: FontWeight.w500,
              color: _accent,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _italic,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontStyle: FontStyle.italic,
                fontSize: 22,
                fontWeight: FontWeight.w300,
                color: kText,
                letterSpacing: -0.3,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(width: 56, height: 0.5, color: kLine2),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _help,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 11.5,
                color: kText3,
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 10.5,
                      color: kText2,
                      letterSpacing: 0.4,
                    ),
                    children: [
                      const TextSpan(text: 'circuit \u00b7 '),
                      TextSpan(
                        text: _circuit,
                        style: TextStyle(
                          color: _accent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_displayPct()}%',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 10.5,
                    color: _accent,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZigZagWarmupPainter extends CustomPainter {
  final int activeIdx;
  final List<int> lit;
  final double progress;
  final bool green;
  final double t;
  _ZigZagWarmupPainter({
    required this.activeIdx,
    required this.lit,
    required this.progress,
    required this.green,
    required this.t,
  });

  // viewBox 296 x 100; positions match the html mockup exactly.
  static const _vbW = 296.0;
  static const _vbH = 100.0;
  static const _onionPositions = [
    Offset(40, 60),
    Offset(110, 32),
    Offset(180, 60),
    Offset(250, 22),
  ];
  static const _labels = ['SELF', 'GUARD', 'MIDDLE', 'HSDIR'];

  Path _curve() => Path()
    ..moveTo(40, 60)
    ..cubicTo(75, 60, 75, 32, 110, 32)
    ..cubicTo(145, 32, 145, 60, 180, 60)
    ..cubicTo(215, 60, 215, 22, 250, 22);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / _vbW, size.height / _vbH);
    final dx = (size.width - _vbW * scale) / 2;
    final dy = (size.height - _vbH * scale) / 2;
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    final accent = green ? kGreen : kAmber;
    final path = _curve();

    // base dim curve
    canvas.drawPath(
      path,
      Paint()
        ..color = kLine2
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );

    // progress curve (filled portion)
    if (progress > 0) {
      final metrics = path.computeMetrics().toList();
      final totalLen = metrics.fold<double>(0, (s, m) => s + m.length);
      final targetLen = totalLen * progress;
      final partial = Path();
      var remaining = targetLen;
      for (final m in metrics) {
        if (remaining <= 0) break;
        if (remaining >= m.length) {
          partial.addPath(m.extractPath(0, m.length), Offset.zero);
          remaining -= m.length;
        } else {
          partial.addPath(m.extractPath(0, remaining), Offset.zero);
          remaining = 0;
        }
      }
      // glow
      canvas.drawPath(
        partial,
        Paint()
          ..color = accent.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      // sharp
      canvas.drawPath(
        partial,
        Paint()
          ..color = accent.withValues(alpha: 0.95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );
    }

    // onions
    for (int i = 0; i < 4; i++) {
      _drawOnion(canvas, _onionPositions[i], i);
    }

    // labels
    for (int i = 0; i < 4; i++) {
      _drawLabel(canvas, _labels[i], _onionPositions[i].dx);
    }

    canvas.restore();
  }

  void _drawOnion(Canvas canvas, Offset c, int i) {
    final isActive = i == activeIdx;
    final isLit = lit.contains(i);
    final accent = green ? kGreen : kAmber;

    if (isActive) {
      // expanding rings (2, staggered)
      _drawPulse(canvas, c, t, accent);
      _drawPulse(canvas, c, (t + 0.5) % 1.0, accent);
    }

    // 4 layered rings, dim by default
    final layers = [
      [11.0, 1.0],
      [7.5, 0.85],
      [4.2, 0.70],
      [1.8, 1.0], // filled core
    ];

    if (isActive || isLit || green) {
      double breathOp = 1.0;
      if (green) {
        // breath in sequence, phase per onion
        final phase = (t + i * 0.075) % 1.0;
        breathOp = 0.55 + 0.45 * (math.sin(phase * 2 * math.pi) * 0.5 + 0.5);
      }

      for (int k = 0; k < layers.length; k++) {
        final radius = layers[k][0];
        final baseOp = layers[k][1];
        final visible = isActive || isLit || green;
        if (!visible) continue;

        final isCore = k == 3;
        if (isCore) {
          // glow kryfo behind core
          if (isActive) {
            canvas.drawCircle(
              c,
              radius + 4,
              Paint()
                ..color = accent.withValues(alpha: 0.5 * breathOp)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
            );
          }
          canvas.drawCircle(
            c,
            radius,
            Paint()..color = accent.withValues(alpha: baseOp * breathOp),
          );
        } else {
          canvas.drawCircle(
            c,
            radius,
            Paint()
              ..color = accent.withValues(
                alpha: baseOp * breathOp * (isActive ? 1.0 : 0.6),
              )
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.6,
          );
        }
      }
    } else {
      // dim placeholder: just outer ring
      canvas.drawCircle(
        c,
        11,
        Paint()
          ..color = kLine2.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
    }
  }

  void _drawPulse(Canvas canvas, Offset c, double phase, Color color) {
    final scaleP = 0.7 + 1.5 * phase;
    final op = 0.7 * (1 - phase);
    if (op <= 0) return;
    canvas.drawCircle(
      c,
      11 * scaleP,
      Paint()
        ..color = color.withValues(alpha: op)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
  }

  void _drawLabel(Canvas canvas, String text, double cx) {
    final accent = green
        ? kGreen.withValues(alpha: 0.7)
        : kAmber.withValues(alpha: 0.7);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 7,
          fontWeight: FontWeight.w500,
          color: green || activeIdx >= 0 || lit.isNotEmpty ? accent : kText3,
          letterSpacing: 1.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, 84));
  }

  @override
  bool shouldRepaint(_ZigZagWarmupPainter old) =>
      old.activeIdx != activeIdx ||
      old.progress != progress ||
      old.green != green ||
      old.t != t ||
      old.lit.length != lit.length;
}

// a padlock snapping shut with two dots trailing it. the shackle lifts and
// closes on a loop; the dots brighten in sequence behind it, so the thing
// reads as sealed first and travelling second.
class _LockTrailPainter extends CustomPainter {
  final double t;
  final Color color;
  _LockTrailPainter({required this.t, required this.color});

  @override
  void paint(Canvas c, Size s) {
    final body = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    // 0 open, 1 shut. sits closed for most of the cycle so it does not
    // look like it is struggling.
    final close = t < 0.35
        ? (t / 0.35)
        : t < 0.75
        ? 1.0
        : 1.0 - ((t - 0.75) / 0.25);
    final lift = (1 - close) * 3.0;

    const bw = 11.0;
    const bh = 8.0;
    final bx = 0.0;
    final by = s.height - bh;

    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, by, bw, bh),
        const Radius.circular(2),
      ),
      body,
    );

    // shackle: a half round that rides up as it opens
    final r = 3.4;
    final cx = bx + bw / 2;
    final cy = by - lift;
    c.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      3.14159,
      3.14159,
      false,
      stroke,
    );

    // two dots behind, brightening in turn
    for (var i = 0; i < 2; i++) {
      final phase = (t + i * 0.18) % 1.0;
      final a = 0.18 + 0.72 * (0.5 - (phase - 0.5).abs()) * 2;
      c.drawCircle(
        Offset(bx + bw + 4.5 + i * 4.0, s.height - bh / 2),
        1.3,
        Paint()..color = color.withValues(alpha: a.clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LockTrailPainter o) =>
      o.t != t || o.color != color;
}

// === SEND PILL (mode-aware) ===
// fast = no pill (delivered ✓ shows inline in bubble meta)
// normal = "1 hop" + 1 rotating onion
// private = "3 hops" + 3 rotating onions, staggered

class SendPill extends StatefulWidget {
  final PrivacyMode mode;
  final bool delivered;
  const SendPill({super.key, required this.mode, this.delivered = false});
  @override
  State<SendPill> createState() => _SendPillState();
}

class _SendPillState extends State<SendPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      // one hop turns faster than three. the pace is the difference you feel
      // before you read the label.
      duration: Duration(
        milliseconds: widget.mode == PrivacyMode.private ? 1400 : 800,
      ),
    )..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  int get _onionCount {
    switch (widget.mode) {
      case PrivacyMode.fast:
        return 0;
      case PrivacyMode.normal:
        return 1;
      case PrivacyMode.private:
        return 3;
    }
  }

  String get _label {
    if (widget.delivered) return 'delivered';
    switch (widget.mode) {
      case PrivacyMode.fast:
        return 'sent';
      case PrivacyMode.normal:
        return '1 hop';
      case PrivacyMode.private:
        return '3 hops';
    }
  }

  // the route has a colour of its own, so the mode reads at a glance
  // without anyone having to parse the words.
  Color get _color {
    if (widget.delivered) return kGreen;
    switch (widget.mode) {
      case PrivacyMode.private:
        return kViolet;
      case PrivacyMode.normal:
        return kCyan;
      case PrivacyMode.fast:
        return kGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == PrivacyMode.fast && !widget.delivered) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _label,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 9.5,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w500,
              color: _color,
            ),
          ),
          if (widget.delivered) ...[
            const SizedBox(width: 5),
            Text(
              '\u2713',
              style: TextStyle(
                fontSize: 11,
                color: _color,
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else if (widget.mode == PrivacyMode.normal) ...[
            const SizedBox(width: 7),
            SizedBox(
              width: 22,
              height: 11,
              child: AnimatedBuilder(
                animation: _ctl,
                builder: (ctx, _) => CustomPaint(
                  painter: _LockTrailPainter(t: _ctl.value, color: _color),
                  size: Size.infinite,
                ),
              ),
            ),
          ] else if (_onionCount > 0) ...[
            const SizedBox(width: 7),
            for (int i = 0; i < _onionCount; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              SizedBox(
                width: 10,
                height: 10,
                child: AnimatedBuilder(
                  animation: _ctl,
                  builder: (ctx, _) => CustomPaint(
                    painter: _OnionSpinPainter(
                      t: _ctl.value,
                      phase: i * (1.0 / _onionCount),
                      color: _color,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _OnionSpinPainter extends CustomPainter {
  final double t;
  final double phase;
  final Color color;
  _OnionSpinPainter({
    required this.t,
    required this.phase,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    // 3 static rings + filled core
    canvas.drawCircle(
      c,
      r * 0.85,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
    canvas.drawCircle(
      c,
      r * 0.55,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
    canvas.drawCircle(
      c,
      r * 0.32,
      Paint()
        ..color = color.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
    canvas.drawCircle(c, r * 0.17, Paint()..color = color);

    // rotating arc (90deg) on the outer ring
    final p = ((t + phase) % 1.0) * 2 * math.pi;
    final rect = Rect.fromCircle(center: c, radius: r * 0.85);
    canvas.drawArc(
      rect,
      p,
      math.pi / 2,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_OnionSpinPainter old) =>
      old.t != t || old.phase != phase || old.color != color;
}

// === TYPING DOTS ===
// unused on purpose. kryfo sends NO typing signal over the wire (privacy: the
// why_kryfo screen promises exactly that). kept only as a local building block
// if a same-device demo ever needs it. do not wire this to the transport.
class TypingDots extends StatefulWidget {
  const TypingDots({super.key});
  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: kSurface3,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
          bottomRight: Radius.circular(14),
          bottomLeft: Radius.circular(4),
        ),
      ),
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (ctx, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(0),
            const SizedBox(width: 3),
            _dot(0.18),
            const SizedBox(width: 3),
            _dot(0.36),
          ],
        ),
      ),
    );
  }

  Widget _dot(double phase) {
    final ph = (_ctl.value + phase) % 1.0;
    final dy = ph < 0.3 ? -3.0 * (math.sin(ph / 0.3 * math.pi)) : 0.0;
    final op = 0.4 + (ph < 0.3 ? 0.6 * math.sin(ph / 0.3 * math.pi) : 0.0);
    return Transform.translate(
      offset: Offset(0, dy),
      child: Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kAmber.withValues(alpha: op),
        ),
      ),
    );
  }
}

// === BREATH STATUS DOT ===
class BreathDot extends StatefulWidget {
  final Color color;
  final double size;
  const BreathDot({super.key, this.color = kGreen, this.size = 5});
  @override
  State<BreathDot> createState() => _BreathDotState();
}

class _BreathDotState extends State<BreathDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      _ctl.stop();
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
      );
    }
    return AnimatedBuilder(
      animation: _ctl,
      builder: (ctx, _) {
        final op = 0.5 + 0.5 * math.sin(_ctl.value * 2 * math.pi);
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: op),
          ),
        );
      },
    );
  }
}

// === BLINKING CURSOR ===
class BlinkCursor extends StatefulWidget {
  final Color color;
  final double height;
  const BlinkCursor({super.key, this.color = kAmber, this.height = 11});
  @override
  State<BlinkCursor> createState() => _BlinkCursorState();
}

class _BlinkCursorState extends State<BlinkCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctl,
    builder: (ctx, _) {
      final visible = _ctl.value < 0.5;
      return Container(
        width: 1.5,
        height: widget.height,
        color: visible ? widget.color : Colors.transparent,
      );
    },
  );
}
