// SPDX-License-Identifier: GPL-3.0-or-later
// lock_state.dart - pin-based app lock with auto-lock on backgrounding.
// pin hash + salt are stored in flutter_secure_storage (Android Keystore-
// backed), so brute force on a stolen unlocked device still needs the
// keystore-protected blob.

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dlog.dart';
import 'package:local_auth/local_auth.dart';

enum PinResult { normal, panic, invalid, throttled }

class LockState extends ChangeNotifier {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kEnabled = 'halo.lock.enabled';
  static const _kHash = 'halo.lock.pin_hash';
  static const _kSalt = 'halo.lock.pin_salt';
  static const _kBio = 'halo.lock.biometric';
  static const _kPanicHash = 'halo.lock.panic_hash';
  static const _kPanicSalt = 'halo.lock.panic_salt';
  static const _kPanicEnabled = 'halo.lock.panic_enabled';
  static const _kMisses = 'halo.lock.misses';
  static const _kUntil = 'halo.lock.until';

  bool _enabled = false;
  // until the first read lands nothing is known, and the gate paints ink
  // rather than a home screen that may be about to lock
  bool _loaded = false;
  bool get loaded => _loaded;
  bool _panicEnabled = false;
  bool _locked = true;
  // wrong pins in a row, and the moment the pad opens again. a four digit
  // pin at pad speed is ten thousand tries; five misses cost thirty
  // seconds, then a minute, then two. the wipe pin is never held back.
  int _misses = 0;
  int _until = 0;
  Duration get throttleLeft {
    final left = _until - DateTime.now().millisecondsSinceEpoch;
    return left > 0 ? Duration(milliseconds: left) : Duration.zero;
  }

  bool _biometric = false;
  bool _bioSupported = false;

  bool get enabled => _enabled;
  // when lock is off, locked is always false. on startup, if lock is on,
  // we begin locked and require pin entry.
  bool get locked => _enabled && _locked;
  bool get biometric => _biometric;
  bool get bioSupported => _bioSupported;
  bool get panicEnabled => _panicEnabled;

  Future<void> load() async {
    try {
      _enabled = (await _storage.read(key: _kEnabled)) == 'true';
      _biometric = (await _storage.read(key: _kBio)) == 'true';
      _panicEnabled = (await _storage.read(key: _kPanicEnabled)) == 'true';
      _misses = int.tryParse(await _storage.read(key: _kMisses) ?? '') ?? 0;
      _until = int.tryParse(await _storage.read(key: _kUntil) ?? '') ?? 0;
    } catch (e) {
      // a keystore that will not answer. fail open, since a pin that can
      // never verify would lock the person out of their own messages, and
      // say so in the debug log
      dlog('lock: storage read failed: $e');
    }
    _locked = _enabled;
    _loaded = true;
    try {
      final auth = LocalAuthentication();
      final canCheck = await auth.canCheckBiometrics;
      final available = await auth.getAvailableBiometrics();
      _bioSupported = canCheck && available.isNotEmpty;
    } catch (_) {
      _bioSupported = false;
    }
    notifyListeners();
  }

  // false when the pin is the wipe pin: verify tries the normal pin first,
  // so that would have quietly disarmed the wipe while the page said set
  Future<bool> setupPin(String pin) async {
    if (_panicEnabled) {
      final ph = await _storage.read(key: _kPanicHash);
      final ps = await _storage.read(key: _kPanicSalt);
      if (ph != null && ps != null && _hashPin(pin, ps) == ph) return false;
    }
    final salt = _randomSalt();
    final hash = _hashPin(pin, salt);
    await _storage.write(key: _kHash, value: hash);
    await _storage.write(key: _kSalt, value: salt);
    await _storage.write(key: _kEnabled, value: 'true');
    _enabled = true;
    _locked = false;
    notifyListeners();
    return true;
  }

  Future<PinResult> verifyPin(String pin) async {
    final held = throttleLeft > Duration.zero;
    // the normal pin first, unless the pad is held
    if (!held) {
      final salt = await _storage.read(key: _kSalt);
      final stored = await _storage.read(key: _kHash);
      if (salt != null && stored != null) {
        if (_hashPin(pin, salt) == stored) {
          _locked = false;
          if (_misses != 0 || _until != 0) {
            _misses = 0;
            _until = 0;
            await _storage.write(key: _kMisses, value: '0');
            await _storage.write(key: _kUntil, value: '0');
          }
          notifyListeners();
          return PinResult.normal;
        }
      }
    }
    // then the panic pin, if set, held or not: someone forced to open the
    // phone must always be able to wipe it. matching it means the user
    // wants the app wiped right now - caller is responsible for invoking
    // wipeHalo(). we do NOT change _locked here.
    if (_panicEnabled) {
      final pSalt = await _storage.read(key: _kPanicSalt);
      final pHash = await _storage.read(key: _kPanicHash);
      if (pSalt != null && pHash != null && _hashPin(pin, pSalt) == pHash) {
        return PinResult.panic;
      }
    }
    if (held) return PinResult.throttled;
    _misses++;
    if (_misses % 5 == 0) {
      final step = _misses ~/ 5;
      final wait = 30000 * (1 << (step - 1).clamp(0, 6));
      _until = DateTime.now().millisecondsSinceEpoch + wait;
      await _storage.write(key: _kUntil, value: '$_until');
    }
    await _storage.write(key: _kMisses, value: '$_misses');
    notifyListeners();
    return PinResult.invalid;
  }

  // setup the panic pin. returns false if it matches the normal pin
  // (panic pin must be distinct or the feature is useless).
  Future<bool> setupPanicPin(String pin) async {
    final normalSalt = await _storage.read(key: _kSalt);
    final normalHash = await _storage.read(key: _kHash);
    if (normalSalt != null && normalHash != null) {
      if (_hashPin(pin, normalSalt) == normalHash) return false;
    }
    final salt = _randomSalt();
    final hash = _hashPin(pin, salt);
    await _storage.write(key: _kPanicHash, value: hash);
    await _storage.write(key: _kPanicSalt, value: salt);
    await _storage.write(key: _kPanicEnabled, value: 'true');
    _panicEnabled = true;
    notifyListeners();
    return true;
  }

  Future<void> disablePanicPin() async {
    await _storage.delete(key: _kPanicHash);
    await _storage.delete(key: _kPanicSalt);
    await _storage.delete(key: _kPanicEnabled);
    _panicEnabled = false;
    notifyListeners();
  }

  Future<void> disable() async {
    await _storage.delete(key: _kEnabled);
    await _storage.delete(key: _kHash);
    await _storage.delete(key: _kSalt);
    await _storage.delete(key: _kBio);
    await _storage.delete(key: _kPanicHash);
    await _storage.delete(key: _kPanicSalt);
    await _storage.delete(key: _kPanicEnabled);
    _enabled = false;
    _locked = false;
    _biometric = false;
    _panicEnabled = false;
    notifyListeners();
  }

  Future<void> setBiometric(bool v) async {
    await _storage.write(key: _kBio, value: v ? 'true' : 'false');
    _biometric = v;
    notifyListeners();
  }

  Future<bool> tryBiometric() async {
    if (!_enabled || !_biometric || !_bioSupported) {
      return false;
    }
    try {
      final auth = LocalAuthentication();
      final ok = await auth.authenticate(
        localizedReason: 'Unlock kryfo',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (ok) {
        _locked = false;
        notifyListeners();
      }
      return ok;
    } catch (e) {
      return false;
    }
  }

  // set while the app itself sent the user out to a system picker, the
  // camera or a share sheet. the pause that follows is ours, not a leave,
  // so it does not lock. cleared the moment that call returns, and by a
  // deadline in case it never does.
  DateTime? _holdUntil;
  int _holdGen = 0;
  bool get holding =>
      _holdUntil != null && DateTime.now().isBefore(_holdUntil!);

  Future<T> hold<T>(Future<T> Function() body) async {
    _holdUntil = DateTime.now().add(const Duration(minutes: 5));
    final gen = ++_holdGen;
    try {
      return await body();
    } finally {
      // a beat past the return: the resume event trails the picker's
      // result and must not see the hold already dropped. a newer hold
      // (save picker, then share sheet) keeps its own deadline.
      Future.delayed(const Duration(seconds: 2), () {
        if (gen == _holdGen) _holdUntil = null;
      });
    }
  }

  void lock() {
    if (!_enabled || holding) return;
    if (!_locked) {
      _locked = true;
      notifyListeners();
    }
  }

  String _randomSalt() {
    final r = Random.secure();
    final bytes = List.generate(16, (_) => r.nextInt(256));
    return base64Encode(bytes);
  }

  String _hashPin(String pin, String salt) {
    // sha256(salt:pin) - fine for 4-digit pin protected by keystore.
    // pbkdf2 here is overkill given the storage layer.
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }
}

final lockState = LockState();
