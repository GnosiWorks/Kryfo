// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import '../theme.dart';

// dissolve-and-ember burn shown when a ghost message expires. shared by the
// 1:1 chat and group chat so both burn the same way.
class BurnFade extends StatelessWidget {
  final bool active;
  final Widget child;
  const BurnFade({super.key, required this.active, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeIn,
      builder: (context, t, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) {
                final line = 1 - t;
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                    Colors.transparent,
                  ],
                  stops: [
                    0.0,
                    (line - 0.16).clamp(0.0, 1.0),
                    (line + 0.02).clamp(0.0, 1.0),
                    1.0,
                  ],
                ).createShader(rect);
              },
              child: child,
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: EmberPainter(t)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class EmberPainter extends CustomPainter {
  final double t;
  EmberPainter(this.t);

  // x-fraction, ignition phase, size, sway direction
  static const _seeds = [
    [0.12, 0.00, 1.0, 1.0],
    [0.24, 0.22, 0.7, -1.0],
    [0.34, 0.08, 1.1, 1.0],
    [0.46, 0.40, 0.65, -1.0],
    [0.55, 0.15, 1.0, 1.0],
    [0.64, 0.55, 0.8, -1.0],
    [0.73, 0.30, 1.05, 1.0],
    [0.82, 0.62, 0.6, -1.0],
    [0.90, 0.45, 0.85, 1.0],
    [0.30, 0.70, 0.7, -1.0],
    [0.60, 0.80, 0.6, 1.0],
    [0.18, 0.50, 0.75, -1.0],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final line = 1 - t;
    final fy = h * line;

    // warm glow pooled at the burning edge, climbing and fading.
    if (t < 0.96) {
      final band = h * 0.42;
      final rect = Rect.fromLTWH(0, fy - band, w, band + 6);
      final glow = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HaloColors.amber.withValues(alpha: 0.0),
            HaloColors.amber.withValues(alpha: 0.26 * (1 - t * 0.5)),
          ],
        ).createShader(rect);
      canvas.drawRect(rect, glow);
    }

    // the bright frontier line itself.
    if (t > 0.02 && t < 0.97) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(3, fy - 2.5, w - 6, 5),
          const Radius.circular(3),
        ),
        Paint()
          ..color = Color.lerp(
            HaloColors.amber,
            Colors.white,
            0.35,
          )!.withValues(alpha: 0.55 * (1 - t * 0.3))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0),
      );
    }

    // sparks peeling off the edge, white-hot cooling to amber.
    for (final s in _seeds) {
      final birth = s[1] * 0.8;
      final age = (t - birth) / 0.32;
      if (age < 0 || age > 1) continue;
      final bornY = h * (1 - birth);
      final rise = age * h * 0.28;
      final sway = s[3] * age * 8.0 * s[2];
      final x = s[0] * w + sway;
      final y = bornY - rise - 2;
      final life = 1 - age;
      final r = (0.6 + 1.5 * life) * s[2];
      final col = Color.lerp(
        HaloColors.amber,
        Colors.white,
        life * 0.55,
      )!.withValues(alpha: life.clamp(0.0, 1.0));
      canvas.drawCircle(
        Offset(x, y),
        r * 2.3,
        Paint()
          ..color = HaloColors.amber.withValues(
            alpha: (life * 0.28).clamp(0.0, 1.0),
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
      );
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = col
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant EmberPainter old) => old.t != t;
}
