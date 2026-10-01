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
import '../widgets/motion.dart' show haloRoute, motionStill;
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
  final _ctrl = PageController();
  int _page = 0;

  void _next() {
    // with less movement the next step is simply there
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl.jumpToPage((_ctrl.page ?? 0).round() + 1);
      return;
    }
    _ctrl.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  // system back walks one step back; only the first step leaves the app
  void _back() {
    final to = (_ctrl.page ?? _page.toDouble()).round() - 1;
    if (to < 0) return;
    HapticFeedback.selectionClick();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl.jumpToPage(to);
      return;
    }
    _ctrl.animateToPage(
      to,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (done, _) {
        if (!done) _back();
      },
      child: Scaffold(
        backgroundColor: HaloColors.ink,
        body: SafeArea(
          child: PageView(
            controller: _ctrl,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              _WelcomeScreen(onContinue: _next),
              _IdentityScreen(appState: widget.appState, onContinue: _next),
              _PickFaceScreen(onContinue: _next),
              _TransportScreen(onContinue: _next),
              _ThreeThingsScreen(onContinue: _next),
              _NotificationScreen(onContinue: _next),
              _AddSomeoneScreen(onComplete: widget.onComplete),
            ],
          ),
        ),
      ),
    );
  }
}

// === 01 · WELCOME ===

class _WelcomeScreen extends StatefulWidget {
  final VoidCallback onContinue;
  const _WelcomeScreen({required this.onContinue});
  @override
  State<_WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<_WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  bool _glowed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // two slow glows as the page opens, then it rests: nothing loops while
    // someone reads
    if (_glowed || MediaQuery.disableAnimationsOf(context)) return;
    _glowed = true;
    // a whole number of glows ends where it began
    _ctl.repeat(count: 2).whenComplete(() {
      if (mounted) _ctl.value = 0;
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _welcome(),
        const PositionedDirectional(top: 5, end: 11, child: LanguageChip()),
      ],
    );
  }

  Widget _welcome() {
    return FitColumn(
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 36),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: _ctl,
          builder: (c, _) {
            final op = 0.7 + 0.3 * math.sin(_ctl.value * 2 * math.pi);
            return Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-0.3, -0.3),
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
            );
          },
        ),
        const SizedBox(height: 28),
        Text(
          l10n.onboardingPrivateByDefault,
          style: HaloType.mono(
            size: 10,
            color: HaloColors.amber,
          ).copyWith(letterSpacing: track(4), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 22),
        RichText(
          text: TextSpan(
            style: HaloType.serif(
              size: 38,
              weight: FontWeight.w300,
              color: HaloColors.text,
              height: 1.05,
            ),
            children: markedSpans(
              l10n.onboardingPrivateMessaging,
              HaloType.serif(
                size: 38,
                weight: FontWeight.w300,
                italic: true,
                color: HaloColors.amber,
                height: 1.05,
              ),
            ),
          ),
        ),
        const SizedBox(height: 26),
        _bullet(l10n.onboardingYourNameIsThree),
        const SizedBox(height: 13),
        _bullet(l10n.onboardingNobodyGetsInUnless),
        const SizedBox(height: 13),
        _bullet(l10n.onboardingTheFirstConnectionTakes),
        const Spacer(),
        PressScale(
          scale: 0.97,
          onTap: widget.onContinue,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: HaloColors.amber,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              l10n.onboardingBegin,
              style: HaloType.sans(
                size: 14,
                color: HaloColors.onAmber,
                weight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: PressScale(
            onTap: () {
              Navigator.of(context).push(haloRoute(const RestoreScreen()));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                l10n.onboardingHaveABackupRestore,
                style: HaloType.sans(size: 12, color: HaloColors.text2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            l10n.onboardingKryfoIsOpenSource,
            style: HaloType.mono(
              size: 10,
              color: HaloColors.text3,
            ).copyWith(letterSpacing: track(2)),
          ),
        ),
      ],
    );
  }

  Widget _bullet(String msg) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 12,
        height: 0.5,
        color: HaloColors.amber,
        margin: const EdgeInsetsDirectional.only(top: 10, end: 12),
      ),
      Expanded(
        child: RichText(
          text: TextSpan(
            style: HaloType.sans(
              size: 13.5,
              color: HaloColors.text2,
              height: 1.6,
            ),
            children: markedSpans(
              msg,
              HaloType.sans(
                size: 13.5,
                color: HaloColors.text,
                weight: FontWeight.w500,
                height: 1.6,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

// === 02 · IDENTITY REVEAL ===

class _IdentityScreen extends StatefulWidget {
  final AppState appState;
  final VoidCallback onContinue;
  const _IdentityScreen({required this.appState, required this.onContinue});
  @override
  State<_IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends State<_IdentityScreen>
    with TickerProviderStateMixin {
  late final AnimationController _shimmer;
  late final AnimationController _reveal;
  late final AnimationController _breath;
  int _revealKey = 0;

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
      duration: const Duration(milliseconds: 3000),
    );
  }

  bool _shown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shown) return;
    _shown = true;
    _play();
  }

  // the name writes itself in, the shine and the ring play twice, then
  // rest. with less movement it is simply there
  void _play() {
    if (MediaQuery.disableAnimationsOf(context)) {
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
    super.dispose();
  }

  // the first key's signal setup may still be running: the button turns
  // until the new name is ready, and taps meanwhile change nothing
  bool _busy = false;

  Future<void> _regenerate() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.appState.regenerateIdentity();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    setState(() => _revealKey++);
    _play();
  }

  void _continue() {
    if (!_busy) widget.onContinue();
  }

  List<String> get _words {
    final id = widget.appState.sessionId;
    if (id.isEmpty) return ['...', '...', '...'];
    return id.split('-').take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final words = _words;
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.4),
          radius: 0.9,
          colors: [
            HaloColors.amber.withValues(alpha: 0.06),
            Colors.transparent,
          ],
        ),
      ),
      child: FitColumn(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
        children: [
          const Spacer(),
          _sigilReveal(),
          const SizedBox(height: 22),
          Text(
            l10n.onboardingYourKryfoId,
            style: HaloType.mono(
              size: 10,
              color: HaloColors.amber,
            ).copyWith(letterSpacing: track(4), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 14),
          _shimmerPill(words),
          const SizedBox(height: 18),
          _fadeAt(1500, child: _italicLine()),
          const SizedBox(height: 14),
          _fadeAt(
            1800,
            // a plain SizedBox would let the fit pass measure this at the
            // full width and the page would overflow instead of scroll
            child: FitWidth(
              width: 240,
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: HaloType.sans(
                    size: 11,
                    color: HaloColors.text3,
                    height: 1.55,
                  ),
                  children: markedSpans(
                    l10n.onboardingGeneratedFromAKey,
                    HaloType.sans(
                      size: 11,
                      color: HaloColors.text2,
                      weight: FontWeight.w500,
                      height: 1.55,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          _fadeAt(
            2100,
            // side by side while they fit; when they don't, the main
            // one goes on top
            child: Wrap(
              alignment: WrapAlignment.center,
              verticalDirection: VerticalDirection.up,
              spacing: 10,
              runSpacing: 10,
              children: [
                PressScale(
                  scale: 0.96,
                  onTap: _regenerate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: HaloColors.line2, width: 0.5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    // the label keeps the size while the arc turns
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: _busy ? 0 : 1,
                          child: Text(
                            l10n.onboardingTryAnother,
                            textAlign: TextAlign.center,
                            style: HaloType.sans(
                              size: 12,
                              color: HaloColors.text2,
                            ),
                          ),
                        ),
                        if (_busy)
                          SizedBox(
                            key: const ValueKey('regenerating'),
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              value: motionStill(context) ? 0.3 : null,
                              strokeWidth: 1.5,
                              color: HaloColors.text2,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                PressScale(
                  scale: 0.96,
                  onTap: _continue,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: HaloColors.amber,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l10n.onboardingUseThisName,
                      textAlign: TextAlign.center,
                      style: HaloType.sans(
                        size: 12,
                        color: HaloColors.onAmber,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _sigilReveal() {
    return AnimatedBuilder(
      animation: Listenable.merge([_breath, _reveal]),
      builder: (c, _) {
        final breath = 0.7 + 0.3 * math.sin(_breath.value * 2 * math.pi);
        final rv = (_reveal.value * 3000 / 1100).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(rv);
        return SizedBox(
          width: 88,
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(88, 88),
                painter: _HaloRingPainter(eased, breath),
              ),
              Opacity(
                opacity: eased,
                child: Transform.scale(
                  scale: 0.72 + 0.28 * eased,
                  child: KryfoAvatar(
                    seed: widget.appState.sessionId.isEmpty
                        ? 'Kryfo'
                        : widget.appState.sessionId,
                    size: 56,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _italicLine() => RichText(
    textAlign: TextAlign.center,
    text: TextSpan(
      style: HaloType.serif(
        size: 19,
        weight: FontWeight.w300,
        color: HaloColors.text,
        height: 1.25,
      ),
      children: markedSpans(
        l10n.onboardingThreeWords,
        HaloType.serif(
          size: 19,
          weight: FontWeight.w300,
          italic: true,
          color: HaloColors.amber,
          height: 1.25,
        ),
      ),
    ),
  );

  Widget _shimmerPill(List<String> words) {
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: HaloColors.amberSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: HaloColors.amber, width: 0.5),
              ),
              child: Row(
                key: ValueKey(_revealKey),
                mainAxisSize: MainAxisSize.min,
                children: [
                  _wordReveal(words[0], 200),
                  _sep(1300),
                  _wordReveal(words[1], 600),
                  _sep(1300),
                  _wordReveal(words[2], 1000),
                ],
              ),
            ),
            if (_shimmer.isAnimating)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
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

  Widget _wordReveal(String word, int delayMs) {
    return AnimatedBuilder(
      animation: _reveal,
      builder: (c, _) {
        final t = (_reveal.value * 3000 - delayMs) / 700;
        final v = t.clamp(0.0, 1.0);
        final blur = (1 - v) * 6;
        final dy = (1 - v) * 10;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: blur,
                sigmaY: blur,
                tileMode: TileMode.decal,
              ),
              child: Text(
                word,
                style: HaloType.mono(size: 14, color: HaloColors.amber)
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text('·', style: HaloType.mono(size: 14, color: HaloColors.text3)),
    ),
  );

  Widget _fadeAt(int delayMs, {required Widget child}) {
    return AnimatedBuilder(
      animation: _reveal,
      builder: (c, _) {
        final t = (_reveal.value * 3000 - delayMs) / 700;
        final v = t.clamp(0.0, 1.0);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 8),
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
      padding: const EdgeInsets.fromLTRB(28, 44, 28, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              header: _heading(),
            ),
          ),
          // side by side while they fit; when they don't, the main one
          // goes on top
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            verticalDirection: VerticalDirection.up,
            runSpacing: 6,
            children: [
              PressScale(
                onTap: widget.onContinue,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 11,
                  ),
                  child: Text(
                    l10n.onboardingKeepMyInitial,
                    style: HaloType.sans(size: 12, color: HaloColors.text2),
                  ),
                ),
              ),
              PressScale(
                scale: 0.96,
                onTap: _saveAndGo,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: HaloColors.amber,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _touched ? l10n.onboardingThatOne : l10n.onboardingContinue,
                    textAlign: TextAlign.center,
                    style: HaloType.sans(
                      size: 12,
                      color: HaloColors.onAmber,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Step(3),
        const SizedBox(height: 22),
        RichText(
          text: TextSpan(
            style: HaloType.serif(
              size: 30,
              weight: FontWeight.w300,
              color: HaloColors.text,
              height: 1.05,
            ),
            children: markedSpans(
              l10n.onboardingPickA,
              HaloType.serif(
                size: 30,
                weight: FontWeight.w300,
                italic: true,
                color: HaloColors.amber,
                height: 1.05,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.onboardingDrawnOnThisPhone,
          style: HaloType.sans(
            size: 13.5,
            color: HaloColors.text2,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 20),
      ],
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
    return FitColumn(
      padding: const EdgeInsets.fromLTRB(28, 44, 28, 36),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Step(4),
        const SizedBox(height: 22),
        _headline(l10n.onboardingHowYourMessages),
        const SizedBox(height: 12),
        Text(
          l10n.onboardingYouCanChangeThis,
          style: HaloType.sans(
            size: 13.5,
            color: HaloColors.text2,
            height: 1.55,
          ),
        ),
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
        const Spacer(),
        _Cta(
          label: _pick == 'private'
              ? l10n.onboardingKeepOnion
              : l10n.onboardingUseThis,
          onTap: _go,
        ),
        const SizedBox(height: 10),
        Center(
          child: PressScale(
            onTap: () async {
              // skip means onion. make it so rather than assume it.
              await appState.setSendMode('private');
              if (mounted) widget.onContinue();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                l10n.onboardingSkipOnionIsA,
                style: HaloType.sans(size: 13, color: HaloColors.text2),
              ),
            ),
          ),
        ),
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
    return PressScale(
      scale: 0.98,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
        decoration: BoxDecoration(
          color: on
              ? HaloColors.amber.withValues(alpha: 0.10)
              : HaloColors.surface2,
          border: Border.all(
            color: on ? HaloColors.amber : HaloColors.line,
            width: on ? 1 : 0.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                on ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18,
                color: on ? HaloColors.amber : HaloColors.text3,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: HaloType.serif(size: 17, color: HaloColors.text),
                  ),
                  const SizedBox(height: 4),
                  // the cost first, then what it buys: a card that lists
                  // only benefits sends everyone to the fastest one
                  Text(
                    cost,
                    style: HaloType.sans(
                      size: 12.5,
                      color: HaloColors.text,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    gain,
                    style: HaloType.sans(
                      size: 12.5,
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
    return FitColumn(
      padding: const EdgeInsets.fromLTRB(28, 44, 28, 36),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Step(5),
        const SizedBox(height: 22),
        _headline(l10n.onboardingThreeThingsThen),
        const SizedBox(height: 12),
        Text(
          l10n.onboardingEverythingElseTheApp,
          style: HaloType.sans(
            size: 13.5,
            color: HaloColors.text2,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 24),
        ...staggerAll([
          _Card(
            num: 1,
            title: l10n.onboardingYourNameIsThreeWords,
            desc: l10n.onboardingThatIsTheWhole,
          ),
          const SizedBox(height: 12),
          _Card(
            num: 2,
            title: l10n.onboardingNobodyCanReachYou,
            desc: l10n.onboardingAStrangerWithYour,
          ),
          const SizedBox(height: 12),
          _Card(
            num: 3,
            title: l10n.onboardingTheFirstConnectionTakesAMinute,
            desc: l10n.onboardingKryfoBuildsAPrivateRouteBefore,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.onboardingYourIdentityLivesOn,
            style: HaloType.sans(
              size: 12,
              color: HaloColors.text3,
              height: 1.5,
            ),
          ),
        ], from: 1),
        const Spacer(),
        _Cta(label: l10n.onboardingIUnderstand, onTap: onContinue),
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
    return FitColumn(
      padding: const EdgeInsets.fromLTRB(28, 44, 28, 36),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Step(6),
        const SizedBox(height: 22),
        _headline(l10n.onboardingOneQuiet),
        const SizedBox(height: 12),
        Text(
          l10n.onboardingAndroidNeedsAVisible,
          style: HaloType.sans(
            size: 13.5,
            color: HaloColors.text2,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 24),
        ...staggerAll([
          _Card(
            icon: Icons.notifications_none,
            title: l10n.onboardingSilentAndAtThe,
            desc: l10n.onboardingItNeverBuzzesTurn,
          ),
        ], from: 1),
        const Spacer(),
        _Cta(label: l10n.onboardingGotIt, onTap: onContinue),
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
    return FitColumn(
      padding: const EdgeInsets.fromLTRB(28, 44, 28, 36),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Step(7),
        const SizedBox(height: 22),
        _headline(l10n.onboardingNow),
        const SizedBox(height: 12),
        Text(
          l10n.onboardingTheAppIsReady,
          style: HaloType.sans(
            size: 13.5,
            color: HaloColors.text2,
            height: 1.55,
          ),
        ),
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
          const SizedBox(height: 12),
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
        const Spacer(),
        Center(
          child: Text(
            l10n.onboardingTheAppIsReadyWhenYou,
            textAlign: TextAlign.center,
            style: HaloType.serif(
              size: 16,
              weight: FontWeight.w300,
              italic: true,
              color: HaloColors.text2,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: PressScale(
            onTap: onComplete,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              child: Text(
                l10n.onboardingNotNowAddPeople,
                textAlign: TextAlign.center,
                style: HaloType.sans(size: 12.5, color: HaloColors.text2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ───────── shared pieces ─────────

// "04 / 07" in mono, so the pace is visible without a progress bar
class _Step extends StatelessWidget {
  final int n;
  const _Step(this.n);
  @override
  Widget build(BuildContext context) {
    return Text(
      '${twoDigits(n)} / ${twoDigits(7)}',
      style: HaloType.mono(
        size: 10,
        color: HaloColors.amber,
      ).copyWith(letterSpacing: track(3), fontWeight: FontWeight.w500),
    );
  }
}

Widget _headline(String msg) => RichText(
  text: TextSpan(
    style: HaloType.serif(
      size: 30,
      weight: FontWeight.w300,
      color: HaloColors.text,
      height: 1.05,
    ),
    children: markedSpans(
      msg,
      HaloType.serif(
        size: 30,
        weight: FontWeight.w300,
        italic: true,
        color: HaloColors.amber,
        height: 1.05,
      ),
    ),
  ),
);

class _Card extends StatelessWidget {
  final int? num;
  final IconData? icon;
  final String title;
  final String desc;
  const _Card({this.num, this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        border: Border.all(color: HaloColors.line, width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: num != null
                ? Text(
                    twoDigits(num!),
                    style: HaloType.mono(size: 10, color: HaloColors.amber)
                        .copyWith(
                          letterSpacing: track(2),
                          fontWeight: FontWeight.w500,
                        ),
                  )
                : Icon(icon, size: 16, color: HaloColors.amber),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: HaloType.sans(
                    size: 13,
                    color: HaloColors.text,
                    weight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: HaloType.sans(
                    size: 12.5,
                    color: HaloColors.text2,
                    height: 1.55,
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
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: HaloColors.surface2,
          border: Border.all(color: HaloColors.line, width: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: HaloColors.amberSoft,
                border: Border.all(color: HaloColors.amber, width: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: HaloColors.amber),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: HaloType.sans(
                      size: 13,
                      color: HaloColors.text,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: HaloType.sans(
                      size: 11,
                      color: HaloColors.text3,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            // points the way reading goes
            Transform.flip(
              flipX: Directionality.of(context) == TextDirection.rtl,
              child: Text(
                '→',
                style: HaloType.sans(size: 18, color: HaloColors.text3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cta extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Cta({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return PressScale(
      scale: 0.97,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: HaloColors.amber,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: HaloType.sans(
            size: 14,
            color: HaloColors.onAmber,
            weight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
