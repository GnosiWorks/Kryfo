// push_settings_screen.dart — three-tier notification wake-up picker.
// tier 1 (tor only) is live. tier 2 (fcm) and tier 3 (unifiedPush) are
// stubbed; tapping saves the preference but does nothing functionally
// until sprints 11/12 wire the actual push pipes.

import 'package:flutter/material.dart';
import '../push_mode.dart';
import '../theme.dart';

class PushSettingsScreen extends StatefulWidget {
  const PushSettingsScreen({super.key});

  @override
  State<PushSettingsScreen> createState() => _PushSettingsScreenState();
}

class _PushSettingsScreenState extends State<PushSettingsScreen> {
  PushMode _mode = PushMode.tor;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    loadPushMode().then((m) => setState(() {
          _mode = m;
          _loaded = true;
        }));
  }

  void _pick(PushMode m) {
    setState(() => _mode = m);
    savePushMode(m);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: !_loaded
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BackBar(onBack: () => Navigator.pop(context)),
                  const _Head(),
                  const SizedBox(height: 6),
                  _PushCard(
                    name: 'Tor only',
                    accent: 'recommended',
                    active: _mode == PushMode.tor,
                    desc: 'Halo polls Tor in the background. Nothing leaves your phone via Google or any third party. Battery cost is small.',
                    badges: const ['no metadata', '~30s latency'],
                    onTap: () => _pick(PushMode.tor),
                  ),
                  _PushCard(
                    name: 'Faster via Google',
                    active: _mode == PushMode.fcm,
                    soon: true,
                    desc: 'Google sends a wake-up ping. Message content is never seen by Google, but timing and the fact that you got a message are.',
                    badges: const ['some metadata', 'instant', 'needs Google Play'],
                    onTap: () => _pick(PushMode.fcm),
                  ),
                  _PushCard(
                    name: 'UnifiedPush',
                    active: _mode == PushMode.unifiedPush,
                    soon: true,
                    desc: 'Open-source push via a relay you pick (or self-host). Less metadata than Google, faster than Tor-only.',
                    badges: const ['less metadata', 'fast', 'pick your relay'],
                    onTap: () => _pick(PushMode.unifiedPush),
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
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.chevron_left, color: HaloColors.text2, size: 26),
        ),
      ]),
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
              Text('notifications',
                  style: HaloType.serif(size: 30, weight: FontWeight.w400)),
              Text('& wake-up',
                  style: HaloType.serif(
                      size: 30,
                      weight: FontWeight.w300,
                      italic: true,
                      color: HaloColors.amber)),
            ],
          ),
          const SizedBox(height: 8),
          Text('how halo learns a message has arrived',
              style: HaloType.sans(size: 11, color: HaloColors.text2)),
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
            color: active ? HaloColors.amber.withOpacity(0.10) : HaloColors.surface,
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
                  Text(name,
                      style: HaloType.serif(size: 18, weight: FontWeight.w400)),
                  if (accent != null) ...[
                    const SizedBox(width: 8),
                    Text(accent!,
                        style: HaloType.mono(
                            size: 10, color: HaloColors.amber, letter: 0.1)),
                  ],
                  const Spacer(),
                  if (soon)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: HaloColors.surface3,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('soon',
                          style: HaloType.mono(
                              size: 9, color: HaloColors.text3, letter: 0.1)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(desc,
                  style: HaloType.sans(
                      size: 13, color: HaloColors.text2, height: 1.45)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: badges
                    .map((b) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: HaloColors.surface2,
                            border: Border.all(color: HaloColors.line, width: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(b,
                              style: HaloType.mono(
                                  size: 10, color: HaloColors.text2)),
                        ))
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
      'Tor only is the privacy default. Faster modes leak some metadata to your push provider; message content is always end-to-end encrypted.',
      style: HaloType.sans(size: 11, color: HaloColors.text3, height: 1.6),
      textAlign: TextAlign.center,
    );
  }
}
