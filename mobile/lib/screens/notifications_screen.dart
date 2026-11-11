// SPDX-License-Identifier: GPL-3.0-or-later
// notifications: how new messages reach this phone, in words a person who
// has never heard of tor can choose between, then how they sound, what
// they show, and what the battery needs for them.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../battery_brand.dart' show BrandGuide;
import '../delivery_mode.dart';
import '../desktop/desktop_mode.dart'
    show deskSound, desktopRun, onDesktop, setDeskSound;
import '../lock_state.dart';
import '../main.dart'
    show
        appState,
        linkedRole,
        reduceMotion,
        session,
        AppStateRoute,
        AppStateDelivery,
        AppStateBridges,
        AppStateSession;
import '../link_view.dart';
import '../miui_autostart.dart';
import '../notif_permission.dart';
import '../notifications.dart';
import '../ready_edge.dart';
import '../seen_timers.dart';
import '../theme.dart';
import 'desk_run_section.dart';
import 'helper_sheet.dart';
import 'icon_screen.dart'
    show IconScreen, NotifShow, notifShowName, notifShowOf;
import '../widgets/card_action.dart';
import '../widgets/motion.dart';
import '../widgets/halo_rows.dart' show HaloGroup, HaloRow, HaloSection;
import '../widgets/press_scale.dart';
import '../widgets/stagger_in.dart';
import '../widgets/swap.dart';
import '../widgets/unfold.dart';
import '../l10n/l10n.dart';
import '../dlog.dart';
import '../wide/read_width.dart' show DeskPage;

// the route switch, a stand-in in tests: the real one moves the engine
@visibleForTesting
Future<void> Function(String mode)? setRouteForTest;

// android's page for the messages channel, a stand-in in tests
@visibleForTesting
Future<bool> Function()? openSoundForTest;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  final _timers = SeenTimers();
  bool _busy = false;
  // google push is starting: firebase asked for its token
  bool _starting = false;
  // what a notification shows: how messages arrive and what they say when
  // they do are the same question. null until read, so the row never opens
  // on a default
  NotifShow? _show;
  // the battery exemption, and the phone maker's own switch where it has one
  bool? _exempt;
  BrandGuide? _guide;
  late final ReadyEdge _torUp;
  // a message request pops up and sounds. null until read
  bool? _requestPopups;

  // no .then() without a catch: a throw here must not break the page
  void _readShow() {
    Future.wait([loadNotifPlain(), loadHideNotifContent(session.container)])
        .then((v) {
          if (mounted) {
            setState(() => _show = notifShowOf(plain: v[0], hidden: v[1]));
          }
        })
        .catchError((Object e) {
          dlog('notifications: setting (${e.runtimeType})');
        });
  }

  void _readBattery() {
    Future.wait([batteryExempt(), makerGuide()])
        .then((v) {
          if (mounted) {
            setState(() {
              _exempt = v[0] as bool;
              _guide = v[1] as BrandGuide?;
            });
          }
        })
        .catchError((Object e) {
          dlog('notifications: battery (${e.runtimeType})');
        });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _readShow();
    _readBattery();
    loadRequestPopups()
        .then((v) {
          if (mounted) setState(() => _requestPopups = v);
        })
        .catchError((Object e) {
          dlog('notifications: requests (${e.runtimeType})');
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

  // back from android's battery or channel page: what it says now
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _readBattery();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timers.watch(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timers.dispose();
    _torUp.dispose();
    _clock.cancel();
    appState.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  // the connection's reading changes by time alone too: a grace ends
  final _clock = LinkClock();

  Future<void> _pick(DeliveryMode m) async {
    if (_busy || m == appState.deliveryMode) return;
    setState(() => _busy = true);
    if (m == DeliveryMode.google) {
      setState(() => _starting = true);
      final ok = await appState.useGoogle();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _starting = false;
      });
      if (!ok) {
        HapticFeedback.heavyImpact();
        showHaloToast(context, l10n.notificationsGoogleNoStart);
      } else {
        HapticFeedback.lightImpact();
      }
      return;
    }
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

  // the helper app and google push go over tor or not at all, so their
  // cards offer the onion route first. the same switch as speed and
  // privacy, which asks nothing before onion
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

  // android keeps a channel's sound once it is made, so its own page is
  // where sound and vibration are set
  Future<void> _openSound() async {
    final opened =
        await (openSoundForTest ??
            () async =>
                openNotificationSettings(channel: await messageChannelId()))();
    if (!opened && mounted) showHaloToast(context, l10n.homeCouldnTOpenIt);
  }

  Widget _note(String text, {bool open = true}) => Unfold(
    open: open,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
      child: Text(
        text,
        style: HaloType.sans(size: 12.5, height: 1.5, color: HaloColors.warm),
      ),
    ),
  );

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 22),
    child: HaloSection(label, flush: true),
  );

  @override
  Widget build(BuildContext context) {
    final mode = appState.deliveryMode;
    final onOnion = appState.sendMode == 'private';
    // why the helper app cannot be picked yet, or null when it can
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
    // google push works on every route, and says so while it starts
    final google = appState.googleOffered || mode == DeliveryMode.google;
    final String? googleWait = _starting
        ? l10n.notificationsGoogleStarting
        : null;
    // the reading the home pill and the tor sheet show, grace and words
    // alike. tor resting between check-ins keeps the check-in lines
    final link = appState.linkView;
    _clock.arm(link.recheckAt, _changed);
    // the dot pulses with the pill's
    final connecting = link.pulsing;
    final resting = mode == DeliveryMode.checkins && link.kind == LinkKind.off;
    DeliveryStatus said(String words) => deliveryStatus(
      mode: mode,
      connected: link.connected,
      connecting: connecting,
      state: link.connected || resting ? null : words,
      lastCheckMs: appState.lastCheckAt,
      lastWakeMs: appState.lastWakeAt,
      nowMs: DateTime.now().millisecondsSinceEpoch,
      helperName: appState.helperName,
    );
    final status = said(link.text);
    // a screen reader hears a new state, not each percent of a climb
    final heard = said(link.spoken).text;
    // how tor gets out, when it is not the usual way. never in a decoy
    final bs = appState.bridgeStatus;
    final String? bridgeNote =
        appState.inDecoyView || appState.sendMode != 'private'
        ? null
        : bs.throughBridge && link.connected
        ? l10n.bridgesThroughABridge
        : appState.autoStruggling
        ? appState.bridgeLine.head
        : null;
    final guide = _guide;
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: DeskPage(
        child: SafeArea(
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
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.settingsNotifications,
                          style: HaloType.serif(
                            size: 30,
                            weight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.notificationsLeadShown,
                        style: HaloType.sans(
                          size: 13,
                          height: 1.45,
                          color: HaloColors.warm,
                        ),
                      ),
                    ],
                  ),
                ),
                // a computer has no delivery modes: the window's process is
                // the app. its own section takes their place
                _section(
                  onDesktop
                      ? l10n.desktopRunSection
                      : l10n.notificationsHowTheyReachYou,
                ),
                const SizedBox(height: 8),
                // play builds on a phone with play services: google push
                // first, the one most people want
                if (google && !onDesktop)
                  _ModeCard(
                    key: const ValueKey('googleCard'),
                    title: l10n.deliveryModeGooglePush,
                    tag: l10n.notificationsRecommended,
                    body: googleCardBody(onion: onOnion),
                    on: mode == DeliveryMode.google,
                    wait: googleWait,
                    checking: _starting,
                    onTap: _starting ? null : () => _pick(DeliveryMode.google),
                  ),
                if (!onDesktop) ...[
                  _ModeCard(
                    title: l10n.gettingMessagesAlwaysOn,
                    // on fast it does not go through tor, and is not the most
                    // private way
                    tag: onOnion ? l10n.gettingMessagesMostPrivate : null,
                    body: onOnion
                        ? l10n.gettingMessagesMessagesArriveInstantlyNothing
                        : l10n.gettingMessagesArriveInstantlyFast,
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
                  // always there, greyed until onion and our relay allow it.
                  // a linked device's pushes are its phone's
                  if (!linkedRole)
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
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
                  child: Row(
                    children: [
                      // it pulses only while tor is on its way, and holds
                      // still once live
                      if (!status.live && connecting)
                        BreathDot(color: HaloColors.amber, size: 6)
                      else
                        AnimatedContainer(
                          duration: reduceMotion(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 300),
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
                          label: heard,
                          excludeSemantics: true,
                          child: RiseSwap(
                            child: Text(
                              status.text,
                              key: ValueKey((status.live, link.kind)),
                              style: HaloType.mono(
                                size: 12,
                                color: status.live
                                    ? HaloColors.greenText
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
                        style: HaloType.mono(
                          size: 11.5,
                          color: HaloColors.text,
                        ),
                      ),
                    ),
                  ),
                ),
                // each mode's note grows in and folds away, so the page never
                // jumps under a finger
                if (onDesktop && desktopRun != null)
                  DeskRunSection(run: desktopRun!),
                if (!onDesktop) ...[
                  _note(
                    l10n.gettingMessagesWhenThePhoneSits,
                    open: mode == DeliveryMode.checkins,
                  ),
                  // some registration the relay keeps refusing: a plain line,
                  // the check-ins carry those chats meanwhile
                  _note(
                    l10n.gettingMessagesHelperRefused,
                    open: mode == DeliveryMode.helper && appState.helperRefused,
                  ),
                  _note(
                    l10n.notificationsGoogleRefused,
                    open: mode == DeliveryMode.google && appState.helperRefused,
                  ),
                  _note(
                    l10n.gettingMessagesHelperNote,
                    open: mode == DeliveryMode.helper,
                  ),
                  _note(
                    l10n.notificationsGoogleNote,
                    open: mode == DeliveryMode.google,
                  ),
                ],
                const SizedBox(height: 10),
                // android's channel page; a computer has its own switch
                _section(l10n.notificationsSoundAndVibrationShown),
                if (onDesktop)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: HaloGroup(
                      children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: deskSound,
                          builder: (_, on, _) => HaloRow(
                            key: const ValueKey('deskSoundRow'),
                            icon: on
                                ? Icons.volume_up_outlined
                                : Icons.volume_off_outlined,
                            label: l10n.notificationsPlaySound,
                            hint: l10n.notificationsPlaySoundHint,
                            toggled: on,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setDeskSound(!on);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!onDesktop)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: HaloGroup(
                      children: [
                        HaloRow(
                          key: const ValueKey('soundRow'),
                          icon: Icons.volume_up_outlined,
                          label: l10n.notificationsChannelName,
                          hint: l10n.notificationsSoundHint,
                          onTap: _openSound,
                        ),
                        // a request from someone not added yet waits quietly
                        // unless this is on
                        HaloRow(
                          key: const ValueKey('requestPopupsRow'),
                          icon: Icons.person_add_alt_outlined,
                          label: l10n.notifRequestPopups,
                          hint: l10n.notifRequestPopupsHint,
                          toggled: _requestPopups ?? false,
                          pending: _requestPopups == null,
                          onTap: _requestPopups == null
                              ? null
                              : () async {
                                  HapticFeedback.selectionClick();
                                  final on = !_requestPopups!;
                                  setState(() => _requestPopups = on);
                                  await saveRequestPopups(on);
                                },
                        ),
                      ],
                    ),
                  ),
                _section(l10n.gettingMessagesWhatShows),
                // what they say is chosen in one place, with the icon: this
                // row goes there
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: HaloGroup(
                    children: [
                      HaloRow(
                        icon: Icons.notifications_none_rounded,
                        label: l10n.notificationsEachShows,
                        value: _show == null ? null : notifShowName(_show!),
                        onTap: () async {
                          await Navigator.of(context).push(
                            haloRoute(const IconScreen(toNotifications: true)),
                          );
                          _readShow();
                        },
                      ),
                    ],
                  ),
                ),
                // a pin turns previews off. if someone turns them back on,
                // say what that gives away, in the warning's own colour
                Unfold(
                  open: lockState.lockOn && _show == NotifShow.all,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
                    child: Text(
                      l10n.gettingMessagesShowsMessageTextIn,
                      style: HaloType.sans(
                        size: 12,
                        color: HaloColors.roseText,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
                if (!onDesktop) _section(l10n.notificationsBatteryTips),
                if (!onDesktop)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: HaloGroup(
                      children: [
                        HaloRow(
                          key: const ValueKey('batteryRow'),
                          icon: Icons.battery_saver,
                          label: l10n.settingsRunInBackground,
                          hint: l10n.settingsSoMessagesArrive,
                          value: _exempt == null
                              ? null
                              : _exempt!
                              ? l10n.notificationsBatteryAllowed
                              : l10n.notificationsBatteryNotYet,
                          onTap: () async {
                            await askBatteryExemption(context);
                            _readBattery();
                          },
                        ),
                        if (guide != null)
                          HaloRow(
                            key: const ValueKey('makerRow'),
                            icon: Icons.phone_android_outlined,
                            label: l10n.notificationsMakerSwitch,
                            hint: guide.title,
                            onTap: () => showMakerGuide(context),
                          ),
                      ],
                    ),
                  ),
              ]),
            ),
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
    super.key,
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
              duration: reduceMotion(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
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
