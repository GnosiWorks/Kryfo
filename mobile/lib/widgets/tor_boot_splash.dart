// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import '../theme.dart';
import 'onion_loader.dart';

// startup screen while the engine warms up tor. it tells the user plainly that
// tor - the thing that makes kryfo private - is starting, so the wait reads as
// purposeful instead of stuck.
class TorBootSplash extends StatefulWidget {
  const TorBootSplash({super.key});

  @override
  State<TorBootSplash> createState() => _TorBootSplashState();
}

class _TorBootSplashState extends State<TorBootSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _hop(double phase) {
    final d = (_c.value - phase) % 1.0;
    if (d < 0.15) return 0.25 + (d / 0.15) * 0.75;
    if (d < 0.35) return 1.0 - ((d - 0.15) / 0.20) * 0.75;
    return 0.25;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.ink,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const OnionLoader(size: 132),
            const SizedBox(height: 26),
            Text(
              'no shortcuts, no traces',
              style: HaloType.serif(
                size: 23,
                weight: FontWeight.w400,
                italic: true,
                color: HaloColors.text,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'starting Tor',
              style: HaloType.mono(size: 12, color: HaloColors.amber),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'the network that keeps you private is warming up',
                textAlign: TextAlign.center,
                style: HaloType.sans(
                  size: 12,
                  color: HaloColors.text2,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 22),
            AnimatedBuilder(
              animation: _c,
              builder: (_, __) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _hopDot('guard', 0.0),
                  _link(),
                  _hopDot('relay', 0.33),
                  _link(),
                  _hopDot('exit', 0.66),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Text(
                'first launch takes a moment · only on startup',
                style: HaloType.mono(size: 10, color: HaloColors.text3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hopDot(String label, double phase) {
    return Column(
      children: [
        Opacity(
          opacity: _hop(phase),
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: HaloColors.amber,
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(label, style: HaloType.mono(size: 10, color: HaloColors.text2)),
      ],
    );
  }

  Widget _link() => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Container(width: 22, height: 1, color: HaloColors.line),
  );
}
