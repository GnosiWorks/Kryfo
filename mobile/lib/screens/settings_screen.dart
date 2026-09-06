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
import '../theme.dart';
import 'modes_screen.dart';
import 'blocked_screen.dart';
import 'push_settings_screen.dart';
import 'lock_setup_screen.dart';
import 'panic_setup_screen.dart';
import 'backup_screen.dart';
import '../wipe.dart';
import 'restore_screen.dart';
import 'package:url_launcher/url_launcher.dart';

Widget _postureLine(String label, bool on, String onText, String offText) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(
          on ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: on ? HaloColors.green : HaloColors.text3,
        ),
        const SizedBox(width: 10),
        Text(label, style: HaloType.sans(size: 13, color: HaloColors.text)),
        const Spacer(),
        Text(
          on ? onText : offText,
          style: HaloType.mono(
            size: 10,
            color: on ? HaloColors.green : HaloColors.text3,
          ),
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
  Future<void> _confirmWipe() async {
    // step 1: explain what's about to happen
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HaloColors.surface3,
        title: Text(
          'wipe kryfo?',
          style: HaloType.serif(size: 18, color: HaloColors.rose),
        ),
        content: Text(
          "this deletes your identity, all messages, all contacts, and every setting on this phone. unrecoverable unless you have a backup.",
          style: HaloType.sans(size: 13, color: HaloColors.text2, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'cancel',
              style: HaloType.sans(size: 13, color: HaloColors.text2),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'continue',
              style: HaloType.sans(size: 13, color: HaloColors.rose),
            ),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    // step 2: type the word
    final confirmCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HaloColors.surface3,
        title: Text(
          "type 'wipe' to confirm",
          style: HaloType.serif(size: 18, color: HaloColors.text),
        ),
        content: TextField(
          controller: confirmCtrl,
          autofocus: true,
          style: HaloType.mono(size: 14, color: HaloColors.text),
          decoration: InputDecoration(
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: HaloColors.line, width: 0.5),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: HaloColors.rose, width: 0.8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'cancel',
              style: HaloType.sans(size: 13, color: HaloColors.text2),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(
              ctx,
            ).pop(confirmCtrl.text.trim().toLowerCase() == 'wipe'),
            child: Text(
              'wipe kryfo',
              style: HaloType.sans(size: 13, color: HaloColors.rose),
            ),
          ),
        ],
      ),
    );
    confirmCtrl.dispose();
    if (ok == true) await wipeHalo();
  }

  Future<void> _confirmDisableLock() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HaloColors.surface3,
        title: Text(
          'disable app lock?',
          style: HaloType.serif(size: 18, color: HaloColors.text),
        ),
        content: Text(
          'the pin will be removed. anyone with your phone will see kryfo when they open it.',
          style: HaloType.sans(size: 13, color: HaloColors.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'cancel',
              style: HaloType.sans(size: 13, color: HaloColors.text2),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'disable',
              style: HaloType.sans(size: 13, color: HaloColors.rose),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await lockState.disable();
  }

  bool _disguise = false;
  bool _acceptIntros = true;
  bool _shieldOn = true;

  @override
  void initState() {
    super.initState();
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

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Color(0xFFAAAAAA)),
        title: Text(
          'settings',
          style: HaloType.serif(size: 22, color: HaloColors.text, italic: true),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([appState, lockState]),
            builder: (_, __) {
              final tor = appState.torStatus == TorStatus.reachable;
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
                      'your protections',
                      style: HaloType.mono(size: 11, color: HaloColors.amber),
                    ),
                    const SizedBox(height: 10),
                    _postureLine('tor routing', tor, 'connected', 'connecting'),
                    _postureLine(
                      'screenshots',
                      appState.blockScreenshots,
                      'blocked',
                      'allowed',
                    ),
                    _postureLine('app lock', lockState.enabled, 'on', 'off'),
                  ],
                ),
              );
            },
          ),

          _Section('privacy'),
          _Row(
            icon: Icons.shield_outlined,
            label: 'speed & privacy',
            value: appState.sendMode == 'fast'
                ? 'fast'
                : appState.sendMode == 'balanced'
                ? 'relay · 1 hop'
                : 'onion · 3 hops',
            onTap: () async {
              await Navigator.of(context).push(haloRoute(const ModesScreen()));
              if (mounted) setState(() {});
            },
          ),
          _Row(
            icon: Icons.notifications_none,
            label: 'notifications',
            value: appState.sendMode == 'private' ? 'over tor' : 'in app',
            onTap: () => Navigator.of(
              context,
            ).push(haloRoute(const PushSettingsScreen())),
          ),
          _Row(
            icon: Icons.battery_saver,
            label: 'run in background',
            value: 'so messages arrive',
            onTap: () => forceShowBackgroundPrompt(context),
          ),
          _Row(
            icon: Icons.block,
            label: 'blocked',
            onTap: () =>
                Navigator.of(context).push(haloRoute(const BlockedScreen())),
          ),
          _Row(
            icon: Icons.people_outline,
            label: 'accept introductions',
            hint:
                'friends can introduce you to their friends. off means introductions are dropped.',
            value: _acceptIntros ? 'on' : 'off',
            onTap: () async {
              setState(() => _acceptIntros = !_acceptIntros);
              await saveAcceptIntros(_acceptIntros);
            },
          ),
          _Row(
            icon: Icons.shield_outlined,
            label: 'scam shield',
            hint:
                'checks messages from strangers on your phone. nothing is sent anywhere.',
            value: _shieldOn ? 'on' : 'off',
            onTap: () async {
              setState(() => _shieldOn = !_shieldOn);
              await saveScamShieldOn(_shieldOn);
            },
          ),
          const SizedBox(height: 24),

          _Section('security'),
          _Row(
            icon: Icons.photo_camera_back_outlined,
            label: 'screen security',
            hint: 'hides kryfo from recents and blocks screenshots here',
            value: appState.secureChats ? 'on' : 'off',
            onTap: () async {
              await appState.setSecureChats(!appState.secureChats);
              setState(() {});
            },
          ),
          _Row(
            icon: Icons.visibility_off_outlined,
            label: 'block screenshots',
            hint: 'hides kryfo from the recents view and screenshots',
            value: appState.blockScreenshots ? 'on' : 'off',
            onTap: () async {
              await appState.setBlockScreenshots(!appState.blockScreenshots);
              setState(() {});
            },
          ),
          _Row(
            icon: Icons.light_mode_outlined,
            label: 'light theme',
            hint: 'same protection, brighter',
            value: HaloColors.isLight ? 'on' : 'off',
            onTap: () async {
              await appState.setLight(!HaloColors.isLight);
              setState(() {});
            },
          ),
          AnimatedBuilder(
            animation: lockState,
            builder: (_, __) => Column(
              children: [
                _Row(
                  icon: Icons.lock_outline,
                  label: 'app lock',
                  value: lockState.enabled ? 'on' : 'off',
                  onTap: () async {
                    if (lockState.enabled) {
                      await _confirmDisableLock();
                    } else {
                      await Navigator.of(
                        context,
                      ).push(haloRoute(const LockSetupScreen()));
                      setState(() {});
                    }
                  },
                ),
                if (lockState.enabled && lockState.bioSupported)
                  _Row(
                    icon: Icons.fingerprint,
                    label: 'unlock with fingerprint',
                    value: lockState.biometric ? 'on' : 'off',
                    onTap: () => lockState.setBiometric(!lockState.biometric),
                  ),
                if (lockState.enabled)
                  _Row(
                    icon: Icons.warning_amber_rounded,
                    label: 'panic pin',
                    value: lockState.panicEnabled ? 'set' : 'off',
                    onTap: () async {
                      if (lockState.panicEnabled) {
                        final disable = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: HaloColors.surface3,
                            title: Text(
                              'panic pin is set',
                              style: HaloType.serif(
                                size: 18,
                                color: HaloColors.text,
                              ),
                            ),
                            content: Text(
                              'remove the panic pin?',
                              style: HaloType.sans(
                                size: 13,
                                color: HaloColors.text2,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: Text(
                                  'cancel',
                                  style: HaloType.sans(
                                    size: 13,
                                    color: HaloColors.text2,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: Text(
                                  'remove',
                                  style: HaloType.sans(
                                    size: 13,
                                    color: HaloColors.rose,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (disable == true) {
                          await lockState.disablePanicPin();
                        }
                      } else {
                        await Navigator.of(
                          context,
                        ).push(haloRoute(PanicSetupScreen()));
                      }
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _Section('backup'),
          _Row(
            icon: Icons.save_alt,
            label: 'back up identity',
            value: 'encrypted file',
            onTap: () =>
                Navigator.of(context).push(haloRoute(const BackupScreen())),
          ),
          _Row(
            icon: Icons.restore,
            label: 'restore from backup',
            value: 'replace current',
            onTap: () =>
                Navigator.of(context).push(haloRoute(const RestoreScreen())),
          ),
          const SizedBox(height: 24),

          _Section('voice'),
          _Row(
            icon: Icons.record_voice_over,
            label: 'disguise voice',
            hint: 'shifts your pitch before a voice note leaves',
            value: _disguise ? 'on' : 'off',
            onTap: () async {
              setState(() => _disguise = !_disguise);
              await appState.saveDisguisePref(_disguise);
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 12, 0),
            child: Text(
              'shifts your pitch so your voice is harder to recognize.',
              style: HaloType.sans(
                size: 12,
                color: HaloColors.text3,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 24),

          _Section('about'),
          _Row(
            icon: Icons.help_outline,
            label: 'why kryfo',
            value: 'how it protects you',
            onTap: () =>
                Navigator.push(context, haloRoute(const WhyKryfoScreen())),
          ),
          _Row(
            icon: Icons.autorenew,
            label: 'reset my invite link',
            hint: 'old qr codes and links stop working',
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: HaloColors.surface3,
                  title: Text(
                    'reset invite link?',
                    style: HaloType.serif(size: 18, color: HaloColors.text),
                  ),
                  content: Text(
                    'anyone holding an old qr code or link stops being able '
                    'to reach you. your contacts, chats and history are not '
                    'touched.',
                    style: HaloType.sans(size: 13, color: HaloColors.text2),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(
                        'cancel',
                        style: HaloType.sans(size: 13, color: HaloColors.text2),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(
                        'reset',
                        style: HaloType.sans(size: 13, color: HaloColors.rose),
                      ),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              await appState.resetInviteAddress();
              if (context.mounted) {
                showHaloToast(context, 'invite reset · share the new code');
              }
            },
          ),
          _Row(
            icon: Icons.visibility_outlined,
            label: 'what we can see',
            value: 'the honest list',
            onTap: () => Navigator.push(context, haloRoute(const SeenScreen())),
          ),
          _Row(
            icon: Icons.vpn_lock_outlined,
            label: 'bridges',
            hint: 'for networks that block tor',
            value: appState.bridgesOn ? 'on' : 'off',
            onTap: () async {
              await Navigator.push(context, haloRoute(const BridgesScreen()));
              setState(() {});
            },
          ),
          _Row(
            icon: Icons.lan_outlined,
            label: 'transport',
            value: 'what the network is doing',
            onTap: () =>
                Navigator.push(context, haloRoute(const TransportScreen())),
          ),
          _Row(
            icon: Icons.info_outline,
            label: 'version',
            value: '0.1 · alpha',
          ),
          _Row(
            icon: Icons.flag_outlined,
            label: 'report an issue',
            value: 'bug or security flaw',
            onTap: () => launchUrl(
              Uri.parse('mailto:gnosiworks@proton.me?subject=Kryfo%20report'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          _Row(
            icon: Icons.code,
            label: 'open source',
            value: 'github.com/GnosiWorks/Kryfo',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 12, 0),
            child: Text(
              'not independently audited. pre-alpha - good for testing, '
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
          InkWell(
            onTap: _confirmWipe,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'wipe kryfo from this phone',
                      style: HaloType.sans(size: 14, color: HaloColors.rose),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: HaloColors.rose, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
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
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Text(
        label,
        style: HaloType.mono(size: 10.5, color: HaloColors.text3),
      ),
    );
  }
}

class _Row extends StatefulWidget {
  final String label;
  final String? value;
  // one plain line under the label. toggles showed on/off and nothing
  // about what the switch actually does.
  final String? hint;
  final VoidCallback? onTap;
  final bool accent;
  final IconData? icon;
  const _Row({
    required this.label,
    this.value,
    this.hint,
    this.onTap,
    this.accent = false,
    this.icon,
  });

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _down = false;
  String get label => widget.label;
  String? get value => widget.value;
  VoidCallback? get onTap => widget.onTap;
  bool get accent => widget.accent;
  IconData? get icon => widget.icon;

  void _set(bool v) {
    if (onTap != null && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    // 14pt is the label size; once it renders past ~19 the two-column layout
    // stops fitting on a phone.
    // a short value ("on", "off", "0.1 · alpha") sits fine on the right. a
    // sentence does not - it either overflows or wraps into ribbons, and both
    // look broken. long values go under the label, at any text size.
    final v = value ?? '';
    final stacked =
        v.length > 14 || MediaQuery.of(context).textScaler.scale(14) > 19;
    if (accent) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
          decoration: BoxDecoration(
            color: HaloColors.amber.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HaloColors.amber.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              Icon(Icons.qr_code_2, color: HaloColors.amber, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: HaloType.sans(
                    size: 14,
                    weight: FontWeight.w600,
                    color: HaloColors.amber,
                  ),
                ),
              ),
              if (value != null)
                Text(
                  value!,
                  style: HaloType.sans(size: 13, color: HaloColors.amber),
                ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: HaloColors.amber, size: 18),
            ],
          ),
        ),
      );
    }
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: HaloColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HaloColors.line, width: 0.5),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: HaloColors.amber),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: HaloType.sans(size: 14, color: HaloColors.text),
                  ),
                  if (widget.hint != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3, right: 10),
                      child: Text(
                        widget.hint!,
                        style: HaloType.mono(
                          size: 10.5,
                          color: HaloColors.text3,
                        ),
                      ),
                    ),
                  // past this scale there is no room for a value beside the
                  // label, so it goes underneath instead of crushing it
                  if (value != null && value!.isNotEmpty && stacked)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 10),
                      child: Text(
                        value!,
                        style: HaloType.sans(size: 13, color: HaloColors.text2),
                      ),
                    ),
                ],
              ),
            ),
            if (value != null && !stacked)
              Text(
                value!,
                style: HaloType.sans(size: 13, color: HaloColors.text2),
                maxLines: 1,
              ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: HaloColors.text3, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
