// SPDX-License-Identifier: GPL-3.0-or-later
// the computer lock as each session sees it. the everyday session changes
// the vault's real lock; a decoy session does the same work, takes the same
// time and says the same things, but keeps what it changed in a note of its
// own database and never touches the vault, the keyring or the tpm
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'desktop_mode.dart';
import 'desktop_passphrase_screen.dart';
import 'desktop_vault.dart';
import 'system_seal.dart';

/// what the passphrase page asks of the lock it shows
abstract class PassphraseLock {
  /// a passphrase opens Kryfo on this computer, as this session shows it
  bool get on;

  /// whether the computer could keep the key: a passphrase may go
  Future<bool> sealWorks();

  /// which words a failure uses
  SealPlace get place;

  Future<void> add(String next);

  /// false when [current] is not the passphrase
  Future<bool> change(String current, String next);

  /// false when [current] is not the passphrase. throws [SealError] when
  /// the computer keeps nothing, and the passphrase then stays
  Future<bool> remove(String current);
}

/// in the vault while the everyday side put the backup card away
const kBackupCardSeen = 'kryfo.backup.card';

class DesktopComputerLock extends ChangeNotifier implements ComputerLockView {
  DesktopComputerLock(this.vault, this.seal);

  final DesktopVault vault;
  final SystemSeal? seal;

  // the decoy's note: {"on": bool, "slot": base64, "seen": bool}
  Map<String, Object?> _note = const {};

  SealPlace get _place => seal?.place ?? SealPlace.keyring;

  @override
  bool passphraseOn({required bool decoy}) {
    if (decoy) {
      if (_note['on'] case final bool on) return on;
    }
    return vault.hasPassphrase;
  }

  @override
  ComputerSeal sealedBy({required bool decoy}) => passphraseOn(decoy: decoy)
      ? ComputerSeal.passphrase
      : _place == SealPlace.windows
      ? ComputerSeal.windows
      : ComputerSeal.keyring;

  @override
  Widget page({required bool decoy}) =>
      DesktopPassphraseScreen(lock: lockFor(decoy: decoy));

  /// what the page works on: the vault's lock, or the decoy's stand-in
  PassphraseLock lockFor({required bool decoy}) =>
      decoy ? _DecoyLock(this) : _RealLock(this);

  @override
  bool backupWise({required bool decoy}) =>
      seal != null &&
      _place == SealPlace.windows &&
      !passphraseOn(decoy: decoy);

  @override
  bool backupCardDue({required bool decoy}) {
    if (!backupWise(decoy: decoy) || !vault.isOpen) return false;
    return decoy ? _note['seen'] != true : vault.read(kBackupCardSeen) == null;
  }

  @override
  Future<void> backupCardSeen({required bool decoy}) async {
    if (decoy) {
      await _keepNote({..._note, 'seen': true});
    } else {
      await vault.write(kBackupCardSeen, '1');
      notifyListeners();
    }
  }

  @override
  void decoyNoteRead(String? note) {
    Map<String, Object?> m = const {};
    try {
      final j = note == null ? null : jsonDecode(note);
      if (j is Map<String, Object?>) m = j;
    } catch (_) {}
    _note = m;
    notifyListeners();
  }

  Future<void> _keepNote(Map<String, Object?> m) async {
    _note = m;
    await keepComputerDecoyNote?.call(jsonEncode(m));
    notifyListeners();
  }

  void _moved() => notifyListeners();

  /// the vault opened: what the row shows is known now
  void opened() => notifyListeners();
}

class _RealLock implements PassphraseLock {
  _RealLock(this.c);
  final DesktopComputerLock c;

  @override
  bool get on => c.vault.hasPassphrase;

  @override
  SealPlace get place => c._place;

  @override
  Future<bool> sealWorks() async => await c.seal?.works() ?? false;

  @override
  Future<void> add(String next) async {
    await c.vault.addPassphrase(next, seal: c.seal);
    c._moved();
  }

  @override
  Future<bool> change(String current, String next) async {
    final ok = await c.vault.changePassphrase(current, next);
    c._moved();
    return ok;
  }

  @override
  Future<bool> remove(String current) async {
    final ok = await c.vault.removePassphrase(current, c.seal!);
    c._moved();
    return ok;
  }
}

// the decoy's row: the real one's work, its answers kept apart
class _DecoyLock implements PassphraseLock {
  _DecoyLock(this.c);
  final DesktopComputerLock c;

  @override
  bool get on => c.passphraseOn(decoy: true);

  @override
  SealPlace get place => c._place;

  @override
  Future<bool> sealWorks() async => await c.seal?.works() ?? false;

  Uint8List? get _slot => switch (c._note['slot']) {
    final String s => base64.decode(s),
    _ => null,
  };

  // the passphrase as this side knows it: its own once it set one, else
  // the real one, checked without a change
  Future<bool> _isCurrent(String current) {
    final s = _slot;
    return s == null
        ? c.vault.isPassphrase(current)
        : c.vault.checkSlot(s, current);
  }

  @override
  Future<void> add(String next) async {
    final slot = await c.vault.rehearseAdd(next, seal: c.seal);
    await c._keepNote({...c._note, 'on': true, 'slot': base64.encode(slot)});
  }

  @override
  Future<bool> change(String current, String next) async {
    if (!await _isCurrent(current)) return false;
    final slot = await c.vault.rehearseAdd(next);
    await c._keepNote({...c._note, 'on': true, 'slot': base64.encode(slot)});
    return true;
  }

  @override
  Future<bool> remove(String current) async {
    if (!await _isCurrent(current)) return false;
    await c.vault.rehearseRemove(c.seal!);
    final m = {...c._note, 'on': false}..remove('slot');
    await c._keepNote(m);
    return true;
  }
}
