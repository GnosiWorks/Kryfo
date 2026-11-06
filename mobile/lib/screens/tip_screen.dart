// SPDX-License-Identifier: GPL-3.0-or-later
// the play build's support tab: a tip through google play, three amounts,
// each giving a supporter badge and nothing else. no other way to pay is
// named or linked here (play's payments policy)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../l10n/marked.dart';
import '../main.dart' show session;
import '../supporter.dart';
import '../theme.dart';
import '../tips/tip_billing.dart';
import '../tips/tip_jar.dart';
import '../widgets/ease_size.dart';
import '../widgets/halo_buttons.dart';
import '../widgets/motion.dart' show haloRoute, motionStill;
import '../widgets/press_scale.dart';
import '../widgets/entrance.dart';

const _tiers = [
  SupporterTier.supporter,
  SupporterTier.patron,
  SupporterTier.guardian,
];

// what the screen can offer
enum _Shop { asking, open, soon, unavailable }

// each tier's orb, as the badge shows it elsewhere
({String glyph, List<Color> grad, Color fg}) _look(SupporterTier t) =>
    switch (t) {
      SupporterTier.patron => (
        glyph: '◆',
        grad: const [Color(0xFFA78BFA), Color(0xFF6D28D9)],
        fg: const Color(0xFF1E1B4B),
      ),
      SupporterTier.guardian => (
        glyph: '✦',
        grad: const [Color(0xFFF59E0B), Color(0xFFD97706)],
        fg: HaloColors.onYellow,
      ),
      _ => (
        glyph: '●',
        grad: const [Color(0xFF60A5FA), Color(0xFF2563EB)],
        fg: const Color(0xFF0C1F3F),
      ),
    };

class TipScreen extends StatefulWidget {
  final TipJar? jar;
  const TipScreen({super.key, this.jar});
  @override
  State<TipScreen> createState() => _TipScreenState();
}

class _TipScreenState extends State<TipScreen> {
  TipJar get _jar => widget.jar ?? TipJar.instance;
  StreamSubscription<TipEvent>? _sub;
  _Shop _shop = _Shop.asking;
  Map<SupporterTier, String> _prices = const {};
  Set<SupporterTier> _owned = const {};
  SupporterTier? _picked;
  bool _opening = false;
  bool _restoring = false;
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    _jar.listen();
    _sub = _jar.events.listen(_heard);
    unawaited(_load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    // a payment that went through meanwhile is granted first
    await _jar.settle(always: true);
    final r = await _jar.products();
    final owned = await _ownedTiers();
    if (!mounted) return;
    final prices = <SupporterTier, String>{
      for (final p in r.items) ?kTipProducts[p.id]: p.price,
    };
    setState(() {
      _prices = prices;
      _owned = owned;
      _shop = switch (r.code) {
        TipCode.ok when prices.isNotEmpty => _Shop.open,
        TipCode.ok || TipCode.missing => _Shop.soon,
        _ => _Shop.unavailable,
      };
      _picked ??= _firstOpen();
    });
  }

  Future<Set<SupporterTier>> _ownedTiers() => _jar.ownedTiers();

  SupporterTier? _firstOpen() {
    for (final t in _tiers) {
      if (_prices.containsKey(t) && !_owned.contains(t)) return t;
    }
    return null;
  }

  void _heard(TipEvent e) {
    if (!mounted) return;
    switch (e.outcome) {
      case TipOutcome.granted || TipOutcome.kept:
        setState(() {
          _opening = false;
          _pending = false;
        });
        HapticFeedback.mediumImpact();
        unawaited(_thanked(e));
      case TipOutcome.pending:
        setState(() {
          _opening = false;
          _pending = true;
        });
      case TipOutcome.canceled:
        setState(() => _opening = false);
      case TipOutcome.nothing:
        setState(() => _opening = false);
      case TipOutcome.unavailable || TipOutcome.failed:
        setState(() => _opening = false);
        showHaloToast(context, l10n.tipsFailed);
    }
  }

  Future<void> _thanked(TipEvent e) async {
    await Navigator.of(context).push(
      haloRoute(_Thanks(tier: e.tier, kept: e.outcome == TipOutcome.kept)),
    );
    if (!mounted) return;
    final owned = await _ownedTiers();
    if (!mounted) return;
    setState(() {
      _owned = owned;
      if (_picked != null && _owned.contains(_picked)) _picked = _firstOpen();
    });
  }

  Future<void> _buy() async {
    final t = _picked;
    if (t == null || _opening) return;
    HapticFeedback.selectionClick();
    setState(() => _opening = true);
    final code = await _jar.buy(t);
    if (!mounted) return;
    // the sheet is up: what came of it arrives as an event
    if (code == TipCode.ok) return;
    setState(() => _opening = false);
    if (code == TipCode.owned) {
      unawaited(_restore());
    } else if (code != TipCode.canceled) {
      showHaloToast(context, l10n.tipsFailed);
    }
  }

  Future<void> _restore() async {
    if (_restoring) return;
    setState(() => _restoring = true);
    final e = await _jar.restore();
    if (!mounted) return;
    setState(() => _restoring = false);
    switch (e.outcome) {
      case TipOutcome.granted:
        HapticFeedback.mediumImpact();
        showHaloToast(context, l10n.tipsRestored(tierKey(e.tier)));
      case TipOutcome.kept:
        showHaloToast(context, l10n.tipsRestored(tierKey(e.tier)));
      case TipOutcome.pending:
        setState(() => _pending = true);
      case TipOutcome.nothing:
        showHaloToast(context, l10n.tipsNothingToRestore);
      case _:
        showHaloToast(context, l10n.tipsFailed);
    }
    final owned = await _ownedTiers();
    if (mounted) setState(() => _owned = owned);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.ink,
      appBar: AppBar(
        backgroundColor: HaloColors.ink,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
        title: Text(
          l10n.tipsTitle,
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Hero(),
              const SizedBox(height: 24),
              EaseSize(child: _shopPart()),
              EaseSize(
                child: _pending
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _Note(
                          key: const ValueKey('tips-pending'),
                          icon: Icons.hourglass_top_rounded,
                          text: l10n.tipsPending,
                          warm: true,
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 22),
              _facts(),
              const SizedBox(height: 14),
              _restoreRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shopPart() {
    switch (_shop) {
      case _Shop.unavailable:
        return _Note(
          key: const ValueKey('tips-unavailable'),
          icon: Icons.storefront_outlined,
          text: l10n.tipsUnavailable,
        );
      case _Shop.soon:
        return _Note(
          key: const ValueKey('tips-soon'),
          icon: Icons.schedule_rounded,
          text: l10n.tipsSoon,
        );
      case _Shop.asking || _Shop.open:
        final asking = _shop == _Shop.asking;
        return Column(
          key: const ValueKey('tips-open'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: asking ? l10n.tipsAsking : null,
              child: Row(
                children: [
                  for (final t in _tiers) ...[
                    if (t != _tiers.first) const SizedBox(width: 8),
                    Expanded(
                      child: _TierCard(
                        tier: t,
                        price: _prices[t],
                        asking: asking,
                        owned: _owned.contains(t),
                        picked: _picked == t,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _picked = t);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            HaloPrimaryButton(
              key: const ValueKey('tips-leave'),
              label: l10n.tipsLeave,
              busy: _opening,
              onTap: asking || _picked == null ? null : _buy,
            ),
          ],
        );
    }
  }

  Widget _facts() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      decoration: BoxDecoration(
        color: HaloColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HaloColors.line),
      ),
      child: Column(
        children: [
          _Fact(icon: Icons.verified_outlined, text: l10n.tipsBadgeOnly),
          _Fact(icon: Icons.lock_outline_rounded, text: l10n.tipsThroughPlay),
          _Fact(icon: Icons.smartphone_rounded, text: l10n.tipsBadgeStays),
        ],
      ),
    );
  }

  Widget _restoreRow() {
    return PressScale(
      key: const ValueKey('tips-restore'),
      label: l10n.tipsRestore,
      scale: 0.98,
      onTap: _restoring ? null : _restore,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: HaloColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HaloColors.line),
        ),
        child: Row(
          children: [
            Icon(Icons.restore_rounded, size: 20, color: HaloColors.amber),
            const SizedBox(width: 12),
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tipsRestore,
                      style: HaloType.sans(
                        size: 14,
                        weight: FontWeight.w600,
                        color: HaloColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.tipsRestoreLine,
                      style: HaloType.sans(
                        size: 12.5,
                        color: HaloColors.text,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 20,
              height: 20,
              child: _restoring
                  ? CircularProgressIndicator(
                      strokeWidth: 2,
                      color: HaloColors.amber,
                    )
                  : Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: HaloColors.amber,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatefulWidget {
  const _Hero();
  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  final _entrance = Entrance();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_in.isAnimating || _in.isCompleted) return;
    _entrance.play(context, _in);
  }

  @override
  void dispose() {
    _entrance.dispose();
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pop = CurvedAnimation(parent: _in, curve: Curves.easeOutBack);
    final fade = CurvedAnimation(
      parent: _in,
      curve: const Interval(0.25, 1, curve: Curves.easeOutCubic),
    );
    return Column(
      children: [
        ScaleTransition(
          scale: Tween(begin: 0.6, end: 1.0).animate(pop),
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [HaloColors.amber, HaloColors.amberDeep],
              ),
              boxShadow: [
                BoxShadow(
                  color: HaloColors.amber.withValues(alpha: 0.5),
                  blurRadius: 36,
                  spreadRadius: -6,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: ExcludeSemantics(
              child: Text(
                '✦',
                style: TextStyle(fontSize: 38, color: HaloColors.onAmber),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        FadeTransition(
          opacity: fade,
          child: Column(
            children: [
              Text.rich(
                TextSpan(
                  children: markedSpans(
                    l10n.tipsHeadline,
                    HaloType.serif(
                      size: 25,
                      italic: true,
                      color: HaloColors.amberText,
                    ),
                  ),
                ),
                textAlign: TextAlign.center,
                style: HaloType.serif(size: 25, color: HaloColors.text),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.tipsLine,
                textAlign: TextAlign.center,
                style: HaloType.sans(
                  size: 13.5,
                  color: HaloColors.text,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TierCard extends StatelessWidget {
  final SupporterTier tier;
  final String? price;
  final bool asking;
  final bool owned;
  final bool picked;
  final VoidCallback onTap;
  const _TierCard({
    required this.tier,
    required this.price,
    required this.asking,
    required this.owned,
    required this.picked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (:glyph, :grad, :fg) = _look(tier);
    final still = motionStill(context);
    final sel = picked && !owned;
    final can = !asking && !owned && price != null;
    final name = tierLabel(tier);
    final label = owned
        ? '$name, ${l10n.tipsYours}'
        : price == null
        ? name
        : '$name, $price';
    return Semantics(
      selected: sel,
      child: PressScale(
        label: label,
        onTap: can ? onTap : null,
        child: AnimatedScale(
          scale: sel && !still ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: still ? Duration.zero : const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 112),
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
            decoration: BoxDecoration(
              color: sel ? HaloColors.amberSoft : HaloColors.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: sel ? HaloColors.amber : HaloColors.line,
                width: sel ? 1.4 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: HaloColors.amber.withValues(alpha: sel ? 0.25 : 0),
                  blurRadius: 14,
                ),
              ],
            ),
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: sel || still ? 1 : 0.88,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: grad),
                      ),
                      alignment: Alignment.center,
                      child: owned
                          ? Icon(Icons.check_rounded, size: 18, color: fg)
                          : Text(
                              glyph,
                              style: TextStyle(fontSize: 13, color: fg),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 22,
                    child: Center(
                      child: asking
                          ? _PricePulse(still: still)
                          : Text(
                              owned ? l10n.tipsYours : (price ?? ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HaloType.mono(
                                size: owned ? 13 : 15,
                                weight: FontWeight.w600,
                                color: sel || owned
                                    ? HaloColors.amberText
                                    : HaloColors.text,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: HaloType.sans(size: 12, color: HaloColors.text),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// a price play has not told yet: a soft bar that breathes, still when the
// phone asks for no movement
class _PricePulse extends StatefulWidget {
  final bool still;
  const _PricePulse({required this.still});
  @override
  State<_PricePulse> createState() => _PricePulseState();
}

class _PricePulseState extends State<_PricePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.still) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PricePulse old) {
    super.didUpdateWidget(old);
    if (widget.still) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 0.9).animate(_c),
      child: Container(
        width: 44,
        height: 12,
        decoration: BoxDecoration(
          color: HaloColors.surface3,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Fact({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: HaloColors.amber),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: HaloType.sans(
                size: 13,
                color: HaloColors.text,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool warm;
  const _Note({
    super.key,
    required this.icon,
    required this.text,
    this.warm = false,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warm ? HaloColors.amberSoft : HaloColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: warm
              ? HaloColors.amber.withValues(alpha: 0.5)
              : HaloColors.line,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: HaloColors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: HaloType.sans(
                size: 13,
                color: HaloColors.text,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// the thank you: a tick that draws itself, what the badge is, and whether
// to show it
class _Thanks extends StatefulWidget {
  final SupporterTier tier;
  final bool kept;
  const _Thanks({required this.tier, required this.kept});
  @override
  State<_Thanks> createState() => _ThanksState();
}

class _ThanksState extends State<_Thanks> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    if (motionStill(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _close(bool show) async {
    if (show) await saveShowBadgeSelf(true, session.container);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = tierKey(widget.tier);
    final buttons = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.7, 1, curve: Curves.easeOut),
    );
    return Scaffold(
      backgroundColor: HaloColors.ink,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: AnimatedBuilder(
                      animation: _c,
                      builder: (_, _) => CustomPaint(
                        painter: _Tick(_c.value, HaloColors.amber),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.tipsThanks,
                    textAlign: TextAlign.center,
                    style: HaloType.serif(size: 24, color: HaloColors.text),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.kept ? l10n.tipsKept(t) : l10n.tipsGranted(t),
                  textAlign: TextAlign.center,
                  style: HaloType.sans(
                    size: 13.5,
                    color: HaloColors.text,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 32),
                FadeTransition(
                  opacity: buttons,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HaloPrimaryButton(
                        key: const ValueKey('tips-show'),
                        label: l10n.profileShowMyBadge,
                        onTap: () => _close(true),
                      ),
                      const SizedBox(height: 6),
                      HaloGhostButton(
                        key: const ValueKey('tips-done'),
                        label: l10n.commonDone,
                        onTap: () => _close(false),
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

// a ring that draws itself, then its tick, as t goes 0..1
class _Tick extends CustomPainter {
  final double t;
  final Color color;
  _Tick(this.t, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: size.width / 2 - 3),
      -1.5708,
      6.2832 * (t / 0.6).clamp(0.0, 1.0),
      false,
      ring,
    );
    if (t <= 0.6) return;
    final k = ((t - 0.6) / 0.4).clamp(0.0, 1.0);
    final a = Offset(size.width * 0.30, size.height * 0.52);
    final b = Offset(size.width * 0.44, size.height * 0.66);
    final e = Offset(size.width * 0.72, size.height * 0.36);
    final path = Path()..moveTo(a.dx, a.dy);
    if (k < 0.5) {
      path.lineTo(a.dx + (b.dx - a.dx) * k * 2, a.dy + (b.dy - a.dy) * k * 2);
    } else {
      path.lineTo(b.dx, b.dy);
      final m = (k - 0.5) * 2;
      path.lineTo(b.dx + (e.dx - b.dx) * m, b.dy + (e.dy - b.dy) * m);
    }
    canvas.drawPath(path, ring);
  }

  @override
  bool shouldRepaint(_Tick old) => old.t != t;
}
