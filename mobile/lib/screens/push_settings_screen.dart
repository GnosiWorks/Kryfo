// SPDX-License-Identifier: GPL-3.0-or-later
// push_settings_screen.dart - what a notification shows on the lock screen.
// the wake-up picker that used to share this screen is gone, see
// push_mode.dart. how messages arrive has its own screen.

import 'package:flutter/material.dart';
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
  bool _loaded = false;
  bool _hideContent = true;

  @override
  void initState() {
    super.initState();
    loadHideNotifContent().then((v) {
      if (!mounted) return;
      setState(() {
        _hideContent = v;
        _loaded = true;
      });
    });
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
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'What a notification gives away',
            style: HaloType.sans(size: 11, color: HaloColors.text2),
          ),
        ],
      ),
    );
  }
}
