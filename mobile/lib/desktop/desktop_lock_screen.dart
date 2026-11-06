// SPDX-License-Identifier: GPL-3.0-or-later
// the first screen of the desktop app: the computer's key fetched, the
// passphrase that opens the vault, or on a first start the choice between
// the two. nothing of the app runs before it is open
import 'dart:async';

import 'package:flutter/material.dart';

import '../dlog.dart';
import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/fit_column.dart';
import '../widgets/halo_buttons.dart';
import '../widgets/motion.dart';
import '../widgets/secret_field.dart';
import 'desktop_start.dart' show DesktopStop;
import 'desktop_trace.dart';
import 'desktop_vault.dart';
import 'system_seal.dart';

class DesktopLockScreen extends StatefulWidget {
  const DesktopLockScreen({
    super.key,
    required this.vault,
    required this.onOpen,
    this.seal,
  });

  final DesktopVault vault;
  final VoidCallback onOpen;

  /// what the computer account offers to keep the key, null where nothing does
  final SystemSeal? seal;

  @override
  State<DesktopLockScreen> createState() => _DesktopLockScreenState();
}

// what the screen shows: a first start's choice, a new passphrase, the
// passphrase, or the computer's key being fetched (and why it was not)
enum _View { waiting, choose, newPass, pass, sealed }

class _DesktopLockScreenState extends State<DesktopLockScreen> {
  final _first = TextEditingController();
  final _again = TextEditingController();
  final _firstFocus = FocusNode();
  final _againFocus = FocusNode();
  late _View _view;
  bool _chose = false;
  bool _shown = false;
  bool _busy = false;
  // a wait longer than a moment shows its spinner
  bool _slow = false;
  Timer? _slowTimer;
  String? _error;
  // a file this version cannot read: a try again changes nothing
  bool _otherVersion = false;

  @override
  void initState() {
    super.initState();
    final seal = widget.seal;
    switch (widget.vault.lockKind) {
      case null:
        if (seal == null) {
          _view = _View.newPass;
        } else {
          _view = _View.waiting;
          _ask(seal);
        }
      case VaultLockKind.passphrase:
        _view = _View.pass;
      case VaultLockKind.system:
        _view = _View.sealed;
        if (seal == null) {
          _error = l10n.desktopKeyMissing;
        } else {
          _busy = true;
          Future.microtask(_openSealed);
        }
      // said at once, before anything is typed or asked
      case VaultLockKind.otherVersion:
        _view = _View.sealed;
        _otherVersion = true;
        _error = l10n.desktopLockOtherVersion;
    }
    _slowTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _slow = true);
    });
  }

  Future<void> _ask(SystemSeal seal) async {
    var works = false;
    try {
      works = await seal.works();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _view = works ? _View.choose : _View.newPass);
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
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

  // windows keeps the key with the account and its security chip: no
  // keyring words there
  bool get _onWindows => widget.seal?.place == SealPlace.windows;

  // the type only: a message could carry a path or a key
  void _failed(String step, Object e, StackTrace st) {
    dlog('desktop lock: ${e.runtimeType}');
    traceError(step, e, st);
    _say(l10n.desktopLockFailed);
  }

  Future<void> _openSealed() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final SealedOpen r;
    try {
      r = await widget.vault.openSealed(widget.seal!);
    } catch (e, st) {
      return _failed('lock sealed', e, st);
    }
    trace('lock sealed ${r.name}');
    switch (r) {
      case SealedOpen.opened:
        if (mounted) setState(() => _busy = false);
        widget.onOpen();
      case SealedOpen.missing:
        _say(l10n.desktopKeyMissing);
      case SealedOpen.unreachable:
        _say(
          _onWindows
              ? l10n.desktopKeyUnreachableWindows
              : l10n.desktopKeyUnreachable,
        );
      case SealedOpen.otherVersion:
        _otherVersion = true;
        _say(l10n.desktopLockOtherVersion);
    }
  }

  Future<void> _keepWithAccount() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    trace('lock keep with account');
    try {
      await widget.vault.createSealed(widget.seal!);
    } on SealError catch (e) {
      // the keyring said no: a passphrase is the way left
      trace('lock seal refused: ${e.why.name}');
      if (!mounted) return;
      setState(() {
        _view = _View.newPass;
        _chose = false;
      });
      return _say(
        _onWindows
            ? l10n.desktopLockAccountRefused
            : l10n.desktopLockKeyringRefused,
      );
    } catch (e, st) {
      return _failed('lock keep', e, st);
    }
    trace('lock kept');
    widget.onOpen();
  }

  void _toNewPass() => setState(() {
    _view = _View.newPass;
    _chose = true;
    _error = null;
  });

  void _back() => setState(() {
    _view = _View.choose;
    _error = null;
    _first.clear();
    _again.clear();
  });

  Future<void> _go() async {
    if (_busy) return;
    final isNew = _view == _View.newPass;
    final pass = _first.text;
    if (isNew) {
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
    trace(isNew ? 'lock create' : 'lock open');
    try {
      if (isNew) {
        await widget.vault.create(pass);
      } else if (!await widget.vault.open(pass, seal: widget.seal)) {
        trace('lock refused');
        _first.clear();
        _firstFocus.requestFocus();
        return _say(
          widget.vault.madeByOtherVersion
              ? l10n.desktopLockOtherVersion
              : l10n.desktopLockWrong,
        );
      }
    } catch (e, st) {
      return _failed('lock', e, st);
    }
    trace('lock opened');
    _first.clear();
    _again.clear();
    widget.onOpen();
  }

  Widget _errorLine(BuildContext context) {
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
                style: HaloType.sans(size: 13, color: HaloColors.roseText),
              ),
            ),
          );
    // the line below the fields fades in and out. a size animation would
    // lie to the page's height measure, so the room it takes changes at once
    return AnimatedSwitcher(
      duration: motionStill(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => current ?? const SizedBox(),
      child: KeyedSubtree(key: ValueKey(_error), child: line),
    );
  }

  Widget _title(String t) => Semantics(
    header: true,
    child: Text(
      t,
      textAlign: TextAlign.center,
      style: HaloType.serif(size: 28, italic: true, color: HaloColors.text),
    ),
  );

  Widget _body(String t) => Text(
    t,
    textAlign: TextAlign.center,
    style: HaloType.sans(size: 14, height: 1.45, color: HaloColors.text),
  );

  Widget _small(String t) => Text(
    t,
    textAlign: TextAlign.center,
    style: HaloType.sans(size: 12.5, height: 1.45, color: HaloColors.text),
  );

  // a spinner only while something is asked and it takes more than a moment
  List<Widget> _waiting() => [
    SizedBox(
      height: 22,
      child: Center(
        child: _slow && (_busy || _view == _View.waiting)
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: HaloColors.amber,
                ),
              )
            : null,
      ),
    ),
  ];

  List<Widget> _choose() => [
    _title(l10n.desktopLockNewTitle),
    const SizedBox(height: 12),
    _body(l10n.desktopLockAccountBody),
    const SizedBox(height: 28),
    _errorLine(context),
    const SizedBox(height: 10),
    HaloPrimaryButton(
      label: l10n.commonContinue,
      busy: _busy,
      onTap: _keepWithAccount,
    ),
    const SizedBox(height: 12),
    HaloGhostButton(
      label: l10n.desktopLockAddPassphrase,
      onTap: _busy ? null : _toNewPass,
    ),
    const SizedBox(height: 22),
    _small(l10n.desktopLockWithoutPassphrase),
  ];

  List<Widget> _passphrase(bool isNew) => [
    _title(isNew ? l10n.desktopLockNewTitle : l10n.desktopLockTitle),
    const SizedBox(height: 12),
    _body(isNew ? l10n.desktopLockNewBody : l10n.desktopLockBody),
    const SizedBox(height: 28),
    SecretField(
      label: l10n.desktopLockField,
      controller: _first,
      shown: _shown,
      onToggle: () => setState(() => _shown = !_shown),
      enabled: !_busy,
      action: isNew ? TextInputAction.next : TextInputAction.go,
      onSubmit: isNew ? _againFocus.requestFocus : _go,
      focusNode: _firstFocus,
      autofocus: true,
    ),
    if (isNew) ...[
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
    _errorLine(context),
    const SizedBox(height: 10),
    HaloPrimaryButton(
      label: isNew ? l10n.desktopLockSet : l10n.desktopLockOpen,
      busy: _busy,
      onTap: _go,
    ),
    if (isNew && _chose) ...[
      const SizedBox(height: 12),
      HaloGhostButton(
        label: l10n.commonBack,
        quiet: true,
        onTap: _busy ? null : _back,
      ),
    ],
    const SizedBox(height: 22),
    _small(isNew ? l10n.desktopLockHonest : l10n.desktopLockForgot),
  ];

  // the computer's key: nothing to type. shown only while it takes long,
  // or when it did not come
  List<Widget> _sealed() => _error == null
      ? _waiting()
      : [
          _title(l10n.desktopLockTitle),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: HaloType.sans(
                size: 14,
                height: 1.45,
                color: HaloColors.text,
              ),
            ),
          ),
          if (!_otherVersion) ...[
            const SizedBox(height: 28),
            HaloPrimaryButton(
              label: l10n.commonTryAgain,
              busy: _busy,
              onTap: widget.seal == null ? null : _openSealed,
            ),
          ],
        ];

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final children = switch (_view) {
      _View.waiting => _waiting(),
      _View.choose => _choose(),
      _View.newPass => _passphrase(true),
      _View.pass => _passphrase(false),
      _View.sealed => _sealed(),
    };
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AnimatedSwitcher(
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.02),
                    end: Offset.zero,
                  ).animate(a),
                  child: child,
                ),
              ),
              child: FitColumn(
                key: ValueKey(_view),
                padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [const Spacer(), ...children, const Spacer(flex: 2)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// the lock screen as the whole app, until the vault is open
class DesktopLockApp extends StatelessWidget {
  const DesktopLockApp({
    super.key,
    required this.vault,
    required this.onOpen,
    this.seal,
  });

  final DesktopVault vault;
  final VoidCallback onOpen;
  final SystemSeal? seal;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Kryfo',
    theme: buildHaloTheme(),
    locale: l10nLocale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: DesktopLockScreen(vault: vault, onOpen: onOpen, seal: seal),
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
                      DesktopStop.failed => l10n.desktopLockFailed,
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
