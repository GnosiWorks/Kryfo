// SPDX-License-Identifier: GPL-3.0-or-later
// onboarding, shown once. three things in the first minute, everything else
// when it is needed: your name is three words, nobody gets in unless you let
// them, the first connection takes a minute.
// welcome → identity → face → transport → three things → notification → add

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/press_scale.dart';
import '../widgets/fit_column.dart';
import '../theme.dart';
import 'restore_screen.dart';
import 'my_kryfo_screen.dart';
import '../main.dart' show appState, AppState, handleHaloUri;
import 'scan_screen.dart';
import 'avatar_picker_screen.dart' show AvatarChoiceEditor;
import '../widgets/kryfo_avatar.dart';
import '../widgets/motion.dart'
    show haloRoute, motionStill, kHouseCurve, kHouseTime;
import '../widgets/stagger_in.dart';
import '../l10n/l10n.dart';
import '../l10n/marked.dart';
import '../l10n/numbers.dart' show twoDigits;
import '../widgets/language_sheet.dart';

class OnboardingScreen extends StatefulWidget {
  final AppState appState;
  final VoidCallback onComplete;
  const OnboardingScreen({
    super.key,
    required this.appState,
    required this.onComplete,
  });
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _steps = 7;
  final _ctrl = PageController();
  int _page = 0;
  // the step being moved to: it settles in while the one left fades out
  int _to = 0;
  // steps already shown: coming back to one, it is simply there
  final _seen = <int>{0};

  void _go(int to) {
    if (to < 0 || to >= _steps) return;
    setState(() => _to = to);
    // with less movement the step is simply there
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl.jumpToPage(to);
      return;
    }
    _ctrl.animateToPage(
      to,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
  }

  int get _at => (_ctrl.page ?? _page.toDouble()).round();

  void _next() => _go(_at + 1);

  // system back walks one step back; only the first step leaves the app
  void _back() {
    final to = _at - 1;
    if (to < 0) return;
    HapticFeedback.selectionClick();
    _go(to);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = <Widget>[
      _WelcomeScreen(onContinue: _next, enter: !_seen.contains(1)),
      _IdentityScreen(
        appState: widget.appState,
        onContinue: _next,
        enter: !_seen.contains(1),
      ),
      _PickFaceScreen(onContinue: _next),
      _TransportScreen(onContinue: _next),
      _ThreeThingsScreen(onContinue: _next),
      _NotificationScreen(onContinue: _next),
      _AddSomeoneScreen(onComplete: widget.onComplete),
    ];
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (done, _) {
        if (!done) _back();
      },
      child: Scaffold(
        backgroundColor: HaloColors.ink,
        body: SafeArea(
          child: Column(
            children: [
              _StepBar(pages: _ctrl, step: _to, count: _steps, onBack: _back),
              Expanded(
                child: PageView(
                  controller: _ctrl,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() {
                    _page = i;
                    _to = i;
                    _seen.add(i);
                  }),
                  children: [
                    for (var i = 0; i < steps.length; i++)
                      _StepFrame(
                        pages: _ctrl,
                        index: i,
                        coming: i == _to,
                        child: steps[i],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// the pager moves a whole width; each step is pulled back so it only
// shifts a little: the one left fades out first, then the next settles in
class _StepFrame extends StatelessWidget {
  final PageController pages;
  final int index;
  final bool coming;
  final Widget child;
  const _StepFrame({
    required this.pages,
    required this.index,
    required this.coming,
    required this.child,
  });

  static const _shift = 28.0;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AnimatedBuilder(
      animation: pages,
      child: child,
      builder: (context, child) {
        var d = 0.0;
        var w = 0.0;
        if (pages.hasClients && pages.position.haveDimensions) {
          d = pages.page! - index;
          w = pages.position.viewportDimension;
        }
        final q = d.abs().clamp(0.0, 1.0);
        final shown = coming
            ? Curves.easeOut.transform(((0.7 - q) / 0.7).clamp(0.0, 1.0))
            : 1 - Curves.easeIn.transform((q / 0.3).clamp(0.0, 1.0));
        return IgnorePointer(
          // a tap while steps change would land on the wrong one
          ignoring: q > 0.01,
          child: Opacity(
            opacity: shown,
            child: Transform.translate(
              offset: Offset(d * (w - _shift) * (rtl ? -1 : 1), 0),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

// back, the steps as a filling track, and the count. on the welcome step
// only the language chip shows
class _StepBar extends StatelessWidget {
  final PageController pages;
  final int step;
  final int count;
  final VoidCallback onBack;
  const _StepBar({
    required this.pages,
    required this.step,
    required this.count,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final counter = AnimatedSwitcher(
      duration: Duration(milliseconds: still ? 0 : 240),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.5),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: Text(
        '${twoDigits(step + 1)} / ${twoDigits(count)}',
        key: ValueKey(step),
        style: HaloType.mono(
          size: 10,
          color: HaloColors.amber,
        ).copyWith(letterSpacing: track(2), fontWeight: FontWeight.w500),
      ),
    );
    // grows with a large text size rather than squeezing the chip
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: AnimatedBuilder(
        animation: pages,
        builder: (context, _) {
          final pos = pages.hasClients && pages.position.haveDimensions
              ? pages.page!
              : step.toDouble();
          final shown = pos.clamp(0.0, 1.0);
          return Row(
            children: [
              const SizedBox(width: 4),
              IgnorePointer(
                ignoring: shown < 0.5,
                child: Opacity(
                  opacity: shown,
                  child: IconButton(
                    tooltip: l10n.commonBack,
                    onPressed: onBack,
                    icon: Icon(
                      Icons.chevron_left,
                      size: 26,
                      color: HaloColors.text2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Opacity(
                  opacity: shown,
                  child: ExcludeSemantics(child: _track(pos)),
                ),
              ),
              const SizedBox(width: 14),
              Stack(
                alignment: AlignmentDirectional.centerEnd,
                children: [
                  IgnorePointer(
                    ignoring: shown >= 0.5,
                    child: Opacity(
                      opacity: 1 - (shown * 2).clamp(0.0, 1.0),
                      child: const LanguageChip(),
                    ),
                  ),
                  IgnorePointer(
                    child: Opacity(
                      opacity: (shown * 2 - 1).clamp(0.0, 1.0),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(end: 10),
                        child: counter,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
            ],
          );
        },
      ),
    );
  }

  // one short bar a step, filled from the reading side as the step arrives
  Widget _track(double pos) {
    return Row(
      children: [
        for (var k = 0; k < count; k++) ...[
          if (k > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: HaloColors.line2,
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: (pos + 1 - k).clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: HaloColors.amber,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// === 01 · WELCOME ===

class _WelcomeScreen extends StatefulWidget {
  final VoidCallback onContinue;
  final bool enter;
  const _WelcomeScreen({required this.onContinue, required this.enter});
  @override
  State<_WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<_WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ctl;
  // the page comes up in order: the light, the line, the promises, the button
  late final AnimationController _in;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _in = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  bool _glowed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // two slow glows as the page opens, then it rests: nothing loops while
    // someone reads
    if (_glowed) return;
    _glowed = true;
    if (!widget.enter || MediaQuery.disableAnimationsOf(context)) {
      _in.value = 1;
      return;
    }
    _in.forward();
    // a whole number of glows ends where it began
    _ctl.repeat(count: 2).whenComplete(() {
      if (mounted) _ctl.value = 0;
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    _in.dispose();
    super.dispose();
  }

  Widget _rise(double from, double to, Widget child, {double by = 14}) {
    final curve = Interval(from, to, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: _in,
      child: child,
      builder: (_, child) {
        final v = curve.transform(_in.value);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * by),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // a short phone keeps the button in view with a smaller light and type
    final tight = MediaQuery.sizeOf(context).height < 720;
    final hero = tight ? 34.0 : 38.0;
    return _StepPage(
      top: tight ? 12 : 20,
      cross: CrossAxisAlignment.start,
      footer: [
        _rise(
          0.68,
          1,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cta(label: l10n.onboardingBegin, onTap: widget.onContinue),
              const SizedBox(height: 2),
              Center(
                child: _TextLink(
                  label: l10n.onboardingHaveABackupRestore,
                  onTap: () => Navigator.of(
                    context,
                  ).push(haloRoute(const RestoreScreen())),
                ),
              ),
            ],
          ),
          by: 10,
        ),
      ],
      children: [
        _orb(tight ? 58 : 70),
        SizedBox(height: tight ? 22 : 28),
        _rise(
          0.15,
          0.5,
          Text(
            l10n.onboardingPrivateByDefault,
            style: HaloType.mono(
              size: 10,
              color: HaloColors.amber,
            ).copyWith(letterSpacing: track(4), fontWeight: FontWeight.w500),
          ),
          by: 8,
        ),
        SizedBox(height: tight ? 16 : 20),
        _rise(
          0.22,
          0.65,
          Text.rich(
            TextSpan(
              style: HaloType.serif(
                size: hero,
                weight: FontWeight.w300,
                color: HaloColors.text,
                height: 1.08,
              ),
              children: markedSpans(
                l10n.onboardingPrivateMessaging,
                HaloType.serif(
                  size: hero,
                  weight: FontWeight.w300,
                  italic: true,
                  color: HaloColors.amber,
                  height: 1.08,
                ),
              ),
            ),
            textScaler: _headScale(context),
          ),
        ),
        SizedBox(height: tight ? 22 : 28),
        _rise(0.4, 0.78, _bullet(l10n.onboardingYourNameIsThree)),
        SizedBox(height: tight ? 10 : 14),
        _rise(0.48, 0.86, _bullet(l10n.onboardingNobodyGetsInUnless)),
        SizedBox(height: tight ? 10 : 14),
        _rise(0.56, 0.94, _bullet(l10n.onboardingTheFirstConnectionTakes)),
        const Spacer(),
        const SizedBox(height: 24),
        _rise(
          0.68,
          1,
          Center(
            child: Text(
              l10n.onboardingKryfoIsOpenSource,
              textAlign: TextAlign.center,
              style: HaloType.mono(
                size: 10,
                color: HaloColors.text3,
              ).copyWith(letterSpacing: track(2)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _orb(double size) {
    return AnimatedBuilder(
      animation: Listenable.merge([_ctl, _in]),
      builder: (c, _) {
        final op = 0.7 + 0.3 * math.sin(_ctl.value * 2 * math.pi);
        final v = const Interval(0, 0.5).transform(_in.value);
        return Opacity(
          opacity: Curves.easeOut.transform(v),
          child: Transform.scale(
            scale: 0.6 + 0.4 * Curves.easeOutBack.transform(v),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.3),
                  colors: [HaloColors.amber, HaloColors.amberDeep],
                ),
                boxShadow: [
                  BoxShadow(
                    color: HaloColors.amber.withValues(alpha: 0.5 * op),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // the lead words carry the weight. the rest is warm, a step brighter than
  // the usual second line: this page has to be read
  Widget _bullet(String msg) {
    const size = 14.0;
    const height = 1.55;
    final line = MediaQuery.textScalerOf(context).scale(size) * height;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: EdgeInsetsDirectional.only(top: line / 2 - 3, end: 14),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: HaloColors.amber,
          ),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: HaloType.sans(
                size: size,
                color: HaloColors.warm,
                height: height,
              ),
              children: markedSpans(
                msg,
                HaloType.sans(
                  size: size,
                  color: HaloColors.text,
                  weight: FontWeight.w600,
                  height: height,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// === 02 · IDENTITY REVEAL ===

class _IdentityScreen extends StatefulWidget {
  final AppState appState;
  final VoidCallback onContinue;
  final bool enter;
  const _IdentityScreen({
    required this.appState,
    required this.onContinue,
    required this.enter,
  });
  @override
  State<_IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends State<_IdentityScreen>
    with TickerProviderStateMixin {
  // the reveal's timeline, in ms
  static const _length = 2400;
  late final AnimationController _shimmer;
  late final AnimationController _reveal;
  late final AnimationController _breath;
  // a new name: the old words lift away, the new ones land one by one
  late final AnimationController _roll;
  late final AnimationController _spin;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _length),
    );
    _roll = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
      value: 1,
    );
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  bool _shown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shown) return;
    _shown = true;
    // the name writes itself in, the shine and the ring play twice, then
    // rest. with less movement, or back on this step, it is simply there
    if (!widget.enter || MediaQuery.disableAnimationsOf(context)) {
      _reveal.value = 1;
      return;
    }
    _reveal.forward(from: 0);
    _shimmer.repeat(count: 2);
    _breath.repeat(count: 2).whenComplete(() {
      if (mounted) _breath.value = 0;
    });
  }

  @override
  void dispose() {
    _shimmer.dispose();
    _reveal.dispose();
    _breath.dispose();
    _roll.dispose();
    _spin.dispose();
    super.dispose();
  }

  // the first key's signal setup may still be running: the arrow turns
  // until the new name is ready, and taps meanwhile change nothing
  bool _busy = false;

  Future<void> _regenerate() async {
    if (_busy) return;
    final still = motionStill(context);
    _reveal.value = 1;
    setState(() {
      _busy = true;
      _leaving = !still;
      _held = widget.appState.sessionId;
    });
    if (!still) _spin.repeat();
    try {
      await Future.wait([
        widget.appState.regenerateIdentity(),
        if (!still)
          _roll
              .animateBack(
                0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInCubic,
              )
              .orCancel
              .catchError((_) {}),
      ]);
      HapticFeedback.lightImpact();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _leaving = false;
          _held = null;
        });
        if (!still) _land();
      }
    }
  }

  void _land() {
    _roll.forward(from: 0);
    _shimmer.forward(from: 0);
    // the arrow finishes its turn and rests
    _spin
        .animateTo(
          1,
          duration: Duration(milliseconds: (500 * (1 - _spin.value)).round()),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          if (mounted) _spin.value = 0;
        });
  }

  void _continue() {
    if (!_busy) widget.onContinue();
  }

  // the name on screen: the old one stays until the new one lands
  String? _held;
  String get _id => _held ?? widget.appState.sessionId;

  List<String> get _words {
    final id = _id;
    if (id.isEmpty) return ['...', '...', '...'];
    return id.split('-').take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final words = _words;
    return _StepPage(
      top: 8,
      cross: CrossAxisAlignment.center,
      footer: [
        _fadeAt(
          1650,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cta(label: l10n.onboardingUseThisName, onTap: _continue),
              const SizedBox(height: 10),
              _tryAnother(),
            ],
          ),
        ),
      ],
      children: [
        const Spacer(),
        _sigilReveal(),
        const SizedBox(height: 24),
        _fadeAt(
          300,
          child: Text(
            l10n.onboardingYourKryfoId,
            textAlign: TextAlign.center,
            style: HaloType.mono(
              size: 10,
              color: HaloColors.amber,
            ).copyWith(letterSpacing: track(4), fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 14),
        _shimmerPill(words),
        const SizedBox(height: 22),
        _fadeAt(1300, child: _italicLine()),
        const SizedBox(height: 12),
        _fadeAt(
          1450,
          // a plain SizedBox would let the fit pass measure this at the
          // full width and the page would overflow instead of scroll
          child: FitWidth(
            width: 280,
            child: Text.rich(
              TextSpan(
                style: HaloType.sans(
                  size: 12.5,
                  color: HaloColors.text2,
                  height: 1.55,
                ),
                children: markedSpans(
                  l10n.onboardingGeneratedFromAKey,
                  HaloType.sans(
                    size: 12.5,
                    color: HaloColors.text,
                    weight: FontWeight.w500,
                    height: 1.55,
                  ),
                ),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _tryAnother() {
    final still = motionStill(context);
    return PressScale(
      scale: 0.97,
      onTap: _regenerate,
      child: AnimatedOpacity(
        // with less movement nothing turns: the button dims while it works
        opacity: _busy && still ? 0.5 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(color: HaloColors.line2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RotationTransition(
                turns: _spin,
                child: Icon(
                  Icons.refresh_rounded,
                  key: _busy ? const ValueKey('regenerating') : null,
                  size: 17,
                  color: HaloColors.amber,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.onboardingTryAnother,
                  textAlign: TextAlign.center,
                  style: HaloType.sans(
                    size: 14,
                    color: HaloColors.text,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sigilReveal() {
    final still = motionStill(context);
    final seed = _id.isEmpty ? 'Kryfo' : _id;
    return AnimatedBuilder(
      animation: Listenable.merge([_breath, _reveal]),
      // a new name draws a new face: it pops in over the last
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: still ? 0 : 360),
        switchInCurve: kHouseCurve,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween(begin: 0.8, end: 1.0).animate(anim),
            child: child,
          ),
        ),
        child: KryfoAvatar(key: ValueKey(seed), seed: seed, size: 56),
      ),
      builder: (c, face) {
        final breath = 0.7 + 0.3 * math.sin(_breath.value * 2 * math.pi);
        final rv = (_reveal.value * _length / 1000).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(rv);
        return SizedBox(
          width: 88,
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // a warm light around the face, faded out before its edge
              Positioned(
                left: -66,
                top: -66,
                right: -66,
                bottom: -66,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: eased,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            HaloColors.amber.withValues(alpha: 0.10),
                            HaloColors.amber.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              CustomPaint(
                size: const Size(88, 88),
                painter: _HaloRingPainter(eased, breath),
              ),
              Opacity(
                opacity: eased,
                child: Transform.scale(
                  scale: 0.72 + 0.28 * Curves.easeOutBack.transform(rv),
                  child: face,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _italicLine() => Text.rich(
    TextSpan(
      style: HaloType.serif(
        size: 20,
        weight: FontWeight.w300,
        color: HaloColors.text,
        height: 1.25,
      ),
      children: markedSpans(
        l10n.onboardingThreeWords,
        HaloType.serif(
          size: 20,
          weight: FontWeight.w300,
          italic: true,
          color: HaloColors.amber,
          height: 1.25,
        ),
      ),
    ),
    textAlign: TextAlign.center,
  );

  Widget _shimmerPill(List<String> words) {
    final still = motionStill(context);
    // the id reads left to right in every language
    final name = Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr,
      children: [
        _wordReveal(words[0], 0, 350),
        _sep(1150),
        _wordReveal(words[1], 1, 600),
        _sep(1150),
        _wordReveal(words[2], 2, 850),
      ],
    );
    return AnimatedBuilder(
      animation: _shimmer,
      // long words at a large text size shrink the pill instead of
      // spilling past the screen
      builder: (c, _) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              decoration: BoxDecoration(
                color: HaloColors.amberSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: HaloColors.amber, width: 0.5),
              ),
              // the pill eases to the new name's width. a zero-length
              // size animation would relayout inside its own layout
              child: still
                  ? name
                  : AnimatedSize(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      child: name,
                    ),
            ),
            if (_shimmer.isAnimating)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: IgnorePointer(
                    child: ShaderMask(
                      blendMode: BlendMode.dstATop,
                      shaderCallback: (rect) {
                        final w = rect.width;
                        final t = _shimmer.value;
                        final x = -w + (w * 3) * t;
                        return LinearGradient(
                          begin: Alignment(x / w * 2 - 1, 0),
                          end: Alignment((x + w) / w * 2 - 1, 0),
                          colors: [
                            Colors.transparent,
                            HaloColors.amber.withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                        ).createShader(rect);
                      },
                      child: Container(color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _wordReveal(String word, int i, int delayMs) {
    return AnimatedBuilder(
      animation: Listenable.merge([_reveal, _roll]),
      builder: (c, _) {
        // the first time: written in from blur. a new name: the words
        // lift away together, then land one after another
        var v = ((_reveal.value * _length - delayMs) / 650).clamp(0.0, 1.0);
        var dy = (1 - v) * 10;
        if (_reveal.value >= 1) {
          if (_leaving) {
            v = Curves.easeIn.transform(_roll.value);
            dy = -(1 - v) * 8;
          } else {
            final t = ((_roll.value * 720 - i * 110) / 480).clamp(0.0, 1.0);
            v = Curves.easeOutCubic.transform(t);
            dy = (1 - Curves.easeOutBack.transform(t)) * 12;
          }
        }
        final blur = (1 - v) * 6;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: ImageFiltered(
              enabled: blur > 0.05,
              imageFilter: ui.ImageFilter.blur(
                sigmaX: blur,
                sigmaY: blur,
                tileMode: TileMode.decal,
              ),
              child: Text(
                word,
                style: HaloType.mono(size: 15, color: HaloColors.amber)
                    .copyWith(
                      letterSpacing: track(0.4),
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sep(int delayMs) => _fadeAt(
    delayMs,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Text('·', style: HaloType.mono(size: 15, color: HaloColors.text2)),
    ),
  );

  Widget _fadeAt(int delayMs, {required Widget child}) {
    return AnimatedBuilder(
      animation: _reveal,
      child: child,
      builder: (c, child) {
        final t = (_reveal.value * _length - delayMs) / 650;
        final v = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
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
}

class _HaloRingPainter extends CustomPainter {
  final double sweep; // 0..1 of a full circle
  final double glow; // 0..1 breath
  _HaloRingPainter(this.sweep, this.glow);
  @override
  void paint(Canvas canvas, Size size) {
    if (sweep <= 0) return;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = HaloColors.amber.withValues(alpha: 0.92)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 + 3.5 * glow);
    canvas.drawArc(rect, -math.pi / 2, sweep * 2 * math.pi, false, p);
  }

  @override
  bool shouldRepaint(_HaloRingPainter old) =>
      old.sweep != sweep || old.glow != glow;
}

// === 03 · PICK A FACE ===
//
// straight after the identity reveal, because the face is drawn from the id
// you have just been shown

class _PickFaceScreen extends StatefulWidget {
  final VoidCallback onContinue;
  const _PickFaceScreen({required this.onContinue});
  @override
  State<_PickFaceScreen> createState() => _PickFaceScreenState();
}

class _PickFaceScreenState extends State<_PickFaceScreen> {
  int? _choice = appState.myAvatar;
  bool _touched = false;

  Future<void> _saveAndGo() async {
    if (_touched) await appState.setMyAvatar(_choice);
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _pagePad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AvatarChoiceEditor(
              padding: const EdgeInsets.only(bottom: 12),
              caption: l10n.onboardingThePeopleYouMessage,
              onChanged: (c) => setState(() {
                _choice = c;
                _touched = true;
              }),
              // the heading scrolls with the choices, so a large text
              // size still leaves room for them
              header: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Headline(l10n.onboardingPickA),
                  const SizedBox(height: 12),
                  _lead(l10n.onboardingDrawnOnThisPhone),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Cta(
            label: _touched ? l10n.onboardingThatOne : l10n.onboardingContinue,
            onTap: _saveAndGo,
          ),
          const SizedBox(height: 4),
          Center(
            child: _TextLink(
              label: l10n.onboardingKeepMyInitial,
              onTap: widget.onContinue,
            ),
          ),
        ],
      ),
    );
  }
}

// === 04 · HOW YOUR MESSAGES TRAVEL ===
// three ways, each with its cost in plain words, onion picked already. one
// tap skips it and keeps the safest.

class _TransportScreen extends StatefulWidget {
  final VoidCallback onContinue;
  const _TransportScreen({required this.onContinue});
  @override
  State<_TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<_TransportScreen> {
  String _pick = 'private';
  bool _busy = false;

  Future<void> _go() async {
    if (_busy) return;
    setState(() => _busy = true);
    // written whatever was picked, onion too: a value left in storage by a
    // half-done wipe or an earlier install must not win over this choice
    await appState.setSendMode(_pick);
    if (mounted) widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    return _StepPage(
      footer: [
        _Cta(
          label: _pick == 'private'
              ? l10n.onboardingKeepOnion
              : l10n.onboardingUseThis,
          onTap: _go,
        ),
        const SizedBox(height: 2),
        Center(
          child: _TextLink(
            label: l10n.onboardingSkipOnionIsA,
            onTap: () async {
              // skip means onion. make it so rather than assume it.
              await appState.setSendMode('private');
              if (mounted) widget.onContinue();
            },
          ),
        ),
      ],
      children: [
        _Headline(l10n.onboardingHowYourMessages),
        const SizedBox(height: 12),
        _lead(l10n.onboardingYouCanChangeThis),
        const SizedBox(height: 24),
        ...staggerAll([
          _ModeCard(
            title: l10n.onboardingOnion,
            cost: l10n.onboardingSlowerAMessageTakes,
            gain: l10n.onboardingHidesYourAddressFrom,
            on: _pick == 'private',
            onTap: () => setState(() => _pick = 'private'),
          ),
          const SizedBox(height: 10),
          _ModeCard(
            title: l10n.onboardingRelay,
            cost: l10n.onboardingOurRelaySeesYour,
            gain: l10n.onboardingAboutASecondWorks,
            on: _pick == 'balanced',
            onTap: () => setState(() => _pick = 'balanced'),
          ),
          const SizedBox(height: 10),
          _ModeCard(
            title: l10n.onboardingFast,
            cost: l10n.onboardingEveryRelayYouUse,
            gain: l10n.onboardingNearInstant,
            on: _pick == 'fast',
            onTap: () => setState(() => _pick = 'fast'),
          ),
        ]),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String cost;
  final String gain;
  final bool on;
  final VoidCallback onTap;
  const _ModeCard({
    required this.title,
    required this.cost,
    required this.gain,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    // read as one radio: the title, the cost, the gain, and whether it is on
    return MergeSemantics(
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        checked: on,
        child: PressScale(
          scale: 0.98,
          onTap: onTap,
          child: AnimatedContainer(
            duration: Duration(milliseconds: still ? 0 : 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 16, 14),
            decoration: BoxDecoration(
              color: on
                  ? Color.alphaBlend(
                      HaloColors.amber.withValues(alpha: 0.10),
                      HaloColors.surface2,
                    )
                  : HaloColors.surface2,
              border: Border.all(
                color: on ? HaloColors.amber : HaloColors.line,
                width: on ? 1.2 : 0.5,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: HaloColors.amber.withValues(alpha: on ? 0.16 : 0),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: _Radio(on: on),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: HaloType.serif(size: 18, color: HaloColors.text),
                      ),
                      const SizedBox(height: 5),
                      // the cost first, then what it buys: a card that lists
                      // only benefits sends everyone to the fastest one
                      Text(
                        cost,
                        style: HaloType.sans(
                          size: 13,
                          color: HaloColors.text,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        gain,
                        style: HaloType.sans(
                          size: 13,
                          color: HaloColors.text2,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// a ring, and a dot that springs in when it is the one
class _Radio extends StatelessWidget {
  final bool on;
  const _Radio({required this.on});

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return AnimatedContainer(
      duration: Duration(milliseconds: still ? 0 : 200),
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: on ? HaloColors.amber : HaloColors.text3,
          width: 1.5,
        ),
      ),
      child: AnimatedScale(
        scale: on ? 1 : 0,
        duration: still ? Duration.zero : kHouseTime,
        curve: on ? kHouseCurve : Curves.easeInCubic,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: HaloColors.amber,
          ),
        ),
      ),
    );
  }
}

// === 05 · THREE THINGS ===
//
// the same three points the welcome page opened with, each with its why.
// rooms, vouching, the shield and modes are explained when they come up.

class _ThreeThingsScreen extends StatelessWidget {
  final VoidCallback onContinue;
  const _ThreeThingsScreen({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return _StepPage(
      footer: [_Cta(label: l10n.onboardingIUnderstand, onTap: onContinue)],
      children: [
        _Headline(l10n.onboardingThreeThingsThen),
        const SizedBox(height: 12),
        _lead(l10n.onboardingEverythingElseTheApp),
        const SizedBox(height: 24),
        ...staggerAll([
          _Card(
            num: 1,
            title: l10n.onboardingYourNameIsThreeWords,
            desc: l10n.onboardingThatIsTheWhole,
          ),
          const SizedBox(height: 10),
          _Card(
            num: 2,
            title: l10n.onboardingNobodyCanReachYou,
            desc: l10n.onboardingAStrangerWithYour,
          ),
          const SizedBox(height: 10),
          _Card(
            num: 3,
            title: l10n.onboardingTheFirstConnectionTakesAMinute,
            desc: l10n.onboardingKryfoBuildsAPrivateRouteBefore,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.onboardingYourIdentityLivesOn,
            style: HaloType.sans(
              size: 12.5,
              color: HaloColors.text2,
              height: 1.5,
            ),
          ),
        ], from: 1),
      ],
    );
  }
}

// === 06 · ONE NOTIFICATION ===
//
// the one android fact worth a page: a background listener needs a visible
// notification, so the tray will show one. two lines, then on.

class _NotificationScreen extends StatelessWidget {
  final VoidCallback onContinue;
  const _NotificationScreen({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return _StepPage(
      footer: [_Cta(label: l10n.onboardingGotIt, onTap: onContinue)],
      children: [
        _Headline(l10n.onboardingOneQuiet),
        const SizedBox(height: 12),
        _lead(l10n.onboardingAndroidNeedsAVisible),
        const SizedBox(height: 24),
        ...staggerAll([
          _Card(
            icon: Icons.notifications_none_rounded,
            title: l10n.onboardingSilentAndAtThe,
            desc: l10n.onboardingItNeverBuzzesTurn,
          ),
        ], from: 1),
      ],
    );
  }
}

// === 07 · ADD SOMEONE ===

class _AddSomeoneScreen extends StatelessWidget {
  final VoidCallback onComplete;
  const _AddSomeoneScreen({required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return _StepPage(
      footer: [
        Text(
          l10n.onboardingTheAppIsReadyWhenYou,
          textAlign: TextAlign.center,
          style: HaloType.serif(
            size: 17,
            weight: FontWeight.w300,
            italic: true,
            color: HaloColors.text2,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: _TextLink(
            label: l10n.onboardingNotNowAddPeople,
            onTap: onComplete,
          ),
        ),
      ],
      children: [
        _Headline(l10n.onboardingNow),
        const SizedBox(height: 12),
        _lead(l10n.onboardingTheAppIsReady),
        const SizedBox(height: 24),
        ...staggerAll([
          _Path(
            icon: Icons.qr_code_2_outlined,
            title: l10n.onboardingEveryWayToAdd,
            desc: l10n.onboardingShowYourCodeSend,
            onTap: () async {
              // open the page first, then finish onboarding once it
              // returns. completing first rebuilds the tree to home and
              // eats the nav.
              final nav = Navigator.of(context);
              await nav.push(haloRoute(const MyKryfoScreen()));
              onComplete();
            },
          ),
          const SizedBox(height: 10),
          _Path(
            icon: Icons.center_focus_weak,
            title: l10n.onboardingScanTheirs,
            desc: l10n.onboardingPointTheCameraAt,
            onTap: () async {
              final nav = Navigator.of(context);
              final raw = await nav.push<String>(
                haloRoute<String>(const ScanScreen()),
              );
              // the scanner only hands the code back; handleHaloUri is what
              // adds the contact
              if (raw != null) {
                final status = await handleHaloUri(raw);
                await appState.refreshContacts();
                if (context.mounted) showHaloToast(context, status);
              }
              onComplete();
            },
          ),
        ], from: 1),
      ],
    );
  }
}

// ───────── shared pieces ─────────

// every step sits under the step bar with the same margins
const _pagePad = EdgeInsets.fromLTRB(28, 16, 28, 20);

// a step: what it says scrolls when it has to, its buttons stay in reach
// at the bottom
class _StepPage extends StatelessWidget {
  final double top;
  final CrossAxisAlignment cross;
  final List<Widget> children;
  final List<Widget> footer;
  const _StepPage({
    this.top = 16,
    this.cross = CrossAxisAlignment.stretch,
    required this.children,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          // what scrolls under the bar or the buttons fades out at the
          // edge instead of being cut
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [
                Color(0x00000000),
                Color(0xFF000000),
                Color(0xFF000000),
                Color(0x00000000),
              ],
              stops: [
                0,
                math.min(8 / r.height, 0.2),
                math.max(1 - 16 / r.height, 0.8),
                1,
              ],
            ).createShader(r),
            child: FitColumn(
              padding: _pagePad.copyWith(top: top, bottom: 16),
              crossAxisAlignment: cross,
              children: children,
            ),
          ),
        ),
        Padding(
          padding: _pagePad.copyWith(top: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: footer,
          ),
        ),
      ],
    );
  }
}

// big type grows less with the text size: a long word at the full scale
// would not fit the line
TextScaler _headScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15);

class _Headline extends StatelessWidget {
  final String msg;
  const _Headline(this.msg);

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: HaloType.serif(
          size: 30,
          weight: FontWeight.w300,
          color: HaloColors.text,
          height: 1.1,
        ),
        children: markedSpans(
          msg,
          HaloType.serif(
            size: 30,
            weight: FontWeight.w300,
            italic: true,
            color: HaloColors.amber,
            height: 1.1,
          ),
        ),
      ),
      textScaler: _headScale(context),
    );
  }
}

Widget _lead(String msg) => Text(
  msg,
  style: HaloType.sans(size: 14, color: HaloColors.text2, height: 1.55),
);

// the amber tile a card leads with: its number or its icon
class _Badge extends StatelessWidget {
  final Widget child;
  const _Badge({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HaloColors.amberSoft,
        border: Border.all(
          color: HaloColors.amber.withValues(alpha: 0.55),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class _Card extends StatelessWidget {
  final int? num;
  final IconData? icon;
  final String title;
  final String desc;
  const _Card({this.num, this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 16, 15),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        border: Border.all(color: HaloColors.line, width: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Badge(
            child: num != null
                ? Text(
                    twoDigits(num!),
                    textScaler: TextScaler.noScaling,
                    style: HaloType.mono(size: 11, color: HaloColors.amber)
                        .copyWith(
                          letterSpacing: track(0.5),
                          fontWeight: FontWeight.w600,
                        ),
                  )
                : Icon(icon, size: 17, color: HaloColors.amber),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 1),
                Text(
                  title,
                  style: HaloType.sans(
                    size: 14,
                    color: HaloColors.text,
                    weight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: HaloType.sans(
                    size: 13,
                    color: HaloColors.text2,
                    height: 1.5,
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

class _Path extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final VoidCallback onTap;
  const _Path({
    required this.icon,
    required this.title,
    required this.desc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      scale: 0.98,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 15, 14, 15),
        decoration: BoxDecoration(
          color: HaloColors.surface2,
          border: Border.all(color: HaloColors.line, width: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _Badge(child: Icon(icon, size: 17, color: HaloColors.amber)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: HaloType.sans(
                      size: 14,
                      color: HaloColors.text,
                      weight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: HaloType.sans(
                      size: 12.5,
                      color: HaloColors.text2,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // points the way reading goes
            Transform.flip(
              flipX: Directionality.of(context) == TextDirection.rtl,
              child: Text(
                '→',
                style: HaloType.sans(size: 18, color: HaloColors.text2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// the main button of a step. a new label crossfades in
class _Cta extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Cta({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return PressScale(
      scale: 0.97,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: HaloColors.amber,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: Duration(milliseconds: still ? 0 : 200),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween(begin: 0.94, end: 1.0).animate(anim),
              child: child,
            ),
          ),
          child: Text(
            label,
            key: ValueKey(label),
            textAlign: TextAlign.center,
            style: HaloType.sans(
              size: 15,
              color: HaloColors.onAmber,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// the quiet way past a step: plain words, a full finger's height
class _TextLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TextLink({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: HaloType.sans(
            size: 13,
            color: HaloColors.text2,
            weight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
