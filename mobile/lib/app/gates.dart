// SPDX-License-Identifier: GPL-3.0-or-later
// the gates the app opens through, and the tor pill

part of '../main.dart';

class _OnboardingGate extends StatefulWidget {
  final Widget child;
  const _OnboardingGate({required this.child});
  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

// when the cold start's splash lets go, set once for the process: a gate
// built again for a switched session holds it to the same moment
DateTime? _splashUntil;

class _OnboardingGateState extends State<_OnboardingGate> {
  // boot is quick enough that the onion is gone before it registers. hold
  // the splash a beat on cold start so it gets seen. warm reopens skip it.
  bool _hold = false;
  // keeps the onboarding's state while it fades out over home
  var _onboardingKey = GlobalKey();
  Widget? _last;
  Widget? _leaving;

  @override
  void initState() {
    super.initState();
    if (!appState.ready) {
      appState.bootWhenWanted();
      _splashUntil ??= DateTime.now().add(const Duration(milliseconds: 2500));
    }
    final left = _splashUntil?.difference(DateTime.now());
    if (left != null && left > Duration.zero) {
      _hold = true;
      Future.delayed(left, () {
        if (mounted) setState(() => _hold = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final Widget before;
        if (appState.bootError != null) {
          before = BootFailedScreen(
            key: const ValueKey('failed'),
            error: appState.bootError!,
            onRetry: () {
              setState(() => _hold = false);
              appState.retryBoot();
            },
            onReopen: appState.bootStuck ? reopenApp : null,
          );
        } else if (!appState.ready || _hold || appState.firstRunAsk) {
          before = const TorBootSplash(key: ValueKey('splash'));
        } else if (appState.movedAway && !appState.movedReadOnly) {
          before = const MovedScreen(key: ValueKey('moved'));
        } else if (!appState.onboardingComplete) {
          before = OnboardingScreen(
            key: _onboardingKey,
            appState: appState,
            onComplete: () => appState.markOnboardingComplete(),
          );
        } else {
          // the onboarding fades out over home, once
          if (_last?.key == _onboardingKey) _leaving = _last;
          _last = null;
          return FadeOver(leaving: _leaving, child: widget.child);
        }
        // an onboarding gone another way may still be fading in the switcher
        if (_last?.key == _onboardingKey && before.key != _onboardingKey) {
          _onboardingKey = GlobalKey();
        }
        _last = before;
        _leaving = null;
        // the splash goes out first, then the next screen comes up: no
        // cut, and never both at once
        return AnimatedSwitcher(
          duration: motionStill(context)
              ? Duration.zero
              : const Duration(milliseconds: 440),
          switchInCurve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
          switchOutCurve: const Interval(0.65, 1, curve: Curves.easeIn),
          child: before,
        );
      },
    );
  }
}

// a language switch redraws everything below here from scratch, on the
// first screen: whatever was open above it is closed. the lock and the
// navigator stay, so a switch never asks for the pin again.
class _LocaleScope extends StatefulWidget {
  final Widget child;
  const _LocaleScope({required this.child});
  @override
  State<_LocaleScope> createState() => _LocaleScopeState();
}

class _LocaleScopeState extends State<_LocaleScope>
    with SingleTickerProviderStateMixin {
  // the new language comes up out of the background instead of every word
  // changing in one frame
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );
  late final _shown = CurvedAnimation(
    parent: _fade,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    localeRevision.addListener(_switched);
  }

  @override
  void dispose() {
    localeRevision.removeListener(_switched);
    _shown.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _switched() {
    if (lockGuard.isLocked()) {
      // under the lock nothing animates, so nothing may be left mid-pop:
      // a new navigator, home only
      renewRootNavigator();
    } else {
      rootNavKey.currentState?.popUntil((r) => r.isFirst);
    }
    setState(() {});
    if (!reduceMotion(context)) _fade.forward(from: 0);
    unawaited(appState.languageChanged());
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: HaloColors.surface,
    child: FadeTransition(
      opacity: _shown,
      child: KeyedSubtree(
        key: ValueKey(localeRevision.value),
        child: widget.child,
      ),
    ),
  );
}

class _LockGate extends StatefulWidget {
  final Widget child;
  const _LockGate({required this.child});
  @override
  State<_LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<_LockGate> {
  @override
  Widget build(BuildContext context) => LockGate(
    app: widget.child,
    lock: lockState,
    loaded: () => lockState.loaded,
    locked: () => lockState.locked,
    load: lockState.load,
    leaving: lockState.leaving,
    returned: lockState.returned,
    left: lockState.left,
    guard: lockGuard,
    quiet: () => sessionQuiet,
    pad: (_) => const LockScreen(),
    lockingUp: appState.lockingUp,
    inFront: appState.appInFront,
    localesChanged: systemLocalesChanged,
    revealed: () {
      appRevealed = true;
      homeRevealed();
    },
  );
}

class TorHalo extends StatefulWidget {
  final bool label;
  const TorHalo({super.key, this.label = false});
  @override
  State<TorHalo> createState() => TorHaloState();
}

/// how long a bare connecting may stand before the pill says what it waits
/// for
const pillPatience = Duration(seconds: 30);

/// what the home pill says, and which kind of line it is: the words change
/// in place within a kind and cross over between kinds. offline is offline
/// in every mode. a decoy hears connected, connecting or offline
@visibleForTesting
({String text, String kind}) pillWords({
  required String mode,
  required TorStatus status,
  required bool online,
  required bool ready,
  required int pct,
  required Duration waited,
  required bool decoy,
}) {
  final off = status == TorStatus.off;
  if (!online && !(mode == 'private' && off)) {
    return (text: l10n.appOffline, kind: 'offline');
  }
  if (mode == 'balanced') return (text: l10n.appViaRelay, kind: 'relay');
  if (mode == 'fast') return (text: l10n.appFast, kind: 'fast');
  if (off) return (text: l10n.appTorOff, kind: 'off');
  if (ready) return (text: l10n.appTorReady, kind: 'ready');
  if (decoy || waited < pillPatience) {
    return (text: l10n.appConnecting2, kind: 'connecting');
  }
  // still building its route: how far along. up with no relay through:
  // that it waits for one
  if (status == TorStatus.starting) {
    return (text: l10n.appConnecting(percent(pct / 100)), kind: 'climbing');
  }
  return (text: l10n.appWaitingForARelay, kind: 'relay-wait');
}

class TorHaloState extends State<TorHalo> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  // wakes the pill when a bare connecting has stood long enough
  Timer? _patience;

  // pulses only while tor is still coming up. once it is usable the chip
  // says so and rests, even when the onion is never confirmed reachable
  bool get _isConnecting => appState.torStatus == TorStatus.starting;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    appState.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  // a few pulses each time tor starts, then still: where tor is blocked it
  // can sit in starting for minutes, and nothing here may run that long.
  // each new way automatic tries gets a few more
  bool _pulsed = false;
  int _attempt = 0;

  // how long tor has been trying, as the app keeps it
  Duration get _waited {
    final t = appState.torTryingSince;
    return t == null ? Duration.zero : DateTime.now().difference(t);
  }

  void _armPatience() {
    final waiting =
        appState.sendMode == 'private' &&
        appState.online &&
        appState.torStatus != TorStatus.off &&
        !appState.torUsable;
    final left = pillPatience - _waited;
    if (!waiting || left <= Duration.zero) {
      _patience?.cancel();
      _patience = null;
      return;
    }
    if (_patience?.isActive ?? false) return;
    _patience = Timer(left + const Duration(milliseconds: 50), () {
      _patience = null;
      if (!mounted) return;
      setState(() {});
      _armPatience();
    });
  }

  void _sync() {
    _armPatience();
    if (!_isConnecting) {
      _pulsed = false;
      if (_c.isAnimating) _c.stop();
      return;
    }
    final a = appState.bridgeStatus.attempt;
    if (a != _attempt) {
      _attempt = a;
      if (a > 1) _pulsed = false;
    }
    if (_pulsed || _c.isAnimating) return;
    _pulsed = true;
    if (mounted && motionStill(context)) return;
    _c.repeat(count: _attempt > 1 ? 3 : 8);
  }

  // tor blocked or nothing got through: the way out is the bridges page
  void _tap() {
    final s = appState.bridgeStatus;
    if (!appState.inDecoyView && (s.exhausted || s.tryingAnother)) {
      Navigator.of(context).push(haloRoute(const BridgesScreen()));
      return;
    }
    _explain();
  }

  @override
  void dispose() {
    appState.removeListener(_sync);
    _patience?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _explain() {
    // capped and scrolling: on a small phone the words run taller than the
    // room above the navigation bar
    showHaloSheet(
      context,
      builder: (_) => AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final s = appState.torStatus;
          final pct = appState.bootstrapPct;
          // no network: tor keeps its last word and the route reads down, but
          // nothing about relays is true then. the home strip says offline too
          final offline = s != TorStatus.off && !appState.online;
          // bootstrapped and publishing both mean tor's client side is live:
          // messages send and arrive over relays, full 3 hops. the remaining
          // wait only publishes our own address so peers can dial us direct.
          // none of it counts while no relay gets through
          final line = s == TorStatus.off
              ? l10n.appTorIsOff
              : offline
              ? l10n.appOffline
              : !appState.torUsable && s != TorStatus.starting
              ? l10n.appConnecting2
              : s == TorStatus.reachable
              ? l10n.appConnectedRoutedThrough3
              : s == TorStatus.publishing
              ? l10n.appReadyToSendPublishing
              : s == TorStatus.bootstrapped
              ? l10n.appReadyToSendFinishing
              : l10n.appConnecting(percent(pct / 100));
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 8),
                  Text(
                    l10n.appTor,
                    style: HaloType.serif(
                      size: 20,
                      italic: true,
                      color: HaloColors.text,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TorWarmupGraph(status: s, bootstrapPct: pct),
                  const SizedBox(height: 16),
                  Text(
                    line,
                    style: HaloType.mono(size: 12, color: HaloColors.text),
                  ),
                  if (s != TorStatus.reachable ||
                      !appState.torUsable ||
                      offline) ...[
                    const SizedBox(height: 16),
                    // past starting with no relay through, the first connection
                    // line would promise a wait that is already over
                    Text(
                      s == TorStatus.off
                          ? l10n.appTorIsOffTurn
                          : offline
                          ? l10n.onboardingKryfoBuildsAPrivateRouteBefore
                          : !appState.torUsable && s != TorStatus.starting
                          ? l10n.appTorNoRelayYet
                          : l10n.appTheFirstConnectionTakes,
                      style: HaloType.sans(
                        size: 12.5,
                        color: HaloColors.text,
                      ).copyWith(height: 1.5),
                    ),
                    // another send mode is no way out of having no network
                    if (!offline) ...[
                      const SizedBox(height: 10),
                      Text(
                        l10n.appRelayAndFastModes,
                        style: HaloType.sans(size: 11, color: HaloColors.text2),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _ring(double size, Color color, double w) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: w),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // nothing to explain outside onion: no bootstrap, no circuit, no
      // descriptor
      onTap: appState.sendMode == 'private' ? _tap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([appState, _c]),
        builder: (context, _) {
          final s = appState.torStatus;
          final off = s == TorStatus.off;
          // ready is the test the outbox and the offline card use, so the
          // pill never says ready over a route nothing gets through
          final ready = appState.torUsable;
          final secured = ready && s == TorStatus.reachable;
          final connecting = _isConnecting;
          final still = motionStill(context);
          final said = pillWords(
            mode: appState.sendMode,
            status: s,
            online: appState.online,
            ready: ready,
            pct: appState.bootstrapPct,
            waited: _waited,
            decoy: appState.inDecoyView,
          );
          // relay does not go through tor, so tor being off never greys it
          final relay = said.kind == 'relay';
          final dim = off && !relay;
          final accent = relay
              ? HaloColors.sky
              : off
              ? HaloColors.text2
              : said.kind == 'offline'
              ? HaloColors.warn
              // one route, one colour. onion stays violet whether tor is
              // merely usable or fully published.
              : appState.sendMode == 'fast'
              ? HaloColors.greenText
              : ready
              ? HaloColors.violetText
              : HaloColors.warnText;
          final t = _c.value;
          Widget dot(Color accent) => SizedBox(
            width: 18,
            height: 18,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (connecting)
                  Transform.scale(
                    scale: 0.5 + t,
                    child: Opacity(
                      opacity: (1 - t) * 0.7,
                      child: _ring(12, accent, 1.4),
                    ),
                  ),
                _ring(
                  12,
                  dim
                      ? HaloColors.text3.withValues(alpha: 0.4)
                      : accent.withValues(alpha: secured ? 1.0 : 0.85),
                  1.4,
                ),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                  ),
                ),
              ],
            ),
          );
          // the state changes are the most watched thing on the screen: the
          // colour slides to the new one and the words cross-fade, rather
          // than both snapping
          Widget tinted(Widget Function(Color) build) =>
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: accent),
                duration: still
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                builder: (_, c, _) => build(c ?? accent),
              );
          if (!widget.label) {
            return tinted(
              (c) =>
                  SizedBox(width: 20, height: 20, child: Center(child: dot(c))),
            );
          }
          return tinted(
            (c) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                dot(c),
                const SizedBox(width: 6),
                AnimatedSwitcher(
                  duration: still
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeIn,
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
                    said.text,
                    key: ValueKey(said.kind),
                    style: HaloType.mono(size: 11, color: c),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
