// SPDX-License-Identifier: GPL-3.0-or-later
// push_settings_screen.dart - three-tier notification wake-up picker.
// tor only is the one way in. see push_mode.dart for what used to sit beside it.
// tier 2 (fcm) is deferred until a play-store variant ships.

import 'package:flutter/material.dart';
import '../main.dart' show appState;
import '../push_mode.dart';
import '../notifications.dart';
import '../theme.dart';
import '../widgets/stagger_in.dart';
import '../widgets/halo_switch.dart';

class PushSettingsScreen extends StatefulWidget {
  const PushSettingsScreen({super.key});

  @override
  State<PushSettingsScreen> createState() => _PushSettingsScreenState();
}

class _PushSettingsScreenState extends State<PushSettingsScreen> {
  PushMode _mode = PushMode.tor;
  bool _loaded = false;
  bool _hideContent = true;

  @override
  void initState() {
    super.initState();
    loadPushMode().then((m) {
      if (!mounted) return;
      setState(() {
        _mode = m;
        _loaded = true;
      });
    });
    loadHideNotifContent().then((v) {
      if (mounted) setState(() => _hideContent = v);
    });
  }

  void _pick(PushMode m) {
    setState(() => _mode = m);
    appState.applyPushMode(m);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: !_loaded
            ? const SizedBox.shrink()
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: staggerAll([
                    _BackBar(onBack: () => Navigator.pop(context)),
                    const _Head(),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hide message preview',
                                  style: HaloType.sans(
                                    size: 14,
                                    color: HaloColors.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Lock screen shows a generic alert, no sender or message text',
                                  style: HaloType.sans(
                                    size: 12,
                                    color: HaloColors.text3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          HaloSwitch(
                            value: _hideContent,
                            onChanged: (v) {
                              setState(() => _hideContent = v);
                              setHideNotifContent(v);
                            },
                          ),
                        ],
                      ),
                    ),
                    _PushCard(
                      name: 'Tor only',
                      accent: 'recommended',
                      active: _mode == PushMode.tor,
                      desc:
                          'Kryfo polls tor in the background. Nothing leaves your phone via any third party. The battery cost is small.',
                      badges: const ['no metadata', '~30s latency'],
                      onTap: () => _pick(PushMode.tor),
                    ),
                    _PushCard(
                      name: 'Via google',
                      active: false,
                      soon: true,
                      desc:
                          'Google would send the wake-up ping. It never sees '
                          'what you were sent, but it does learn that you were '
                          'sent something, and when. We are looking at '
                          'unifiedpush instead: same speed, no google.',
                      badges: const [
                        'not available',
                        'Needs google play',
                        'leaks timing',
                      ],
                      onTap: () {},
                    ),
                    const SizedBox(height: 32),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: _Footnote(),
                    ),
                  ]),
                ),
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
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
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
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              Text(
                'Notifications',
                style: HaloType.serif(size: 30, weight: FontWeight.w400),
              ),
              Text(
                '& wake-up',
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
            'How kryfo learns a message has arrived',
            style: HaloType.sans(size: 11, color: HaloColors.text2),
          ),
        ],
      ),
    );
  }
}

class _PushCard extends StatelessWidget {
  final String name;
  final String? accent;
  final bool active;
  final bool soon;
  final String desc;
  final List<String> badges;
  final VoidCallback onTap;

  const _PushCard({
    required this.name,
    this.accent,
    required this.active,
    this.soon = false,
    required this.desc,
    required this.badges,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: GestureDetector(
        onTap: onTap,
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
                  if (accent != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      accent!,
                      style: HaloType.mono(
                        size: 10,
                        color: HaloColors.amber,
                        letter: 0.1,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (soon)
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
                          color: HaloColors.text3,
                          letter: 0.1,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                desc,
                style: HaloType.sans(
                  size: 13,
                  color: HaloColors.text2,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: badges
                    .map(
                      (b) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: HaloColors.surface2,
                          border: Border.all(
                            color: HaloColors.line,
                            width: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          b,
                          style: HaloType.mono(
                            size: 10,
                            color: HaloColors.text2,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote();
  @override
  Widget build(BuildContext context) {
    return Text(
      'Tor only is the default. The faster modes leak some timing to your push provider. Message content is end to end encrypted either way.',
      style: HaloType.sans(size: 11, color: HaloColors.text3, height: 1.6),
      textAlign: TextAlign.center,
    );
  }
}
