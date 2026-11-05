// SPDX-License-Identifier: GPL-3.0-or-later
// user-facing settings. the dev screen keeps the technical ones.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart' show historyCopyPage;
import '../main.dart'
    show
        appState,
        session,
        sessionQuiet,
        AppStateRoute,
        AppStatePrefs,
        AppStateProfile,
        AppStateDelivery,
        AppStateTyping,
        AppStateBridges,
        AppStateSession,
        AppStateDevchat,
        LinkViewBuilder,
        linkedRole,
        ownDevicesSource;
import '../app_version.dart';
import '../wide/read_width.dart';
import '../link_view.dart';
import '../lock_state.dart';
import '../intro_prefs.dart';
import '../scam_prefs.dart';
import '../typing.dart' show loadTypingOn;
import '../gifs/gif_opt_in.dart' show showGifOptInSheet;
import '../gifs/gif_source.dart' show loadGifSearchOn, saveGifSearchOn;
import '../widgets/press_scale.dart';
import '../widgets/motion.dart' show haloRoute, houseSpring;
import 'licences_screen.dart';
import 'why_kryfo_screen.dart';
import 'appearance_screen.dart';
import 'transport_screen.dart';
import 'bridges_screen.dart';
import '../bridge_mode.dart' show BridgeChoice, bridgeChoiceName;
import 'seen_screen.dart';
import 'translation_screen.dart';
import '../voice/ui/voice_tx_screen.dart';
import '../voice/voice_transcripts.dart' show voiceTranscriptsIfOn;
import '../translate/hub_live.dart' show translationHubIfOn;
import '../theme.dart';
import '../notif_permission.dart';
import 'modes_screen.dart';
import 'blocked_screen.dart';
import 'pins_screen.dart';
import 'backup_screen.dart';
import '../wipe.dart';
import 'restore_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../notifications.dart';
import '../delivery_mode.dart';
import '../desktop/desktop_mode.dart'
    show ComputerLockView, ComputerSeal, computerLock, desktopRun, onDesktop;
import '../last_backup.dart' show backupFresh, backupWhen, loadLastBackup;
import 'notifications_screen.dart';
import 'icon_screen.dart';
import '../app_icon.dart' show AppFace, AppFaceWords, appFaceNow, readAppFace;
import '../widgets/halo_rows.dart';
import '../widgets/dev_avatar.dart' show DevRing;
import 'dev_about_sheet.dart' show devChatOffered, writeToMarios;
import 'auto_get_screen.dart';
import 'follow_section.dart';
import 'linked_devices_screen.dart';
import '../devices/own_devices.dart' show kLinkedDevicesOn, OwnDevices;
import '../widgets/stagger_in.dart';
import '../widgets/unfold.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/message_menu.dart' show MenuSheet, MenuSheetRow;
import '../widgets/halo_sheet.dart';
import '../l10n/l10n.dart';
import '../widgets/language_sheet.dart';
import '../wipe_word.dart';
import '../first_contact.dart' show firstFails;
import '../update_check.dart' show updateNotice;

// one protection: a ring that fills on the house spring and ticks, and its
// state, which rises in when it changes. turning on washes the line amber
// once, so a change made elsewhere is noticed here
class ProtectionLine extends StatefulWidget {
  final String label;
  final bool on;
  final String state;
  // what makes a new state rather than new words in the same one: a
  // climbing percent changes in place
  final Object? stateKey;
  // a line that leads somewhere: the whole line is the button
  final VoidCallback? onTap;
  const ProtectionLine(
    this.label,
    this.on,
    this.state, {
    this.stateKey,
    super.key,
    this.onTap,
  });
  @override
  State<ProtectionLine> createState() => _ProtectionLineState();
}

class _ProtectionLineState extends State<ProtectionLine>
    with TickerProviderStateMixin {
  late final AnimationController _mark = AnimationController.unbounded(
    vsync: this,
    value: widget.on ? 1 : 0,
  );
  late final AnimationController _wash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didUpdateWidget(ProtectionLine old) {
    super.didUpdateWidget(old);
    if (old.on == widget.on) return;
    final to = widget.on ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _mark.value = to;
      return;
    }
    // the spring stops within a hair of its end: the end itself after
    _mark.animateWith(houseSpring(_mark.value, to, _mark.velocity)).then((_) {
      if (mounted) _mark.value = to;
    });
    if (widget.on) _wash.forward(from: 0);
  }

  @override
  void dispose() {
    _mark.dispose();
    _wash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.on;
    final still = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _wash,
      builder: (_, child) {
        final w = _wash.isAnimating
            ? Curves.easeOut.transform(_wash.value)
            : 1.0;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: HaloColors.amber.withValues(alpha: 0.12 * (1 - w)),
          ),
          child: child,
        );
      },
      child: _tappable(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _mark,
                builder: (_, _) => CustomPaint(
                  size: const Size.square(18),
                  painter: _MarkPainter(
                    _mark.value,
                    HaloColors.amber,
                    HaloColors.text3,
                    HaloColors.onAmber,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // the label wraps and the state keeps its place: in a long
              // language at a big font size the two do not fit one line
              Expanded(
                child: Text(
                  widget.label,
                  style: HaloType.sans(size: 13, color: HaloColors.text),
                ),
              ),
              const SizedBox(width: 8),
              // a long state wraps at its end rather than running off it
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.4,
                ),
                child: AnimatedSwitcher(
                  duration: still
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.35),
                        end: Offset.zero,
                      ).animate(a),
                      child: c,
                    ),
                  ),
                  layoutBuilder: (top, gone) => Stack(
                    alignment: AlignmentDirectional.centerEnd,
                    children: [...gone, ?top],
                  ),
                  child: Text(
                    widget.state,
                    key: ValueKey(widget.stateKey ?? widget.state),
                    textAlign: TextAlign.end,
                    style: HaloType.mono(
                      size: 10,
                      color: on ? HaloColors.amberText : HaloColors.text3,
                    ),
                  ),
                ),
              ),
              if (widget.onTap != null) ...[
                const SizedBox(width: 2),
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left
                      : Icons.chevron_right,
                  size: 16,
                  color: HaloColors.text3,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tappable(Widget child) {
    final tap = widget.onTap;
    if (tap == null) return child;
    return Semantics(
      button: true,
      child: PressScale(scale: 0.98, onTap: tap, child: child),
    );
  }
}

// a ring, then a filled round with a tick drawn across it as [t] goes to 1
class _MarkPainter extends CustomPainter {
  final double t;
  final Color amber, ring, tick;
  _MarkPainter(this.t, this.amber, this.ring, this.tick);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 1;
    final k = t.clamp(0.0, 1.0);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Color.lerp(ring, amber, k)!,
    );
    if (t <= 0.01) return;
    canvas.drawCircle(c, r * t.clamp(0.0, 1.15), Paint()..color = amber);
    final d = (t - 0.35) / 0.65;
    if (d <= 0) return;
    final p = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.67)
      ..lineTo(size.width * 0.73, size.height * 0.36);
    final m = p.computeMetrics().first;
    canvas.drawPath(
      m.extractPath(0, m.length * d.clamp(0.0, 1.0)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = tick,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter o) =>
      o.t != t || o.amber != amber || o.ring != ring || o.tick != tick;
}

// how many of the lines are on, one segment each, filling as they turn on
class ProtectionMeter extends StatelessWidget {
  final List<bool> on;
  const ProtectionMeter(this.on, {super.key});

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, lit) in on.indexed) ...[
            if (i > 0) const SizedBox(width: 3),
            AnimatedContainer(
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: lit ? 16 : 10,
              height: 4,
              decoration: BoxDecoration(
                color: lit ? HaloColors.amber : HaloColors.line2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // known already when anything read it before: the row never grows a line
  late bool? _hidePreview = hideNotifContentKnown(session.container);
  // plain notifications, the phone's: they hide the preview too
  bool? _plain = notifPlainKnown();
  Future<void> _confirmWipe() async {
    // step 1: explain what's about to happen
    final go = await showConfirmSheet(
      context,
      title: l10n.settingsWipeKryfo,
      line: l10n.settingsIdentityMessagesContactsAndShown,
      yes: l10n.commonContinue,
      keep: l10n.commonCancel,
    );
    if (!go || !mounted) return;

    // step 2: type the word
    final typed = (await showInputSheet(
      context,
      title: l10n.settingsTypeWipeToConfirm(l10n.settingsWipeWord),
      line: l10n.settingsTheLastStepNothing,
      hint: l10n.settingsWipeWord,
      mono: true,
      rose: true,
      save: l10n.settingsWipeKryfo2,
    ));
    if (isWipeWord(typed, l10n.settingsWipeWord)) {
      // a quiet session holds no handle, and gives none back
      await wipeHalo(releaseHandle: !sessionQuiet);
    }
  }

  // null until read: a switch never opens on a default and slides
  bool? _disguise;
  bool? _acceptIntros;
  bool? _shieldOn;
  bool? _typingOn;
  bool? _gifOn;
  // only for copies from the site or github
  bool _updateOffered = false;
  bool? _updateOn;
  // asked once a visit, not on every rebuild
  late final Future<bool> _notifs = notificationsEnabled();
  // when this side last handed a backup out, once read
  bool _backupRead = false;
  DateTime? _lastBackup;

  void _readLastBackup() {
    loadLastBackup(session.container).then((v) {
      if (mounted) {
        setState(() {
          _backupRead = true;
          _lastBackup = v;
        });
      }
    });
  }

  Future<void> _openBackup() async {
    await Navigator.of(context).push(haloRoute(const BackupScreen()));
    if (mounted) _readLastBackup();
  }

  Future<void> _openComputerLock(ComputerLockView lock) => Navigator.of(
    context,
  ).push(haloRoute(lock.page(decoy: lockState.inDecoy)));

  @override
  void initState() {
    super.initState();
    readAppFace();
    _readHidePreview();
    // a PIN set on the App lock screen hides the preview too
    hideNotifRevision.addListener(_readHidePreview);
    appState.loadDisguisePref().then((d) {
      if (mounted) setState(() => _disguise = d);
    });
    loadAcceptIntros(session.container).then((v) {
      if (mounted) setState(() => _acceptIntros = v);
    });
    loadScamShieldOn(session.container).then((v) {
      if (mounted) setState(() => _shieldOn = v);
    });
    loadTypingOn(session.container).then((v) {
      if (mounted) setState(() => _typingOn = v);
    });
    loadGifSearchOn(session.container).then((v) {
      if (mounted) setState(() => _gifOn = v);
    });
    _readUpdateOn();
    if (kLinkedDevicesOn) _readDevices();
    if (!linkedRole) _readLastBackup();
  }

  // the devices row's value, from where the devices page reads
  OwnDevices? _devices;
  String? _devicesValue;
  Future<void> _readDevices() async {
    try {
      final src = await ownDevicesSource();
      final all = await src.load();
      if (!mounted) return;
      setState(() {
        _devices = src;
        _devicesValue = devicesRowValue(all);
      });
    } catch (_) {
      // no value then, and the row still opens the page
      if (mounted) setState(() => _devicesValue = '');
    }
  }

  Future<void> _openDevices() async {
    final src = _devices ?? await ownDevicesSource();
    if (!mounted) return;
    await Navigator.of(context).push(
      haloRoute(LinkedDevicesScreen(source: src, copyPage: historyCopyPage)),
    );
    if (mounted) await _readDevices();
  }

  Future<void> _readUpdateOn() async {
    await updateNotice.ready();
    if (!updateNotice.eligible) return;
    final v = await updateNotice.isOn();
    if (mounted) {
      setState(() {
        _updateOffered = true;
        _updateOn = v;
      });
    }
  }

  // how messages arrive, how they sound and what they show: one screen
  Future<void> _openNotifications() async {
    await Navigator.of(context).push(haloRoute(const NotificationsScreen()));
    _readHidePreview();
  }

  void _readHidePreview() {
    loadHideNotifContent(session.container).then((v) {
      if (mounted) setState(() => _hidePreview = v);
    });
    loadNotifPlain().then((v) {
      if (mounted) setState(() => _plain = v);
    });
  }

  @override
  void dispose() {
    hideNotifRevision.removeListener(_readHidePreview);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        leading: BackButton(color: HaloColors.text2),
        title: Text(
          l10n.commonSettings,
          style: HaloType.serif(size: 18, color: HaloColors.text, italic: true),
        ),
      ),
      // a computer keeps the rows in a centred column, the wheel still
      // scrolls from the margins
      body: ReadWidth(
        builder: (context, side) => ListView(
          padding: EdgeInsets.fromLTRB(
            20 + side,
            8,
            20 + side,
            32 + MediaQuery.paddingOf(context).bottom,
          ),
          children: staggerAll([
            LinkViewBuilder(
              builder: (_, link) => ListenableBuilder(
                listenable: Listenable.merge([lockState, ?computerLock]),
                builder: (_, _) {
                  // the reading the home pill and the tor sheet show, grace and
                  // words alike, or the screens disagree about the same tor.
                  // relay and fast modes never use tor, so a state there would
                  // be a promise nothing is trying to keep
                  final onTor = appState.sendMode == 'private';
                  final torOn = onTor && link.kind == LinkKind.ready;
                  // as the App lock screen reads it: a lock turned off in a
                  // decoy session is off
                  final lock = lockState.lockOn;
                  // a computer shows what opens its vault instead, as this
                  // session sees it: a decoy its own note
                  final desk = onDesktop ? computerLock : null;
                  final sealed = desk?.sealedBy(decoy: lockState.inDecoy);
                  final passOn = sealed == ComputerSeal.passphrase;
                  // this side's own backups. a linked device keeps none
                  final backups = !linkedRole;
                  final fresh = backupFresh(_lastBackup);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                    decoration: BoxDecoration(
                      color: HaloColors.surface2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: HaloColors.line, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.settingsYourProtections,
                                  style: HaloType.mono(
                                    size: 11,
                                    color: HaloColors.amberText,
                                  ),
                                ),
                              ),
                              ProtectionMeter([
                                torOn,
                                desk == null ? lock : passOn,
                                if (backups) fresh,
                              ]),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ProtectionLine(
                          l10n.settingsTorRouting,
                          stateKey: (onTor, link.kind),
                          torOn,
                          torOn
                              ? l10n.settingsConnected
                              : onTor
                              ? link.text
                              // relay and fast are one route now
                              : l10n.settingsOffFastMode,
                        ),
                        if (desk == null)
                          ProtectionLine(
                            l10n.settingsAppLock,
                            lock,
                            lock ? l10n.settingsOn : l10n.settingsOff,
                          )
                        else
                          ProtectionLine(
                            l10n.desktopPassRow,
                            passOn,
                            switch (sealed!) {
                              ComputerSeal.passphrase => l10n.settingsOn,
                              ComputerSeal.windows =>
                                l10n.desktopPassWindowsAccount,
                              ComputerSeal.keyring => l10n.desktopPassKeyring,
                            },
                            key: const ValueKey('computerPassLine'),
                            onTap: () => _openComputerLock(desk),
                          ),
                        if (backups)
                          ProtectionLine(
                            l10n.settingsProtectBackup,
                            fresh,
                            _backupRead ? backupWhen(_lastBackup) : '',
                            key: const ValueKey('backupLine'),
                            onTap: _openBackup,
                          ),
                        // only when android is blocking them: a line that says
                        // so outlives the home banner, which can be dismissed
                        FutureBuilder<bool>(
                          future: _notifs,
                          builder: (_, snap) => Unfold(
                            open: snap.data == false,
                            child: ProtectionLine(
                              l10n.settingsNotifications,
                              false,
                              l10n.settingsBlockedByAndroid,
                              key: const ValueKey('notifsBlockedLine'),
                              onTap: _openNotifications,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            HaloGroup(
              children: [
                HaloRow(
                  icon: Icons.language,
                  label: l10n.languageTitle,
                  value: languageValue(),
                  onTap: () => pickLanguage(context),
                ),
              ],
            ),
            HaloSection(l10n.settingsPrivacy),
            HaloGroup(
              children: [
                HaloRow(
                  icon: Icons.shield_outlined,
                  label: l10n.settingsSpeedPrivacy,
                  value: appState.sendMode == 'private'
                      ? l10n.settingsPrivateTor
                      : l10n.settingsFast,
                  onTap: () async {
                    await Navigator.of(
                      context,
                    ).push(haloRoute(const ModesScreen()));
                    if (mounted) setState(() {});
                  },
                ),
                HaloRow(
                  icon: Icons.vpn_lock_outlined,
                  label: l10n.bridgesConnection,
                  hint: l10n.settingsBridgesForNetworksThat,
                  // a decoy sees automatic, whatever runs underneath
                  value: bridgeChoiceName(
                    appState.inDecoyView
                        ? BridgeChoice.auto
                        : appState.bridgeChoice,
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      haloRoute(const BridgesScreen()),
                    );
                    if (mounted) setState(() {});
                  },
                ),
                // one row: how messages arrive and what they say when they do
                // belong together
                ListenableBuilder(
                  listenable: desktopRun ?? const _Still(),
                  builder: (_, _) {
                    // a computer has no delivery modes: it keeps running in
                    // the tray, or gets messages while its window is open
                    final how = !onDesktop
                        ? deliveryModeName(appState.deliveryMode)
                        : desktopRun?.trayOn == false
                        ? l10n.settingsDeskWhileOpen
                        : l10n.settingsDeskInTray;
                    return HaloRow(
                      icon: Icons.notifications_none_rounded,
                      label: l10n.settingsNotifications,
                      value: switch (_plain == true ? true : _hidePreview) {
                        null => how,
                        true => l10n.settingsPreviewHidden(how),
                        false => l10n.settingsPreviewShown(how),
                      },
                      onTap: _openNotifications,
                    );
                  },
                ),
                HaloRow(
                  icon: Icons.lan_outlined,
                  label: l10n.settingsTransport,
                  value: l10n.settingsWhatTheNetworkIs,
                  onTap: () => Navigator.push(
                    context,
                    haloRoute(const TransportScreen()),
                  ),
                ),
                HaloRow(
                  icon: Icons.block,
                  label: l10n.settingsBlocked,
                  onTap: () => Navigator.of(
                    context,
                  ).push(haloRoute(const BlockedScreen())),
                ),
                HaloRow(
                  icon: Icons.people_outline,
                  label: l10n.settingsAcceptIntroductions,
                  hint: l10n.settingsFriendsCanIntroduceYou,
                  toggled: _acceptIntros ?? true,
                  pending: _acceptIntros == null,
                  onTap: () async {
                    final v = !(_acceptIntros ?? true);
                    setState(() => _acceptIntros = v);
                    await saveAcceptIntros(v, session.container);
                  },
                ),
                HaloRow(
                  icon: Icons.shield_outlined,
                  label: l10n.settingsScamShield,
                  hint: l10n.settingsScamShieldHintShown,
                  toggled: _shieldOn ?? true,
                  pending: _shieldOn == null,
                  onTap: () async {
                    final v = !(_shieldOn ?? true);
                    setState(() => _shieldOn = v);
                    await saveScamShieldOn(v, session.container);
                  },
                ),
                // on by default, and mutual: with it off nothing goes and
                // nothing shows. it works on the onion route alone. a decoy's
                // flips like this one and does nothing
                // while bridges carry tor it is off and says why, and comes
                // back by itself after. a decoy shows nothing of the bridges
                ListenableBuilder(
                  listenable: appState,
                  builder: (_, _) {
                    final bridged =
                        !appState.inDecoyView && appState.typingBridged;
                    return HaloRow(
                      icon: Icons.more_horiz_rounded,
                      label: l10n.settingsTypingIndicator,
                      hint: l10n.settingsTypingIndicatorHint,
                      note: appState.sendMode != 'private'
                          ? l10n.settingsTypingOnionOnly
                          : bridged
                          ? l10n.settingsTypingBridgesOff
                          : null,
                      toggled: (_typingOn ?? true) && !bridged,
                      pending: _typingOn == null,
                      onTap: bridged
                          ? null
                          : () async {
                              final v = !(_typingOn ?? true);
                              setState(() => _typingOn = v);
                              await appState.setTypingOn(v);
                            },
                    );
                  },
                ),
                // off by default: turning it on says first what it does. each
                // identity has its own, and a quiet session's never searches
                HaloRow(
                  icon: Icons.gif_box_outlined,
                  label: l10n.settingsGifSearch,
                  hint: l10n.settingsGifSearchHint,
                  toggled: _gifOn ?? false,
                  pending: _gifOn == null,
                  onTap: () async {
                    if (_gifOn ?? false) {
                      setState(() => _gifOn = false);
                      await saveGifSearchOn(false, session.container);
                      return;
                    }
                    final yes = await showGifOptInSheet(
                      context,
                      overTor: appState.sendMode == 'private',
                    );
                    if (!yes || !mounted) return;
                    setState(() => _gifOn = true);
                    await saveGifSearchOn(true, session.container);
                  },
                ),
              ],
            ),
            HaloSection(l10n.settingsSecurity),
            HaloGroup(
              children: [
                AnimatedBuilder(
                  animation: lockState,
                  builder: (_, _) => HaloRow(
                    icon: Icons.lock_outline,
                    label: l10n.settingsAppLock2,
                    hint: l10n.settingsYourPinAndA,
                    value: !lockState.lockOn
                        ? l10n.commonOff
                        : lockState.panicEnabled
                        ? l10n.settingsPinWipePin
                        : l10n.commonOn,
                    onTap: () => Navigator.of(
                      context,
                    ).push(haloRoute(const PinsScreen())),
                  ),
                ),
                // the same row and page in a decoy session, which keeps
                // what it changes to itself and never moves the real lock
                if (computerLock case final lock?)
                  ListenableBuilder(
                    listenable: Listenable.merge([lock, lockState]),
                    builder: (_, _) {
                      final decoy = lockState.inDecoy;
                      return HaloRow(
                        icon: Icons.key_rounded,
                        label: l10n.desktopPassRow,
                        value: lock.passphraseOn(decoy: decoy)
                            ? l10n.commonOn
                            : l10n.commonOff,
                        onTap: () => Navigator.of(
                          context,
                        ).push(haloRoute(lock.page(decoy: decoy))),
                      );
                    },
                  ),
                // the icon and the notifications read the phone's values, in
                // any session. a computer has no launcher icon to disguise:
                // what notifications show is under Notifications there
                if (!onDesktop)
                  ValueListenableBuilder<AppFace?>(
                    valueListenable: appFaceNow,
                    builder: (_, face, _) {
                      return HaloRow(
                        icon: Icons.apps_rounded,
                        label: l10n.settingsIconAndNotifications,
                        value: face == null
                            ? null
                            : _plain == true
                            ? l10n.iconSettingsValue(face.label)
                            : face.label,
                        onTap: () => Navigator.of(
                          context,
                        ).push(haloRoute(const IconScreen())),
                      );
                    },
                  ),
              ],
            ),
            if (kLinkedDevicesOn) ...[
              HaloSection(l10n.settingsDevices),
              HaloGroup(
                children: [
                  HaloRow(
                    icon: Icons.devices_rounded,
                    label: l10n.devicesLinkedDevices,
                    // held in place unseen until the load, then faded in
                    value: _devicesValue ?? devicesRowValue(const []),
                    pending: _devicesValue == null,
                    hint: linkedRole ? l10n.settingsLinkedToLine : null,
                    onTap: _openDevices,
                  ),
                ],
              ),
            ],
            HaloSection(l10n.settingsAppearance),
            HaloGroup(
              children: [
                HaloRow(
                  icon: Icons.light_mode_outlined,
                  label: l10n.settingsLightTheme,
                  hint: l10n.settingsSameProtectionBrighter,
                  toggled: HaloColors.isLight,
                  onTap: () async {
                    await appState.setLight(!HaloColors.isLight);
                    if (mounted) setState(() {});
                  },
                ),
                HaloRow(
                  icon: Icons.palette_outlined,
                  label: l10n.settingsColoursAndWallpaper,
                  value: accentName(HaloColors.accent),
                  onTap: () async {
                    await Navigator.of(
                      context,
                    ).push(haloRoute(const AppearanceScreen()));
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
            HaloSection(l10n.settingsFiles),
            HaloGroup(
              children: [
                HaloRow(
                  icon: Icons.download_for_offline_outlined,
                  label: l10n.autoGetTitle,
                  onTap: () => Navigator.of(
                    context,
                  ).push(haloRoute(const AutoGetScreen())),
                ),
              ],
            ),
            // a linked device keeps no backup of its own: its phone's
            // backup is the account's
            if (!linkedRole) ...[
              HaloSection(l10n.settingsBackup),
              HaloGroup(
                children: [
                  // windows without a passphrase: a backup is the way back if
                  // the computer's key goes
                  ListenableBuilder(
                    listenable: Listenable.merge([?computerLock, lockState]),
                    builder: (_, _) => HaloRow(
                      icon: Icons.save_alt,
                      label: l10n.settingsBackUpIdentity,
                      value: l10n.settingsEncryptedFile,
                      hint:
                          computerLock?.backupWise(decoy: lockState.inDecoy) ??
                              false
                          ? l10n.desktopBackupHint
                          : null,
                      onTap: _openBackup,
                    ),
                  ),
                  HaloRow(
                    icon: Icons.restore,
                    label: l10n.settingsRestoreFromBackup,
                    value: l10n.settingsReplaceCurrent,
                    onTap: () => Navigator.of(
                      context,
                    ).push(haloRoute(const RestoreScreen())),
                  ),
                ],
              ),
            ],
            HaloSection(l10n.settingsVoice),
            HaloGroup(
              children: [
                HaloRow(
                  icon: Icons.record_voice_over,
                  label: l10n.settingsDisguiseByDefault,
                  hint: l10n.settingsDisguiseByDefaultHint,
                  toggled: _disguise ?? false,
                  pending: _disguise == null,
                  onTap: () async {
                    final v = !(_disguise ?? false);
                    setState(() => _disguise = v);
                    await appState.saveDisguisePref(v);
                  },
                ),
                if (voiceTranscriptsIfOn() case final hub?)
                  HaloRow(
                    icon: Icons.notes_rounded,
                    label: l10n.voiceSettingsTitle,
                    hint: l10n.translateSettingsHintShown,
                    onTap: () => Navigator.of(
                      context,
                    ).push(haloRoute(VoiceTxScreen(hub: hub))),
                  ),
              ],
            ),
            if (translationHubIfOn() case final hub?) ...[
              HaloSection(l10n.translateSettingsTitle),
              HaloGroup(
                children: [
                  HaloRow(
                    icon: Icons.translate_rounded,
                    label: l10n.translateSettingsRow,
                    hint: l10n.translateSettingsHintShown,
                    onTap: () => Navigator.of(
                      context,
                    ).push(haloRoute(TranslationScreen(hub: hub))),
                  ),
                ],
              ),
            ],
            HaloSection(l10n.settingsAbout),
            HaloGroup(
              children: [
                HaloRow(
                  icon: Icons.help_outline,
                  label: l10n.settingsWhyKryfo,
                  value: l10n.settingsHowItProtectsYou,
                  onTap: () => Navigator.push(
                    context,
                    haloRoute(const WhyKryfoScreen()),
                  ),
                ),
                // the developer's own phone: every install pins its card, and
                // a new link would cut every chat with it
                // invites are the phone's: a linked device has none
                if (linkedRole)
                  ...const <Widget>[]
                else if (appState.devMode)
                  HaloRow(
                    icon: Icons.lock_outline,
                    label: l10n.settingsResetMyInviteLink,
                    hint: l10n.supportResetPinned,
                  )
                else
                  HaloRow(
                    icon: Icons.autorenew,
                    label: l10n.settingsResetMyInviteLink,
                    hint: l10n.settingsOldLinksAndCodes,
                    onTap: () async {
                      final ok = await showConfirmSheet(
                        context,
                        title: l10n.settingsResetInviteLink,
                        line: l10n.settingsAnyoneWithAnOld,
                        yes: l10n.settingsReset,
                      );
                      if (!ok) return;
                      await appState.resetInviteAddress();
                      if (context.mounted) {
                        showHaloToast(
                          context,
                          l10n.settingsInviteResetShareThe,
                        );
                      }
                    },
                  ),
                HaloRow(
                  icon: Icons.visibility_outlined,
                  label: l10n.settingsWhatWeCanSee,
                  value: l10n.settingsTheHonestList,
                  onTap: () =>
                      Navigator.push(context, haloRoute(const SeenScreen())),
                ),
                HaloRow(
                  icon: Icons.info_outline,
                  label: l10n.settingsVersion,
                  value: l10n.settingsVersionAlpha(kAppVersion),
                ),
                // f-droid and play keep their copies updated. a quiet
                // session keeps a switch of its own and asks nothing
                if (_updateOffered)
                  HaloRow(
                    icon: Icons.system_update_outlined,
                    label: l10n.settingsCheckForUpdates,
                    hint: l10n.settingsCheckForUpdatesHint,
                    toggled: _updateOn ?? true,
                    pending: _updateOn == null,
                    onTap: () async {
                      final v = !(_updateOn ?? true);
                      setState(() => _updateOn = v);
                      await updateNotice.setOn(v);
                    },
                  ),
                // the chat with the developer: the way back after a delete.
                // none on his own phone, none with no key pinned
                if (devChatOffered && !linkedRole)
                  HaloRow(
                    mark: const DevRing(size: 20),
                    label: l10n.settingsWriteToMarios,
                    hint: l10n.settingsWriteToMariosHint,
                    onTap: () => writeToMarios(context),
                  ),
                HaloRow(
                  icon: Icons.flag_outlined,
                  label: l10n.settingsReportAnIssue,
                  value: l10n.settingsBugOrSecurityFlaw,
                  onTap: () => reportAnIssue(context),
                ),
                // copies, never opens: a browser hop would hand github the
                // phone's address
                HaloRow(
                  icon: Icons.code,
                  label: l10n.settingsOpenSource,
                  value: 'github.com/GnosiWorks/Kryfo',
                  tapHint: l10n.settingsCopyLinkHint,
                  onTap: () async {
                    await Clipboard.setData(
                      const ClipboardData(
                        text: 'https://github.com/GnosiWorks/Kryfo',
                      ),
                    );
                    if (context.mounted) {
                      showHaloToast(context, l10n.settingsLinkCopied);
                    }
                  },
                ),
                HaloRow(
                  icon: Icons.article_outlined,
                  label: l10n.settingsLicences,
                  value: l10n.settingsLicencesValue,
                  onTap: () => Navigator.push(
                    context,
                    haloRoute(const LicencesScreen()),
                  ),
                ),
              ],
            ),
            // the map is a tool, and a computer has no tools tab yet
            if (!onDesktop)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 10, 12, 0),
                child: Text(
                  l10n.settingsTheOfflineMapIn,
                  style: HaloType.sans(
                    size: 12,
                    color: HaloColors.warm,
                    height: 1.4,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 10, 12, 0),
              child: Text(
                l10n.settingsNotIndependentlyAuditedPre,
                style: HaloType.sans(
                  size: 12,
                  color: HaloColors.text2,
                  height: 1.4,
                ),
              ),
            ),
            const FollowSection(),
            HaloSection(l10n.settingsDangerZone),
            HaloGroup(
              rose: true,
              children: [
                HaloRow(
                  icon: Icons.delete_outline,
                  label: l10n.settingsWipeKryfoFromThisShown,
                  rose: true,
                  onTap: _confirmWipe,
                ),
              ],
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }
}

// what a mailed report carries of this phone: why the last first contacts
// failed, as codes and minutes ago, never who, what or a key. nothing from
// a quiet session: an empty phone has nothing to say
@visibleForTesting
String reportCodes() {
  if (sessionQuiet) return '';
  final fc = firstFails.summary();
  return fc.isEmpty ? '' : '&body=${Uri.encodeComponent('first contact: $fc')}';
}

// a report goes where it is read soonest: the chat with Marios first, then
// mail. on his own phone, or with no key pinned, mail is the only way
Future<void> reportAnIssue(BuildContext context) async {
  void mail() => launchUrl(
    Uri.parse(
      'mailto:gnosiworks@proton.me?subject=Kryfo%20report${reportCodes()}',
    ),
    mode: LaunchMode.externalApplication,
  );
  if (!devChatOffered) {
    mail();
    return;
  }
  final pick = await showHaloSheet<String>(
    context,
    scroll: true,
    builder: (ctx) => SingleChildScrollView(
      child: MenuSheet(
        groups: [
          [
            MenuSheetRow(
              icon: Icons.forum_outlined,
              label: l10n.settingsReportInKryfo,
              sub: l10n.settingsReportInKryfoSub,
              tint: HaloColors.amber,
              onTap: () => Navigator.pop(ctx, 'chat'),
            ),
            MenuSheetRow(
              icon: Icons.mail_outline,
              label: l10n.settingsReportByEmail,
              sub: l10n.settingsReportByEmailSub,
              onTap: () => Navigator.pop(ctx, 'mail'),
            ),
          ],
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  if (pick == 'chat') await writeToMarios(context);
  if (pick == 'mail') mail();
}

// nothing to hear: the phone's rows build once
class _Still implements Listenable {
  const _Still();
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}
