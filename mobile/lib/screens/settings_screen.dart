// SPDX-License-Identifier: GPL-3.0-or-later
// settings_screen.dart - user-facing settings, consolidated from dev.
// reachable from the "Me" tab. tap on tab opens this, long-press still
// opens dev for technical use.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart' show appState;
import '../lock_state.dart';
import '../intro_prefs.dart';
import '../scam_prefs.dart';
import '../link_prefs.dart';
import '../miui_autostart.dart';
import '../widgets/motion.dart' show TorStatus, haloRoute;
import 'why_kryfo_screen.dart';
import 'transport_screen.dart';
import 'bridges_screen.dart';
import 'seen_screen.dart';
import '../copy.dart';
import '../theme.dart';
import '../notif_permission.dart';
import 'modes_screen.dart';
import 'blocked_screen.dart';
import 'push_settings_screen.dart';
import 'pins_screen.dart';
import 'backup_screen.dart';
import '../wipe.dart';
import 'restore_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../push_mode.dart';
import '../widgets/stagger_in.dart';
import '../widgets/confirm_sheet.dart';

Widget _postureLine(String label, bool on, String onText, String offText) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            on ? Icons.check_circle : Icons.radio_button_unchecked,
            key: ValueKey(on),
            size: 16,
            color: on ? HaloColors.amber : HaloColors.text3,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          sentence(label),
          style: HaloType.sans(size: 13, color: HaloColors.text),
        ),
        const Spacer(),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 240),
          style: HaloType.mono(
            size: 10,
            color: on ? HaloColors.amber : HaloColors.text3,
          ),
          child: Text(sentence(on ? onText : offText)),
        ),
      ],
    ),
  );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PushMode? _push;
  Future<void> _confirmWipe() async {
    // step 1: explain what's about to happen
    final go = await showConfirmSheet(
      context,
      title: 'Wipe kryfo?',
      line:
          'Identity, messages, contacts and settings on this phone. '
          'Gone for good unless you have a backup.',
      yes: 'Continue',
      keep: 'Cancel',
    );
    if (!go || !mounted) return;

    // step 2: type the word
    final ok =
        (await showInputSheet(
          context,
          title: "type 'wipe' to confirm",
          line: 'The last step. Nothing survives it.',
          hint: 'Wipe',
          mono: true,
          rose: true,
          save: 'Wipe kryfo',
        ))?.trim().toLowerCase() ==
        'wipe';
    if (ok) await wipeHalo();
  }

  bool _disguise = false;
  bool _acceptIntros = true;
  bool _shieldOn = true;

  @override
  void initState() {
    super.initState();
    loadPushMode().then((v) {
      if (mounted) setState(() => _push = v);
    });
    appState.loadDisguisePref().then((d) {
      if (mounted) setState(() => _disguise = d);
    });
    loadAcceptIntros().then((v) {
      if (mounted) setState(() => _acceptIntros = v);
    });
    loadScamShieldOn().then((v) {
      if (mounted) setState(() => _shieldOn = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: HaloColors.text2),
        title: Text(
          'Settings',
          style: HaloType.serif(size: 22, color: HaloColors.text, italic: true),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: staggerAll([
          ListenableBuilder(
            listenable: Listenable.merge([appState, lockState]),
            builder: (_, _) {
              final tor = appState.torStatus == TorStatus.reachable;
              // relay and fast modes never use tor, so "connecting" there
              // would be a promise nothing is trying to keep
              final onTor = appState.sendMode == 'private';
              return Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                decoration: BoxDecoration(
                  color: HaloColors.surface2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: HaloColors.line, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your protections',
                      style: HaloType.mono(size: 11, color: HaloColors.amber),
                    ),
                    const SizedBox(height: 10),
                    _postureLine(
                      'tor routing',
                      onTor && tor,
                      'connected',
                      onTor
                          ? 'connecting'
                          : 'off · ${appState.sendMode == 'fast' ? 'fast' : 'relay'} mode',
                    ),
                    _postureLine(
                      'screenshots',
                      appState.blockScreenshotsApplied,
                      'blocked',
                      'allowed',
                    ),
                    _postureLine('app lock', lockState.enabled, 'on', 'off'),
                    // only when android is blocking them: a line that says
                    // so outlives the home banner, which can be dismissed
                    FutureBuilder<bool>(
                      future: notificationsEnabled(),
                      builder: (_, snap) => snap.data == false
                          ? _postureLine(
                              'notifications',
                              false,
                              '',
                              'blocked by android',
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              );
            },
          ),

          _Section('privacy'),
          _Group(
            children: [
              _Row(
                icon: Icons.shield_outlined,
                label: 'Speed & privacy',
                value: appState.sendMode == 'fast'
                    ? 'fast'
                    : appState.sendMode == 'balanced'
                    ? 'Relay · 1 hop'
                    : 'Onion · 3 hops',
                onTap: () async {
                  await Navigator.of(
                    context,
                  ).push(haloRoute(const ModesScreen()));
                  if (mounted) setState(() {});
                },
              ),
              _Row(
                icon: Icons.vpn_lock_outlined,
                label: 'Bridges',
                hint: 'For networks that block tor',
                value: appState.bridgesOn ? 'On' : 'Off',
                onTap: () async {
                  await Navigator.push(
                    context,
                    haloRoute(const BridgesScreen()),
                  );
                  if (mounted) setState(() {});
                },
              ),
              _Row(
                icon: Icons.notifications_none,
                label: 'Notifications',
                value: switch (_push) {
                  null => '',
                  PushMode.tor => 'Over tor',
                  PushMode.fcm => 'Google push',
                  PushMode.ntfy => 'Ntfy push',
                },
                onTap: () async {
                  await Navigator.of(
                    context,
                  ).push(haloRoute(const PushSettingsScreen()));
                  final v = await loadPushMode();
                  if (mounted) setState(() => _push = v);
                },
              ),
              _Row(
                icon: Icons.battery_saver,
                label: 'Run in background',
                value: 'So messages arrive',
                onTap: () => forceShowBackgroundPrompt(context),
              ),
              _Row(
                icon: Icons.lan_outlined,
                label: 'Transport',
                value: 'What the network is doing',
                onTap: () =>
                    Navigator.push(context, haloRoute(const TransportScreen())),
              ),
              _Row(
                icon: Icons.block,
                label: 'Blocked',
                onTap: () => Navigator.of(
                  context,
                ).push(haloRoute(const BlockedScreen())),
              ),
              _Row(
                icon: Icons.people_outline,
                label: 'Accept introductions',
                hint: 'Friends can introduce you to theirs',
                value: _acceptIntros ? 'On' : 'Off',
                onTap: () async {
                  setState(() => _acceptIntros = !_acceptIntros);
                  await saveAcceptIntros(_acceptIntros);
                },
              ),
              _Row(
                icon: Icons.shield_outlined,
                label: 'Scam shield',
                hint: 'Checks strangers on your phone. Nothing leaves it',
                value: _shieldOn ? 'On' : 'Off',
                onTap: () async {
                  setState(() => _shieldOn = !_shieldOn);
                  await saveScamShieldOn(_shieldOn);
                },
              ),
              _Row(
                icon: Icons.travel_explore_outlined,
                label: 'Add link previews',
                hint:
                    'You fetch the title over tor and send it along. Onion mode only',
                value: sendLinkPreviews ? 'On' : 'Off',
                onTap: () async {
                  await saveSendLinkPreviews(!sendLinkPreviews);
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          _Section('security'),
          _Group(
            children: [
              // one switch for the whole app, applied at the next start.
              // the per-chat one went: changing the flag live recreated the
              // surface and flashed on every toggle.
              _Row(
                icon: Icons.visibility_off_outlined,
                label: 'Block screenshots',
                hint: appState.blockScreenshotsPending
                    ? 'Whole app hidden from recents and screenshots · '
                          'takes effect after the next start'
                    : 'Whole app hidden from recents and screenshots',
                value: appState.blockScreenshots
                    ? (appState.blockScreenshotsPending
                          ? 'On · next start'
                          : 'On')
                    : (appState.blockScreenshotsPending
                          ? 'Off · next start'
                          : 'Off'),
                onTap: () async {
                  await appState.setBlockScreenshots(
                    !appState.blockScreenshots,
                  );
                  if (mounted) setState(() {});
                },
              ),
              _Row(
                icon: Icons.light_mode_outlined,
                label: 'Light theme',
                hint: 'Same protection, brighter',
                value: HaloColors.isLight ? 'On' : 'Off',
                onTap: () async {
                  await appState.setLight(!HaloColors.isLight);
                  if (mounted) setState(() {});
                },
              ),
              AnimatedBuilder(
                animation: lockState,
                builder: (_, _) => _Row(
                  icon: Icons.lock_outline,
                  label: 'App lock',
                  hint: 'Your pin, and a wipe pin',
                  value: !lockState.enabled
                      ? 'Off'
                      : lockState.panicEnabled
                      ? 'Pin · wipe pin'
                      : 'On',
                  onTap: () =>
                      Navigator.of(context).push(haloRoute(const PinsScreen())),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _Section('backup'),
          _Group(
            children: [
              _Row(
                icon: Icons.save_alt,
                label: 'Back up identity',
                value: 'Encrypted file',
                onTap: () =>
                    Navigator.of(context).push(haloRoute(const BackupScreen())),
              ),
              _Row(
                icon: Icons.restore,
                label: 'Restore from backup',
                value: 'Replace current',
                onTap: () => Navigator.of(
                  context,
                ).push(haloRoute(const RestoreScreen())),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _Section('voice'),
          _Group(
            children: [
              _Row(
                icon: Icons.record_voice_over,
                label: 'Disguise voice',
                hint: 'Shifts your pitch before a voice note leaves',
                value: _disguise ? 'On' : 'Off',
                onTap: () async {
                  setState(() => _disguise = !_disguise);
                  await appState.saveDisguisePref(_disguise);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          _Section('about'),
          _Group(
            children: [
              _Row(
                icon: Icons.help_outline,
                label: 'Why kryfo',
                value: 'How it protects you',
                onTap: () =>
                    Navigator.push(context, haloRoute(const WhyKryfoScreen())),
              ),
              _Row(
                icon: Icons.autorenew,
                label: 'Reset my invite link',
                hint: 'Old links and codes stop working, for everyone',
                onTap: () async {
                  final ok = await showConfirmSheet(
                    context,
                    title: 'Reset invite link?',
                    line:
                        'Anyone with an old code or link stops being able to '
                        'reach you, on every route. People who have it but '
                        'never used it will need a new one from you. Contacts, '
                        'chats and history stay.',
                    yes: 'Reset',
                  );
                  if (!ok) return;
                  await appState.resetInviteAddress();
                  if (context.mounted) {
                    showHaloToast(context, 'Invite reset · share the new code');
                  }
                },
              ),
              _Row(
                icon: Icons.visibility_outlined,
                label: 'What we can see',
                value: 'The honest list',
                onTap: () =>
                    Navigator.push(context, haloRoute(const SeenScreen())),
              ),
              _Row(
                icon: Icons.info_outline,
                label: 'Version',
                value: '0.2.9 · alpha',
              ),
              _Row(
                icon: Icons.flag_outlined,
                label: 'Report an issue',
                value: 'Bug or security flaw',
                onTap: () => launchUrl(
                  Uri.parse(
                    'mailto:gnosiworks@proton.me?subject=Kryfo%20report',
                  ),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              // copies, never opens: a browser hop would hand github the
              // phone's address
              _Row(
                icon: Icons.code,
                label: 'Open source',
                value: 'github.com/GnosiWorks/Kryfo',
                onTap: () async {
                  await Clipboard.setData(
                    const ClipboardData(
                      text: 'https://github.com/GnosiWorks/Kryfo',
                    ),
                  );
                  if (context.mounted) showHaloToast(context, 'Link copied');
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 12, 0),
            child: Text(
              'Not independently audited. Pre-alpha - good for testing, '
              'not yet for high-stakes use.',
              style: HaloType.sans(
                size: 12,
                color: HaloColors.text3,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 24),

          _Section('danger zone'),
          _Group(
            rose: true,
            children: [
              _Row(
                icon: Icons.delete_outline,
                label: 'Wipe kryfo from this phone',
                rose: true,
                onTap: _confirmWipe,
              ),
            ],
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  const _Section(this.label);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 4, 8),
      child: Text(
        sentence(label),
        style: HaloType.mono(size: 10.5, color: HaloColors.text3, letter: 0.06),
      ),
    );
  }
}

// one rounded surface holding a section's rows, a hairline between each.
// the page used to be a stack of separate cards, one per row.
class _Group extends StatelessWidget {
  final List<Widget> children;
  final bool rose;
  const _Group({required this.children, this.rose = false});
  @override
  Widget build(BuildContext context) {
    final line = rose
        ? HaloColors.rose.withValues(alpha: 0.35)
        : HaloColors.line;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: rose
            ? HaloColors.rose.withValues(alpha: 0.05)
            : HaloColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line, width: 0.5),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 58),
                child: Container(height: 0.5, color: line),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String? value;
  // one plain line under the label. toggles showed on/off and nothing
  // about what the switch actually does.
  final String? hint;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool rose;
  const _Row({
    required this.label,
    this.value,
    this.hint,
    this.onTap,
    this.icon,
    this.rose = false,
  });

  @override
  Widget build(BuildContext context) {
    // 14pt is the label size; once it renders past ~19 the two-column layout
    // stops fitting on a phone. a short value sits on the right, a sentence
    // goes under the label instead of wrapping into ribbons.
    final v = value ?? '';
    final stacked =
        v.length > 16 || MediaQuery.of(context).textScaler.scale(14) > 19;
    final fg = rose ? HaloColors.rose : HaloColors.text;
    final tile = rose
        ? HaloColors.rose.withValues(alpha: 0.12)
        : HaloColors.amberSoft;
    final ink = rose ? HaloColors.rose : HaloColors.amber;
    return InkWell(
      onTap: onTap,
      splashColor: ink.withValues(alpha: 0.08),
      highlightColor: ink.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tile,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Icon(icon ?? Icons.circle_outlined, size: 17, color: ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sentence(label),
                    style: HaloType.sans(size: 14, color: fg),
                  ),
                  if (hint != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3, right: 10),
                      child: Text(
                        sentence(hint!),
                        style: HaloType.mono(
                          size: 10.5,
                          color: HaloColors.text3,
                        ),
                      ),
                    ),
                  if (v.isNotEmpty && stacked)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 10),
                      child: Text(
                        sentence(v),
                        style: HaloType.sans(size: 13, color: HaloColors.text2),
                      ),
                    ),
                ],
              ),
            ),
            if (v.isNotEmpty && !stacked) ...[
              const SizedBox(width: 8),
              Text(
                sentence(v),
                style: HaloType.sans(size: 13, color: HaloColors.text2),
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                color: rose ? ink : HaloColors.text3,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
