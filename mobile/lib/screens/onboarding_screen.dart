// halo onboarding flow — 5 screens shown on first launch, then never again.
// welcome → identity reveal → keep safe → staying connected → first contact.

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme.dart';
import 'restore_screen.dart';
import '../main.dart' show appState;
import '../main.dart';
import 'scan_screen.dart';
import '../widgets/halo_avatar.dart';

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

  void _next() {
    _ctrl.nextPage(
      duration: const Duration(milliseconds: 380),
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
    return Scaffold(
      backgroundColor: HaloColors.ink,
      body: SafeArea(
        child: PageView(
          controller: _ctrl,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _WelcomeScreen(onContinue: _next),
            _IdentityScreen(appState: widget.appState, onContinue: _next),
            _KeepSafeScreen(onContinue: _next),
            _StayingConnectedScreen(onContinue: _next),
            _FirstContactScreen(onComplete: widget.onComplete),
          ],
        ),
      ),
    );
  }
}

// === 02 · WELCOME ===

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
    )..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 36),
      child: Column(
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
            'PRIVATE BY DEFAULT',
            style: HaloType.mono(
              size: 10,
              color: HaloColors.amber,
            ).copyWith(letterSpacing: 4, fontWeight: FontWeight.w500),
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
              children: [
                const TextSpan(text: 'private messaging,\n'),
                TextSpan(
                  text: 'without the catch',
                  style: HaloType.serif(
                    size: 38,
                    weight: FontWeight.w300,
                    italic: true,
                    color: HaloColors.amber,
                    height: 1.05,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 26),
          _bullet('no phone, no email.', 'nothing tying this app to you.'),
          const SizedBox(height: 13),
          _bullet(
            'no servers.',
            'messages travel directly between devices, end-to-end encrypted.',
          ),
          const SizedBox(height: 13),
          _bullet(
            'onion-routed.',
            "your IP stays hidden. nobody sees who's talking to whom.",
          ),
          const Spacer(),
          GestureDetector(
            onTap: widget.onContinue,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: HaloColors.amber,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Text(
                'begin',
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
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RestoreScreen()),
                );
              },
              child: Text(
                'have a backup? restore →',
                style: HaloType.sans(size: 12, color: HaloColors.text2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'halo is open source',
              style: HaloType.mono(
                size: 10,
                color: HaloColors.text3,
              ).copyWith(letterSpacing: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String bold, String rest) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 12,
        height: 0.5,
        color: HaloColors.amber,
        margin: const EdgeInsets.only(top: 10, right: 12),
      ),
      Expanded(
        child: RichText(
          text: TextSpan(
            style: HaloType.sans(
              size: 13.5,
              color: HaloColors.text2,
              height: 1.6,
            ),
            children: [
              TextSpan(
                text: '$bold ',
                style: HaloType.sans(
                  size: 13.5,
                  color: HaloColors.text,
                  weight: FontWeight.w500,
                  height: 1.6,
                ),
              ),
              TextSpan(text: rest),
            ],
          ),
        ),
      ),
    ],
  );
}

// === 03 · IDENTITY REVEAL ===

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
    )..repeat();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _reveal.forward();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    _reveal.dispose();
    _breath.dispose();
    super.dispose();
  }

  Future<void> _regenerate() async {
    await widget.appState.regenerateIdentity();
    setState(() {
      _revealKey++;
      _reveal.reset();
      _reveal.forward();
    });
  }

  List<String> get _words {
    final id = widget.appState.myId;
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            _sigilReveal(),
            const SizedBox(height: 22),
            Text(
              'YOUR HALO ID',
              style: HaloType.mono(
                size: 10,
                color: HaloColors.amber,
              ).copyWith(letterSpacing: 4, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 14),
            _shimmerPill(words),
            const SizedBox(height: 18),
            _fadeAt(1500, child: _italicLine()),
            const SizedBox(height: 14),
            _fadeAt(
              1800,
              child: SizedBox(
                width: 240,
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: HaloType.sans(
                      size: 11,
                      color: HaloColors.text3,
                      height: 1.55,
                    ),
                    children: [
                      const TextSpan(text: 'no phone, no email. '),
                      TextSpan(
                        text: 'these three words are your identity',
                        style: HaloType.sans(
                          size: 11,
                          color: HaloColors.text2,
                          weight: FontWeight.w500,
                          height: 1.55,
                        ),
                      ),
                      const TextSpan(
                        text:
                            ', derived from a key that lives only on this device.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            _fadeAt(
              2100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
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
                      child: Text(
                        'regenerate',
                        style: HaloType.sans(size: 12, color: HaloColors.text2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: widget.onContinue,
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
                        'this is me \u2192',
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
                  child: HaloAvatar(
                    seed: widget.appState.myId.isEmpty
                        ? 'halo'
                        : widget.appState.myId,
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
      children: [
        const TextSpan(text: 'three words. '),
        TextSpan(
          text: 'yours alone.',
          style: HaloType.serif(
            size: 19,
            weight: FontWeight.w300,
            italic: true,
            color: HaloColors.amber,
            height: 1.25,
          ),
        ),
      ],
    ),
  );

  Widget _shimmerPill(List<String> words) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (c, _) {
        return Stack(
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
        );
      },
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
                style: HaloType.mono(
                  size: 14,
                  color: HaloColors.amber,
                ).copyWith(letterSpacing: 0.4, fontWeight: FontWeight.w500),
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
      child: Text(
        '\u00b7',
        style: HaloType.mono(size: 14, color: HaloColors.text3),
      ),
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

// === 04 · KEEP SAFE ===

class _KeepSafeScreen extends StatelessWidget {
  final VoidCallback onContinue;
  const _KeepSafeScreen({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 50, 28, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              border: Border.all(color: HaloColors.amber, width: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '!',
              style: HaloType.sans(
                size: 16,
                color: HaloColors.amber,
                weight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          RichText(
            text: TextSpan(
              style: HaloType.serif(
                size: 30,
                weight: FontWeight.w300,
                color: HaloColors.text,
                height: 1.05,
              ),
              children: [
                const TextSpan(text: 'three things to '),
                TextSpan(
                  text: 'know',
                  style: HaloType.serif(
                    size: 30,
                    weight: FontWeight.w300,
                    italic: true,
                    color: HaloColors.amber,
                    height: 1.05,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'read these. they matter more than the app itself.',
            style: HaloType.sans(
              size: 13.5,
              color: HaloColors.text2,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 24),
          _rule(
            '01',
            'write your halo down',
            'your three words are the only key. paper, password manager, anywhere safe. losing them means losing this identity for good — there\'s no recovery, by design.',
          ),
          const SizedBox(height: 12),
          _rule(
            '02',
            'first connection takes a few minutes',
            'we\'re routing through anonymous relays so no one can see your IP. it\'s slow the first time, fast after. trust the process — the wait is the privacy guarantee.',
          ),
          const SizedBox(height: 12),
          _rule(
            '03',
            'both of you have to be online',
            'messages travel directly, peer to peer. if your friend\'s app isn\'t open, your message waits in your outbox until they\'re back.',
          ),
          const Spacer(),
          GestureDetector(
            onTap: onContinue,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: HaloColors.amber,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Text(
                'i understand \u2192',
                style: HaloType.sans(
                  size: 14,
                  color: HaloColors.onAmber,
                  weight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rule(String num, String title, String desc) => Container(
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
          child: Text(
            num,
            style: HaloType.mono(
              size: 10,
              color: HaloColors.amber,
            ).copyWith(letterSpacing: 2, fontWeight: FontWeight.w500),
          ),
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
                  size: 11.5,
                  color: HaloColors.text3,
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

// === 04b · STAYING CONNECTED ===

class _StayingConnectedScreen extends StatelessWidget {
  final VoidCallback onContinue;
  const _StayingConnectedScreen({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 50, 28, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              border: Border.all(color: HaloColors.amber, width: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.lock_outline, size: 18, color: HaloColors.amber),
          ),
          const SizedBox(height: 24),
          RichText(
            text: TextSpan(
              style: HaloType.serif(
                size: 30,
                weight: FontWeight.w300,
                color: HaloColors.text,
                height: 1.05,
              ),
              children: [
                const TextSpan(text: 'staying '),
                TextSpan(
                  text: 'connected',
                  style: HaloType.serif(
                    size: 30,
                    weight: FontWeight.w300,
                    italic: true,
                    color: HaloColors.amber,
                    height: 1.05,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'halo keeps one small notification in your tray. here is what it is for.',
            style: HaloType.sans(
              size: 13.5,
              color: HaloColors.text2,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 24),
          _point(
            'it keeps your line open',
            'halo listens through tor in the background so encrypted messages reach you even when the app is closed. android requires a visible notification while it does that.',
          ),
          const SizedBox(height: 12),
          _point(
            'it is safe to leave on',
            'the notification is silent and sits at the bottom of your shade. turning it off does not make halo lighter — it just stops messages arriving until you reopen the app.',
          ),
          const Spacer(),
          GestureDetector(
            onTap: onContinue,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: HaloColors.amber,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Text(
                'got it →',
                style: HaloType.sans(
                  size: 14,
                  color: HaloColors.onAmber,
                  weight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _point(String title, String desc) => Container(
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
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: HaloColors.amber,
              shape: BoxShape.circle,
            ),
          ),
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
                  size: 11.5,
                  color: HaloColors.text3,
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

// === 05 · FIRST CONTACT ===

class _FirstContactScreen extends StatelessWidget {
  final VoidCallback onComplete;
  const _FirstContactScreen({required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 50, 28, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: HaloType.serif(
                size: 30,
                weight: FontWeight.w300,
                color: HaloColors.text,
                height: 1.05,
              ),
              children: [
                const TextSpan(text: 'now, '),
                TextSpan(
                  text: 'find someone',
                  style: HaloType.serif(
                    size: 30,
                    weight: FontWeight.w300,
                    italic: true,
                    color: HaloColors.amber,
                    height: 1.05,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'the app is ready. messages will be encrypted, onion-routed, and forgotten by everyone except you and them.',
            style: HaloType.sans(
              size: 13.5,
              color: HaloColors.text2,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 24),
          _path('show my halo', 'share a QR code with someone next to you', () {
            onComplete();
          }),
          const SizedBox(height: 12),
          _path(
            'scan a halo',
            "scan a friend's QR code or paste their three words",
            () async {
              // open the scanner first, then finish onboarding once it returns.
              // marking onboarding done first rebuilt the tree to home and ate the
              // navigation, dropping the user on home with no camera.
              final nav = Navigator.of(context);
              await nav.push(
                MaterialPageRoute(builder: (_) => const ScanScreen()),
              );
              onComplete();
            },
          ),
          const Spacer(),
          Center(
            child: Text(
              'the app is ready when you are.',
              style: HaloType.serif(
                size: 16,
                weight: FontWeight.w300,
                italic: true,
                color: HaloColors.text2,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: GestureDetector(
              onTap: onComplete,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: HaloColors.amber,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'skip \u00b7 find people later',
                  style: HaloType.sans(
                    size: 12,
                    color: HaloColors.onAmber,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _path(String title, String desc, VoidCallback onTap) {
    return GestureDetector(
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
              child: Text(
                title.startsWith('show') ? '\u229E' : '\u2316',
                style: HaloType.sans(size: 14, color: HaloColors.amber),
              ),
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
            Text(
              '\u2192',
              style: HaloType.sans(size: 18, color: HaloColors.text3),
            ),
          ],
        ),
      ),
    );
  }
}
