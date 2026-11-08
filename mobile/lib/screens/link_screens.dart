// SPDX-License-Identifier: GPL-3.0-or-later
// the two sides of linking a device. on the phone: reaching the device,
// the six numbers to compare, linking, and how it ended. on the new
// device: its code, the same six numbers, linking, and the account's key
// number once it is linked. each page reads one LinkFlow; the decoy's
// flow runs the same pages
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../devices/link_flow.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart' show percent, whole;
import '../theme.dart';
import '../widgets/fit_column.dart';
import '../widgets/halo_buttons.dart';
import '../widgets/motion.dart' show BreathDot, motionStill;
import '../widgets/onion_loader.dart';
import '../widgets/page_head.dart';
import '../widgets/swap.dart';

/// the phone's side, from the moment the code was scanned
class LinkRunScreen extends StatefulWidget {
  const LinkRunScreen({
    super.key,
    required this.flow,
    this.onAgain,
    this.onSeeCopy,
  });
  final LinkFlow flow;

  /// back to the scanner for a new code
  final VoidCallback? onAgain;

  /// linked: the history copy's page, where the copy is followed
  final VoidCallback? onSeeCopy;

  @override
  State<LinkRunScreen> createState() => _LinkRunScreenState();
}

class _LinkRunScreenState extends State<LinkRunScreen> {
  @override
  void initState() {
    super.initState();
    widget.flow.addListener(_moved);
    unawaited(widget.flow.start());
  }

  LinkStep? _was;
  void _moved() {
    final s = widget.flow.value.step;
    if (s == _was) return;
    _was = s;
    switch (s) {
      case LinkStep.digits:
        HapticFeedback.mediumImpact();
      case LinkStep.done:
        HapticFeedback.heavyImpact();
      case LinkStep.failed:
        HapticFeedback.lightImpact();
      default:
    }
  }

  @override
  void dispose() {
    widget.flow.removeListener(_moved);
    widget.flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageBar(title: l10n.devicesLinkADevice),
            Expanded(
              child: ValueListenableBuilder<LinkStage>(
                valueListenable: widget.flow,
                builder: (context, v, _) => FadeSwap(
                  child: KeyedSubtree(
                    key: ValueKey(v.step),
                    child: _phonePage(context, v),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _phonePage(BuildContext context, LinkStage v) {
    final flow = widget.flow;
    return switch (v.step) {
      LinkStep.preparing || LinkStep.showing || LinkStep.reaching => _Waiting(
        title: l10n.devicesLinkReaching,
        line: l10n.devicesLinkReachingLine,
      ),
      LinkStep.digits => _Compare(
        digits: v.digits ?? '',
        line: l10n.devicesLinkCompareLine,
        onMatch: () {
          HapticFeedback.selectionClick();
          unawaited(flow.match());
        },
        onNoMatch: flow.noMatch,
      ),
      LinkStep.linking => _Waiting(
        share: v.share,
        title: l10n.devicesLinkLinking,
        line: l10n.devicesLinkLinkingLine,
      ),
      LinkStep.done => _Outcome(
        good: true,
        title: l10n.devicesLinkDone,
        line: l10n.devicesLinkDoneLine,
        primary: l10n.commonDone,
        onPrimary: () => Navigator.of(context).pop(true),
        // the history copy starts now: followed from here, or on its card
        secondary: widget.onSeeCopy == null ? null : l10n.historyCopySee,
        onSecondary: widget.onSeeCopy,
      ),
      LinkStep.failed => _Outcome(
        good: false,
        title: v.end == LinkEnd.unreached
            ? l10n.devicesLinkUnreached
            : l10n.devicesLinkStopped,
        line: switch (v.end) {
          LinkEnd.full => l10n.devicesFull,
          LinkEnd.stopped => l10n.devicesLinkStoppedLine,
          LinkEnd.interrupted => l10n.devicesLinkInterruptedLine,
          _ => l10n.devicesLinkUnreachedLine,
        },
        primary: v.end == LinkEnd.full ? l10n.commonClose : l10n.commonTryAgain,
        onPrimary: () {
          if (v.end == LinkEnd.full || widget.onAgain == null) {
            Navigator.of(context).pop(false);
          } else {
            widget.onAgain!();
          }
        },
        secondary: v.end == LinkEnd.full ? null : l10n.commonClose,
        onSecondary: () => Navigator.of(context).pop(false),
      ),
    };
  }
}

/// the new device's side: its code until the phone answers, then the rest
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, required this.newFlow, required this.onLinked});

  /// a fresh flow, for the first code and each new one
  final LinkFlow Function() newFlow;

  /// linked: what the app does next (opens as the linked device)
  final VoidCallback onLinked;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  late LinkFlow _flow;
  LinkStep? _was;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  void _begin() {
    _flow = widget.newFlow()..addListener(_moved);
    _was = null;
    unawaited(_flow.start());
  }

  void _moved() {
    final s = _flow.value.step;
    if (s == _was) return;
    _was = s;
    switch (s) {
      case LinkStep.digits:
        HapticFeedback.mediumImpact();
      case LinkStep.done:
        HapticFeedback.heavyImpact();
      default:
    }
  }

  void _again() {
    HapticFeedback.selectionClick();
    final old = _flow;
    old.removeListener(_moved);
    setState(_begin);
    old.dispose();
  }

  @override
  void dispose() {
    _flow.removeListener(_moved);
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageBar(title: l10n.joinTitle),
            Expanded(
              child: ValueListenableBuilder<LinkStage>(
                key: ObjectKey(_flow),
                valueListenable: _flow,
                builder: (context, v, _) => FadeSwap(
                  child: KeyedSubtree(
                    // getting ready and the code share one page: the code
                    // settles into the frame that waited for it
                    key: ValueKey(
                      v.step == LinkStep.preparing
                          ? '${LinkStep.showing}'
                          : '${v.step}',
                    ),
                    child: _joinPage(v),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _joinPage(LinkStage v) {
    return switch (v.step) {
      LinkStep.preparing => const _ShowCode(offer: null),
      LinkStep.showing || LinkStep.reaching => _ShowCode(offer: v.offer),
      LinkStep.digits => _Compare(
        digits: v.digits ?? '',
        line: l10n.joinCompareLine,
        onMatch: () {
          HapticFeedback.selectionClick();
          unawaited(_flow.match());
        },
        onNoMatch: _flow.noMatch,
      ),
      LinkStep.linking => _Waiting(
        share: v.share,
        title: l10n.joinLinking,
        line: l10n.joinLinkingLine,
      ),
      LinkStep.done => _Outcome(
        good: true,
        title: l10n.joinDone,
        line: l10n.joinDoneLine,
        number: v.keyNumber,
        primary: l10n.joinOpen,
        onPrimary: widget.onLinked,
      ),
      LinkStep.failed => _Outcome(
        good: false,
        title: v.end == LinkEnd.unreached
            ? l10n.joinUnreached
            : l10n.devicesLinkStopped,
        line: switch (v.end) {
          LinkEnd.unreached => l10n.joinUnreachedLine,
          LinkEnd.stopped => l10n.devicesLinkStoppedLine,
          _ => l10n.devicesLinkInterruptedLine,
        },
        // a new code on this computer, its own identity untouched: nothing
        // here falls back to what was before
        primary: l10n.commonTryAgain,
        onPrimary: _again,
      ),
    };
  }
}

// ---- the parts both sides share ----

class _Page extends StatelessWidget {
  const _Page({required this.children, this.foot = const []});
  final List<Widget> children;
  final List<Widget> foot;

  // a wide window keeps the page at a phone's width, in the middle
  static const _widest = 480.0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _widest),
        child: FitColumn(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            ...children,
            const Spacer(),
            const SizedBox(height: 20),
            ...foot,
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.title, this.line);
  final String title;
  final String line;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: HaloType.serif(size: 24, color: HaloColors.text),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          line,
          textAlign: TextAlign.center,
          style: HaloType.sans(size: 14, color: HaloColors.text, height: 1.45),
        ),
      ],
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.title, required this.line, this.share});
  final String title;
  final String line;

  /// how far, once something is counted: a bar under the words
  final double? share;

  @override
  Widget build(BuildContext context) {
    final s = share;
    return _Page(
      children: [
        Center(child: OnionLoader(size: 104, color: HaloColors.amber)),
        const SizedBox(height: 28),
        Semantics(liveRegion: true, child: _Title(title, line)),
        const SizedBox(height: 22),
        // the bar's place is kept from the start: nothing jumps when it
        // comes
        AnimatedOpacity(
          opacity: s == null ? 0 : 1,
          duration: motionStill(context)
              ? Duration.zero
              : const Duration(milliseconds: 240),
          child: _LinkBar(share: s ?? 0),
        ),
      ],
    );
  }
}

class _LinkBar extends StatelessWidget {
  const _LinkBar({required this.share});
  final double share;

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Semantics(
          value: percent(share),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: share),
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                color: HaloColors.amber,
                backgroundColor: HaloColors.surface3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// six numbers as two threes, read out in order whatever the language
class LinkDigits extends StatelessWidget {
  const LinkDigits(this.digits, {super.key});
  final String digits;

  @override
  Widget build(BuildContext context) {
    final d = digits.length == 6
        ? '${digits.substring(0, 3)} ${digits.substring(3)}'
        : digits;
    // one line always: big text or a narrow phone shrinks it, never wraps
    return Semantics(
      label: digits.split('').join(' '),
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          d,
          maxLines: 1,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          style: HaloType.mono(
            size: 44,
            weight: FontWeight.w600,
            color: HaloColors.amberText,
            letter: 0.16,
          ),
        ),
      ),
    );
  }
}

class _Compare extends StatefulWidget {
  const _Compare({
    required this.digits,
    required this.line,
    required this.onMatch,
    required this.onNoMatch,
  });
  final String digits;
  final String line;
  final VoidCallback onMatch;
  final VoidCallback onNoMatch;

  @override
  State<_Compare> createState() => _CompareState();
}

class _CompareState extends State<_Compare>
    with SingleTickerProviderStateMixin {
  // the numbers settle in a beat after the page, so the eye lands on them
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  bool _sent = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionStill(context)) {
      _in.value = 1;
    } else if (!_in.isAnimating && _in.value == 0) {
      _in.forward();
    }
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rise = CurvedAnimation(parent: _in, curve: Curves.easeOutBack);
    return _Page(
      foot: [
        HaloPrimaryButton(
          label: l10n.devicesLinkMatch,
          busy: _sent,
          onTap: _sent
              ? null
              : () {
                  setState(() => _sent = true);
                  widget.onMatch();
                },
        ),
        const SizedBox(height: 10),
        HaloGhostButton(
          label: l10n.devicesLinkNoMatch,
          quiet: true,
          onTap: _sent ? null : widget.onNoMatch,
        ),
      ],
      children: [
        _Title(l10n.devicesLinkCompare, widget.line),
        const SizedBox(height: 30),
        AnimatedBuilder(
          animation: rise,
          builder: (_, child) => Opacity(
            opacity: _in.value,
            child: Transform.scale(
              scale: 0.86 + 0.14 * rise.value,
              child: child,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            decoration: BoxDecoration(
              color: HaloColors.amberSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: HaloColors.amber.withValues(alpha: 0.35),
              ),
            ),
            child: LinkDigits(widget.digits),
          ),
        ),
      ],
    );
  }
}

class _Outcome extends StatefulWidget {
  const _Outcome({
    required this.good,
    required this.title,
    required this.line,
    required this.primary,
    required this.onPrimary,
    this.number,
    this.secondary,
    this.onSecondary,
  });
  final bool good;
  final String title;
  final String line;
  final String? number;
  final String primary;
  final VoidCallback onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;

  @override
  State<_Outcome> createState() => _OutcomeState();
}

class _OutcomeState extends State<_Outcome>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionStill(context)) {
      _pop.value = 1;
    } else if (_pop.value == 0 && !_pop.isAnimating) {
      _pop.forward();
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // calm either way: an end is said, never sounded as an alarm
    final tint = HaloColors.amber;
    final n = widget.number;
    return _Page(
      foot: [
        HaloPrimaryButton(label: widget.primary, onTap: widget.onPrimary),
        if (widget.secondary != null) ...[
          const SizedBox(height: 10),
          HaloGhostButton(
            label: widget.secondary!,
            quiet: true,
            onTap: widget.onSecondary,
          ),
        ],
      ],
      children: [
        Center(
          child: ScaleTransition(
            scale: CurvedAnimation(parent: _pop, curve: Curves.easeOutBack),
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tint.withValues(alpha: 0.14),
                border: Border.all(color: tint.withValues(alpha: 0.4)),
              ),
              alignment: Alignment.center,
              child: ExcludeSemantics(
                child: Icon(
                  widget.good ? Icons.check_rounded : Icons.link_off_rounded,
                  size: 36,
                  color: HaloColors.amberText,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Semantics(liveRegion: true, child: _Title(widget.title, widget.line)),
        if (n != null) ...[
          const SizedBox(height: 18),
          Semantics(
            // read out a digit at a time, a group after a group
            label: [
              for (final g in n.split(' ')) g.split('').join(' '),
            ].join(', '),
            excludeSemantics: true,
            child: Text(
              n,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style: HaloType.mono(size: 17, color: HaloColors.text),
            ),
          ),
        ],
      ],
    );
  }
}

// the new device's code, and what to do with it on the phone
class _ShowCode extends StatelessWidget {
  const _ShowCode({required this.offer});
  final String? offer;

  @override
  Widget build(BuildContext context) {
    final o = offer;
    final wide = MediaQuery.sizeOf(context).shortestSide >= 600;
    final size = wide ? 248.0 : 212.0;
    final steps = [l10n.joinStep1, l10n.joinStep2, l10n.joinStep3];
    final still = motionStill(context);
    return _Page(
      foot: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BreathDot(color: HaloColors.amber, size: 6),
            const SizedBox(width: 8),
            Flexible(
              child: FadeSwap(
                child: Text(
                  o == null ? l10n.joinPreparing : l10n.joinWaiting,
                  key: ValueKey(o == null),
                  style: HaloType.sans(
                    size: 13,
                    weight: FontWeight.w500,
                    color: HaloColors.text,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        o == null
            ? const _PreparingLine()
            : Text(
                l10n.joinCodeLife,
                textAlign: TextAlign.center,
                style: HaloType.sans(size: 12.5, color: HaloColors.text),
              ),
      ],
      children: [
        Center(
          child: Container(
            width: size + 28,
            height: size + 28,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            // the code fades into the frame that waited for it
            child: AnimatedSwitcher(
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 280),
              child: o == null
                  ? Center(
                      key: const ValueKey('ready'),
                      child: OnionLoader(size: 64, color: HaloColors.amber),
                    )
                  : Semantics(
                      key: const ValueKey('code'),
                      label: l10n.joinStep3,
                      image: true,
                      child: QrImageView(
                        data: o,
                        version: QrVersions.auto,
                        size: size,
                        backgroundColor: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        for (final (i, s) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _JoinStep(n: i + 1, text: s),
          ),
      ],
    );
  }
}

// a first start's tor can take a minute or two: said once it has
class _PreparingLine extends StatefulWidget {
  const _PreparingLine();
  @override
  State<_PreparingLine> createState() => _PreparingLineState();
}

class _PreparingLineState extends State<_PreparingLine> {
  bool _slow = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(seconds: 20), () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeSwap(
      child: Text(
        _slow ? l10n.joinPreparingSlow : l10n.joinPreparingLine,
        key: ValueKey(_slow),
        textAlign: TextAlign.center,
        style: HaloType.sans(size: 12.5, color: HaloColors.text),
      ),
    );
  }
}

class _JoinStep extends StatelessWidget {
  const _JoinStep({required this.n, required this.text});
  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsetsDirectional.only(end: 12),
            decoration: BoxDecoration(
              color: HaloColors.amberSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              whole(n),
              style: HaloType.sans(
                size: 12,
                weight: FontWeight.w600,
                color: HaloColors.amberText,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: HaloType.sans(
                  size: 14,
                  color: HaloColors.text,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
