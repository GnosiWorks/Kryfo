// SPDX-License-Identifier: GPL-3.0-or-later
// how new messages reach this phone, in words a person who has never heard
// of tor can choose between.
import 'dart:async';

import 'package:flutter/material.dart';

import '../delivery_mode.dart';
import '../lock_state.dart';
import '../main.dart' show appState;
import '../miui_autostart.dart';
import '../notifications.dart';
import '../theme.dart';
import '../widgets/motion.dart';
import '../widgets/press_scale.dart';
import '../widgets/halo_switch.dart';
import '../widgets/stagger_in.dart';
import '../l10n/l10n.dart';

class GettingMessagesScreen extends StatefulWidget {
  const GettingMessagesScreen({super.key});

  @override
  State<GettingMessagesScreen> createState() => _GettingMessagesScreenState();
}

class _GettingMessagesScreenState extends State<GettingMessagesScreen> {
  Timer? _tick;
  bool _busy = false;
  // what a notification shows on the lock screen: how messages arrive and
  // what they say when they do are the same question
  bool _hidePreview = true;

  @override
  void initState() {
    super.initState();
    // no .then() without a catch: a throw here must not break the page
    loadHideNotifContent()
        .then((v) {
          if (mounted) setState(() => _hidePreview = v);
        })
        .catchError((_) {});
    appState.addListener(_changed);
    // "4 min ago" has to become "5 min ago" on its own
    _tick = Timer.periodic(const Duration(seconds: 20), (_) => _changed());
  }

  @override
  void dispose() {
    _tick?.cancel();
    appState.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _pick(DeliveryMode m) async {
    if (_busy || m == appState.deliveryMode) return;
    setState(() => _busy = true);
    await appState.setDeliveryMode(m);
    if (!mounted) return;
    setState(() => _busy = false);
    if (m == DeliveryMode.checkins) {
      // a check-in is a background job. a phone that stops background work
      // stops check-ins too, so the same ask applies.
      unawaited(forceShowBackgroundPrompt(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = appState.deliveryMode;
    final s = appState.torStatus;
    final status = deliveryStatus(
      mode: mode,
      connected: s == TorStatus.reachable || s == TorStatus.publishing,
      connecting: s == TorStatus.starting || s == TorStatus.bootstrapped,
      lastCheckMs: appState.lastCheckAt,
      lastWakeMs: appState.lastWakeAt,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: staggerAll([
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: l10n.commonBack,
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.chevron_left,
                        color: HaloColors.warm,
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.gettingMessagesGettingMessages,
                      style: HaloType.serif(size: 30, weight: FontWeight.w400),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.gettingMessagesHowNewMessagesReach,
                      style: HaloType.sans(
                        size: 13,
                        height: 1.45,
                        color: HaloColors.warm,
                      ),
                    ),
                  ],
                ),
              ),
              _ModeCard(
                title: l10n.gettingMessagesAlwaysOn,
                tag: l10n.gettingMessagesMostPrivate,
                body: l10n.gettingMessagesMessagesArriveInstantlyNothing,
                on: mode == DeliveryMode.always,
                onTap: () => _pick(DeliveryMode.always),
              ),
              _ModeCard(
                title: l10n.gettingMessagesCheckIns,
                tag: l10n.gettingMessagesLightest,
                body: l10n.gettingMessagesKryfoLooksForMessages,
                on: mode == DeliveryMode.checkins,
                onTap: () => _pick(DeliveryMode.checkins),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 2),
                child: Text(
                  l10n.gettingMessagesOnTheLockScreen,
                  style: HaloType.mono(
                    size: 10.5,
                    color: HaloColors.text3,
                    letter: 0.06,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.gettingMessagesHideMessagePreview,
                            style: HaloType.sans(
                              size: 14,
                              color: HaloColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.gettingMessagesAGenericAlertWith,
                            style: HaloType.sans(
                              size: 12,
                              color: HaloColors.text3,
                            ),
                          ),
                          // a pin turns previews off. if someone turns them
                          // back on, say what that gives away.
                          if (lockState.enabled && !_hidePreview) ...[
                            const SizedBox(height: 6),
                            Text(
                              l10n.gettingMessagesShowsMessageTextIn,
                              style: HaloType.sans(
                                size: 12,
                                color: HaloColors.rose,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    HaloSwitch(
                      value: _hidePreview,
                      onChanged: (v) {
                        setState(() => _hidePreview = v);
                        setHideNotifContent(v);
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                child: Row(
                  children: [
                    if (status.live)
                      BreathDot(color: HaloColors.green, size: 6)
                    else
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: HaloColors.amber,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          status.text,
                          style: HaloType.mono(
                            size: 12,
                            color: status.live
                                ? HaloColors.green
                                : HaloColors.text,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (mode == DeliveryMode.checkins)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                  child: Text(
                    l10n.gettingMessagesWhenThePhoneSits,
                    style: HaloType.sans(
                      size: 12.5,
                      height: 1.5,
                      color: HaloColors.warm,
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String? tag;
  final String body;
  final bool on;
  final VoidCallback onTap;
  const _ModeCard({
    required this.title,
    this.tag,
    required this.body,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Semantics(
        selected: on,
        button: true,
        child: PressScale(
          label: '$title. $body',
          onTap: onTap,
          scale: 0.98,
          child: ExcludeSemantics(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
              decoration: BoxDecoration(
                color: on
                    ? HaloColors.amber.withValues(alpha: 0.08)
                    : HaloColors.surface2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: on ? HaloColors.amber : HaloColors.line,
                  width: on ? 1.4 : 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: HaloType.sans(
                            size: 15.5,
                            weight: FontWeight.w600,
                            color: HaloColors.text,
                          ),
                        ),
                      ),
                      if (tag != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: HaloColors.amber.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            tag!,
                            style: HaloType.mono(
                              size: 10,
                              letter: 0.06,
                              color: HaloColors.amber,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: HaloType.sans(
                      size: 13,
                      height: 1.5,
                      color: HaloColors.warm,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
