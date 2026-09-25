// SPDX-License-Identifier: GPL-3.0-or-later
// lock_state.dart - the app lock. the pins live in one table the engine
// keeps (engine/pin.go): eight entries of one size, so what is stored does
// not say which pins exist, and one check that does the same work whatever
// was typed. everything a check needs is read once in load(); a check reads
// nothing and writes exactly one value, whatever it turns out to be. the
// outcome is shown at one moment after the tap, the same for every pin.

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'container.dart';
import 'dlog.dart';
import 'l10n/l10n.dart';
import 'notifications.dart';

enum PinResult { normal, panic, decoy, invalid, throttled }

// which entry of the table plays which part. fixed, so a pin set in one
// place can never land on another's entry
class PinSlot {
  static const app = 0;
  static const wipe = 1;
  static const decoy = 2;
  static const vault = 3;
  static const decoyWipe = 4;
  static const decoyDecoy = 5;
}

// what an entry opens, sealed inside it
class PinKind {
  static const everyday = 1;
  static const wipe = 2;
  static const decoy = 3;
  static const vault = 4;
}

// the everyday container's id inside the sealed records
final everydayContainer = HaloContainer.everyday.id;

// a decoy session is open: nothing of kryfo's may show. read from storage
// every time, so a process the job starts honours it too. an unreadable
// value counts as quiet: a missed notification over one in a decoy
Future<bool> quietNow([LockStore? store]) async {
  try {
    final s = await (store ?? SecureLockStore()).read('halo.lock.state');
    if (s == null) return false;
    return (jsonDecode(s) as Map<String, dynamic>)['q'] == true;
  } catch (_) {
    return true;
  }
}

// secure storage, behind a seam so a test can count what is read and written
abstract class LockStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureLockStore implements LockStore {
  // resetOnError off: on a read error the plugin used to delete every key,
  // the database passphrase with them
  static const _s = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: false,
    ),
  );
  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

// the engine's pin calls, behind a seam for tests. each runs on its own
// isolate: scrypt takes a fifth of a second and the pad keeps breathing
abstract class PinEngine {
  Future<Map<String, dynamic>> calibrate();
  Future<String> newTable(int logN);
  Future<Map<String, dynamic>> check(String pin, String table, String legacy);
  // {"t": table, "w": wrapped} or throws PinCollision
  Future<Map<String, dynamic>> setup(
    String pin,
    String table,
    String legacy,
    int index,
    int kind,
    String container,
  );
  Future<String> clear(String table, int index);
}

class PinCollision implements Exception {}

// the phone's clocks: time since boot, which a change of date does not
// move, and which boot this is
abstract class LockClock {
  Future<int> uptimeMs();
  Future<int> bootCount();
}

class PlatformLockClock implements LockClock {
  static const _ch = MethodChannel('halo/platform');
  @override
  Future<int> uptimeMs() async {
    try {
      return await _ch.invokeMethod<int>('uptimeMs') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<int> bootCount() async {
    try {
      return await _ch.invokeMethod<int>('bootCount') ?? -1;
    } catch (_) {
      return -1;
    }
  }
}

// fingerprint unlock on a key the phone throws away when a finger is added
// (BioKey.kt). "ok", "cancel", "invalidated", "none", "error"
abstract class LockBio {
  Future<bool> ready();
  Future<String> state();
  Future<bool> enable();
  Future<void> disable();
  Future<String> unlock(String title, String cancel);
}

class PlatformLockBio implements LockBio {
  static const _ch = MethodChannel('halo/platform');
  Future<T?> _call<T>(String m, [Object? a]) async {
    try {
      return await _ch.invokeMethod<T>(m, a);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> ready() async => await _call<bool>('bioReady') ?? false;
  @override
  Future<String> state() async => await _call<String>('bioState') ?? 'error';
  @override
  Future<bool> enable() async => await _call<bool>('bioEnable') ?? false;
  @override
  Future<void> disable() => _call<bool>('bioDisable');
  @override
  Future<String> unlock(String title, String cancel) async =>
      await _call<String>('bioUnlock', {'title': title, 'cancel': cancel}) ??
      'error';
}

class FfiPinEngine implements PinEngine {
  static DynamicLibrary _lib() => Platform.isAndroid
      ? DynamicLibrary.open('libhalo.so')
      : DynamicLibrary.process();

  static String _take(Pointer<Utf8> p) => p.toDartString();

  // the pin's bytes are overwritten before they are freed
  static void _wipeFree(Pointer<Utf8> p) {
    final b = p.cast<Uint8>();
    var i = 0;
    while (b[i] != 0) {
      b[i] = 0;
      i++;
    }
    calloc.free(p);
  }

  static Map<String, dynamic> _json(String s) {
    if (s.startsWith('error:')) throw StateError(s);
    return jsonDecode(s) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> calibrate() => Isolate.run(() {
    final fn = _lib()
        .lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>(
          'HaloPinCalibrate',
        );
    return _json(_take(fn()));
  });

  @override
  Future<String> newTable(int logN) => Isolate.run(() {
    final fn = _lib()
        .lookupFunction<
          Pointer<Utf8> Function(Int32),
          Pointer<Utf8> Function(int)
        >('HaloPinNewTable');
    final s = _take(fn(logN));
    if (s.startsWith('error:')) throw StateError(s);
    return s;
  });

  @override
  Future<Map<String, dynamic>> check(String pin, String table, String legacy) =>
      Isolate.run(() {
        final fn = _lib()
            .lookupFunction<
              Pointer<Utf8> Function(
                Pointer<Utf8>,
                Pointer<Utf8>,
                Pointer<Utf8>,
                Pointer<Utf8>,
              ),
              Pointer<Utf8> Function(
                Pointer<Utf8>,
                Pointer<Utf8>,
                Pointer<Utf8>,
                Pointer<Utf8>,
              )
            >('HaloPinCheck');
        final p = pin.toNativeUtf8(),
            t = table.toNativeUtf8(),
            l = legacy.toNativeUtf8(),
            w = ''.toNativeUtf8();
        try {
          return _json(_take(fn(p, t, l, w)));
        } finally {
          _wipeFree(p);
          calloc.free(t);
          calloc.free(l);
          calloc.free(w);
        }
      });

  @override
  Future<Map<String, dynamic>> setup(
    String pin,
    String table,
    String legacy,
    int index,
    int kind,
    String container,
  ) => Isolate.run(() {
    final fn = _lib()
        .lookupFunction<
          Pointer<Utf8> Function(
            Pointer<Utf8>,
            Pointer<Utf8>,
            Pointer<Utf8>,
            Int32,
            Int32,
            Pointer<Utf8>,
            Pointer<Utf8>,
          ),
          Pointer<Utf8> Function(
            Pointer<Utf8>,
            Pointer<Utf8>,
            Pointer<Utf8>,
            int,
            int,
            Pointer<Utf8>,
            Pointer<Utf8>,
          )
        >('HaloPinSetup');
    final p = pin.toNativeUtf8(),
        t = table.toNativeUtf8(),
        l = legacy.toNativeUtf8();
    final c = container.toNativeUtf8(), w = ''.toNativeUtf8();
    try {
      final s = _take(fn(p, t, l, index, kind, c, w));
      if (s == 'error: collision') throw PinCollision();
      return _json(s);
    } finally {
      _wipeFree(p);
      calloc.free(t);
      calloc.free(l);
      calloc.free(c);
      calloc.free(w);
    }
  });

  @override
  Future<String> clear(String table, int index) => Isolate.run(() {
    final fn = _lib()
        .lookupFunction<
          Pointer<Utf8> Function(Pointer<Utf8>, Int32),
          Pointer<Utf8> Function(Pointer<Utf8>, int)
        >('HaloPinClear');
    final t = table.toNativeUtf8();
    try {
      final s = _take(fn(t, index));
      if (s.startsWith('error:')) throw StateError(s);
      return s;
    } finally {
      calloc.free(t);
    }
  });
}

// the one value a check writes: misses since any unlock (run), misses since
// the last everyday unlock (budget), the hold measured on the uptime clock,
// and whether a decoy session is open (quiet)
class LockCounters {
  final int run;
  final int budget;
  final int holdStart;
  final int holdLen;
  final int holdBoot;
  final bool quiet;
  const LockCounters({
    this.run = 0,
    this.budget = 0,
    this.holdStart = 0,
    this.holdLen = 0,
    this.holdBoot = -1,
    this.quiet = false,
  });

  factory LockCounters.parse(String? s) {
    if (s == null) return const LockCounters();
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      int n(String k) => (j[k] as num?)?.toInt() ?? 0;
      return LockCounters(
        run: n('r'),
        budget: n('b'),
        holdStart: n('hs'),
        holdLen: n('hl'),
        holdBoot: (j['hb'] as num?)?.toInt() ?? -1,
        quiet: j['q'] == true,
      );
    } catch (_) {
      // unreadable: a hold rather than none
      return const LockCounters(budget: 20, holdLen: 5 * 60000);
    }
  }

  String encode() => jsonEncode({
    'r': run,
    'b': budget,
    'hs': holdStart,
    'hl': holdLen,
    'hb': holdBoot,
    'q': quiet,
  });

  // after a reboot the uptime clock starts from zero: the whole hold starts
  // again from the first check that sees the new boot
  LockCounters rebased(int uptime, int boot) {
    if (holdLen <= 0 || boot == holdBoot) return this;
    return LockCounters(
      run: run,
      budget: budget,
      holdStart: uptime,
      holdLen: holdLen,
      holdBoot: boot,
      quiet: quiet,
    );
  }

  // what is left of the hold. after a reboot the whole hold starts again
  int holdLeft(int uptime, int boot) {
    if (holdLen <= 0) return 0;
    if (boot != holdBoot || uptime < holdStart) return holdLen;
    return max(0, holdStart + holdLen - uptime);
  }

  // a miss: every fifth in a row holds the pad 30 s, doubling; from twenty
  // since the last everyday unlock, every fifth holds five minutes,
  // doubling, up to eight hours. a decoy unlock clears the run but not the
  // budget, so it cannot be used to keep guessing the real pin
  LockCounters miss(int uptime, int boot) {
    final r = run + 1, b = budget + 1;
    var len = 0;
    if (r % 5 == 0) len = 30000 * (1 << ((r ~/ 5) - 1).clamp(0, 6));
    if (b >= 20 && b % 5 == 0) {
      final long = 5 * 60000 * (1 << ((b - 20) ~/ 5).clamp(0, 7));
      len = max(len, min(long, 8 * 3600000));
    }
    return len > 0
        ? LockCounters(
            run: r,
            budget: b,
            holdStart: uptime,
            holdLen: len,
            holdBoot: boot,
            quiet: quiet,
          )
        : LockCounters(
            run: r,
            budget: b,
            holdStart: holdStart,
            holdLen: holdLen,
            holdBoot: holdBoot,
            quiet: quiet,
          );
  }
}

// set once the decoy session exists (step 1, piece 5). until then a decoy
// match counts as a wrong pin, so it can never open the everyday app
bool decoyReady = false;

class LockState extends ChangeNotifier {
  LockState({
    LockStore? store,
    PinEngine? engine,
    LockClock? clock,
    LockBio? bio,
    this.revealAfter = const Duration(milliseconds: 450),
  }) : _store = store ?? SecureLockStore(),
       _engine = engine ?? FfiPinEngine(),
       _clock = clock ?? PlatformLockClock(),
       _bio = bio ?? PlatformLockBio();

  final LockStore _store;
  final PinEngine _engine;
  final LockClock _clock;
  final LockBio _bio;
  // the session an unlock opens is built here, under the lock screen, before
  // it lifts: the everyday one, or the decoy's
  Future<void> Function(PinResult)? onOutcome;
  // the containers are open and a decoy session could be built: a check
  // waits for it (the same wait whatever is typed), so a decoy pin typed
  // in the first second after a cold start is not taken for a wrong one
  Future<void>? sessionsReady;
  // the fingerprint key is gone or was invalidated by a new finger: no
  // finger opens kryfo until the pin has been typed once
  bool _bioStale = false;
  bool get bioStale => _bioStale;
  // every outcome is shown this long after the tap at the earliest
  final Duration revealAfter;

  static const _kEnabled = 'halo.lock.enabled';
  static const _kTable = 'halo.lock.table';
  static const _kState = 'halo.lock.state';
  static const _kBio = 'halo.lock.biometric';
  static const _kWipeOn = 'halo.lock.panic_enabled';
  // whether the decoy has a wipe pin, or a decoy pin, of its own
  static const _kDWipe = 'halo.lock.d.wipe';
  static const _kDDecoy = 'halo.lock.d.decoy';
  // from before the table: sha256("salt:pin"), kept until migrated
  static const _kHash = 'halo.lock.pin_hash';
  static const _kSalt = 'halo.lock.pin_salt';
  static const _kPanicHash = 'halo.lock.panic_hash';
  static const _kPanicSalt = 'halo.lock.panic_salt';
  static const _kMisses = 'halo.lock.misses';
  static const _kUntil = 'halo.lock.until';

  bool _enabled = false;
  bool _loaded = false;
  bool get loaded => _loaded;
  // a keystore that would not answer. the lock stays shut and load tries
  // again rather than opening the app to whoever holds the phone
  bool _unreadable = false;
  bool get unreadable => _unreadable;
  bool _panicEnabled = false;
  bool _locked = true;
  bool _biometric = false;
  bool _bioSupported = false;

  String? _table;
  // a table of random entries at the lowest cost, checked when there is no
  // real one yet (only a legacy pin), so that check costs the same
  String? _standIn;
  Map<String, String> _legacy = const {};
  LockCounters _counters = const LockCounters();
  DateTime _holdEndsForScreen = DateTime.fromMillisecondsSinceEpoch(0);

  bool get enabled => _enabled;
  bool get locked => (_enabled || _unreadable) && _locked;
  bool get biometric => _biometric;
  bool get bioSupported => _bioSupported;
  bool get panicEnabled => _inDecoy ? _dWipe : _panicEnabled;

  // a decoy session is open (the session switch says so). the App lock
  // screen then works on the decoy's own entries: its pin, its wipe pin, its
  // decoy pin. a pin that clashes with one it cannot see is taken and kept
  // nowhere, so nothing there says another exists; turning the lock off
  // only pauses it until the next start
  bool _inDecoy = false;
  bool get inDecoy => _inDecoy;
  set inDecoy(bool v) {
    _inDecoy = v;
    notifyListeners();
  }

  bool _paused = false;
  bool _dWipe = false;
  bool _dDecoy = false;
  // what the App lock screen shows as on
  bool get lockOn => _enabled && !_paused;
  bool get decoyPinOn => _dDecoy;
  // a decoy session is open: nothing may notify
  bool get quiet => _counters.quiet;
  // the old wipe pin is still the sha256 kind: App lock asks for it again
  bool get legacyWipe => (_legacy['ws'] ?? '').isNotEmpty;

  Duration get throttleLeft {
    final left = _holdEndsForScreen.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> load() async {
    try {
      _enabled = (await _store.read(_kEnabled)) == 'true';
      _biometric = (await _store.read(_kBio)) == 'true';
      _panicEnabled = (await _store.read(_kWipeOn)) == 'true';
      _dWipe = (await _store.read(_kDWipe)) == 'true';
      _dDecoy = (await _store.read(_kDDecoy)) == 'true';
      _table = await _store.read(_kTable);
      _legacy = {
        'as': await _store.read(_kSalt) ?? '',
        'ah': await _store.read(_kHash) ?? '',
        'ws': await _store.read(_kPanicSalt) ?? '',
        'wh': await _store.read(_kPanicHash) ?? '',
      };
      var c = LockCounters.parse(await _store.read(_kState));
      // misses and a hold from before the table
      final oldMisses = int.tryParse(await _store.read(_kMisses) ?? '');
      if (oldMisses != null) {
        final oldUntil = int.tryParse(await _store.read(_kUntil) ?? '') ?? 0;
        final leftMs = max(0, oldUntil - DateTime.now().millisecondsSinceEpoch);
        c = LockCounters(
          run: oldMisses,
          budget: oldMisses,
          holdStart: await _clock.uptimeMs(),
          holdLen: leftMs,
          holdBoot: await _clock.bootCount(),
        );
        await _store.write(_kState, c.encode());
        await _store.delete(_kMisses);
        await _store.delete(_kUntil);
      }
      _counters = c;
      _unreadable = false;
    } catch (e) {
      dlog('lock: storage read failed: $e');
      _unreadable = true;
      _locked = true;
      _loaded = true;
      notifyListeners();
      Future.delayed(const Duration(seconds: 2), load);
      return;
    }
    _standIn ??= await _engine.newTable(14);
    await _refreshHoldForScreen();
    _locked = _enabled;
    _loaded = true;
    try {
      final auth = LocalAuthentication();
      _bioSupported =
          await _bio.ready() &&
          await auth.canCheckBiometrics &&
          (await auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      _bioSupported = false;
    }
    if (_biometric) _bioStale = await _bio.state() != 'ok';
    notifyListeners();
  }

  Future<void> _refreshHoldForScreen() async {
    final left = _counters.holdLeft(
      await _clock.uptimeMs(),
      await _clock.bootCount(),
    );
    _holdEndsForScreen = DateTime.now().add(Duration(milliseconds: left));
  }

  String get _legacyJson => jsonEncode(_legacy);

  // the table, made on first need with the cost this phone can bear
  Future<String> _ensureTable() async {
    final t = _table;
    if (t != null) return t;
    final cal = await _engine.calibrate();
    final made = await _engine.newTable((cal['n'] as num).toInt());
    await _store.write(_kTable, made);
    _table = made;
    return made;
  }

  // one pin, one check, one write, one moment to show it
  Future<PinResult> verifyPin(String pin) async {
    final ready = sessionsReady;
    if (ready != null) {
      await ready.timeout(const Duration(seconds: 8), onTimeout: () {});
    }
    final t0 = DateTime.now();
    final uptime = await _clock.uptimeMs();
    final boot = await _clock.bootCount();
    final base = _counters.rebased(uptime, boot);
    final held = base.holdLeft(uptime, boot) > 0;
    _standIn ??= await _engine.newTable(14);
    final r = await _engine.check(pin, _table ?? _standIn!, _legacyJson);
    final kind = (r['k'] as num?)?.toInt() ?? 0;
    final everyday = kind == PinKind.everyday || r['la'] == true;
    final wipe = kind == PinKind.wipe || r['lw'] == true;
    final decoy = kind == PinKind.decoy;

    late final PinResult result;
    late final LockCounters next;
    if (wipe) {
      // someone forced to open the phone can always wipe it, held or not
      result = PinResult.panic;
      next = base;
    } else if (held) {
      result = PinResult.throttled;
      next = base;
    } else if (everyday) {
      result = PinResult.normal;
      next = const LockCounters();
    } else if (decoy && decoyReady) {
      result = PinResult.decoy;
      next = LockCounters(budget: base.budget, quiet: true);
    } else {
      result = PinResult.invalid;
      next = base.miss(uptime, boot);
    }
    await _store.write(_kState, next.encode());
    _counters = next;
    if (result == PinResult.normal || result == PinResult.decoy) {
      try {
        await onOutcome?.call(result);
      } catch (e) {
        dlog('lock: session not opened: $e');
      }
    }
    final built = DateTime.now().difference(t0);

    final left = revealAfter - built;
    if (left > Duration.zero) await Future.delayed(left);
    // profile builds only, and only times: how close every outcome comes
    // to the moment it is shown
    if (kProfileMode) {
      debugPrint(
        'lock: ready ${built.inMilliseconds} ms, shown '
        '${DateTime.now().difference(t0).inMilliseconds} ms',
      );
    }

    if (result == PinResult.normal || result == PinResult.decoy) {
      _locked = false;
    }

    if (result == PinResult.invalid || result == PinResult.throttled) {
      await _refreshHoldForScreen();
    }
    notifyListeners();
    // the pin was typed: a finger added before now may open kryfo again.
    // after the reveal, so it adds nothing to the wait
    if (result == PinResult.normal && _biometric && _bioStale) {
      unawaited(
        _bio.enable().then((ok) {
          _bioStale = !ok;
          notifyListeners();
        }),
      );
    }
    // an everyday unlock with the old kind of pin moves it into the table,
    // after the screen has already opened
    if (result == PinResult.normal &&
        kind != PinKind.everyday &&
        r['la'] == true) {
      unawaited(_migrateApp(pin));
    }
    return result;
  }

  // the table is written first and the old keys deleted after, never the
  // other way round: storage writes land in order, so a crash in between
  // leaves both, and both open the app
  Future<void> _migrateApp(String pin) async {
    try {
      final table = await _ensureTable();
      // the old app hash is the pin being moved: not a clash
      final out = await _engine.setup(
        pin,
        table,
        jsonEncode({..._legacy, 'as': '', 'ah': ''}),
        PinSlot.app,
        PinKind.everyday,
        everydayContainer,
      );
      final t = jsonEncode(out['t']);
      await _store.write(_kTable, t);
      _table = t;
      await _store.delete(_kHash);
      await _store.delete(_kSalt);
      _legacy = {..._legacy, 'as': '', 'ah': ''};
    } catch (e) {
      dlog('lock: migrate failed: $e');
    }
  }

  // false when the pin is already in use: the screen says "pick a
  // different pin" and never which one it matched
  Future<bool> setupPin(String pin) => _inDecoy
      ? _setup(
          pin,
          PinSlot.decoy,
          PinKind.decoy,
          container: HaloContainer.decoy.id,
        )
      : _setup(pin, PinSlot.app, PinKind.everyday);

  // the decoy's pin opens the decoy container. its entry is written last
  // when a decoy is made, and cleared first when one is removed
  Future<bool> setupDecoyPin(String pin) async {
    final ok = await _setup(
      pin,
      _inDecoy ? PinSlot.decoyDecoy : PinSlot.decoy,
      PinKind.decoy,
      container: HaloContainer.decoy.id,
    );
    if (ok && _inDecoy) {
      await _store.write(_kDDecoy, 'true');
      _dDecoy = true;
      notifyListeners();
    }
    return ok;
  }

  // everything the decoy opens or set for itself, from the everyday side
  Future<void> clearDecoyPins() async {
    var t = _table;
    if (t != null) {
      for (final i in [PinSlot.decoy, PinSlot.decoyWipe, PinSlot.decoyDecoy]) {
        t = await _engine.clear(t!, i);
      }
      await _store.write(_kTable, t!);
      _table = t;
    }
    await _store.delete(_kDWipe);
    await _store.delete(_kDDecoy);
    _dWipe = false;
    _dDecoy = false;
    notifyListeners();
  }

  // inside the decoy: its own decoy pin goes
  Future<void> clearInnerDecoyPin() async {
    final t = _table;
    if (t != null) {
      final out = await _engine.clear(t, PinSlot.decoyDecoy);
      await _store.write(_kTable, out);
      _table = out;
    }
    await _store.delete(_kDDecoy);
    _dDecoy = false;
    notifyListeners();
  }

  // "Enter your PIN" before any Advanced protection flow: the pin of the
  // session that is open. a miss counts as it would on the lock screen, the
  // wipe pin wipes as it would there, and an old sha256 pin moves into the
  // table here too, for people who only ever used their fingerprint
  Future<PinResult> confirmPin(String pin) async {
    final uptime = await _clock.uptimeMs();
    final boot = await _clock.bootCount();
    final base = _counters.rebased(uptime, boot);
    _standIn ??= await _engine.newTable(14);
    final r = await _engine.check(pin, _table ?? _standIn!, _legacyJson);
    final kind = (r['k'] as num?)?.toInt() ?? 0;
    if (kind == PinKind.wipe || r['lw'] == true) return PinResult.panic;
    if (base.holdLeft(uptime, boot) > 0) return PinResult.throttled;
    final ok = _inDecoy
        ? kind == PinKind.decoy
        : kind == PinKind.everyday || r['la'] == true;
    if (!ok) {
      _counters = base.miss(uptime, boot);
      await _store.write(_kState, _counters.encode());
      await _refreshHoldForScreen();
      notifyListeners();
      return PinResult.invalid;
    }
    if (!_inDecoy && kind != PinKind.everyday && r['la'] == true) {
      await _migrateApp(pin);
    }
    return PinResult.normal;
  }

  Future<bool> setupPanicPin(String pin) async {
    if (_inDecoy) {
      final ok = await _setup(pin, PinSlot.decoyWipe, PinKind.wipe);
      if (ok) {
        await _store.write(_kDWipe, 'true');
        _dWipe = true;
        notifyListeners();
      }
      return ok;
    }
    final ok = await _setup(pin, PinSlot.wipe, PinKind.wipe);
    if (ok) {
      await _store.write(_kWipeOn, 'true');
      await _store.delete(_kPanicHash);
      await _store.delete(_kPanicSalt);
      _legacy = {..._legacy, 'ws': '', 'wh': ''};
      _panicEnabled = true;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> _setup(
    String pin,
    int slot,
    int kind, {
    String? container,
  }) async {
    final wasOn = _enabled;
    final table = await _ensureTable();
    // a pin changed in place may equal the one it replaces: leave that
    // entry's old legacy twin out of the clash check
    final legacy = jsonEncode({
      ..._legacy,
      if (slot == PinSlot.app) 'as': '',
      if (slot == PinSlot.app) 'ah': '',
      if (slot == PinSlot.wipe) 'ws': '',
      if (slot == PinSlot.wipe) 'wh': '',
    });
    try {
      final out = await _engine.setup(
        pin,
        table,
        legacy,
        slot,
        kind,
        container ?? everydayContainer,
      );
      final t = jsonEncode(out['t']);
      await _store.write(_kTable, t);
      _table = t;
    } on PinCollision {
      // inside the decoy a clash is taken and kept nowhere
      if (_inDecoy) return true;
      final uptime = await _clock.uptimeMs();
      final boot = await _clock.bootCount();
      _counters = _counters.miss(uptime, boot);
      await _store.write(_kState, _counters.encode());
      return false;
    }
    if (slot == PinSlot.app) {
      await _store.delete(_kHash);
      await _store.delete(_kSalt);
      _legacy = {..._legacy, 'as': '', 'ah': ''};
      await _store.write(_kEnabled, 'true');
      _enabled = true;
      // a pin means the app is not to be read without it, and a
      // notification with the message in it is the app read without it
      if (!wasOn) await setHideNotifContent(true);
      _locked = false;
    }
    notifyListeners();
    return true;
  }

  Future<void> disablePanicPin() async {
    if (_inDecoy) {
      final t = _table;
      if (t != null) {
        final out = await _engine.clear(t, PinSlot.decoyWipe);
        await _store.write(_kTable, out);
        _table = out;
      }
      await _store.delete(_kDWipe);
      _dWipe = false;
      notifyListeners();
      return;
    }
    final t = _table;
    if (t != null) {
      final out = await _engine.clear(t, PinSlot.wipe);
      await _store.write(_kTable, out);
      _table = out;
    }
    await _store.delete(_kPanicHash);
    await _store.delete(_kPanicSalt);
    await _store.delete(_kWipeOn);
    _legacy = {..._legacy, 'ws': '', 'wh': ''};
    _panicEnabled = false;
    notifyListeners();
  }

  // everything goes: the table, the counters, the old keys. inside the
  // decoy it only stops locking until the next start and deletes nothing
  Future<void> disable() async {
    if (_inDecoy) {
      _paused = true;
      notifyListeners();
      return;
    }
    for (final k in [
      _kEnabled,
      _kTable,
      _kState,
      _kBio,
      _kWipeOn,
      _kDWipe,
      _kDDecoy,
      _kHash,
      _kSalt,
      _kPanicHash,
      _kPanicSalt,
      _kMisses,
      _kUntil,
    ]) {
      await _store.delete(k);
    }
    _table = null;
    _legacy = const {};
    _counters = const LockCounters();
    _enabled = false;
    _locked = false;
    _biometric = false;
    _panicEnabled = false;
    notifyListeners();
  }

  Future<bool> setBiometric(bool v) async {
    if (v && !await _bio.enable()) return false;
    if (!v) await _bio.disable();
    await _store.write(_kBio, v ? 'true' : 'false');
    _biometric = v;
    _bioStale = false;
    notifyListeners();
    return true;
  }

  // a finger opens the everyday app and nothing else
  Future<bool> tryBiometric() async {
    if (throttleLeft > Duration.zero) return false;
    if (!_enabled || !_biometric || !_bioSupported || _bioStale) return false;
    final r = await _bio.unlock(l10n.lockStateUnlockKryfo, l10n.commonCancel);
    if (r == 'invalidated' || r == 'none') {
      // a finger was added since, or the key is gone: the pin first
      _bioStale = true;
      notifyListeners();
      return false;
    }
    if (r != 'ok') return false;
    _counters = const LockCounters();
    await _store.write(_kState, _counters.encode());
    try {
      await onOutcome?.call(PinResult.normal);
    } catch (e) {
      dlog('lock: session not opened: $e');
    }
    _locked = false;
    notifyListeners();
    return true;
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

  // the app went away while a picker hold was open. the hold can run out
  // while it is away, and no second pause event ever comes, so whether it
  // locks has to be asked again when it comes back.
  bool _leftWhileHeld = false;

  // called on pause and on hidden
  void leaving() {
    if (!_enabled) return;
    _leftWhileHeld = holding;
    lock();
  }

  // called on resume. the picker coming back keeps its hold and nothing
  // locks. anything else - the home key from inside the picker, another
  // app, a call - left the hold to expire in the background, and this is
  // the only place that notices.
  void returned() {
    if (!_leftWhileHeld) return;
    _leftWhileHeld = false;
    lock();
  }

  void lock() {
    if (!_enabled || holding || _paused) return;
    if (!_locked) {
      _locked = true;
      notifyListeners();
    }
  }
}

final lockState = LockState();
