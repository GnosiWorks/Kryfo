// SPDX-License-Identifier: GPL-3.0-or-later
// speed & privacy modes. private (tor) is live and stays the default;
// balanced (clearnet to our own relay) and fast (direct) are ui-only until
// the engine can route around tor. balanced exists because mandatory tor is
// the app's biggest usability cost - see transport tiers in CONTEXT.

import 'package:flutter/material.dart';
import '../theme.dart';
import '../main.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/sheet_handle.dart';
import 'package:flutter/services.dart';
import '../widgets/stagger_in.dart';

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: staggerAll([
            _BackBar(onBack: () => Navigator.pop(context)),
            const _Head(),
            const SizedBox(height: 6),
            _ModeCard(
              name: 'onion',
              accent: '·',
              active: _mode == 'private',
              desc:
                  'Full onion routing, three hops. A message takes two to five seconds. Nobody sees who you talk to.',
              speed: 'slower',
              hops: '3',
              ipVisible: false,
              onTap: () => _pick('private'),
            ),
            _ModeCard(
              name: 'relay',
              active: _mode == 'balanced',
              desc:
                  "one sealed connection to kryfo's own relay, like a vpn "
                  'With nothing to log. Sends land in about a second, and it '
                  'works where tor is blocked.',
              speed: 'quick',
              hops: '1',
              ipVisible: false,
              ipText: 'Relay only',
              ipWarn: true,
              onTap: () => _pick('balanced'),
            ),
            _ModeCard(
              name: 'fast',
              active: _mode == 'fast',
              desc:
                  'Plain connections to every relay. Near instant, and the '
                  'least private of the three.',
              speed: 'instant',
              hops: '0',
              ipVisible: true,
              warning:
                  'Every relay you use knows the address you connect from, not '
                  'only ours. Messages are still sealed, but the fact that you '
                  'sent one is not. Off by default, and off again after a '
                  'reinstall.',
              onTap: _pickFast,
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: _Footnote(),
            ),
          ]),
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
      padding: const EdgeInsets.fromLTRB(4, 4, 0, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
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
                'Speed',
                style: HaloType.serif(size: 30, weight: FontWeight.w400),
              ),
              const SizedBox(width: 8),
              Text(
                '& privacy',
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
            'Change globally, or per chat',
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
  // some tiers aren't a clean hidden/visible - 'relay only' is its own.
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
                        'Soon',
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
                        'Active',
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
                  _Meta(k: 'speed', v: speed),
                  const SizedBox(width: 14),
                  _Meta(k: 'hops', v: hops),
                  const SizedBox(width: 14),
                  _Meta(
                    k: 'ip',
                    v: ipText ?? (ipVisible ? 'Visible' : 'hidden'),
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
                      children: [
                        TextSpan(
                          text: 'Heads up: ',
                          style: HaloType.sans(
                            size: 10,
                            weight: FontWeight.w500,
                            color: HaloColors.rose,
                          ),
                        ),
                        TextSpan(text: warning!),
                      ],
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
        Text(
          k.toUpperCase(),
          style: HaloType.mono(size: 10, color: HaloColors.text3),
        ),
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
      'Onion is the default and stays that way unless you change it. '
      'Switching takes effect on the next message.',
      style: HaloType.mono(size: 10, color: HaloColors.text3),
    );
  }
}

// the warning. what fast costs, in plain words, and a button
// the one warning fast mode carries, shown by every way into it: the
// modes screen and the home's "our relay is quiet" shortcut alike
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
              'Fast mode',
              style: HaloType.serif(size: 20, color: HaloColors.text),
            ),
            const SizedBox(height: 10),
            Text(
              'Plain connections to every relay. Quicker, and the relays can '
              'see your ip address. Messages stay end to end encrypted '
              'either way.',
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
                  'Turn on fast mode',
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
                    'Keep it off',
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
