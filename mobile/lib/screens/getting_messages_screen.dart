// SPDX-License-Identifier: GPL-3.0-or-later
// how new messages reach this phone, in words a person who has never heard
// of tor can choose between.
import 'dart:async';

import 'package:flutter/material.dart';

import '../delivery_mode.dart';
import '../lock_state.dart';
import '../main.dart' show appState, reduceMotion, session;
import '../miui_autostart.dart';
import '../notifications.dart';
import '../ready_edge.dart';
import '../seen_timers.dart';
import '../theme.dart';
import 'helper_sheet.dart';
import '../widgets/card_action.dart';
import '../widgets/motion.dart';
import '../widgets/halo_rows.dart' show HaloSection;
import '../widgets/press_scale.dart';
import '../widgets/halo_switch.dart';
import '../widgets/stagger_in.dart';
import '../widgets/swap.dart';
import '../widgets/unfold.dart';
import '../l10n/l10n.dart';
import '../dlog.dart';

// the route switch, a stand-in in tests: the real one moves the engine
@visibleForTesting
Future<void> Function(String mode)? setRouteForTest;

class GettingMessagesScreen extends StatefulWidget {
  const GettingMessagesScreen({super.key});

  @override
  State<GettingMessagesScreen> createState() => _GettingMessagesScreenState();
}

class _GettingMessagesScreenState extends State<GettingMessagesScreen> {
  final _timers = SeenTimers();
  bool _busy = false;
  // what a notification shows on the lock screen: how messages arrive and
  // what they say when they do are the same question. null until read, so
  // the switch never opens on a default and slides
  bool? _hidePreview;
  late final ReadyEdge _torUp;

  @override
  void initState() {
    super.initState();
    // no .then() without a catch: a throw here must not break the page
    loadHideNotifContent(session.container)
        .then((v) {
          if (mounted) setState(() => _hidePreview = v);
        })
        .catchError((Object e) {
          dlog('getting messages: preview setting (${e.runtimeType})');
        });
    appState.addListener(_changed);
    // the helper app is offered once our relay says it can knock. tor is
    // often still coming up as the page opens, so it is asked again each
    // time tor on the onion route turns ready
    unawaited(appState.refreshHelperOffer());
    _torUp = ReadyEdge(
      appState,
      () => appState.sendMode == 'private' && appState.torReady,
      () => unawaited(appState.refreshHelperOffer()),
    );
    // "4 min ago" has to become "5 min ago" on its own, while it is seen
    _timers.every(const Duration(seconds: 20), _changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timers.watch(context);
  }

  @override
  void dispose() {
    _timers.dispose();
    _torUp.dispose();
    appState.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _pick(DeliveryMode m) async {
    if (_busy || m == appState.deliveryMode) return;
    setState(() => _busy = true);
    if (m == DeliveryMode.helper) {
      // the mode is set by the sheet, once the helper app has answered
      final app = await showHelperSheet(context);
      if (!mounted) return;
      setState(() => _busy = false);
      if (app == null) return;
    } else {
      await appState.setDeliveryMode(m);
      if (!mounted) return;
      setState(() => _busy = false);
    }
    if (m != DeliveryMode.always) {
      // a check-in, and a knock's, is a background job. a phone that stops
      // background work stops those too, so the same ask applies.
      unawaited(forceShowBackgroundPrompt(context));
    }
  }

  // the helper app goes over tor or not at all, so its card offers the
  // onion route first. the same switch as speed and privacy, which asks
  // nothing before onion
  Future<void> _toOnion() async {
    if (_busy) return;
    setState(() => _busy = true);
    var saved = true;
    try {
      await (setRouteForTest ?? appState.setSendMode)('private');
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!saved) showHaloToast(context, l10n.modesNotChanged);
  }

  @override
  Widget build(BuildContext context) {
    final mode = appState.deliveryMode;
    // why the helper app cannot be picked yet, or null when it can
    final onOnion = appState.sendMode == 'private';
    final offered = mode == DeliveryMode.helper || appState.helperOffered;
    // on onion, not offered yet: checking until the relay itself says no
    final checking = !offered && onOnion && !appState.helperRelaySaidNo;
    final String? helperWait = offered
        ? null
        : !onOnion
        ? l10n.gettingMessagesHelperOnionOnly
        : checking
        ? l10n.gettingMessagesHelperChecking
        : l10n.gettingMessagesHelperRelayNotYet;
    // the app's one meaning of connected, the same the home screen shows
    final connecting = appState.linkComing;
    final status = deliveryStatus(
      mode: mode,
      connected: appState.linkUp,
      connecting: connecting,
      lastCheckMs: appState.lastCheckAt,
      lastWakeMs: appState.lastWakeAt,
      nowMs: DateTime.now().millisecondsSinceEpoch,
      helperName: appState.helperName,
    );
    // how tor gets out, when it is not the usual way. never in a decoy
    final bs = appState.bridgeStatus;
    final String? bridgeNote =
        appState.inDecoyView || appState.sendMode != 'private'
        ? null
        : bs.throughBridge && appState.linkUp
        ? l10n.bridgesThroughABridge
        : appState.autoStruggling
        ? appState.bridgeLine.head
        : null;
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
              // always there, greyed until onion and our relay allow it
              _ModeCard(
                title: l10n.deliveryModeThroughAHelperApp,
                body: l10n.gettingMessagesHelperBody,
                on: mode == DeliveryMode.helper,
                wait: helperWait,
                checking: checking,
                // a pill says what the tap does: move the route, or set up
                action: mode == DeliveryMode.helper
                    ? null
                    : helperWait == null
                    ? l10n.gettingMessagesHelperSetUp
                    : onOnion
                    ? null
                    : l10n.gettingMessagesHelperUseOnion,
                onTap: helperWait == null
                    ? () => _pick(DeliveryMode.helper)
                    : onOnion
                    ? null
                    : _toOnion,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: HaloSection(
                  l10n.gettingMessagesOnTheLockScreen,
                  flush: true,
                ),
              ),
              // one switch to a screen reader, named by its title and line
              MergeSemantics(
                child: Padding(
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
                                color: HaloColors.text2,
                              ),
                            ),
                            // a pin turns previews off. if someone turns them
                            // back on, say what that gives away.
                            Unfold(
                              open: lockState.lockOn && _hidePreview == false,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  l10n.gettingMessagesShowsMessageTextIn,
                                  style: HaloType.sans(
                                    size: 12,
                                    color: HaloColors.rose,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FadeSwap(
                        child: _hidePreview == null
                            ? const SizedBox(
                                key: ValueKey('pending'),
                                width: 46,
                                height: 26,
                              )
                            : HaloSwitch(
                                key: const ValueKey('switch'),
                                value: _hidePreview!,
                                onChanged: (v) {
                                  setState(() => _hidePreview = v);
                                  setHideNotifContent(v, session.container);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                child: Row(
                  children: [
                    // it pulses only while tor is on its way, and holds
                    // still once live
                    if (!status.live && connecting)
                      BreathDot(color: HaloColors.amber, size: 6)
                    else
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: status.live
                              ? HaloColors.green
                              : HaloColors.amber,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: 9),
                    Expanded(
                      // a new state rises in; the minutes counting on
                      // change in place
                      child: Semantics(
                        liveRegion: true,
                        child: RiseSwap(
                          child: Text(
                            status.text,
                            key: ValueKey((status.live, connecting)),
                            style: HaloType.mono(
                              size: 12,
                              color: status.live
                                  ? HaloColors.green
                                  : HaloColors.text,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Unfold(
                open: bridgeNote != null,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(37, 4, 22, 0),
                  child: RiseSwap(
                    child: Text(
                      bridgeNote ?? '',
                      key: ValueKey(bridgeNote),
                      style: HaloType.mono(size: 11.5, color: HaloColors.text2),
                    ),
                  ),
                ),
              ),
              // the check-ins note grows in and folds away, so the page
              // never jumps under a finger
              Unfold(
                open: mode == DeliveryMode.checkins,
                child: Padding(
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
              ),
              // some registration the relay keeps refusing: a plain line,
              // the check-ins carry those chats meanwhile
              Unfold(
                open: mode == DeliveryMode.helper && appState.helperRefused,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                  child: Text(
                    l10n.gettingMessagesHelperRefused,
                    style: HaloType.sans(
                      size: 12.5,
                      height: 1.5,
                      color: HaloColors.warm,
                    ),
                  ),
                ),
              ),
              Unfold(
                open: mode == DeliveryMode.helper,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                  child: Text(
                    l10n.gettingMessagesHelperNote,
                    style: HaloType.sans(
                      size: 12.5,
                      height: 1.5,
                      color: HaloColors.warm,
                    ),
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
  // why it cannot be picked yet: the card greys and says so
  final String? wait;
  // the wait line is a check still running: a small spinner before it
  final bool checking;
  final String? action;
  final VoidCallback? onTap;
  const _ModeCard({
    required this.title,
    this.tag,
    required this.body,
    required this.on,
    this.wait,
    this.checking = false,
    this.action,
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
          label: wait == null ? '$title. $body' : '$title. $body. $wait',
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
                  AnimatedOpacity(
                    opacity: wait == null ? 1 : 0.45,
                    duration: const Duration(milliseconds: 200),
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
                                  color: HaloColors.amber.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  tag!,
                                  style: HaloType.mono(
                                    size: 10,
                                    letter: 0.06,
                                    color: HaloColors.amberText,
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
                  Unfold(
                    open: wait != null || action != null,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      // the pill drops under the line when both do not fit.
                      // full width, or a wrap shrinks and the pill sits left
                      child: SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: wait == null
                              ? WrapAlignment.end
                              : WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            if (wait != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (checking) ...[
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        key: const ValueKey('helperChecking'),
                                        strokeWidth: 1.4,
                                        color: HaloColors.amberText,
                                        value: reduceMotion(context)
                                            ? 0.7
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: Text(
                                      wait!,
                                      style: HaloType.mono(
                                        size: 11.5,
                                        color: HaloColors.amberText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            if (action != null)
                              CardAction(
                                label: action!,
                                onTap: onTap,
                                fill: HaloColors.amber,
                                ink: HaloColors.onAmber,
                                swap: true,
                              ),
                          ],
                        ),
                      ),
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
