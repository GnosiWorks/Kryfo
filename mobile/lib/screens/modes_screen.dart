// SPDX-License-Identifier: GPL-3.0-or-later
// speed & privacy modes. private (tor) is live and stays the default;
// balanced (clearnet to our own relay) and fast (direct) are ui-only until
// the engine can route around tor. balanced exists because mandatory tor is
// the app's biggest usability cost - see transport tiers in CONTEXT.

import 'package:flutter/material.dart';
import '../theme.dart';
import '../main.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BackBar(onBack: () => Navigator.pop(context)),
            const _Head(),
            const SizedBox(height: 6),
            _ModeCard(
              name: 'Private',
              accent: '·',
              active: _mode == 'private',
              desc:
                  'Full onion routing, 3 hops. A message takes 2–5 seconds. Nobody sees who you talk to.',
              speed: 'slower',
              hops: '3',
              ipVisible: false,
              onTap: () => _pick('private'),
            ),
            _ModeCard(
              name: 'Balanced',
              soon: true,
              active: _mode == 'balanced',
              desc:
                  'Straight to a Kryfo relay, no onion hops. Sends land in about a second and there is no waiting for Tor to warm up.',
              speed: 'quick',
              hops: '1',
              ipVisible: false,
              ipText: 'relay only',
              ipWarn: true,
              warning:
                  'the relay sees the address you connect from. your contacts and every other relay still do not, and messages stay end-to-end encrypted either way.',
              onTap: () => _pick('balanced'),
            ),
            _ModeCard(
              name: 'Fast',
              soon: true,
              active: _mode == 'fast',
              desc:
                  'Direct connection. Near-instant. Use for low-stakes chats.',
              speed: 'instant',
              hops: '0',
              ipVisible: true,
              warning: 'not active yet · every message still uses full Tor.',
              onTap: () => _pick('fast'),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: _Footnote(),
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
      padding: const EdgeInsets.fromLTRB(4, 4, 0, 0),
      child: Row(
        children: [
          IconButton(
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
                'speed',
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
            'change globally, or per chat',
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
  final bool soon;
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
    this.soon = false,
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
                        'soon',
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
                        'active',
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
                    v: ipText ?? (ipVisible ? 'visible' : 'hidden'),
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
                          text: 'heads up: ',
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
      'private is live. balanced and fast are still being built - '
      'until then every message routes through tor.',
      style: HaloType.mono(size: 10, color: HaloColors.text3),
    );
  }
}
