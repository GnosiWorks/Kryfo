// settings_screen.dart — user-facing settings, consolidated from dev.
// reachable from the "Me" tab. tap on tab opens this, long-press still
// opens dev for technical use.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart' show appState, engine;
import '../lock_state.dart';
import '../theme.dart';
import 'modes_screen.dart';
import 'blocked_screen.dart';
import 'push_settings_screen.dart';
import 'lock_setup_screen.dart';
import 'panic_setup_screen.dart';
import 'backup_screen.dart';
import '../wipe.dart';
import 'restore_screen.dart';

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
          decoration: const InputDecoration(
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
          _Section('identity'),
          _IdentityCard(haloId: appState.myId, onion: appState.myOnion),
          const SizedBox(height: 24),

          _Section('privacy'),
          _Row(
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
            label: 'notifications',
            value: 'tor only',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PushSettingsScreen()),
            ),
          ),
          _Row(
            label: 'blocked',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const BlockedScreen())),
          ),
          const SizedBox(height: 24),

          _Section('security'),
          AnimatedBuilder(
            animation: lockState,
            builder: (_, __) => Column(
              children: [
                _Row(
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
                    label: 'unlock with fingerprint',
                    value: lockState.biometric ? 'on' : 'off',
                    onTap: () => lockState.setBiometric(!lockState.biometric),
                  ),
                if (lockState.enabled)
                  _Row(
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
            label: 'back up identity',
            value: 'encrypted file',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const BackupScreen())),
          ),
          _Row(
            label: 'restore from backup',
            value: 'replace current',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const RestoreScreen())),
          ),
          const SizedBox(height: 24),

          _Section('about'),
          _Row(label: 'version', value: '0.1 · alpha'),
          _Row(label: 'open source', value: 'github.com/halo'),
          const SizedBox(height: 24),

          _Section('danger zone'),
          InkWell(
            onTap: _confirmWipe,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'wipe halo from this phone',
                      style: HaloType.sans(size: 14, color: HaloColors.rose),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: HaloColors.rose,
                    size: 18,
                  ),
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
  const _Row({required this.label, this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
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
            const Divider(color: HaloColors.line, height: 1),
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
