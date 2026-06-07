// settings_screen.dart — user-facing settings, consolidated from dev.
// reachable from the "Me" tab. tap on tab opens this, long-press still
// opens dev for technical use.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart' show appState, engine;
import '../lock_state.dart';
import '../widgets/motion.dart' show TorStatus;
import 'my_halo_screen.dart';
import 'why_halo_screen.dart';
import '../theme.dart';
import 'modes_screen.dart';
import 'blocked_screen.dart';
import 'push_settings_screen.dart';
import 'lock_setup_screen.dart';
import 'panic_setup_screen.dart';
import 'backup_screen.dart';
import '../wipe.dart';
import 'restore_screen.dart';

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
          'wipe halo?',
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
              'wipe halo',
              style: HaloType.sans(size: 13, color: HaloColors.rose),
            ),
          ),
        ],
      ),
    );
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
          'the pin will be removed. anyone with your phone will see halo when they open it.',
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

  @override
  Future<void> _editDisplayName() async {
    final ctrl = TextEditingController(text: appState.displayName);
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HaloColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          20 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'display name',
              style: HaloType.serif(size: 18, color: HaloColors.text),
            ),
            const SizedBox(height: 6),
            Text(
              'a name you choose for yourself. it is not verified and not '
              'sent anywhere yet — for now it only shows on this phone.',
              style: HaloType.sans(
                size: 12,
                color: HaloColors.text2,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLength: 32,
              style: HaloType.serif(
                size: 20,
                italic: true,
                color: HaloColors.text,
              ),
              cursorColor: HaloColors.amber,
              decoration: InputDecoration(
                hintText: 'your name',
                counterText: '',
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: HaloColors.line, width: 0.5),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: HaloColors.amber, width: 0.8),
                ),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                  child: Text(
                    'save',
                    style: HaloType.sans(
                      size: 14,
                      weight: FontWeight.w600,
                      color: HaloColors.amber,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (name == null) return;
    await appState.setDisplayName(name);
    if (mounted) setState(() {});
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
          _Section('identity'),
          _IdentityCard(haloId: appState.myId, onion: appState.myOnion),
          _Row(
            accent: true,
            label: 'my halo code',
            value: 'show & share',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyHaloScreen()),
            ),
          ),
          _Row(
            icon: Icons.badge_outlined,
            label: 'display name',
            value: appState.displayName.isEmpty
                ? 'not set'
                : appState.displayName,
            onTap: _editDisplayName,
          ),
          const SizedBox(height: 24),

          _Section('privacy'),
          _Row(
            icon: Icons.shield_outlined,
            label: 'speed & privacy',
            value: appState.sendMode == 'fast'
                ? 'fast · direct'
                : 'private · 3 hops',
            onTap: () async {
              await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ModesScreen()));
              if (mounted) setState(() {});
            },
          ),
          _Row(
            icon: Icons.notifications_none,
            label: 'notifications',
            value: 'tor only',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PushSettingsScreen()),
            ),
          ),
          _Row(
            icon: Icons.block,
            label: 'blocked',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const BlockedScreen())),
          ),
          const SizedBox(height: 24),

          _Section('security'),
          _Row(
            icon: Icons.visibility_off_outlined,
            label: 'block screenshots',
            value: appState.blockScreenshots ? 'on' : 'off',
            onTap: () async {
              await appState.setBlockScreenshots(!appState.blockScreenshots);
              setState(() {});
            },
          ),
          _Row(
            icon: Icons.light_mode_outlined,
            label: 'light theme',
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
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LockSetupScreen(),
                        ),
                      );
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
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => PanicSetupScreen()),
                        );
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
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const BackupScreen())),
          ),
          _Row(
            icon: Icons.restore,
            label: 'restore from backup',
            value: 'replace current',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const RestoreScreen())),
          ),
          const SizedBox(height: 24),

          _Section('about'),
          _Row(
            icon: Icons.help_outline,
            label: 'why halo',
            value: 'how it protects you',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WhyHaloScreen()),
            ),
          ),
          _Row(
            icon: Icons.info_outline,
            label: 'version',
            value: '0.1 · alpha',
          ),
          _Row(
            icon: Icons.code,
            label: 'open source',
            value: 'github.com/halo',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 12, 0),
            child: Text(
              'not independently audited. pre-alpha — good for testing, '
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
                      'wipe halo from this phone',
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

class _Row extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool accent;
  final IconData? icon;
  const _Row({
    required this.label,
    this.value,
    this.onTap,
    this.accent = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
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
              child: Text(
                label,
                style: HaloType.sans(size: 14, color: HaloColors.text),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: HaloType.sans(size: 13, color: HaloColors.text2),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF6B625A),
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  final String haloId;
  final String onion;
  const _IdentityCard({required this.haloId, required this.onion});

  void _copy(BuildContext context, String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    showHaloToast(context, '$what copied');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HaloColors.line, width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _copy(context, haloId, 'halo id'),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    haloId,
                    style: HaloType.mono(size: 16, color: HaloColors.amber),
                  ),
                ),
                const Icon(
                  Icons.copy_outlined,
                  color: Color(0xFF6B625A),
                  size: 14,
                ),
              ],
            ),
          ),
          if (onion.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: HaloColors.line, height: 1),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _copy(context, onion, 'onion address'),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      onion,
                      style: HaloType.mono(size: 10, color: HaloColors.text2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.copy_outlined,
                    color: Color(0xFF6B625A),
                    size: 14,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
