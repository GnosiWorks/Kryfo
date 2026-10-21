// SPDX-License-Identifier: GPL-3.0-or-later
// the app lock. the pins live in the engine's table (engine/pin.go). a check
// reads nothing, writes one value and does the same work whatever was typed,
// and every outcome shows at the same moment after the tap.

import 'dart:async';
import 'secure_store.dart';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:local_auth/local_auth.dart';

import 'container.dart';
import 'dlog.dart';
import 'engine_strings.dart';
import 'l10n/l10n.dart';
import 'l10n/numbers.dart';
import 'lock_guard.dart' show LockDropped, lockGuard;
import 'notifications.dart';

// vault: the everyday app with its hidden chats. the decoy's vault comes back
// as decoy, with its key handed to the session
enum PinResult { normal, panic, decoy, vault, invalid, throttled }

// which entry of the table plays which part. fixed, so a pin set in one
// place can never land on another's entry
class PinSlot {
  static const app = 0;
  static const wipe = 1;
  static const decoy = 2;
  static const vault = 3;
  static const decoyWipe = 4;
  static const decoyDecoy = 5;
  static const decoyVault = 6;
  // 7 to 15 free
}

// what an entry opens, sealed inside it
class PinKind {
  static const everyday = 1;
  static const wipe = 2;
  static const decoy = 3;
  static const vault = 4;
}

// whether a pin table is kept. without one no pin opens anything, a vault
// included. read from storage, so it holds before the lock has loaded. an
// unreadable store counts as one: a vault may be there
Future<bool> pinTableKept([LockStore? store]) async {
  try {
    return await (store ?? SecureLockStore()).read(LockState._kTable) != null;
  } catch (e) {
    dlog('lock: table unread (${e.runtimeType})');
    return true;
  }
}

// the everyday container's id inside the sealed records
final everydayContainer = HaloContainer.everyday.id;

// a decoy session is open: nothing of kryfo's may show. read from storage
// every time, so a process the job starts honours it too. an unreadable
// value counts as quiet: a missed notification over one in a decoy
Future<bool> quietNow([LockStore? store]) async =>
    await quietRead(store) ?? true;

// the same, null when it could not be read
Future<bool?> quietRead([LockStore? store]) async {
  try {
    final s = await (store ?? SecureLockStore()).read('halo.lock.state');
    if (s == null) return false;
    return (jsonDecode(s) as Map<String, dynamic>)['q'] == true;
  } catch (_) {
    return null;
  }
}

// secure storage, behind a seam so a test can count what is read and written
abstract class LockStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureLockStore implements LockStore {
  // a read that fails leaves every key where it is (secure_store.dart)
  static const _s = secureStore;
  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

// the engine's pin calls, behind a seam for tests. each runs on its own
// isolate: scrypt takes a fifth of a second and the pad stays responsive
abstract class PinEngine {
  Future<Map<String, dynamic>> calibrate();
  Future<String> newTable(int logN);
  // {"i", "k", "c", "la", "lw", "u"}. u is the key the matched entry wraps,
  // 64 hex, or ''
  Future<Map<String, dynamic>> check(String pin, String table, String legacy);
  // {"t": table} or throws PinCollision. wrapPlain is a vault's database key
  // in hex, sealed into the entry, or '' for none
  Future<Map<String, dynamic>> setup(
    String pin,
    String table,
    String legacy,
    int index,
    int kind,
    String container,
    String wrapPlain,
  );
  // entry index opens with newPin instead, keeping what it opens and the key
  // it wraps: the key never leaves the engine. {"t": table}, throws
  // PinCollision, or a StateError for a wrong old pin or an entry with no key
  Future<Map<String, dynamic>> rewrap(
    String oldPin,
    String newPin,
    String table,
    String legacy,
    int index,
  );
  // the table as v2, the same pins opening the same entries
  Future<String> upgrade(String table);
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

// what a finger gave back: "ok" with the container the seal opened, or
// "cancel", "lockout", "invalidated", "none", "error", or "refused" (the
// finger was taken but the phone would not open the seal with it)
class BioOpened {
  const BioOpened(this.result, [this.opens]);
  final String result;
  final String? opens;
}

// fingerprint unlock (BioKey.kt): what a finger opens is sealed to a key the
// phone throws away when a finger is added, and is known only once a finger
// opened the seal. a seal looks the same whatever it holds
abstract class LockBio {
  Future<bool> ready();
  // "ok", "invalidated", "none", "error"
  Future<String> state();
  // a new key with [opens] sealed to it: the seal, or null when the phone
  // would not make one that opens
  Future<String?> seal(String opens);
  Future<void> disable();
  Future<BioOpened> unlock(String title, String cancel, String seal);
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
  Future<String?> seal(String opens) =>
      _call<String>('bioSeal', {'opens': opens});
  @override
  Future<void> disable() => _call<bool>('bioDisable');
  @override
  Future<BioOpened> unlock(String title, String cancel, String seal) async {
    final m = await _call<Map<Object?, Object?>>('bioUnlock', {
      'title': title,
      'cancel': cancel,
      'seal': seal,
    });
    final r = m?['r'], p = m?['p'];
    return BioOpened(r is String ? r : 'error', p is String ? p : null);
  }
}

// tells the engine whether a decoy session is open. it asks the tor
// project for nothing while one is, or before it has been told. without
// the engine, as in tests, there is no one to tell.
void tellEngineDecoy(bool on) {
  try {
    final fn = FfiPinEngine._lib()
        .lookupFunction<
          Pointer<Utf8> Function(Int32),
          Pointer<Utf8> Function(int)
        >('HaloSetDecoy');
    engineTake(fn(on ? 1 : 0));
  } on ArgumentError {
    // no engine loaded here
  }
}

class FfiPinEngine implements PinEngine {
  static DynamicLibrary _lib() => Platform.isAndroid
      ? DynamicLibrary.open('libhalo.so')
      : DynamicLibrary.process();

  // pin results can carry the vault key, so every one is zeroed on the way
  // back
  static String _take(Pointer<Utf8> p) => engineTakeSecret(p);

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
  Future<Map<String, dynamic>> check(
    String pin,
    String table,
    String legacy,
  ) => Isolate.run(() {
    final fn = _lib()
        .lookupFunction<
          Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>),
          Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>)
        >('HaloPinCheck');
    final p = pin.toNativeUtf8(),
        t = table.toNativeUtf8(),
        l = legacy.toNativeUtf8();
    try {
      return _json(_take(fn(p, t, l)));
    } finally {
      _wipeFree(p);
      calloc.free(t);
      calloc.free(l);
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
    String wrapPlain,
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
    final c = container.toNativeUtf8(), w = wrapPlain.toNativeUtf8();
    try {
      final s = _take(fn(p, t, l, index, kind, c, w));
      if (s == 'error: collision') throw PinCollision();
      return _json(s);
    } finally {
      _wipeFree(p);
      calloc.free(t);
      calloc.free(l);
      calloc.free(c);
      // the key's bytes go the way the pin's do
      _wipeFree(w);
    }
  });

  // two scrypt runs, so an isolate like the check
  @override
  Future<Map<String, dynamic>> rewrap(
    String oldPin,
    String newPin,
    String table,
    String legacy,
    int index,
  ) => Isolate.run(() {
    final fn = _lib()
        .lookupFunction<
          Pointer<Utf8> Function(
            Pointer<Utf8>,
            Pointer<Utf8>,
            Pointer<Utf8>,
            Pointer<Utf8>,
            Int32,
          ),
          Pointer<Utf8> Function(
            Pointer<Utf8>,
            Pointer<Utf8>,
            Pointer<Utf8>,
            Pointer<Utf8>,
            int,
          )
        >('HaloPinRewrap');
    final o = oldPin.toNativeUtf8(), n = newPin.toNativeUtf8();
    final t = table.toNativeUtf8(), l = legacy.toNativeUtf8();
    try {
      final s = _take(fn(o, n, t, l, index));
      if (s == 'error: collision') throw PinCollision();
      return _json(s);
    } finally {
      _wipeFree(o);
      _wipeFree(n);
      calloc.free(t);
      calloc.free(l);
    }
  });

  @override
  Future<String> upgrade(String table) => Isolate.run(() {
    final fn = _lib()
        .lookupFunction<
          Pointer<Utf8> Function(Pointer<Utf8>),
          Pointer<Utf8> Function(Pointer<Utf8>)
        >('HaloPinUpgrade');
    final t = table.toNativeUtf8();
    try {
      final s = _take(fn(t));
      if (s.startsWith('error:')) throw StateError(s);
      return s;
    } finally {
      calloc.free(t);
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

// set once the decoy session exists. until then a decoy match counts as a
// wrong pin, so it can never open the everyday app
bool decoyReady = false;

// a line the lock screen shows about the fingerprint: too many wrong fingers
// locked the sensor, or the phone would not keep a key for it and it is off
enum FingerNote { lockedOut, refused }

class LockState extends ChangeNotifier {
  LockState({
    LockStore? store,
    PinEngine? engine,
    LockClock? clock,
    LockBio? bio,
    this.revealAfter = const Duration(milliseconds: 450),
    this.sealWait = const Duration(seconds: 30),
    this.dropWait = const Duration(seconds: 5),
  }) : _store = store ?? SecureLockStore(),
       _engine = engine ?? FfiPinEngine(),
       _clock = clock ?? PlatformLockClock(),
       _bio = bio ?? PlatformLockBio();

  final LockStore _store;
  final PinEngine _engine;
  final LockClock _clock;
  final LockBio _bio;
  // the session an unlock opens is built here, under the lock screen, before
  // it lifts: the everyday one, or the decoy's. with vaultKey, that one with
  // its vault, opened with the key the pin unwrapped. it throws when the
  // vault will not open
  Future<void> Function(PinResult, {String? vaultKey})? onOutcome;
  // the containers are open and a decoy session could be built: a check
  // waits for it (the same wait whatever is typed), so a decoy pin typed
  // in the first second after a cold start is not taken for a wrong one
  Future<void>? sessionsReady;
  // a pick that will not be handed over: the copies the pickers left in the
  // cache go now rather than at the next start
  Future<void> Function()? picksDropped;
  // the fingerprint key is gone or was invalidated by a new finger: no
  // finger opens kryfo until the pin has been typed once
  bool _bioStale = false;
  bool get bioStale => _bioStale;
  // every outcome is shown this long after the tap at the earliest
  final Duration revealAfter;
  // the longest a new fingerprint key may take before the phone counts as
  // having refused it: a keystore that never answers leaves no switch busy
  final Duration sealWait;
  // the same for dropping the key, which waits behind any seal still running
  final Duration dropWait;

  FingerNote? _fingerNote;
  FingerNote? get fingerNote => _fingerNote;

  static const _kEnabled = 'halo.lock.enabled';
  static const _kTable = 'halo.lock.table';
  static const _kState = 'halo.lock.state';
  static const _kBio = 'halo.lock.biometric';
  // what a finger opens, sealed (BioKey.kt). the same key and the same form
  // whichever side it opens
  static const _kSeal = 'halo.lock.biometric.seal';
  static const _kWipeOn = 'halo.lock.panic_enabled';
  // whether the decoy has a wipe pin, or a decoy pin, of its own
  static const _kDWipe = 'halo.lock.d.wipe';
  static const _kDDecoy = 'halo.lock.d.decoy';
  // the decoy's old fingerprint switch, which opened nothing. only removed
  static const _kDBio = 'halo.lock.d.bio';
  // legacy sha256("salt:pin") keys, kept until migrated
  static const _kHash = 'halo.lock.pin_hash';
  static const _kSalt = 'halo.lock.pin_salt';
  static const _kPanicHash = 'halo.lock.panic_hash';
  static const _kPanicSalt = 'halo.lock.panic_salt';
  static const _kMisses = 'halo.lock.misses';
  static const _kUntil = 'halo.lock.until';

  bool _enabled = false;
  bool _loaded = false;
  bool get loaded => _loaded;

  // tests stand in a lock that was read and is open, without the pin engine
  @visibleForTesting
  void openForTest({bool enabled = false}) {
    _loaded = true;
    _locked = false;
    _enabled = enabled;
    _paused = false;
  }

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
  // the switch on App lock, as this session shows it. while a decoy pin is
  // set a finger opens only the decoy, so the everyday app has no switch.
  // the decoy has its own, unless it set a decoy pin of its own
  bool get biometric => _biometric && fingerOffered;
  bool get bioSupported => _bioSupported;
  bool get panicEnabled => _inDecoy ? _dWipe && !_dWipeHidden : _panicEnabled;
  bool get fingerOffered => _bioSupported && _fingerMine;
  bool get _fingerMine => _inDecoy ? !_dDecoy : !_decoyListed;
  // the lock screen offers a finger. which side it opens is in the seal,
  // known only once a finger opened it
  bool get fingerUnlock => _biometric;
  // what a finger may open now
  String get _fingerOpens =>
      decoySet ? HaloContainer.decoy.id : everydayContainer;

  // the app lists a decoy: a decoy pin is set. a decoy session is one too
  bool _decoyListed = false;
  bool get decoySet => _decoyListed || _inDecoy;

  // a decoy session is open: the App lock screen works on the decoy's own
  // entries. a pin that clashes with one it cannot see is taken and kept
  // nowhere, and turning the lock off only pauses it until the next start
  bool _inDecoy = false;
  bool get inDecoy => _inDecoy;
  set inDecoy(bool v) {
    _inDecoy = v;
    tellEngineDecoy(v);
    notifyListeners();
  }

  // a vault is open over the session, set by the session like inDecoy
  bool _inVault = false;
  bool get inVault => _inVault;
  set inVault(bool v) {
    _inVault = v;
    notifyListeners();
  }

  bool _paused = false;
  bool _dWipe = false;
  bool _dDecoy = false;
  // a turn off in the decoy shows its wipe pin gone, as a turn off does
  // anywhere. its entry stays until the next start, or goes when a pin is
  // set again
  bool _dWipeHidden = false;
  // what the App lock screen shows as on
  bool get lockOn => _enabled && !_paused;
  bool get decoyPinOn => _dDecoy;
  // a decoy session is open: nothing may notify
  bool get quiet => _counters.quiet;
  // the wipe pin is still the legacy kind: App lock asks for it again
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
      _decoyListed = (await _store.read(kListedContainers) ?? '')
          .split(',')
          .contains(HaloContainer.decoy.id);
      _table = await _store.read(_kTable);
      _legacy = {
        'as': await _store.read(_kSalt) ?? '',
        'ah': await _store.read(_kHash) ?? '',
        'ws': await _store.read(_kPanicSalt) ?? '',
        'wh': await _store.read(_kPanicHash) ?? '',
      };
      var c = LockCounters.parse(await _store.read(_kState));
      // legacy misses and hold move into the counters
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
    // the old decoy switch goes. fingerprint unlock from before seals
    // opened the everyday app: with a decoy listed it goes as a new decoy
    // pin would take it, without one it waits for the pin to seal it
    try {
      if (await _store.read(_kDBio) != null) await _store.delete(_kDBio);
      final sealed = await _store.read(_kSeal) != null;
      // a seal without the switch is one a turn off left halfway
      if (!_biometric && sealed) await _store.delete(_kSeal);
      if (_biometric && _decoyListed && !sealed) await _fingerOff();
    } catch (e) {
      dlog('lock: decoy finger left (${e.runtimeType})');
    }
    await _upgradeTable();
    _standIn ??= await _engine.newTable(14);
    await _refreshHoldForScreen();
    await _probeBio();
    // read and told in one step, after the probe: until then the app stays
    // under its cover, and the lock screen knows about the fingerprint
    _locked = _enabled;
    _loaded = true;
    notifyListeners();
    // the screen came while this ran, in a process the service started:
    // its ask waited for the load, and is made now
    if (_probeWanted) unawaited(_probeBioAgain());
  }

  // whether this phone can unlock with a finger. android answers only
  // with a screen attached, and a process the service or the job started
  // has none, so a no is asked again each time the app comes to the front
  Future<void> _probeBio() async {
    // the app waits under its cover for these, so none of them may hang
    const most = Duration(seconds: 3);
    try {
      final auth = LocalAuthentication();
      _bioSupported =
          await _bio.ready().timeout(most) &&
          await auth.canCheckBiometrics.timeout(most) &&
          (await auth.getAvailableBiometrics().timeout(most)).isNotEmpty;
    } catch (_) {
      _bioSupported = false;
    }
    if (_biometric) {
      try {
        _bioStale =
            await _bio.state().timeout(most) != 'ok' ||
            await _store.read(_kSeal) == null;
      } catch (e) {
        // a hint for the screen only: the unlock asks the keystore again
        dlog('lock: finger state unread (${e.runtimeType})');
      }
    }
  }

  bool _reprobing = false;
  bool _probeWanted = false;
  Future<void> _probeBioAgain() async {
    if (!_loaded) {
      _probeWanted = true;
      return;
    }
    if (_bioSupported) return;
    // one already running: asked again once it is done
    if (_reprobing) {
      _probeWanted = true;
      return;
    }
    _probeWanted = false;
    _reprobing = true;
    try {
      await _probeBio();
      // the screen can be in front a beat before android answers for it:
      // asked twice more while it stays in front
      for (final wait in const [Duration(seconds: 1), Duration(seconds: 2)]) {
        if (_bioSupported || !_inFront()) break;
        await Future<void>.delayed(wait);
        if (!_inFront()) break;
        await _probeBio();
      }
    } finally {
      _reprobing = false;
    }
    if (_bioSupported) {
      notifyListeners();
    } else if (_probeWanted && _inFront()) {
      unawaited(_probeBioAgain());
    }
  }

  bool _inFront() =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  // a table from before vaults gets its wraps and more entries, in one
  // write. until that write lands the old table opens the same pins, and a
  // failed one is tried again on the next start
  Future<void> _upgradeTable() async {
    final t = _table;
    if (t == null || _tableVersion(t) == 2) return;
    try {
      final up = await _engine.upgrade(t);
      await _store.write(_kTable, up);
      _table = up;
    } catch (e) {
      dlog('lock: table upgrade failed: $e');
    }
  }

  static int _tableVersion(String table) {
    try {
      return ((jsonDecode(table) as Map)['v'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
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
    // the decoy's vault opens with the decoy, and counts as the decoy does
    final decoysVault =
        kind == PinKind.vault && r['c'] == HaloContainer.decoyVault.id;
    final vault = kind == PinKind.vault && !decoysVault;
    final decoy = kind == PinKind.decoy || decoysVault;

    var result = PinResult.invalid;
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
    } else if (vault) {
      // the owner's other pin: it clears the budget as the app pin does
      result = PinResult.vault;
      next = const LockCounters();
    } else if (decoy && decoyReady) {
      result = PinResult.decoy;
      next = LockCounters(budget: base.budget, quiet: true);
    } else {
      next = base.miss(uptime, boot);
    }
    await _store.write(_kState, next.encode());
    _counters = next;
    final opensVault =
        result == PinResult.vault || (result == PinResult.decoy && decoysVault);
    result = await _open(result, opensVault ? r['u'] as String? ?? '' : null);
    final built = DateTime.now().difference(t0);

    final left = revealAfter - built;
    if (left > Duration.zero) await Future.delayed(left);
    // profile builds only, and only timings
    if (kProfileMode) {
      debugPrint(
        'lock: ready ${built.inMilliseconds} ms, shown '
        '${DateTime.now().difference(t0).inMilliseconds} ms',
      );
    }

    if (result == PinResult.normal ||
        result == PinResult.decoy ||
        result == PinResult.vault) {
      _locked = false;
    }

    if (result == PinResult.invalid || result == PinResult.throttled) {
      await _refreshHoldForScreen();
    }
    notifyListeners();
    // the pin was typed: a finger added before now may open again what a
    // finger opens. after the reveal, so it adds nothing to the wait
    if ((result == PinResult.normal ||
            result == PinResult.vault ||
            result == PinResult.decoy) &&
        _biometric &&
        _bioStale) {
      unawaited(_reseal());
    }
    // a legacy pin moves into the table after the screen has opened
    if (result == PinResult.normal &&
        kind != PinKind.everyday &&
        r['la'] == true) {
      unawaited(_migrateApp(pin));
    }
    return result;
  }

  // builds the session the pin opened, under the lock. a vault that will not
  // open gives its primary's session instead: the pin was right, and nothing
  // on screen may differ from any other unlock
  Future<PinResult> _open(PinResult result, String? vaultKey) async {
    if (result != PinResult.normal &&
        result != PinResult.decoy &&
        result != PinResult.vault) {
      return result;
    }
    if (vaultKey != null) {
      try {
        if (vaultKey.isEmpty) throw StateError('no key');
        await onOutcome?.call(result, vaultKey: vaultKey);
        return result;
      } catch (e) {
        // the type only: an open error may quote the key
        dlog('lock: vault not opened: ${e.runtimeType}');
        if (result == PinResult.vault) result = PinResult.normal;
      }
    }
    try {
      await onOutcome?.call(result);
    } catch (e) {
      dlog('lock: session not opened: $e');
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
        '',
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
  Future<bool> setupPin(String pin) async {
    if (!_inDecoy) return _setup(pin, PinSlot.app, PinKind.everyday);
    if (!await _setTry()) return false;
    // the wipe pin went with the turn off, as the sheet said: a pin set
    // again starts without it, so no pin wipes that shows as gone
    if (_dWipeHidden) await _dropDecoyWipe();
    await _setup(
      pin,
      PinSlot.decoy,
      PinKind.decoy,
      container: HaloContainer.decoy.id,
      tried: true,
    );
    // it locks again whether the pin went in or hit one it cannot see, so
    // the two look the same
    _paused = false;
    notifyListeners();
    return true;
  }

  // the decoy's pin opens the decoy container. its entry is written last
  // when a decoy is made, and cleared first when one is removed
  Future<bool> setupDecoyPin(String pin) async {
    // a new decoy takes fingerprint unlock with it, before anything says
    // a decoy is there. a changed decoy pin leaves the finger as it is
    if (!_inDecoy) await parkFingerForDecoy();
    final hadInner = _dDecoy;
    final bool ok;
    try {
      ok = await _setup(
        pin,
        _inDecoy ? PinSlot.decoyDecoy : PinSlot.decoy,
        PinKind.decoy,
        container: HaloContainer.decoy.id,
      );
    } catch (_) {
      if (!_inDecoy) await _unparkFinger();
      rethrow;
    }
    if (ok && _inDecoy) {
      await _store.write(_kDDecoy, 'true');
      _dDecoy = true;
      // as in any install: a decoy pin takes fingerprint unlock with it
      if (!hadInner) await _fingerOff();
      notifyListeners();
    }
    if (!_inDecoy) {
      if (ok) {
        _fingerParked = false;
        _decoyListed = true;
      } else {
        await _unparkFinger();
      }
      notifyListeners();
    }
    return ok;
  }

  // an everyday finger goes before a decoy is listed, so no stop halfway
  // leaves its seal beside a decoy. it comes back if the decoy is not made
  bool _fingerParked = false;
  Future<void> parkFingerForDecoy() async {
    if (_decoyListed || _inDecoy || !_biometric) return;
    _fingerParked = true;
    await _fingerOff();
  }

  // the decoy was not made after all: a finger parked for it comes back
  Future<void> decoyNotMade() => _unparkFinger();

  Future<void> _unparkFinger() async {
    if (!_fingerParked || _decoyListed) return;
    _fingerParked = false;
    try {
      await setBiometric(true);
    } catch (e) {
      dlog('lock: finger not back (${e.runtimeType})');
    }
  }

  // everything the decoy opens or set for itself, from the everyday side
  Future<void> clearDecoyPins() async {
    var t = _table;
    if (t != null) {
      for (final i in [
        PinSlot.decoy,
        PinSlot.decoyWipe,
        PinSlot.decoyDecoy,
        PinSlot.decoyVault,
      ]) {
        t = await _engine.clear(t!, i);
      }
      await _store.write(_kTable, t!);
      _table = t;
    }
    await _store.delete(_kDWipe);
    await _store.delete(_kDDecoy);
    await _store.delete(_kDBio);
    // a finger could only open the decoy: its seal and key go with it, and
    // the everyday switch comes back off
    if (_decoyListed) await _fingerOff();
    _dWipe = false;
    _dDecoy = false;
    _dWipeHidden = false;
    _decoyListed = false;
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

  // "Enter your PIN" before an Advanced protection flow. misses and the wipe
  // pin count as on the lock screen, and a legacy pin moves into the table
  // here too, for people who only unlock by fingerprint. inside a vault its
  // own pin is taken too, and a flow that changes the vault takes only that
  // one. anywhere else a vault pin is a miss. normal when taken
  Future<PinResult> confirmPin(String pin, {bool changesVault = false}) async {
    final uptime = await _clock.uptimeMs();
    final boot = await _clock.bootCount();
    final base = _counters.rebased(uptime, boot);
    _standIn ??= await _engine.newTable(14);
    final r = await _engine.check(pin, _table ?? _standIn!, _legacyJson);
    final kind = (r['k'] as num?)?.toInt() ?? 0;
    if (kind == PinKind.wipe || r['lw'] == true) return PinResult.panic;
    if (base.holdLeft(uptime, boot) > 0) return PinResult.throttled;
    final primary = _inDecoy
        ? kind == PinKind.decoy
        : kind == PinKind.everyday || r['la'] == true;
    final ownVault =
        kind == PinKind.vault &&
        r['c'] == _vaultContainer &&
        (r['u'] as String? ?? '').isNotEmpty;
    final ok = _inVault ? ownVault || (primary && !changesVault) : primary;
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

  // the vault of the session's own identity: the everyday one's, or inside
  // the decoy the decoy's
  int get _vaultSlot => _inDecoy ? PinSlot.decoyVault : PinSlot.vault;
  String get _vaultContainer =>
      (_inDecoy ? HaloContainer.decoyVault : HaloContainer.vault).id;

  // a vault named outright: a restore keeps to the one of the session it
  // began in, whichever session is open by the time it lands
  static int _slotOf(HaloContainer vault) => switch (vault) {
    HaloContainer.vault => PinSlot.vault,
    HaloContainer.decoyVault => PinSlot.decoyVault,
    _ => throw ArgumentError('${vault.id} is not a vault'),
  };

  // the vault's pin, its database key sealed into the entry. written last
  // when a vault is made. false when the pin is in use. [of] names the
  // vault, else it is the session's own
  Future<bool> setupVaultPin(
    String pin,
    String keyHex, {
    HaloContainer? of,
  }) async {
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(keyHex)) {
      throw ArgumentError('a vault key is 64 hex characters');
    }
    // with no app lock no pin is ever asked for, and the vault never opens
    if (!_enabled) throw StateError('no app lock');
    return _setup(
      pin,
      of == null ? _vaultSlot : _slotOf(of),
      PinKind.vault,
      container: of?.id ?? _vaultContainer,
      wrapPlain: keyHex,
    );
  }

  // a new pin for the same vault. the engine opens the key and seals it
  // again, so it never reaches here. the old pin is one confirmPin already
  // took, so a wrong one throws. the new one is a try as any set is. false
  // when it is in use or the pad is held
  Future<bool> rewrapVaultPin(String oldPin, String newPin) async {
    final t = _table;
    if (t == null) throw StateError('no table');
    if (!await _setTry()) return false;
    try {
      final out = await _engine.rewrap(
        oldPin,
        newPin,
        t,
        _legacyJson,
        _vaultSlot,
      );
      final nt = jsonEncode(out['t']);
      await _store.write(_kTable, nt);
      _table = nt;
    } on PinCollision {
      if (_inDecoy) await _store.write(_kTable, t);
      return _clash();
    }
    notifyListeners();
    return true;
  }

  // the vault's entry goes back to random bytes: the first step when a
  // vault is replaced or removed, so no pin opens a half-gone one. [of]
  // names the vault, else it is the session's own
  Future<void> clearVault({HaloContainer? of}) async {
    final slot = of == null ? _vaultSlot : _slotOf(of);
    final t = _table;
    if (t == null) return;
    final out = await _engine.clear(t, slot);
    await _store.write(_kTable, out);
    _table = out;
  }

  Future<bool> setupPanicPin(String pin) async {
    if (_inDecoy) {
      final ok = await _setup(pin, PinSlot.decoyWipe, PinKind.wipe);
      if (ok) {
        await _store.write(_kDWipe, 'true');
        _dWipe = true;
        _dWipeHidden = false;
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
    String wrapPlain = '',
    // its try is counted already
    bool tried = false,
  }) async {
    // with no table yet there is no other pin it could find
    if (!tried && (_inDecoy || _table != null) && !await _setTry()) {
      return false;
    }
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
        wrapPlain,
      );
      final t = jsonEncode(out['t']);
      await _store.write(_kTable, t);
      _table = t;
    } on PinCollision {
      // the same write a set makes, so a clash takes as long
      if (_inDecoy) await _store.write(_kTable, table);
      return _clash();
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

  // any pin set may land on one the session cannot see, the hidden chats'
  // or the decoy's own, so each set is a try at the lock: counted whether
  // it clashes or not, and refused while the pad is held, before the engine
  // is asked. false when held
  Future<bool> _setTry() async {
    final uptime = await _clock.uptimeMs();
    final boot = await _clock.bootCount();
    final base = _counters.rebased(uptime, boot);
    final held = base.holdLeft(uptime, boot) > 0;
    _counters = held ? base : base.miss(uptime, boot);
    await _store.write(_kState, _counters.encode());
    await _refreshHoldForScreen();
    if (held) notifyListeners();
    return !held;
  }

  // a pin already in use. the screen says "pick a different pin", never
  // which one. inside the decoy it is taken and kept nowhere, so the decoy
  // never learns a pin it cannot see. its try was counted before
  Future<bool> _clash() async => _inDecoy;

  Future<void> _dropDecoyWipe() async {
    final t = _table;
    if (t != null) {
      final out = await _engine.clear(t, PinSlot.decoyWipe);
      await _store.write(_kTable, out);
      _table = out;
    }
    await _store.delete(_kDWipe);
    _dWipe = false;
    _dWipeHidden = false;
  }

  Future<void> disablePanicPin() async {
    if (_inDecoy) {
      await _dropDecoyWipe();
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
      _dWipeHidden = true;
      // its fingerprint goes with its lock, as in any install, the switch
      // included. nothing else is written
      if (_biometric || await _store.read(_kBio) != null) {
        await _fingerOff(forget: true);
      }
      notifyListeners();
      return;
    }
    await _fingerOff();
    for (final k in [
      _kEnabled,
      _kTable,
      _kState,
      _kBio,
      _kSeal,
      _kWipeOn,
      _kDWipe,
      _kDDecoy,
      _kDBio,
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
    _dWipe = false;
    _dDecoy = false;
    notifyListeners();
  }

  // the same steps on either side, the decoy's switch included: only what
  // is sealed differs, and the seal does not show it
  Future<bool> setBiometric(bool v) async {
    // the everyday app has no switch while a decoy pin is set
    if (!_fingerMine) return false;
    if (v) {
      final gen = ++_sealGen;
      final s = await _sealOrNull(_fingerOpens);
      // a newer turn on or off came in meanwhile: it has the last word
      if (gen != _sealGen) return false;
      // the phone would not make a key: the screen says so
      if (s == null) return false;
      await _store.write(_kSeal, s);
      await _store.write(_kBio, 'true');
      _biometric = true;
      _bioStale = false;
      _fingerNote = null;
    } else {
      await _fingerOff();
    }
    notifyListeners();
    return true;
  }

  // the switch, then the seal, then the key: a stop anywhere leaves no
  // switch on whose seal the next pin would make again. [forget] deletes
  // the switch, as turning the lock off does
  Future<void> _fingerOff({bool forget = false}) async {
    _sealGen++;
    _biometric = false;
    _bioStale = false;
    forget ? await _store.delete(_kBio) : await _store.write(_kBio, 'false');
    await _store.delete(_kSeal);
    try {
      // a keystore that never answers leaves the switch off all the same
      await _bio.disable().timeout(dropWait);
    } catch (e) {
      dlog('lock: finger key not dropped (${e.runtimeType})');
    }
  }

  // each turn on, off or new seal moves this: a seal that comes back after
  // a newer one was asked for is never written
  int _sealGen = 0;

  // a seal, or null for a phone that refused or never answered
  Future<String?> _sealOrNull(String opens) async {
    try {
      return await _bio.seal(opens).timeout(sealWait, onTimeout: () => null);
    } catch (e) {
      dlog('lock: finger not sealed (${e.runtimeType})');
      return null;
    }
  }

  // a new key and seal once the pin was typed after a finger was added. a
  // phone that still has a finger but will not make a key turns the finger
  // off and says so, rather than asking for the pin at every start
  Future<void> _reseal() async {
    final gen = ++_sealGen;
    final target = _fingerOpens;
    bool moved() => gen != _sealGen || target != _fingerOpens || !_biometric;
    var s = await _sealOrNull(target);
    if (s == null && !moved()) {
      // once more, for a keystore busy right after the unlock
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!moved()) s = await _sealOrNull(target);
    }
    if (moved()) return;
    if (s == null) {
      // no finger on the phone now: it sleeps until one is back
      if (!await _fingerThere() || moved()) return;
      await _refused();
      return;
    }
    try {
      await _store.write(_kSeal, s);
      _bioStale = false;
      notifyListeners();
    } catch (e) {
      dlog('lock: finger not sealed (${e.runtimeType})');
    }
  }

  // whether the phone has a finger to unlock with right now
  Future<bool> _fingerThere() async {
    const most = Duration(seconds: 3);
    try {
      final auth = LocalAuthentication();
      return await auth.canCheckBiometrics.timeout(most) &&
          (await auth.getAvailableBiometrics().timeout(most)).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // the phone will not use a finger for Kryfo: off, with a line that says so
  Future<void> _refused() async {
    dlog('lock: finger refused by the phone');
    _fingerNote = FingerNote.refused;
    try {
      await _fingerOff();
    } catch (e) {
      dlog('lock: finger not turned off (${e.runtimeType})');
    }
    notifyListeners();
  }

  // a finger opens what its seal holds: the everyday app, or while a decoy
  // pin is set only the decoy. never a vault. wrong fingers are the
  // sensor's to count, and none of them counts here
  Future<bool> tryBiometric() async {
    // the pin opened it already: a finger asked for now would open a session
    // over the one on screen
    if (!locked) return false;
    if (throttleLeft > Duration.zero) return false;
    if (!_enabled || !_biometric || !_bioSupported || _bioStale) return false;
    final seal = await _store.read(_kSeal);
    if (seal == null) {
      _bioStale = true;
      notifyListeners();
      return false;
    }
    if (_fingerNote == FingerNote.lockedOut) {
      _fingerNote = null;
      notifyListeners();
    }
    final r = await _bio.unlock(
      l10n.lockStateUnlockKryfo,
      l10n.commonCancel,
      seal,
    );
    if (r.result == 'invalidated' || r.result == 'none') {
      // a finger was added since, or the key is gone: the pin first
      _bioStale = true;
      notifyListeners();
      return false;
    }
    if (r.result == 'refused') {
      // the finger was taken and the seal still did not open: the same
      // would happen after the pin, so no loop of pin and finger
      await _refused();
      return false;
    }
    if (r.result == 'lockout') {
      // the sensor is locked for a while, or until the phone's own screen
      // lock is used: the pin is the way in, and the screen says why the
      // finger does nothing
      _fingerNote = FingerNote.lockedOut;
      notifyListeners();
      return false;
    }
    if (r.result != 'ok') return false;
    // from the finger on every outcome takes the same time, whichever side
    // opens and however long building it takes
    final t0 = DateTime.now();
    final opened = await _openByFinger(r.opens);
    final left = revealAfter - DateTime.now().difference(t0);
    if (left > Duration.zero) await Future.delayed(left);
    if (!opened) return false;
    _locked = false;
    notifyListeners();
    return true;
  }

  Future<bool> _openByFinger(String? opens) async {
    final ready = sessionsReady;
    if (ready != null) {
      await ready.timeout(const Duration(seconds: 8), onTimeout: () {});
    }
    final decoy = opens == HaloContainer.decoy.id;
    if (opens != _fingerOpens) {
      // a seal for a side a finger may not open now opens nothing, ever
      dlog('lock: finger seal dropped');
      await _fingerOff();
      notifyListeners();
      return false;
    }
    if (decoy && !decoyReady) return false;
    // the decoy clears the run but not the budget, as its pin does. quiet
    // is written before its session is built, and taken back if it is not
    final was = _counters;
    _counters = decoy
        ? LockCounters(budget: was.budget, quiet: true)
        : const LockCounters();
    await _store.write(_kState, _counters.encode());
    try {
      await onOutcome?.call(decoy ? PinResult.decoy : PinResult.normal);
    } catch (e) {
      dlog('lock: session not opened: $e');
    }
    // a decoy that did not open keeps the lock: under it may be the
    // everyday app
    if (decoy && !_inDecoy) {
      _counters = was;
      await _store.write(_kState, was.encode());
      return false;
    }
    return true;
  }

  // set while the app itself sent the user out to a picker, the camera or a
  // share sheet: that pause is ours and does not lock. cleared a beat after
  // the call returns, when android says the person left (see left), or by a
  // deadline in case it never does.
  DateTime? _holdUntil;
  int _holdGen = 0;
  // how many holds a real leave has ended
  int _holdsEnded = 0;
  bool get holding =>
      _holdUntil != null && DateTime.now().isBefore(_holdUntil!);

  Future<T> hold<T>(Future<T> Function() body) async {
    // work that ends in a system dialog while the lock is up (an export, a
    // file opened with its password) waits for it: the dialog never opens
    // over the pin pad
    await lockGuard.unlocked();
    _holdUntil = DateTime.now().add(const Duration(minutes: 5));
    final gen = ++_holdGen;
    final ended = _holdsEnded;
    final decoy = _inDecoy;
    final vault = _inVault;
    try {
      final r = await body();
      // left from inside the picker, or another session opened meanwhile
      // (a hold past its deadline locks without counting as left): what it
      // gave back waits for the pin, whichever pin it is, and never reaches
      // another session
      if (_holdsEnded != ended || _inDecoy != decoy || _inVault != vault) {
        await lockGuard.anyUnlock();
        if (_inDecoy != decoy || _inVault != vault) {
          try {
            await picksDropped?.call();
          } catch (e) {
            dlog('lock: picker copies not swept (${e.runtimeType})');
          }
          throw const LockDropped();
        }
      }
      return r;
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

  // android says the person went home or to recents, the screen went off,
  // or the app was opened from outside while a picker covered it. leaving
  // from inside a picker locks too: the hold ends here, also in the beat
  // after the picker returned. with no hold open the lifecycle already locks
  void left() {
    if (!_enabled || !holding) return;
    _holdUntil = null;
    _holdsEnded++;
    lock();
  }

  // the App lock page asks again as it opens: a phone that said no before
  // it had a screen shows the switch without leaving the app first
  Future<void> recheckFinger() => _probeBioAgain();

  // called on resume. the picker coming back keeps its hold. a hold that
  // ran out while the app was away (a picker left open past its deadline)
  // locks here; a hold that left ended has locked already.
  void returned() {
    unawaited(_probeBioAgain());
    if (!_leftWhileHeld) return;
    _leftWhileHeld = false;
    lock();
  }

  void lock() {
    if (!_enabled || holding || _paused) return;
    if (!_locked) {
      _locked = true;
      // each lock tries the finger afresh
      if (_fingerNote == FingerNote.lockedOut) _fingerNote = null;
      notifyListeners();
    }
  }
}

final lockState = LockState();

/// why a new pin was not taken: a held pad, or anywhere but the decoy one
/// in use
String pinNotTakenLine(LockState lock) => lock.throttleLeft > Duration.zero
    ? tooManyTriesLine(lock.throttleLeft)
    : l10n.pinPickDifferent;

/// how long the pad is held, as a person reads it: seconds up to a minute
/// and a half, then minutes and seconds, then hours, minutes and seconds,
/// in the language's own digits
String tooManyTriesLine(Duration left) {
  final s = left.inSeconds + 1;
  if (s <= 90) return l10n.lockTooManyTriesS(whole(s));
  final h = s ~/ 3600;
  final m = s % 3600 ~/ 60;
  final sec = twoDigits(s % 60);
  return l10n.lockTooManyTriesFor(
    h > 0 ? '${whole(h)}:${twoDigits(m)}:$sec' : '${whole(m)}:$sec',
  );
}
