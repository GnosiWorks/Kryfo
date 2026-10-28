// SPDX-License-Identifier: GPL-3.0-or-later
// speed and privacy: two routes. private, over tor, is the default. fast
// goes straight to our two servers at once, for those for whom tor is slow
// or blocked, and says in one line who sees the address. relay and fast
// were one each before; whoever had either is on fast now.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../fast_servers.dart';
import '../l10n/l10n.dart';
import '../main.dart' hide live;
import '../theme.dart';
import '../widgets/ease_size.dart';
import '../widgets/fit_column.dart';
import '../widgets/motion.dart' show haloRoute;
import '../widgets/press_scale.dart';
import '../widgets/stagger_in.dart';
import 'bridges_screen.dart';
import 'fast_servers_screen.dart';
import 'seen_screen.dart';

class ModesScreen extends StatefulWidget {
  const ModesScreen({super.key});
  @override
  State<ModesScreen> createState() => _ModesScreenState();
}

class _ModesScreenState extends State<ModesScreen> {
  // what is in use now, so the page opens on the right card. read from the
  // app and never again from storage: a read still on its way when a card
  // is tapped would put the old mode back over the new one
  late String _mode = appState.sendMode == 'balanced' ? 'balanced' : 'private';

  // taps still in the queue. the picked card says it is switching until
  // the last of them is done, then the page shows the mode in use
  int _going = 0;

  // the fast card's status comes from the engine's relay rows, read while
  // the page is open
  Timer? _poll;
  List? _rows;

  @override
  void initState() {
    super.initState();
    _read();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _read());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _read() {
    if (appState.sendMode != 'balanced') return;
    try {
      appState.sampleRelayHealth();
      final rows = engine.transportState()['relays'] as List?;
      if (mounted) setState(() => _rows = rows);
    } catch (_) {
      // not readable yet: the card says connecting
    }
  }

  Future<void> _pick(String m) async {
    if (m == _mode && _going == 0) return;
    HapticFeedback.selectionClick();
    setState(() {
      _mode = m;
      _going++;
      _rows = null;
    });
    var saved = true;
    try {
      await appState.setSendMode(m);
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    setState(() {
      _going--;
      // a tap behind this one may have moved it since: only the last done
      // says which card is in use
      if (_going == 0) {
        _mode = appState.sendMode == 'balanced' ? 'balanced' : 'private';
      }
    });
    if (saved) {
      _read();
    } else {
      // not saved, so nothing moved for this tap
      showHaloToast(context, l10n.modesNotChanged);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fast = _mode == 'balanced';
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        // fits or scrolls: a plain column runs past the body on a short
        // phone and whatever sits below the fold cannot be tapped
        child: FitColumn(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // the spacer stays a direct child of the column: wrapped by the
            // stagger it throws a parent-data error, which release paints as
            // a light box
            ...staggerAll([
              _TopBar(onBack: () => Navigator.pop(context)),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 4, 24, 20),
                child: Text(
                  l10n.modesPickHow,
                  style: HaloType.sans(
                    size: 15,
                    color: HaloColors.text2,
                    height: 1.5,
                  ),
                ),
              ),
              _RouteCard(
                key: const ValueKey('private'),
                icon: Icons.track_changes_rounded,
                name: l10n.modesPrivate,
                tag: l10n.modesPrivateTag,
                line: l10n.modesPrivateLine,
                active: !fast,
                switching: _going > 0 && !fast,
                chip: l10n.modesDefault,
                onTap: () => _pick('private'),
              ),
              const SizedBox(height: 14),
              _RouteCard(
                key: const ValueKey('fast'),
                icon: Icons.bolt_rounded,
                name: l10n.modesFast,
                tag: l10n.modesFastTag,
                line: l10n.modesFastLine,
                active: fast,
                switching: _going > 0 && fast,
                status: fast
                    ? _FastStatus(rows: _rows, going: _going > 0)
                    : null,
                onTap: () => _pick('balanced'),
              ),
              const _BothLine(),
            ]),
            const Spacer(),
            StaggerIn(
              index: 6,
              child: _BottomLink(
                label: fast
                    ? l10n.modesWhatServersSee
                    : l10n.modesConnectionBridges,
                onTap: () => Navigator.of(context).push(
                  haloRoute(fast ? const SeenScreen() : const BridgesScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 12, 16, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.commonBack,
            onPressed: onBack,
            icon: Icon(Icons.chevron_left, color: HaloColors.text, size: 26),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                '${l10n.modesSpeed} ${l10n.modesPrivacy}',
                style: HaloType.serif(
                  size: 24,
                  weight: FontWeight.w400,
                  italic: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final IconData icon;
  final String name;
  final String tag;
  final String line;
  final bool active;
  // picked, and the app still moving onto it
  final bool switching;
  final String? chip;
  // the fast card's live part, shown while it is in use
  final Widget? status;
  final VoidCallback onTap;
  const _RouteCard({
    super.key,
    required this.icon,
    required this.name,
    required this.tag,
    required this.line,
    required this.active,
    required this.onTap,
    this.switching = false,
    this.chip,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final d = still ? Duration.zero : const Duration(milliseconds: 240);
    final accent = HaloColors.amber;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Semantics(
        button: true,
        selected: active,
        inMutuallyExclusiveGroup: true,
        child: PressScale(
          scale: 0.98,
          onTap: onTap,
          child: AnimatedContainer(
            duration: d,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: active
                  ? accent.withValues(alpha: 0.10)
                  : HaloColors.surface2,
              border: Border.all(
                color: active ? accent : HaloColors.line,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedContainer(
                      duration: d,
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: active
                            ? accent.withValues(alpha: 0.18)
                            : HaloColors.surface3,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        size: 22,
                        color: active ? HaloColors.amberText : HaloColors.text,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: HaloType.sans(
                              size: 18,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tag,
                            style: HaloType.mono(
                              size: 11,
                              letter: 0.6,
                              color: active
                                  ? HaloColors.amberText
                                  : HaloColors.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Tick(on: active, switching: switching),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  line,
                  style: HaloType.sans(
                    size: 15,
                    color: HaloColors.text,
                    height: 1.5,
                  ),
                ),
                if (chip != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      chip!,
                      style: HaloType.sans(
                        size: 12,
                        weight: FontWeight.w500,
                        color: HaloColors.amberText,
                      ),
                    ),
                  ),
                ],
                // the live part grows in on the card that was picked
                EaseSize(
                  duration: const Duration(milliseconds: 240),
                  child: status ?? const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// the round mark at the card's end: filled with a tick on the route in use,
// a ring that turns while the app moves onto it
class _Tick extends StatelessWidget {
  final bool on;
  final bool switching;
  const _Tick({required this.on, required this.switching});
  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final Widget mark;
    if (on && switching) {
      mark = SizedBox(
        key: const ValueKey('going'),
        width: 24,
        height: 24,
        child: Semantics(
          label: l10n.modesSwitching,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              // reduced motion: a still ring, the label says the rest
              value: still ? 0.75 : null,
              color: HaloColors.amber,
            ),
          ),
        ),
      );
    } else if (on) {
      mark = Container(
        key: const ValueKey('on'),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: HaloColors.amber,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.check_rounded, size: 15, color: HaloColors.onAmber),
      );
    } else {
      mark = Container(
        key: const ValueKey('off'),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: HaloColors.line2, width: 2),
        ),
      );
    }
    return AnimatedSwitcher(
      duration: still ? Duration.zero : const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: a, child: c),
      ),
      child: mark,
    );
  }
}

// the fast card while fast is in use: connected or not, the backup line,
// and the way to the servers' own rows
class _FastStatus extends StatelessWidget {
  final List? rows;
  final bool going;
  const _FastStatus({required this.rows, required this.going});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final v = fastViewOf(
          rows,
          downSince: appState.relayDownSince,
          now: DateTime.now(),
        );
        final link = going ? FastLink.connecting : v.link;
        final (word, dot) = switch (link) {
          FastLink.connected => (l10n.modesFastConnected, HaloColors.green),
          FastLink.connecting => (l10n.modesFastConnecting, HaloColors.warn),
          FastLink.down => (l10n.modesFastDown, HaloColors.rose),
        };
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: HaloColors.amber.withValues(alpha: 0.22),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Dot(color: dot, pulse: link == FastLink.connecting),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          word,
                          style: HaloType.sans(
                            size: 14,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    // a small link, with room enough for a thumb
                    Semantics(
                      button: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => Navigator.of(
                          context,
                        ).push(haloRoute(const FastServersScreen())),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              12,
                              6,
                              4,
                              6,
                            ),
                            child: Center(
                              widthFactor: 1,
                              child: Text(
                                l10n.modesDetails,
                                style: HaloType.sans(
                                  size: 13,
                                  weight: FontWeight.w500,
                                  color: HaloColors.amberText,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.modesBackupReady,
                  style: HaloType.sans(
                    size: 13,
                    color: HaloColors.text2,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// a status dot. connecting breathes, unless the phone asks for stillness
class _Dot extends StatefulWidget {
  final Color color;
  final bool pulse;
  const _Dot({required this.color, required this.pulse});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Dot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final move = widget.pulse && !MediaQuery.disableAnimationsOf(context);
    if (move && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!move && _c.isAnimating) {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: 1 - _c.value * 0.55),
        ),
      ),
    );
  }
}

class _BothLine extends StatelessWidget {
  const _BothLine();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 0),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: HaloColors.text2,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.modesBothLine,
                style: HaloType.sans(
                  size: 13,
                  color: HaloColors.text2,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _BottomLink({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
      child: Semantics(
        button: true,
        child: PressScale(
          scale: 0.98,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 14, 12),
            decoration: BoxDecoration(
              color: HaloColors.surface2,
              border: Border.all(color: HaloColors.line),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  // the route picked changes where it leads, and the words
                  // cross over rather than jump
                  child: AnimatedSwitcher(
                    duration: still
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    layoutBuilder: (cur, prev) => Stack(
                      alignment: AlignmentDirectional.centerStart,
                      children: [...prev, ?cur],
                    ),
                    child: Text(
                      label,
                      key: ValueKey(label),
                      style: HaloType.sans(size: 15, color: HaloColors.text),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, size: 20, color: HaloColors.text2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
