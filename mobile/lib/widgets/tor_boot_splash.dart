// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../dlog.dart';
import '../main.dart' show appState;
import '../reopen.dart';
import '../secure_store.dart';
import '../theme.dart';
import 'fit_column.dart';
import 'onion_loader.dart';
import '../l10n/l10n.dart';

// startup screen while the engine warms up tor. it says plainly that tor is
// starting, so the wait reads as purposeful, not stuck.
class TorBootSplash extends StatefulWidget {
  const TorBootSplash({super.key});

  @override
  State<TorBootSplash> createState() => _TorBootSplashState();
}

class _TorBootSplashState extends State<TorBootSplash>
    with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );
  // the words come up under the onion once it has started to draw
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _still = false;

  // the hops light in turn while tor starts, the only time this screen is
  // up. still with less movement
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_still) {
      _c.stop();
      _in.value = 1;
    } else {
      if (!_c.isAnimating) _c.repeat();
      if (_in.isDismissed) _in.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _in.dispose();
    super.dispose();
  }

  // how lit a hop is: a pulse runs guard, relay, exit and rests between
  double _hop(double phase) {
    if (_still) return 0.7;
    final d = (_c.value - phase) % 1.0;
    if (d < 0.15) return 0.25 + (d / 0.15) * 0.75;
    if (d < 0.35) return 1.0 - ((d - 0.15) / 0.20) * 0.75;
    return 0.25;
  }

  // where the pulse is on a link, 0 to 1, or null while it is elsewhere
  double? _travel(double from) {
    if (_still) return null;
    final d = (_c.value - from) % 1.0;
    if (d < 0.1 || d > 0.38) return null;
    return (d - 0.1) / 0.28;
  }

  @override
  void initState() {
    super.initState();
    dlog('LAUNCH splash');
  }

  Widget _rise(double from, double to, Widget child) {
    final curve = Interval(from, to, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: _in,
      child: child,
      builder: (_, child) {
        final v = curve.transform(_in.value);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 10),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.ink,
      body: SafeArea(
        child: FitColumn(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
          children: [
            const Spacer(),
            OnionLoader(
              size: 132,
              color: HaloColors.amber,
              ink: HaloColors.isLight ? HaloColors.amberDeep : null,
            ),
            const SizedBox(height: 26),
            _rise(
              0.1,
              0.6,
              Text(
                l10n.torBootSplashNoShortcutsNoTraces,
                textAlign: TextAlign.center,
                style: HaloType.serif(
                  size: 23,
                  weight: FontWeight.w400,
                  italic: true,
                  color: HaloColors.text,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 18),
            _rise(
              0.25,
              0.8,
              ListenableBuilder(
                listenable: appState,
                builder: (_, _) {
                  final tor = appState.bootPhase == l10n.appStartingTor;
                  return Column(
                    children: [
                      AnimatedSwitcher(
                        duration: _still
                            ? Duration.zero
                            : const Duration(milliseconds: 260),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, 0.35),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: Text(
                          appState.bootPhase,
                          key: ValueKey(appState.bootPhase),
                          textAlign: TextAlign.center,
                          style: HaloType.mono(
                            size: 12,
                            color: HaloColors.amber,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          tor
                              ? l10n.torBootSplashTheNetworkThatKeeps
                              : l10n.torBootSplashMadeOnThisPhone,
                          textAlign: TextAlign.center,
                          style: HaloType.sans(
                            size: 12.5,
                            color: HaloColors.text2,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            _rise(
              0.4,
              1,
              ExcludeSemantics(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _hopDot('guard', 0.0),
                      _link(0.0),
                      _hopDot('relay', 0.33),
                      _link(0.33),
                      _hopDot('exit', 0.66),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            const SizedBox(height: 24),
            _rise(
              0.6,
              1,
              // a key store call that has not answered for a while: the way
              // out is a new process, offered before boot gives up on it
              ValueListenableBuilder<bool>(
                valueListenable: keyStoreSlow,
                builder: (_, slow, _) {
                  final line = slow
                      ? _slow()
                      : Text(
                          l10n.torBootSplashFirstLaunchTakesA,
                          key: const ValueKey('first'),
                          textAlign: TextAlign.center,
                          style: HaloType.mono(
                            size: 10,
                            color: HaloColors.text2,
                          ),
                        );
                  if (_still) return line;
                  const d = Duration(milliseconds: 320);
                  return AnimatedSize(
                    duration: d,
                    curve: Curves.easeOutCubic,
                    child: AnimatedSwitcher(duration: d, child: line),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slow() => Column(
    key: const ValueKey('slow'),
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        l10n.torBootSplashTakingLonger,
        textAlign: TextAlign.center,
        style: HaloType.sans(size: 12.5, color: HaloColors.text2, height: 1.5),
      ),
      const SizedBox(height: 2),
      TextButton(
        onPressed: reopenApp,
        child: Text(
          l10n.bootFailedCloseAndReopen,
          textAlign: TextAlign.center,
          style: HaloType.sans(size: 13, color: HaloColors.amber),
        ),
      ),
    ],
  );

  Widget _hopDot(String label, double phase) {
    final lit = _hop(phase);
    return Column(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: Center(
            child: Transform.scale(
              scale: 0.8 + 0.3 * lit,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HaloColors.amber.withValues(alpha: lit),
                  boxShadow: [
                    BoxShadow(
                      color: HaloColors.amber.withValues(
                        alpha: (lit - 0.4).clamp(0.0, 1.0) * 0.6,
                      ),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: HaloType.mono(size: 10, color: HaloColors.text2)),
      ],
    );
  }

  // the line between two hops, with the pulse running along it
  Widget _link(double from) => Padding(
    padding: const EdgeInsets.only(top: 6.5),
    child: CustomPaint(
      size: const Size(28, 1),
      painter: _LinkPainter(
        _travel(from),
        HaloColors.line2,
        HaloColors.amber,
        Directionality.of(context) == TextDirection.rtl,
      ),
    ),
  );
}

class _LinkPainter extends CustomPainter {
  final double? at;
  final Color line;
  final Color pulse;
  final bool rtl;
  _LinkPainter(this.at, this.line, this.pulse, this.rtl);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = line
        ..strokeWidth = 1,
    );
    final t = at;
    if (t == null) return;
    final x = (rtl ? 1 - t : t) * size.width;
    final fade = math.sin(t * math.pi);
    canvas.drawCircle(
      Offset(x, y),
      1.8,
      Paint()..color = pulse.withValues(alpha: fade),
    );
  }

  @override
  bool shouldRepaint(_LinkPainter old) =>
      old.at != at || old.line != line || old.pulse != pulse || old.rtl != rtl;
}
