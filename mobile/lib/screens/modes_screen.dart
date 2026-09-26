// SPDX-License-Identifier: GPL-3.0-or-later
// speed and privacy modes. private, over tor, is the default; balanced
// exists because mandatory tor is the app's biggest usability cost.

import 'package:flutter/material.dart';
import '../theme.dart';
import '../main.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/sheet_handle.dart';
import 'package:flutter/services.dart';
import '../widgets/stagger_in.dart';
import '../widgets/fit_column.dart';
import '../l10n/l10n.dart';
import '../l10n/marked.dart';

class ModesScreen extends StatefulWidget {
  const ModesScreen({super.key});
  @override
  State<ModesScreen> createState() => _ModesScreenState();
}

class _ModesScreenState extends State<ModesScreen> {
  String _mode = 'private';

  @override
  void initState() {
    super.initState();
    _sync();
  }

  Future<void> _sync() async {
    await appState.loadSendMode();
    if (appState.sendMode == 'normal') await appState.setSendMode('private');
    if (mounted) setState(() => _mode = appState.sendMode);
  }

  void _pick(String m) {
    setState(() => _mode = m);
    appState.setSendMode(m);
  }

  // fast is the one mode that costs something, so it says so first
  Future<void> _pickFast() async {
    if (_mode == 'fast') return;
    final ok = await showFastGateSheet(context);
    if (ok && mounted) {
      HapticFeedback.mediumImpact();
      _pick('fast');
    }
  }

  @override
  Widget build(BuildContext context) {
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
              _BackBar(onBack: () => Navigator.pop(context)),
              const _Head(),
              const SizedBox(height: 6),
              _ModeCard(
                name: l10n.modesOnion,
                accent: '·',
                active: _mode == 'private',
                desc: l10n.modesFullOnionRoutingThree,
                speed: l10n.modesSlower,
                hops: '3',
                ipVisible: false,
                onTap: () => _pick('private'),
              ),
              _ModeCard(
                name: l10n.modesRelay,
                active: _mode == 'balanced',
                desc: l10n.modesOneSealedConnectionTo,
                speed: l10n.modesQuick,
                hops: '1',
                ipVisible: false,
                ipText: l10n.modesRelayOnly,
                ipWarn: true,
                onTap: () => _pick('balanced'),
              ),
              _ModeCard(
                name: l10n.modesFast,
                active: _mode == 'fast',
                desc: l10n.modesPlainConnectionsToEvery,
                speed: l10n.modesInstant,
                hops: '0',
                ipVisible: true,
                warning: l10n.modesEveryRelayYouUse,
                onTap: _pickFast,
              ),
            ]),
            const Spacer(),
            const StaggerIn(
              index: 5,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: _Footnote(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackBar extends StatelessWidget {
  final VoidCallback onBack;
  const _BackBar({required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 0, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.commonBack,
            onPressed: onBack,
            icon: Icon(Icons.chevron_left, color: HaloColors.text2, size: 26),
          ),
        ],
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                l10n.modesSpeed,
                style: HaloType.serif(size: 30, weight: FontWeight.w400),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.modesPrivacy,
                style: HaloType.serif(
                  size: 30,
                  weight: FontWeight.w300,
                  italic: true,
                  color: HaloColors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.modesChangeGloballyOrPer,
            style: HaloType.sans(size: 11, color: HaloColors.text2),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String name;
  final String? accent;
  final bool active;
  final bool soon = false;
  final String desc;
  final String speed;
  final String hops;
  final bool ipVisible;
  // some tiers aren't a clean hidden/visible: 'relay only' is its own
  final String? ipText;
  final bool ipWarn;
  final String? warning;
  final VoidCallback onTap;
  const _ModeCard({
    required this.name,
    this.accent,
    required this.active,
    required this.desc,
    required this.speed,
    required this.hops,
    required this.ipVisible,
    this.ipText,
    this.ipWarn = false,
    this.warning,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: GestureDetector(
        onTap: soon ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: active
                ? HaloColors.amber.withValues(alpha: 0.10)
                : HaloColors.surface,
            border: Border.all(
              color: active ? HaloColors.amber : HaloColors.line,
              width: active ? 1 : 0.5,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: HaloType.serif(size: 18, weight: FontWeight.w400),
                  ),
                  if (soon) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: HaloColors.surface3,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l10n.modesSoon,
                        style: HaloType.mono(
                          size: 9,
                          color: HaloColors.amber,
                          letter: 0.6,
                        ),
                      ),
                    ),
                  ],
                  if (active && accent != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      accent!,
                      style: HaloType.serif(
                        size: 18,
                        weight: FontWeight.w400,
                        italic: true,
                        color: HaloColors.amber,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (active)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: HaloColors.amber,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        l10n.modesActive,
                        style: HaloType.mono(
                          size: 10,
                          weight: FontWeight.w500,
                          color: HaloColors.onAmber,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                desc,
                style: HaloType.sans(
                  size: 11,
                  color: HaloColors.text2,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Meta(k: l10n.modesSpeed2, v: speed),
                  const SizedBox(width: 14),
                  _Meta(k: l10n.modesHops, v: hops),
                  const SizedBox(width: 14),
                  _Meta(
                    k: l10n.modesIp,
                    v:
                        ipText ??
                        (ipVisible ? l10n.modesVisible : l10n.modesHidden),
                    red: ipVisible,
                    warn: ipWarn,
                  ),
                ],
              ),
              if (warning != null && active) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: HaloColors.rose.withValues(alpha: 0.10),
                    border: Border.all(
                      color: HaloColors.rose.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: HaloType.sans(
                        size: 10,
                        color: HaloColors.rose,
                        height: 1.4,
                      ),
                      children: markedSpans(
                        l10n.modesHeadsUp(warning!),
                        HaloType.sans(
                          size: 10,
                          weight: FontWeight.w500,
                          color: HaloColors.rose,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final String k;
  final String v;
  final bool red;
  final bool warn;
  const _Meta({
    required this.k,
    required this.v,
    this.red = false,
    this.warn = false,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(k, style: HaloType.mono(size: 10, color: HaloColors.text3)),
        const SizedBox(width: 4),
        Text(
          v,
          style: HaloType.sans(
            size: 10,
            weight: FontWeight.w500,
            color: red
                ? HaloColors.rose
                : warn
                ? HaloColors.amber
                : HaloColors.text,
          ),
        ),
      ],
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote();
  @override
  Widget build(BuildContext context) {
    return Text(
      l10n.modesOnionIsTheDefault,
      style: HaloType.mono(size: 10, color: HaloColors.text3),
    );
  }
}

// what fast costs, in plain words. shown by every way into it: the modes
// screen and the home's "our relay is quiet" shortcut alike
Future<bool> showFastGateSheet(BuildContext context) async {
  final ok = await showHaloSheet<bool>(
    context,
    scroll: true,
    builder: (_) => const _FastGateSheet(),
  );
  return ok == true;
}

class _FastGateSheet extends StatelessWidget {
  const _FastGateSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 12),
            Text(
              l10n.modesFastMode,
              style: HaloType.serif(size: 20, color: HaloColors.text),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.modesPlainConnectionsToEveryRelayQuicker,
              style: HaloType.sans(
                size: 13,
                color: HaloColors.text2,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () => Navigator.pop(context, true),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: HaloColors.amber,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  l10n.modesTurnOnFastMode,
                  style: HaloType.sans(
                    size: 14,
                    weight: FontWeight.w600,
                    color: HaloColors.onAmber,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => Navigator.pop(context, false),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text(
                    l10n.modesKeepItOff,
                    style: HaloType.sans(size: 13, color: HaloColors.text2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
