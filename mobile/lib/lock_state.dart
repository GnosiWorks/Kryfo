// lock_state.dart — pin-based app lock with auto-lock on backgrounding.
// pin hash + salt are stored in flutter_secure_storage (Android Keystore-
// backed), so brute force on a stolen unlocked device still needs the
// keystore-protected blob.

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LockState extends ChangeNotifier {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kEnabled = 'halo.lock.enabled';
  static const _kHash = 'halo.lock.pin_hash';
  static const _kSalt = 'halo.lock.pin_salt';

  bool _enabled = false;
  bool _locked = true;

  bool get enabled => _enabled;
  // when lock is off, locked is always false. on startup, if lock is on,
  // we begin locked and require pin entry.
  bool get locked => _enabled && _locked;

  Future<void> load() async {
    _enabled = (await _storage.read(key: _kEnabled)) == 'true';
    _locked = _enabled;
    notifyListeners();
  }

  Future<void> setupPin(String pin) async {
    final salt = _randomSalt();
    final hash = _hashPin(pin, salt);
    await _storage.write(key: _kHash, value: hash);
    await _storage.write(key: _kSalt, value: salt);
    await _storage.write(key: _kEnabled, value: 'true');
    _enabled = true;
    _locked = false;
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _kSalt);
    final stored = await _storage.read(key: _kHash);
    if (salt == null || stored == null) return false;
    final computed = _hashPin(pin, salt);
    if (computed != stored) return false;
    _locked = false;
    notifyListeners();
    return true;
  }

  Future<void> disable() async {
    await _storage.delete(key: _kEnabled);
    await _storage.delete(key: _kHash);
    await _storage.delete(key: _kSalt);
    _enabled = false;
    _locked = false;
    notifyListeners();
  }

  void lock() {
    if (_enabled) {
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
    // sha256(salt:pin) — fine for 4-digit pin protected by keystore.
    // pbkdf2 here is overkill given the storage layer.
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }
}

final lockState = LockState();
