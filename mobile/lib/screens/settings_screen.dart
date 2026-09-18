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
import '../widgets/halo_rows.dart';
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

          HaloSection('privacy'),
          HaloGroup(
            children: [
              HaloRow(
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
              HaloRow(
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
              HaloRow(
                icon: Icons.notifications_none,
                label: 'Notifications',
                value: switch (_push) {
                  null => '',
                  PushMode.tor => 'Over tor',
                  PushMode.fcm => 'Google push',
                },
                onTap: () async {
                  await Navigator.of(
                    context,
                  ).push(haloRoute(const PushSettingsScreen()));
                  final v = await loadPushMode();
                  if (mounted) setState(() => _push = v);
                },
              ),
              HaloRow(
                icon: Icons.battery_saver,
                label: 'Run in background',
                value: 'So messages arrive',
                onTap: () => forceShowBackgroundPrompt(context),
              ),
              HaloRow(
                icon: Icons.lan_outlined,
                label: 'Transport',
                value: 'What the network is doing',
                onTap: () =>
                    Navigator.push(context, haloRoute(const TransportScreen())),
              ),
              HaloRow(
                icon: Icons.block,
                label: 'Blocked',
                onTap: () => Navigator.of(
                  context,
                ).push(haloRoute(const BlockedScreen())),
              ),
              HaloRow(
                icon: Icons.people_outline,
                label: 'Accept introductions',
                hint: 'Friends can introduce you to theirs',
                value: _acceptIntros ? 'On' : 'Off',
                onTap: () async {
                  setState(() => _acceptIntros = !_acceptIntros);
                  await saveAcceptIntros(_acceptIntros);
                },
              ),
              HaloRow(
                icon: Icons.shield_outlined,
                label: 'Scam shield',
                hint: 'Checks strangers on your phone. Nothing leaves it',
                value: _shieldOn ? 'On' : 'Off',
                onTap: () async {
                  setState(() => _shieldOn = !_shieldOn);
                  await saveScamShieldOn(_shieldOn);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          HaloSection('security'),
          HaloGroup(
            children: [
              // one switch for the whole app, applied at the next start.
              // the per-chat one went: changing the flag live recreated the
              // surface and flashed on every toggle.
              HaloRow(
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
              HaloRow(
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
                builder: (_, _) => HaloRow(
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

          HaloSection('backup'),
          HaloGroup(
            children: [
              HaloRow(
                icon: Icons.save_alt,
                label: 'Back up identity',
                value: 'Encrypted file',
                onTap: () =>
                    Navigator.of(context).push(haloRoute(const BackupScreen())),
              ),
              HaloRow(
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

          HaloSection('voice'),
          HaloGroup(
            children: [
              HaloRow(
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

          HaloSection('about'),
          HaloGroup(
            children: [
              HaloRow(
                icon: Icons.help_outline,
                label: 'Why kryfo',
                value: 'How it protects you',
                onTap: () =>
                    Navigator.push(context, haloRoute(const WhyKryfoScreen())),
              ),
              HaloRow(
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
              HaloRow(
                icon: Icons.visibility_outlined,
                label: 'What we can see',
                value: 'The honest list',
                onTap: () =>
                    Navigator.push(context, haloRoute(const SeenScreen())),
              ),
              HaloRow(
                icon: Icons.info_outline,
                label: 'Version',
                value: '0.2.11 · alpha',
              ),
              HaloRow(
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
              HaloRow(
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
              'The offline map in Tools is drawn from Natural Earth (public '
              'domain). Town names are from GeoNames, geonames.org, under '
              'CC BY 4.0.',
              style: HaloType.sans(
                size: 12,
                color: HaloColors.warm,
                height: 1.4,
              ),
            ),
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

          HaloSection('danger zone'),
          HaloGroup(
            rose: true,
            children: [
              HaloRow(
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
