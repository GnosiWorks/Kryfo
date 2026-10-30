// SPDX-License-Identifier: GPL-3.0-or-later
// settings: the passphrase on this computer. off, the computer account keeps
// the vault's key; on, the passphrase does and is asked at every start
import 'package:flutter/material.dart';

import '../dlog.dart';
import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/fit_column.dart';
import '../widgets/halo_buttons.dart';
import '../widgets/motion.dart';
import '../widgets/secret_field.dart';
import 'computer_lock.dart';
import 'desktop_vault.dart' show kVaultMinLength;
import 'system_seal.dart';

class DesktopPassphraseScreen extends StatefulWidget {
  const DesktopPassphraseScreen({super.key, required this.lock});

  /// the real lock, or a decoy session's stand-in: the page cannot tell
  final PassphraseLock lock;

  @override
  State<DesktopPassphraseScreen> createState() =>
      _DesktopPassphraseScreenState();
}

// what the page shows: where things stand, or one of the three forms
enum _Form { none, add, change, remove }

class _DesktopPassphraseScreenState extends State<DesktopPassphraseScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _again = TextEditingController();
  final _againFocus = FocusNode();
  final _nextFocus = FocusNode();
  _Form _form = _Form.none;
  bool _shown = false;
  bool _busy = false;
  // the computer can keep the key: a passphrase may go
  bool _sealWorks = false;
  String? _error;

  bool get _on => widget.lock.on;

  @override
  void initState() {
    super.initState();
    _probe();
  }

  Future<void> _probe() async {
    var works = false;
    try {
      works = await widget.lock.sealWorks();
    } catch (_) {}
    if (mounted) setState(() => _sealWorks = works);
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _again.dispose();
    _againFocus.dispose();
    _nextFocus.dispose();
    super.dispose();
  }

  void _open(_Form f) => setState(() {
    _form = f;
    _error = null;
    _current.clear();
    _next.clear();
    _again.clear();
  });

  void _say(String? e) {
    if (!mounted) return;
    setState(() {
      _error = e;
      _busy = false;
    });
  }

  void _done(String toast) {
    _current.clear();
    _next.clear();
    _again.clear();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _form = _Form.none;
      _error = null;
    });
    showHaloToast(context, toast);
  }

  // a new passphrase typed twice, long enough
  String? _newOk() {
    if (_next.text.runes.length < kVaultMinLength) {
      return l10n.desktopLockShort(kVaultMinLength);
    }
    if (_next.text != _again.text) return l10n.desktopLockMismatch;
    return null;
  }

  Future<void> _submit() async {
    if (_busy) return;
    final form = _form;
    if (form != _Form.remove) {
      final bad = _newOk();
      if (bad != null) return _say(bad);
    }
    if (form != _Form.add && _current.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      switch (form) {
        case _Form.add:
          await widget.lock.add(_next.text);
          return _done(l10n.desktopPassAdded);
        case _Form.change:
          if (!await widget.lock.change(_current.text, _next.text)) {
            _current.clear();
            return _say(l10n.desktopLockWrong);
          }
          return _done(l10n.desktopPassChanged);
        case _Form.remove:
          if (!await widget.lock.remove(_current.text)) {
            _current.clear();
            return _say(l10n.desktopLockWrong);
          }
          return _done(l10n.desktopPassRemoved);
        case _Form.none:
          return;
      }
    } on SealError {
      return _say(
        widget.lock.place == SealPlace.windows
            ? l10n.desktopPassStaysWindows
            : l10n.desktopPassStays,
      );
    } catch (e) {
      // the type only: a message could carry a path or a key
      dlog('desktop passphrase: ${e.runtimeType}');
      return _say(l10n.desktopLockFailed);
    }
  }

  Widget _body(String t, {Color? color}) => Text(
    t,
    textAlign: TextAlign.center,
    style: HaloType.sans(
      size: 14,
      height: 1.45,
      color: color ?? HaloColors.text2,
    ),
  );

  Widget _small(String t) => Text(
    t,
    textAlign: TextAlign.center,
    style: HaloType.sans(size: 12.5, height: 1.45, color: HaloColors.text3),
  );

  SecretField _field(
    String label,
    TextEditingController c, {
    FocusNode? focus,
    bool autofocus = false,
    TextInputAction action = TextInputAction.next,
    VoidCallback? onSubmit,
  }) => SecretField(
    label: label,
    controller: c,
    shown: _shown,
    onToggle: () => setState(() => _shown = !_shown),
    enabled: !_busy,
    action: action,
    onSubmit: onSubmit,
    focusNode: focus,
    autofocus: autofocus,
  );

  Widget _errorLine() => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Text(
        _error ?? '',
        textAlign: TextAlign.center,
        style: HaloType.sans(size: 13, color: HaloColors.roseText),
      ),
    ),
  );

  List<Widget> _state() => _on
      ? [
          _body(l10n.desktopPassOnBody, color: HaloColors.text),
          const SizedBox(height: 28),
          HaloPrimaryButton(
            label: l10n.desktopPassChange,
            onTap: () => _open(_Form.change),
          ),
          const SizedBox(height: 12),
          if (_sealWorks)
            HaloGhostButton(
              label: l10n.desktopPassRemove,
              quiet: true,
              onTap: () => _open(_Form.remove),
            )
          else
            _small(l10n.desktopPassStays),
        ]
      : [
          _body(l10n.desktopPassOffBody, color: HaloColors.text),
          const SizedBox(height: 28),
          HaloPrimaryButton(
            label: l10n.desktopLockAddPassphrase,
            onTap: () => _open(_Form.add),
          ),
          const SizedBox(height: 22),
          _small(l10n.desktopLockWithoutPassphrase),
        ];

  List<Widget> _fields() {
    final f = _form;
    final withNew = f != _Form.remove;
    return [
      if (f == _Form.remove) ...[
        _body(l10n.desktopPassRemoveBody),
        const SizedBox(height: 20),
      ],
      if (f != _Form.add) ...[
        _field(
          l10n.desktopPassCurrent,
          _current,
          autofocus: true,
          action: withNew ? TextInputAction.next : TextInputAction.go,
          onSubmit: withNew ? _nextFocus.requestFocus : _submit,
        ),
        const SizedBox(height: 14),
      ],
      if (withNew) ...[
        _field(
          f == _Form.add ? l10n.desktopLockField : l10n.desktopPassNew,
          _next,
          focus: _nextFocus,
          autofocus: f == _Form.add,
          onSubmit: _againFocus.requestFocus,
        ),
        const SizedBox(height: 14),
        _field(
          l10n.desktopLockRepeat,
          _again,
          focus: _againFocus,
          action: TextInputAction.go,
          onSubmit: _submit,
        ),
      ],
      _errorLine(),
      const SizedBox(height: 10),
      HaloPrimaryButton(
        label: switch (f) {
          _Form.add => l10n.desktopLockAddPassphrase,
          _Form.change => l10n.desktopPassChange,
          _ => l10n.desktopPassRemove,
        },
        busy: _busy,
        onTap: _submit,
      ),
      const SizedBox(height: 12),
      HaloGhostButton(
        label: l10n.commonCancel,
        quiet: true,
        onTap: _busy ? null : () => _open(_Form.none),
      ),
      const SizedBox(height: 22),
      _small(
        f == _Form.remove
            ? l10n.desktopLockWithoutPassphrase
            : l10n.desktopLockHonest,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return Scaffold(
      backgroundColor: HaloColors.ink,
      appBar: AppBar(
        backgroundColor: HaloColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
        title: Text(
          l10n.desktopPassRow,
          style: HaloType.sans(
            size: 17,
            weight: FontWeight.w600,
            color: HaloColors.text,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AnimatedSwitcher(
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, a) =>
                  FadeTransition(opacity: a, child: child),
              child: FitColumn(
                key: ValueKey('$_form$_on'),
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...(_form == _Form.none ? _state() : _fields()),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
