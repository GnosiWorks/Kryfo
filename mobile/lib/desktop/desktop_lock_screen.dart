// SPDX-License-Identifier: GPL-3.0-or-later
// the first screen of the desktop app: the passphrase that opens the vault,
// or a new one on a first start. nothing of the app runs before it is open
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/fit_column.dart';
import '../widgets/halo_buttons.dart';
import '../widgets/motion.dart';
import '../widgets/secret_field.dart';
import 'desktop_start.dart' show DesktopStop;
import 'desktop_vault.dart';

class DesktopLockScreen extends StatefulWidget {
  const DesktopLockScreen({
    super.key,
    required this.vault,
    required this.onOpen,
  });

  final DesktopVault vault;
  final VoidCallback onOpen;

  @override
  State<DesktopLockScreen> createState() => _DesktopLockScreenState();
}

class _DesktopLockScreenState extends State<DesktopLockScreen> {
  final _first = TextEditingController();
  final _again = TextEditingController();
  final _firstFocus = FocusNode();
  final _againFocus = FocusNode();
  late final bool _isNew = !widget.vault.exists;
  bool _shown = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _again.dispose();
    _firstFocus.dispose();
    _againFocus.dispose();
    super.dispose();
  }

  void _say(String? e) {
    if (!mounted) return;
    setState(() {
      _error = e;
      _busy = false;
    });
  }

  Future<void> _go() async {
    if (_busy) return;
    final pass = _first.text;
    if (_isNew) {
      if (pass.runes.length < kVaultMinLength) {
        return _say(l10n.desktopLockShort(kVaultMinLength));
      }
      if (pass != _again.text) return _say(l10n.desktopLockMismatch);
    } else if (pass.isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isNew) {
        await widget.vault.create(pass);
      } else if (!await widget.vault.open(pass)) {
        _first.clear();
        _firstFocus.requestFocus();
        return _say(
          widget.vault.madeByOtherVersion
              ? l10n.desktopLockOtherVersion
              : l10n.desktopLockWrong,
        );
      }
    } catch (_) {
      return _say(l10n.desktopLockFailed);
    }
    _first.clear();
    _again.clear();
    widget.onOpen();
  }

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final title = _isNew ? l10n.desktopLockNewTitle : l10n.desktopLockTitle;
    final line = _error == null
        ? const SizedBox(width: double.infinity, height: 14)
        : Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 2),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                key: ValueKey(_error),
                textAlign: TextAlign.center,
                style: HaloType.sans(size: 13, color: HaloColors.rose),
              ),
            ),
          );
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: FitColumn(
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: HaloType.serif(
                      size: 28,
                      italic: true,
                      color: HaloColors.text,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isNew ? l10n.desktopLockNewBody : l10n.desktopLockBody,
                  textAlign: TextAlign.center,
                  style: HaloType.sans(
                    size: 14,
                    height: 1.45,
                    color: HaloColors.text2,
                  ),
                ),
                const SizedBox(height: 28),
                SecretField(
                  label: l10n.desktopLockField,
                  controller: _first,
                  shown: _shown,
                  onToggle: () => setState(() => _shown = !_shown),
                  enabled: !_busy,
                  action: _isNew ? TextInputAction.next : TextInputAction.go,
                  onSubmit: _isNew ? _againFocus.requestFocus : _go,
                  focusNode: _firstFocus,
                  autofocus: true,
                ),
                if (_isNew) ...[
                  const SizedBox(height: 14),
                  SecretField(
                    label: l10n.desktopLockRepeat,
                    controller: _again,
                    shown: _shown,
                    onToggle: () => setState(() => _shown = !_shown),
                    enabled: !_busy,
                    action: TextInputAction.go,
                    onSubmit: _go,
                    focusNode: _againFocus,
                  ),
                ],
                // the line below the fields fades in and out. a size
                // animation would lie to the page's height measure, so the
                // room it takes changes at once
                AnimatedSwitcher(
                  duration: still
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (current, previous) =>
                      current ?? const SizedBox(),
                  child: KeyedSubtree(key: ValueKey(_error), child: line),
                ),
                const SizedBox(height: 10),
                HaloPrimaryButton(
                  label: _isNew ? l10n.desktopLockSet : l10n.desktopLockOpen,
                  busy: _busy,
                  onTap: _go,
                ),
                const SizedBox(height: 22),
                Text(
                  _isNew ? l10n.desktopLockHonest : l10n.desktopLockForgot,
                  textAlign: TextAlign.center,
                  style: HaloType.sans(
                    size: 12.5,
                    height: 1.45,
                    color: HaloColors.text3,
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// the lock screen as the whole app, until the vault is open
class DesktopLockApp extends StatelessWidget {
  const DesktopLockApp({super.key, required this.vault, required this.onOpen});

  final DesktopVault vault;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Kryfo',
    theme: buildHaloTheme(),
    locale: l10nLocale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: DesktopLockScreen(vault: vault, onOpen: onOpen),
  );
}

/// the whole app when the folder cannot be had: one calm line
class DesktopStopApp extends StatelessWidget {
  const DesktopStopApp({super.key, required this.stop});

  final DesktopStop stop;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Kryfo',
    theme: buildHaloTheme(),
    locale: l10nLocale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: FitColumn(
              padding: const EdgeInsets.all(28),
              children: [
                const Spacer(),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    switch (stop) {
                      DesktopStop.alreadyOpen => l10n.desktopAlreadyOpen,
                      DesktopStop.notYours => l10n.desktopFolderNotYours,
                      DesktopStop.notPrivate => l10n.desktopFolderNotPrivate,
                      DesktopStop.noMemory => l10n.desktopNoMemoryFolder,
                    },
                    textAlign: TextAlign.center,
                    style: HaloType.sans(
                      size: 15,
                      height: 1.45,
                      color: HaloColors.text,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
