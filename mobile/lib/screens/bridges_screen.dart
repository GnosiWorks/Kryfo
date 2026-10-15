// SPDX-License-Identifier: GPL-3.0-or-later
// how tor gets out. one choice, applied at once: automatic finds a way by
// itself, direct is tor alone, and a friend's bridge is a line someone
// gave you. the details, transport names and all, wait behind "more".
// a decoy sees automatic and the status line, nothing else.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bridge_mode.dart';
import '../l10n/l10n.dart';
import '../lock_state.dart' show lockState;
import '../l10n/numbers.dart';
import '../main.dart' hide live;
import '../theme.dart';
import '../widgets/ease_size.dart';
import '../widgets/halo_bar.dart';
import '../widgets/halo_buttons.dart';
import '../widgets/halo_switch.dart';
import '../widgets/motion.dart';
import '../widgets/press_scale.dart';
import '../widgets/stagger_in.dart';
import '../widgets/swap.dart';
import 'bridge_sheets.dart';

class BridgesScreen extends StatefulWidget {
  const BridgesScreen({super.key});

  @override
  State<BridgesScreen> createState() => _BridgesScreenState();
}

class _BridgesScreenState extends State<BridgesScreen> {
  bool _more = false;

  Future<void> _pick(BridgeChoice c) async {
    if (c == BridgeChoice.friend &&
        splitBridgeLines(appState.bridge.friendLines).isEmpty) {
      await showFriendLinesSheet(context);
      return;
    }
    if (c == appState.bridgeChoice) return;
    HapticFeedback.selectionClick();
    await appState.chooseBridge(c);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final decoy = appState.inDecoyView;
        final b = appState.bridge;
        final s = appState.bridgeStatus;
        final line = appState.bridgeLine;
        // decoy: automatic, whatever runs underneath
        final chosen = decoy ? BridgeChoice.auto : b.choice;
        String? tag(BridgeChoice c) {
          if (c != chosen || line.tone == BridgeTone.quiet) return null;
          if (!decoy && s.phase == 'captive') {
            return l10n.bridgesWaitingForWifiSignIn;
          }
          if (line.tone == BridgeTone.green) return l10n.bridgesConnected;
          if (line.tone == BridgeTone.amber) return l10n.bridgesConnecting;
          return null;
        }

        final friendCount = splitBridgeLines(b.friendLines).length;
        return Scaffold(
          backgroundColor: HaloColors.surface,
          appBar: AppBar(
            backgroundColor: HaloColors.surface,
            elevation: 0,
            iconTheme: IconThemeData(color: HaloColors.text2),
            title: Text(
              l10n.bridgesConnection,
              style: HaloType.serif(
                size: 18,
                italic: true,
                color: HaloColors.text,
              ),
            ),
          ),
          body: ListView(
            padding: EdgeInsetsDirectional.fromSTEB(
              20,
              4,
              20,
              40 + MediaQuery.paddingOf(context).bottom,
            ),
            children: staggerAll([
              BridgeStatusView(
                line: line,
                onAction: decoy ? null : (a) => _act(a),
              ),
              const SizedBox(height: 18),
              if (!decoy)
                EaseSize(
                  child:
                      b.offerAuto &&
                          b.choice != BridgeChoice.auto &&
                          !lockState.inVault
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _OfferCard(
                            onYes: () => _pick(BridgeChoice.auto),
                            onNo: appState.dismissAutoOffer,
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              Semantics(
                container: true,
                explicitChildNodes: true,
                child: Column(
                  children: [
                    _ChoiceCard(
                      title: l10n.bridgesAutomatic,
                      body: l10n.bridgesKryfoFindsAWay,
                      selected: chosen == BridgeChoice.auto,
                      tag: tag(BridgeChoice.auto),
                      onTap: decoy ? null : () => _pick(BridgeChoice.auto),
                    ),
                    if (!decoy) ...[
                      const SizedBox(height: 10),
                      _ChoiceCard(
                        title: l10n.bridgesDirect,
                        body: l10n.bridgesFastestWhereTorIsnt,
                        selected: chosen == BridgeChoice.direct,
                        tag: tag(BridgeChoice.direct),
                        onTap: () => _pick(BridgeChoice.direct),
                      ),
                      const SizedBox(height: 10),
                      _ChoiceCard(
                        title: l10n.bridgesBridgeFromAFriend,
                        body: l10n.bridgesPasteOrScanALine,
                        selected: chosen == BridgeChoice.friend,
                        tag: tag(BridgeChoice.friend),
                        onTap: () => _pick(BridgeChoice.friend),
                        extra: friendCount == 0
                            ? null
                            : _FriendLinesRow(
                                count: friendCount,
                                onEdit: () => showFriendLinesSheet(context),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
              // a way picked under "more" shows here, so no card stands
              // unexplained with none selected
              if (!decoy)
                EaseSize(
                  child: _usingLine(chosen) == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: 4,
                            top: 12,
                          ),
                          child: RiseSwap(
                            child: Text(
                              _usingLine(chosen)!,
                              key: ValueKey(chosen),
                              style: HaloType.mono(
                                size: 12,
                                weight: FontWeight.w600,
                                color: HaloColors.violet,
                              ),
                            ),
                          ),
                        ),
                ),
              if (!decoy) ...[
                const SizedBox(height: 8),
                _MoreToggle(
                  open: _more,
                  onTap: () => setState(() => _more = !_more),
                ),
                EaseSize(
                  child: _more
                      ? _MoreSection(status: s, setup: b)
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }

  String? _usingLine(BridgeChoice c) => switch (c) {
    BridgeChoice.builtin => l10n.bridgesUsingBuiltIn,
    BridgeChoice.snowflake => l10n.bridgesUsingSnowflake,
    BridgeChoice.torProject => l10n.bridgesUsingTorProject,
    _ => null,
  };

  Future<void> _act(BridgeAction a) async {
    switch (a) {
      case BridgeAction.tryAgain:
        HapticFeedback.mediumImpact();
        appState.bridgeRetry();
      case BridgeAction.getBridge:
        await showTorBlockedSheet(context);
      case BridgeAction.openWifi:
        await openWifiSettings();
    }
  }
}

/// android's wi-fi page, where a network's sign-in page is offered. no
/// browser to a probe address of our own
Future<bool> openWifiSettings() async {
  try {
    return await const MethodChannel(
          'halo/platform',
        ).invokeMethod<bool>('openWifiSettings') ??
        false;
  } catch (_) {
    return false;
  }
}

Color bridgeToneColor(BridgeTone t) => switch (t) {
  BridgeTone.green => HaloColors.green,
  BridgeTone.amber => HaloColors.amber,
  BridgeTone.rose => HaloColors.rose,
  BridgeTone.quiet => HaloColors.violet,
};

String bridgeActionLabel(BridgeAction a) => switch (a) {
  BridgeAction.tryAgain => l10n.commonTryAgain,
  BridgeAction.getBridge => l10n.bridgesGetABridge,
  BridgeAction.openWifi => l10n.bridgesOpenWifiSettings,
};

/// the live status line: a dot, the state in plain words, how far along,
/// and the one thing to do when stuck. a new state rises in; a percent or
/// a count changes in place
class BridgeStatusView extends StatefulWidget {
  const BridgeStatusView({super.key, required this.line, this.onAction});
  final BridgeLine line;
  final void Function(BridgeAction a)? onAction;

  @override
  State<BridgeStatusView> createState() => _BridgeStatusViewState();
}

class _BridgeStatusViewState extends State<BridgeStatusView> {
  // the clock counts here, once a second, from what the engine last said:
  // nothing else rebuilds for it
  Timer? _tick;
  int _ticks = 0;
  int? _base;

  @override
  void initState() {
    super.initState();
    _clockFrom(widget.line.clockMs);
  }

  @override
  void didUpdateWidget(BridgeStatusView old) {
    super.didUpdateWidget(old);
    if (old.line.clockMs != widget.line.clockMs) {
      _clockFrom(widget.line.clockMs);
    }
  }

  void _clockFrom(int? ms) {
    _base = ms;
    _ticks = 0;
    _tick?.cancel();
    _tick = ms == null
        ? null
        : Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() => _ticks++);
          });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final tint = bridgeToneColor(line.tone);
    final still = motionStill(context);
    final action = widget.onAction == null ? null : line.action;
    final base = _base;
    final clock = base == null ? null : bridgeClock(base + _ticks * 1000);
    final detail = [?line.detail, ?clock].join(bridgeSep);
    return AnimatedContainer(
      duration: still ? Duration.zero : const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          tint.withValues(alpha: 0.07),
          HaloColors.surface2,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // a few breaths on each new state, then still, as the tor dot
              SizedBox(
                width: 10,
                child: line.moving
                    ? BreathDot(
                        key: ValueKey((tint, line.head, line.detailKind)),
                        color: tint,
                        size: 8,
                        breaths: 3,
                      )
                    : AnimatedContainer(
                        duration: still
                            ? Duration.zero
                            : const Duration(milliseconds: 300),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: tint,
                          shape: BoxShape.circle,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              // read out once per new state, never the word leaving
              Expanded(
                child: Semantics(
                  // its own node: the detail and the ticking clock are
                  // never read out with it
                  container: true,
                  liveRegion: true,
                  label: line.head,
                  child: ExcludeSemantics(
                    child: RiseSwap(
                      child: Text(
                        line.head,
                        key: ValueKey(line.head),
                        style: HaloType.serif(size: 20, color: HaloColors.text),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          EaseSize(
            child: detail.isEmpty
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 20,
                      top: 5,
                    ),
                    child: RiseSwap(
                      child: Text(
                        detail,
                        key: ValueKey(line.detailKind),
                        style: HaloType.mono(
                          size: 12,
                          color: HaloColors.text2,
                        ).copyWith(height: 1.45),
                      ),
                    ),
                  ),
          ),
          // how far, where tor says: no endless sweep when it does not
          EaseSize(
            child: line.moving && line.progress != null
                ? Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 20,
                      top: 12,
                    ),
                    child: HaloBar(
                      value: line.progress,
                      height: 3,
                      color: tint,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          EaseSize(
            child: action == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: HaloPrimaryButton(
                      label: bridgeActionLabel(action),
                      onTap: () => widget.onAction!(action),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// the round mark of a choice: its centre springs in when picked
class _Mark extends StatelessWidget {
  const _Mark({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return AnimatedContainer(
      duration: still ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: on ? HaloColors.violet : HaloColors.line2,
          width: on ? 2 : 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: AnimatedScale(
        scale: on ? 1 : 0,
        duration: still ? Duration.zero : kHouseTime,
        curve: kHouseCurve,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: HaloColors.violet,
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
    this.tag,
    this.extra,
  });
  final String title;
  final String body;
  final bool selected;
  final VoidCallback? onTap;
  // connected or connecting, on the one in use
  final String? tag;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final t = tag;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: onTap != null,
      child: PressScale(
        scale: 0.98,
        haptic: false,
        onTap: onTap,
        child: AnimatedContainer(
          duration: still ? Duration.zero : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 16, 14),
          decoration: BoxDecoration(
            color: selected
                ? Color.alphaBlend(
                    HaloColors.violet.withValues(alpha: 0.08),
                    HaloColors.surface2,
                  )
                : HaloColors.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? HaloColors.violet.withValues(alpha: 0.6)
                  : HaloColors.line,
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: _Mark(on: selected),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // a long tag goes under the title, never through it
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        Text(
                          title,
                          style: HaloType.serif(
                            size: 18,
                            color: HaloColors.text,
                          ),
                        ),
                        RiseSwap(
                          alignment: AlignmentDirectional.centerEnd,
                          child: t == null
                              ? const SizedBox.shrink(key: ValueKey('none'))
                              : Text(
                                  t,
                                  key: ValueKey(t),
                                  style: HaloType.mono(
                                    size: 10.5,
                                    weight: FontWeight.w600,
                                    color: t == l10n.bridgesConnected
                                        ? HaloColors.green
                                        : HaloColors.amberText,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: HaloType.sans(
                        size: 13,
                        color: HaloColors.text2,
                        height: 1.4,
                      ),
                    ),
                    ?extra,
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

class _FriendLinesRow extends StatelessWidget {
  const _FriendLinesRow({required this.count, required this.onEdit});
  final int count;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            l10n.bridges1LineSaved(count),
            style: HaloType.mono(size: 11, color: HaloColors.violet),
          ),
        ),
        PressScale(
          scale: 0.95,
          onTap: onEdit,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Center(
              child: Text(
                l10n.commonEdit,
                style: HaloType.mono(
                  size: 12,
                  weight: FontWeight.w600,
                  color: HaloColors.amberText,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// an upgrade from before automatic: offered once, never switched on alone
class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.onYes, required this.onNo});
  final VoidCallback onYes;
  final VoidCallback onNo;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [
          HaloColors.violet.withValues(alpha: 0.16),
          HaloColors.violet.withValues(alpha: 0.05),
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: HaloColors.violet.withValues(alpha: 0.35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.bridgesKryfoCanGetAround,
          style: HaloType.sans(
            size: 14.5,
            weight: FontWeight.w600,
            color: HaloColors.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.bridgesAutomaticFindsAWay,
          style: HaloType.sans(size: 13, color: HaloColors.text2, height: 1.4),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: HaloPrimaryButton(
                label: l10n.bridgesTurnOnAutomatic,
                onTap: onYes,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HaloGhostButton(
                label: l10n.bridgesNotNow,
                onTap: onNo,
                quiet: true,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _MoreToggle extends StatelessWidget {
  const _MoreToggle({required this.open, required this.onTap});
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    expanded: open,
    child: PressScale(
      scale: 0.97,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Flexible(
              child: Text(
                l10n.bridgesMore,
                style: HaloType.mono(
                  size: 12.5,
                  weight: FontWeight.w600,
                  color: HaloColors.amberText,
                ),
              ),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: open ? 0.5 : 0,
              duration: motionStill(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: HaloColors.amber,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// the details: what is in use, the other ways in, the tor project, and the
// lines kept on this phone
class _MoreSection extends StatelessWidget {
  const _MoreSection({required this.status, required this.setup});
  final BridgeStatus status;
  final BridgeSetup setup;

  @override
  Widget build(BuildContext context) {
    final asks = setup.consent == 'yes';
    final friend = splitBridgeLines(setup.friendLines);
    final project = splitBridgeLines(setup.torProjectLines);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Box(
          children: [
            _InfoRow(
              label: l10n.bridgesInUse,
              value: bridgeMethodWords(status, choice: setup.choice),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Box(
          children: [
            _RowChoice(
              title: l10n.bridgesBuiltInBridges,
              body: l10n.bridgesObfs4BridgesThatCome,
              selected: setup.choice == BridgeChoice.builtin,
              onTap: () => _pick(BridgeChoice.builtin),
            ),
            _RowChoice(
              title: 'Snowflake',
              body: l10n.bridgesGoesThroughAVolunteer,
              selected: setup.choice == BridgeChoice.snowflake,
              onTap: () => _pick(BridgeChoice.snowflake),
            ),
            if (project.isNotEmpty)
              _RowChoice(
                title: l10n.bridgesFromTheTorProject,
                body: l10n.bridgesBridgesTheTorProject,
                selected: setup.choice == BridgeChoice.torProject,
                onTap: () => _pick(BridgeChoice.torProject),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _Box(
          children: [
            _SwitchRow(
              title: l10n.bridgesAskTorProject,
              body: l10n.bridgesWhenTorIsBlockedAutomatic,
              value: asks,
              onChanged: (v) async {
                if (!v) return appState.setBridgeConsent(false);
                await showTorProjectConsentSheet(context);
              },
            ),
            EaseSize(
              child: asks
                  ? _CountryRow(country: setup.country)
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
        if (friend.isNotEmpty || project.isNotEmpty) ...[
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
            child: Text(
              l10n.bridgesSavedLines,
              style: HaloType.mono(
                size: 11,
                weight: FontWeight.w600,
                color: HaloColors.amberText,
              ),
            ),
          ),
          _Box(
            children: [
              for (var i = 0; i < friend.length; i++)
                _LineRow(
                  line: friend[i],
                  number: i + 1,
                  from: l10n.bridgesFromAFriendLower,
                  check: _check(BridgeChoice.friend, i),
                  onRemove: () => _remove(context, BridgeChoice.friend, i),
                ),
              for (var i = 0; i < project.length; i++)
                _LineRow(
                  line: project[i],
                  number: friend.length + i + 1,
                  from: l10n.bridgesFromTheTorProjectLower,
                  check: _check(BridgeChoice.torProject, i),
                  onRemove: () => _remove(context, BridgeChoice.torProject, i),
                ),
            ],
          ),
        ],
      ],
    );
  }

  // the line goes at once, and comes back with the undo for a few seconds
  Future<void> _remove(BuildContext context, BridgeChoice from, int i) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final change = await appState.removeBridgeLine(from, i);
    if (change == null || messenger == null) return;
    final (before, after) = change;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          // an action makes a snack bar stay by default: this one goes
          duration: const Duration(seconds: 5),
          persist: false,
          backgroundColor: HaloColors.surface3,
          content: Text(
            l10n.bridgesBridgeRemoved,
            style: HaloType.sans(size: 13.5, color: HaloColors.text),
          ),
          action: SnackBarAction(
            label: l10n.bridgesUndo,
            textColor: HaloColors.amber,
            onPressed: () => appState.putBridgeSetupBack(before, after),
          ),
        ),
      );
  }

  BridgeLineCheck? _check(BridgeChoice of, int i) {
    for (final c in appState.lineChecksFor(of)) {
      if (c.i == i) return c;
    }
    return null;
  }

  void _pick(BridgeChoice c) {
    if (c == appState.bridgeChoice) return;
    HapticFeedback.selectionClick();
    appState.chooseBridge(c);
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: HaloColors.surface2,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: HaloColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 0.5, color: HaloColors.line),
          children[i],
        ],
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        // a long label wraps; the value keeps the rest of the row
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 130),
          child: Text(
            label,
            style: HaloType.sans(size: 14, color: HaloColors.text),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RiseSwap(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              value,
              key: ValueKey(value),
              textAlign: TextAlign.end,
              style: HaloType.mono(size: 12, color: HaloColors.violet),
            ),
          ),
        ),
      ],
    ),
  );
}

class _RowChoice extends StatelessWidget {
  const _RowChoice({
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    inMutuallyExclusiveGroup: true,
    button: true,
    child: PressScale(
      scale: 0.98,
      haptic: false,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 13, 16, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Mark(on: selected),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: HaloType.sans(
                      size: 14.5,
                      weight: FontWeight.w600,
                      color: HaloColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: HaloType.sans(
                      size: 12.5,
                      color: HaloColors.text2,
                      height: 1.4,
                    ),
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

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.body,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: PressScale(
      scale: 0.98,
      haptic: false,
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 13, 14, 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: HaloType.sans(
                      size: 14.5,
                      weight: FontWeight.w600,
                      color: HaloColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: HaloType.sans(
                      size: 12.5,
                      color: HaloColors.text2,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            HaloSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    ),
  );
}

// the country the tor project advises for. its own guess comes first
class _CountryRow extends StatefulWidget {
  const _CountryRow({required this.country});
  final String country;

  @override
  State<_CountryRow> createState() => _CountryRowState();
}

class _CountryRowState extends State<_CountryRow> {
  bool _asking = false;

  // the sheet comes up at once. the tor project is asked only when its
  // guess is picked
  Future<void> _open() async {
    final picked = await showCountrySheet(
      context,
      current: widget.country,
      guess: appState.moatGuess,
    );
    if (picked == null || !mounted) return;
    await appState.setBridgeCountry(picked);
    if (picked.isNotEmpty || !mounted) return;
    setState(() => _asking = true);
    await appState.askMoatGuess();
    if (mounted) setState(() => _asking = false);
  }

  @override
  Widget build(BuildContext context) {
    final cc = widget.country;
    final guess = appState.moatGuess;
    final value = _asking
        ? l10n.bridgesAsking
        : cc.isNotEmpty
        ? bridgeCountryName(cc)
        : guess != null
        ? '${bridgeCountryName(guess)} · ${l10n.bridgesTheTorProjectSGuess}'
        : l10n.bridgesLetTheTorProject;
    return Semantics(
      button: true,
      child: PressScale(
        scale: 0.98,
        onTap: _open,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 14),
          child: Row(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(
                  l10n.bridgesCountry,
                  style: HaloType.sans(size: 14, color: HaloColors.text),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RiseSwap(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    value,
                    key: ValueKey(value),
                    textAlign: TextAlign.end,
                    style: HaloType.mono(size: 12, color: HaloColors.violet),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: HaloColors.text2,
                textDirection: Directionality.of(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// one kept line: its transport and address, never more of it, and whether
// kryfo can use it
class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.number,
    required this.from,
    required this.check,
    required this.onRemove,
  });
  final String line;
  final int number;
  final String from;
  final BridgeLineCheck? check;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final f = line.split(RegExp(r'\s+'));
    final name = bridgeTransport(line) ?? f.first;
    final where = f.length > 1 ? f[1] : '';
    final c = check;
    final bad = c != null && c.broken;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name  $where',
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HaloType.mono(size: 12, color: HaloColors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  bad
                      ? (c.tooLong
                            ? l10n.bridgesTooLongForTor
                            : l10n.bridgesKryfoCanTUseThis)
                      : from,
                  style: HaloType.sans(
                    size: 12,
                    color: bad ? HaloColors.rose : HaloColors.text2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.bridgesRemoveBridgeN(whole(number)),
            onPressed: () {
              HapticFeedback.selectionClick();
              onRemove();
            },
            icon: Icon(Icons.close_rounded, size: 18, color: HaloColors.text2),
          ),
        ],
      ),
    );
  }
}
