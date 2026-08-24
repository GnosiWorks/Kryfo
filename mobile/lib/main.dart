// SPDX-License-Identifier: GPL-3.0-or-later
// kryfo mobile - phase 1: identity persistence + ECDH + editorial UI

import 'dart:async';
import 'widgets/tor_boot_splash.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Curve;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'notifications.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'theme.dart';
import 'wipe.dart';
import 'media_progress.dart';
import 'screens/home_screen.dart';
import 'screens/new_group_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'screens/group_chat_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/pair_code_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/modes_screen.dart';
import 'screens/push_settings_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/my_kryfo_screen.dart';
import 'screens/onboarding_screen.dart';
import 'lock_state.dart';
import 'screens/lock_screen.dart';
import 'screens/lock_setup_screen.dart';
import 'push_mode.dart';
import 'supporter.dart';
import 'ntfy_listener.dart';
import 'message_envelope.dart';
import 'widgets/motion.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:app_links/app_links.dart';
import 'signal_session.dart';
import 'dart:isolate';

typedef VoidFn = Void Function();
typedef IntArgFn = Void Function(Int32);
typedef IntArgFnDart = void Function(int);
typedef VoidFnDart = void Function();
typedef CStrFn = Pointer<Utf8> Function();
typedef CStrFnDart = Pointer<Utf8> Function();
typedef OneArgFn = Pointer<Utf8> Function(Pointer<Utf8>);
typedef OneArgFnDart = Pointer<Utf8> Function(Pointer<Utf8>);
typedef TwoArgFn = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef TwoArgFnDart = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef ThreeArgFn =
    Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef ThreeArgFnDart =
    Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef CounterFn = Pointer<Utf8> Function(Int32);
typedef CounterFnDart = Pointer<Utf8> Function(int);

class HaloEngine {
  late final DynamicLibrary _lib;
  late final CStrFnDart _version;
  late final CStrFnDart _genIdentity;
  late final TwoArgFnDart _restoreIdentity;
  late final CStrFnDart _myId;
  late final CStrFnDart _myEdPub;
  late final CStrFnDart _myXPub;
  late final CStrFnDart _myEdPriv;
  late final CStrFnDart _myXPriv;
  late final TwoArgFnDart _encryptFor;
  late final TwoArgFnDart _decryptFrom;
  late final Pointer<Utf8> Function(Pointer<Utf8>) _start;
  late final CStrFnDart _drainInbox;
  late final VoidFnDart _shutdown;
  late final IntArgFnDart _setDebug;
  late final CStrFnDart _getStatus;
  late final TwoArgFnDart _send;
  late final OneArgFnDart _nostrInit;
  late final TwoArgFnDart _nostrSend;
  late final OneArgFnDart _nostrSubscribe;
  late final CStrFnDart _nostrPoll;
  late final CounterFnDart _fcPk;
  late final CStrFnDart _txState;
  late final TwoArgFnDart _setBridges;
  late final CStrFnDart _bridgeState;
  late final CStrFnDart _restartTor;
  late final CStrFnDart _moatFetch;
  late final OneArgFnDart _setMode;
  late final OneArgFnDart _handleCheck;
  late final ThreeArgFnDart _handleClaim;
  late final OneArgFnDart _handleRelease;
  late final TwoArgFnDart _moatSolve;
  late final OneArgFnDart _ntfyPing;
  late final OneArgFnDart _torGet;
  late final OneArgFnDart _torGetJson;
  late final TwoArgFnDart _torPost;
  late final OneArgFnDart _torGetB64;
  late final OneArgFnDart _idFromEdPub;
  late final TwoArgFnDart _encryptBackup;
  late final TwoArgFnDart _decryptBackup;

  HaloEngine() {
    _lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    _version = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloVersion');
    _genIdentity = _lib.lookupFunction<CStrFn, CStrFnDart>(
      'HaloGenerateIdentity',
    );
    _restoreIdentity = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>(
      'HaloRestoreIdentity',
    );
    _myId = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloMyId');
    _myEdPub = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloMyEdPubkey');
    _myXPub = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloMyXPubkey');
    _myEdPriv = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloMyEdPrivkey');
    _myXPriv = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloMyXPrivkey');
    _encryptFor = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloEncryptFor');
    _decryptFrom = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>(
      'HaloDecryptFrom',
    );
    _start = _lib
        .lookupFunction<
          Pointer<Utf8> Function(Pointer<Utf8>),
          Pointer<Utf8> Function(Pointer<Utf8>)
        >('HaloStartListener');
    _drainInbox = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloDrainInbox');
    _shutdown = _lib.lookupFunction<VoidFn, VoidFnDart>('HaloShutdown');
    _getStatus = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloGetStatus');
    _send = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloSendTo');
    _nostrInit = _lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloNostrInit');
    _nostrSend = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloNostrSend');
    _nostrSubscribe = _lib.lookupFunction<OneArgFn, OneArgFnDart>(
      'HaloNostrSubscribe',
    );
    _nostrPoll = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloNostrPoll');
    _fcPk = _lib.lookupFunction<CounterFn, CounterFnDart>('HaloFirstContactPk');
    _txState = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloTransportState');
    _setBridges = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloSetBridges');
    _bridgeState = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloBridgeState');
    _restartTor = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloRestartTor');
    _moatFetch = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloMoatFetch');
    _setMode = _lib.lookupFunction<OneArgFn, OneArgFnDart>(
      'HaloSetTransportMode',
    );
    _handleCheck = _lib.lookupFunction<OneArgFn, OneArgFnDart>(
      'HaloHandleCheck',
    );
    _handleClaim = _lib.lookupFunction<ThreeArgFn, ThreeArgFnDart>(
      'HaloHandleClaim',
    );
    _handleRelease = _lib.lookupFunction<OneArgFn, OneArgFnDart>(
      'HaloHandleRelease',
    );
    _moatSolve = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloMoatSolve');
    _ntfyPing = _lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloNtfyPing');
    _torGet = _lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloTorGet');
    _torGetJson = _lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloTorGetJSON');
    _torPost = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloTorPost');
    _torGetB64 = _lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloTorGetB64');
    _idFromEdPub = _lib.lookupFunction<OneArgFn, OneArgFnDart>(
      'HaloIdFromEdPub',
    );
    _encryptBackup = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>(
      'HaloEncryptBackup',
    );
    _decryptBackup = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>(
      'HaloDecryptBackup',
    );
    _setDebug = _lib.lookupFunction<IntArgFn, IntArgFnDart>('HaloSetDebug');
    // engine logs to logcat only in debug. release builds stay silent so no
    // onion address, peer id, or tor timing ever lands in the log.
    _setDebug(kDebugMode ? 1 : 0);
  }

  String version() => _version().toDartString();
  String generateIdentity() => _genIdentity().toDartString();
  String myId() => _myId().toDartString();
  String myEdPubkey() => _myEdPub().toDartString();
  String myXPubkey() => _myXPub().toDartString();
  String myEdPrivkey() => _myEdPriv().toDartString();
  String myXPrivkey() => _myXPriv().toDartString();
  String startListener(String dataDir) {
    final ptr = dataDir.toNativeUtf8();
    try {
      return _start(ptr).toDartString();
    } finally {
      malloc.free(ptr);
    }
  }

  void shutdown() => _shutdown();

  List<String> drainInbox() {
    final raw = _drainInbox().toDartString();
    if (raw.isEmpty) return const [];
    return raw.split('\n');
  }

  String getStatus() => _getStatus().toDartString();

  String nostrInit(String relaysCSV) {
    final ptr = relaysCSV.toNativeUtf8();
    try {
      return _nostrInit(ptr).toDartString();
    } finally {
      malloc.free(ptr);
    }
  }

  String ntfyPing(String endpoint) {
    final ptr = endpoint.toNativeUtf8();
    try {
      return _ntfyPing(ptr).toDartString();
    } finally {
      calloc.free(ptr);
    }
  }

  String idFromEdPub(String hexPub) {
    final ptr = hexPub.toNativeUtf8();
    try {
      return _idFromEdPub(ptr).toDartString();
    } finally {
      calloc.free(ptr);
    }
  }

  String encryptBackup(String plain, String passphrase) {
    final p1 = plain.toNativeUtf8();
    final p2 = passphrase.toNativeUtf8();
    try {
      return _encryptBackup(p1, p2).toDartString();
    } finally {
      calloc.free(p1);
      calloc.free(p2);
    }
  }

  String decryptBackup(String blob, String passphrase) {
    final p1 = blob.toNativeUtf8();
    final p2 = passphrase.toNativeUtf8();
    try {
      return _decryptBackup(p1, p2).toDartString();
    } finally {
      calloc.free(p1);
      calloc.free(p2);
    }
  }

  // offloaded to a background isolate so a slow relay never freezes the ui.
  Future<String> nostrSend(String peerXPubHex, String b64Cipher) =>
      _sendOnIsolate((nostr: true, a: peerXPubHex, b: b64Cipher)).timeout(
        const Duration(seconds: 60),
        onTimeout: () => 'error: relay timeout',
      );

  void nostrSubscribeBg(String peerXPubHex) {
    _subscribeOnIsolate(peerXPubHex).ignore();
  }

  // the address a stranger can reach us at. cheap and synchronous - it is a
  // key derivation, no network.
  // bridge lines in, a summary out. tor only reads its config at startup, so
  // callers restart it after changing this or nothing happens.
  String setBridges(String lines, bool on) {
    final a = lines.toNativeUtf8();
    final b = (on ? '1' : '0').toNativeUtf8();
    try {
      return _setBridges(a, b).toDartString();
    } finally {
      malloc.free(a);
      malloc.free(b);
    }
  }

  // "on|count|port"
  String bridgeState() => _bridgeState().toDartString();

  void restartTor() => _restartTor();

  String handleCheck(String h) {
    final p = h.toNativeUtf8();
    try {
      return _handleCheck(p).toDartString();
    } finally {
      malloc.free(p);
    }
  }

  String handleClaim(String h, String invite, String bio) {
    final a = h.toNativeUtf8();
    final b = invite.toNativeUtf8();
    final c = bio.toNativeUtf8();
    try {
      return _handleClaim(a, b, c).toDartString();
    } finally {
      malloc.free(a);
      malloc.free(b);
      malloc.free(c);
    }
  }

  String handleRelease(String h) {
    final p = h.toNativeUtf8();
    try {
      return _handleRelease(p).toDartString();
    } finally {
      malloc.free(p);
    }
  }

  // tell the engine whether to route through tor. it decides the route; the
  // relay list for each mode is chosen below.
  String setTransportMode(String mode) {
    final p = mode.toNativeUtf8();
    try {
      return _setMode(p).toDartString();
    } finally {
      malloc.free(p);
    }
  }

  // both moat calls block on a network round trip, so they run off the ui
  // isolate. the request is plain https on purpose - tor being unreachable is
  // why someone is asking for bridges at all.
  Future<String> moatFetch() => _moatOnIsolate(null, null).timeout(
    const Duration(seconds: 60),
    onTimeout: () => 'error: timed out reaching the bridge service',
  );

  Future<String> moatSolve(String challenge, String answer) =>
      _moatOnIsolate(challenge, answer).timeout(
        const Duration(seconds: 60),
        onTimeout: () => 'error: timed out sending the answer',
      );

  // everything the transport knows, in one read. no
  // inference on this side.
  Map<String, dynamic> transportState() {
    try {
      return jsonDecode(_txState().toDartString()) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }

  String firstContactPk(int counter) => _fcPk(counter).toDartString();

  // put an invite where a six digit code points, and look for one there.
  Future<String> pairCodePublish(String code, String payload) =>
      _pairCodeOnIsolate(code, payload).timeout(
        const Duration(seconds: 50),
        onTimeout: () => 'error: could not reach a relay',
      );

  Future<String> pairCodeFetch(String code) => _pairCodeOnIsolate(
    code,
    null,
  ).timeout(const Duration(seconds: 40), onTimeout: () => 'empty');

  // watch it. unlike every other subscription this needs no contacts, which
  // is the whole point.
  void subscribeFirstContactBg(int counter) {
    _fcSubscribeOnIsolate(counter).ignore();
  }

  // introduce ourselves to someone who has never heard of us.
  Future<String> sendFirstContact(
    String peerXPubHex,
    String fcPk,
    String b64Cipher,
  ) => _fcSendOnIsolate(peerXPubHex, fcPk, b64Cipher).timeout(
    const Duration(seconds: 60),
    onTimeout: () => 'error: relay timeout',
  );

  String nostrSubscribe(String peerXPubHex) {
    final ptr = peerXPubHex.toNativeUtf8();
    try {
      return _nostrSubscribe(ptr).toDartString();
    } finally {
      malloc.free(ptr);
    }
  }

  // fetch a url's html over tor (for sender-side link previews). slow + can
  // fail - caller treats anything starting 'error:' as no-preview.
  // POST json over tor (badge invoices). keeps 2xx bodies, unlike torGet.
  String torPost(String url, String body) {
    final u = url.toNativeUtf8();
    final b = body.toNativeUtf8();
    try {
      return _torPost(u, b).toDartString();
    } finally {
      calloc.free(u);
      calloc.free(b);
    }
  }

  // GET over tor that accepts any 2xx - the badge service replies 202 while
  // a donation is still unconfirmed.
  String torGetJson(String url) {
    final ptr = url.toNativeUtf8();
    try {
      return _torGetJson(ptr).toDartString();
    } finally {
      calloc.free(ptr);
    }
  }

  String torGet(String url) {
    final ptr = url.toNativeUtf8();
    try {
      return _torGet(ptr).toDartString();
    } finally {
      malloc.free(ptr);
    }
  }

  // fetch binary (preview image) over tor, returns 'ok:<base64>' or 'error:..'.
  String torGetB64(String url) {
    final ptr = url.toNativeUtf8();
    try {
      return _torGetB64(ptr).toDartString();
    } finally {
      malloc.free(ptr);
    }
  }

  List<({String peer, String cipher})> nostrPoll() {
    final raw = _nostrPoll().toDartString();
    if (raw.isEmpty) return const [];
    return raw.split('\n').map((line) {
      final idx = line.indexOf('|');
      if (idx < 0) return (peer: '', cipher: line);
      return (peer: line.substring(0, idx), cipher: line.substring(idx + 1));
    }).toList();
  }

  String restoreIdentity(String edPriv, String xPriv) {
    final c1 = edPriv.toNativeUtf8();
    final c2 = xPriv.toNativeUtf8();
    try {
      return _restoreIdentity(c1, c2).toDartString();
    } finally {
      calloc.free(c1);
      calloc.free(c2);
    }
  }

  String encryptFor(String peerPub, String plain) {
    final cPub = peerPub.toNativeUtf8();
    final cPlain = plain.toNativeUtf8();
    try {
      return _encryptFor(cPub, cPlain).toDartString();
    } finally {
      calloc.free(cPub);
      calloc.free(cPlain);
    }
  }

  String decryptFrom(String peerPub, String b64) {
    final cPub = peerPub.toNativeUtf8();
    final cB64 = b64.toNativeUtf8();
    try {
      return _decryptFrom(cPub, cB64).toDartString();
    } finally {
      calloc.free(cPub);
      calloc.free(cB64);
    }
  }

  // offloaded to a background isolate so a slow tor dial never freezes the ui.
  Future<String> sendTo(String addr, String msg) =>
      _sendOnIsolate((nostr: false, a: addr, b: msg)).timeout(
        const Duration(seconds: 15),
        onTimeout: () => 'error: onion timeout',
      );
}

Future<String> _fcSendOnIsolate(String peerXPub, String fcPk, String msg) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final fn = lib.lookupFunction<ThreeArgFn, ThreeArgFnDart>(
      'HaloNostrSendFirstContact',
    );
    final a = peerXPub.toNativeUtf8();
    final b = fcPk.toNativeUtf8();
    final c = msg.toNativeUtf8();
    try {
      return fn(a, b, c).toDartString();
    } finally {
      malloc.free(a);
      malloc.free(b);
      malloc.free(c);
    }
  });
}

Future<String> _moatOnIsolate(String? challenge, String? answer) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    if (challenge == null) {
      final fn = lib.lookupFunction<CStrFn, CStrFnDart>('HaloMoatFetch');
      return fn().toDartString();
    }
    final fn = lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloMoatSolve');
    final a = challenge.toNativeUtf8();
    final b = (answer ?? '').toNativeUtf8();
    try {
      return fn(a, b).toDartString();
    } finally {
      malloc.free(a);
      malloc.free(b);
    }
  });
}

// publishing and fetching both wait on a relay, so they go off the ui thread.
Future<String> _pairCodeOnIsolate(String code, String? payload) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final c = code.toNativeUtf8();
    try {
      if (payload == null) {
        final fn = lib.lookupFunction<OneArgFn, OneArgFnDart>(
          'HaloPairCodeFetch',
        );
        return fn(c).toDartString();
      }
      final fn = lib.lookupFunction<TwoArgFn, TwoArgFnDart>(
        'HaloPairCodePublish',
      );
      final pl = payload.toNativeUtf8();
      try {
        return fn(c, pl).toDartString();
      } finally {
        malloc.free(pl);
      }
    } finally {
      malloc.free(c);
    }
  });
}

Future<String> _fcSubscribeOnIsolate(int counter) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final fn = lib.lookupFunction<CounterFn, CounterFnDart>(
      'HaloNostrSubscribeFirstContact',
    );
    return fn(counter).toDartString();
  });
}

// run a blocking native send on a throwaway background isolate so the ui
// thread never stalls on a tor dial. opens its own handle to libhalo -
// same process image, so it shares the running tor - and frees its strings.
Future<String> _nostrInitOnIsolate(String relaysCSV) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final fn = lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloNostrInit');
    final p = relaysCSV.toNativeUtf8();
    try {
      return fn(p).toDartString();
    } finally {
      malloc.free(p);
    }
  });
}

Future<String> _startListenerOnIsolate(String dataDir) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final fn = lib
        .lookupFunction<
          Pointer<Utf8> Function(Pointer<Utf8>),
          Pointer<Utf8> Function(Pointer<Utf8>)
        >('HaloStartListener');
    final p = dataDir.toNativeUtf8();
    try {
      return fn(p).toDartString();
    } finally {
      malloc.free(p);
    }
  });
}

Future<String> _sendOnIsolate(({bool nostr, String a, String b}) args) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final fn = lib.lookupFunction<TwoArgFn, TwoArgFnDart>(
      args.nostr ? 'HaloNostrSend' : 'HaloSendTo',
    );
    final p1 = args.a.toNativeUtf8();
    final p2 = args.b.toNativeUtf8();
    try {
      return fn(p1, p2).toDartString();
    } finally {
      malloc.free(p1);
      malloc.free(p2);
    }
  });
}

Future<String> _subscribeOnIsolate(String xPub) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final fn = lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloNostrSubscribe');
    final p = xPub.toNativeUtf8();
    try {
      return fn(p).toDartString();
    } finally {
      malloc.free(p);
    }
  });
}

// tor fetches run on a background isolate. the raw ffi call blocks for the whole
// tor round-trip (5-8s), so doing it on the main isolate froze the ui while a
// link preview resolved. re-open the lib inside the isolate, same as sends.
Future<String> torGetOnIsolate(String url) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final fn = lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloTorGet');
    final p = url.toNativeUtf8();
    try {
      return fn(p).toDartString();
    } finally {
      malloc.free(p);
    }
  });
}

Future<String> torGetB64OnIsolate(String url) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final fn = lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloTorGetB64');
    final p = url.toNativeUtf8();
    try {
      return fn(p).toDartString();
    } finally {
      malloc.free(p);
    }
  });
}

class HaloDb {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _passphraseKey = 'halo.db.passphrase';

  Database? _db;

  Future<String> _passphrase() async {
    var pw = await _storage.read(key: _passphraseKey);
    if (pw != null) return pw;
    pw = _randomPassphrase();
    await _storage.write(key: _passphraseKey, value: pw);
    return pw;
  }

  String _randomPassphrase() {
    // 32 bytes from the platform csprng, hex. the old version derived the
    // key from the launch timestamp - brute-forceable offline down to the
    // microsecond the app first opened.
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<Database> open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'halo.db');
    final pw = await _passphrase();
    _db = await openDatabase(
      path,
      password: pw,
      version: 35,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE identity (
            id TEXT PRIMARY KEY,
            ed_priv TEXT NOT NULL,
            x_priv TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE contacts (
            halo_id TEXT PRIMARY KEY,
            onion TEXT NOT NULL,
            xpub TEXT NOT NULL,
            first_seen INTEGER NOT NULL,
            last_seen INTEGER NOT NULL,
            back_paired INTEGER NOT NULL DEFAULT 0,
            nickname TEXT,
            blocked INTEGER NOT NULL DEFAULT 0,
            muted INTEGER NOT NULL DEFAULT 0,
            archived INTEGER NOT NULL DEFAULT 0,
            verified INTEGER NOT NULL DEFAULT 0,
            unread INTEGER NOT NULL DEFAULT 0,
            atmosphere TEXT,
            note TEXT,
            pinned INTEGER NOT NULL DEFAULT 0,
            key_changed INTEGER NOT NULL DEFAULT 0,
            peer_bundle TEXT,
            accepted INTEGER NOT NULL DEFAULT 1,
            supporter_badge TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            peer_id TEXT NOT NULL,
            direction TEXT NOT NULL,
            plaintext TEXT NOT NULL,
            sent_at INTEGER NOT NULL,
            burn_at INTEGER,
            msg_uid TEXT,
            reply_to TEXT,
            group_id TEXT,
            edited INTEGER NOT NULL DEFAULT 0,
            pinned INTEGER NOT NULL DEFAULT 0,
            secure INTEGER NOT NULL DEFAULT 0,
            media_path TEXT,
            file_path TEXT,
            file_name TEXT,
            voice_disguised INTEGER NOT NULL DEFAULT 0,
            saved INTEGER NOT NULL DEFAULT 0,
            sent INTEGER NOT NULL DEFAULT 1,
            delivered INTEGER NOT NULL DEFAULT 0,
            preview TEXT,
            FOREIGN KEY (peer_id) REFERENCES contacts(halo_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE reactions (
            msg_uid TEXT NOT NULL,
            reactor TEXT NOT NULL,
            emoji TEXT NOT NULL,
            reacted_at INTEGER NOT NULL,
            PRIMARY KEY (msg_uid, reactor)
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_messages_msg_uid ON messages(msg_uid)',
        );
        await db.execute(
          'CREATE INDEX idx_messages_group_id ON messages(group_id)',
        );
        await db.execute('''
          CREATE TABLE groups (
            group_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            created_at INTEGER NOT NULL,
            is_admin INTEGER NOT NULL DEFAULT 0,
            admin_id TEXT,
            unread INTEGER NOT NULL DEFAULT 0,
            atmosphere TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE group_members (
            group_id TEXT NOT NULL,
            halo_id TEXT NOT NULL,
            joined_at INTEGER NOT NULL,
            PRIMARY KEY (group_id, halo_id),
            FOREIGN KEY (group_id) REFERENCES groups(group_id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE seen_msgs (
            hash TEXT PRIMARY KEY,
            ts INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE media_chunks (
            media_id TEXT NOT NULL,
            idx INTEGER NOT NULL,
            slice TEXT NOT NULL,
            total INTEGER NOT NULL,
            burn INTEGER,
            at INTEGER NOT NULL,
            PRIMARY KEY (media_id, idx)
          )
        ''');
        await _signalTables(db);
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 35) {
          // the sender can ask that a message not be screenshotted. we
          // keep the flag so it still holds after a restart.
          // a phone that already ran a v35 build has this column, and the
          // ALTER then throws, the database never opens, and the app hangs on
          // boot with no way back. migrations have to be safe to re-run.
          try {
            await db.execute(
              'ALTER TABLE messages ADD COLUMN secure INTEGER NOT NULL DEFAULT 0',
            );
          } catch (e) {
            debugPrint('migrate v35: column already present ($e)');
          }
        }
        if (oldV < 34) {
          // partial media used to live in ram only - a restart lost it.
          await db.execute('''
            CREATE TABLE IF NOT EXISTS media_chunks (
              media_id TEXT NOT NULL,
              idx INTEGER NOT NULL,
              slice TEXT NOT NULL,
              total INTEGER NOT NULL,
              burn INTEGER,
              at INTEGER NOT NULL,
              PRIMARY KEY (media_id, idx)
            )
          ''');
        }
        if (oldV < 33) {
          try {
            await db.execute(
              'ALTER TABLE messages ADD COLUMN delivered INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 32) {
          try {
            await db.execute(
              'ALTER TABLE contacts ADD COLUMN supporter_badge TEXT',
            );
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 31) {
          // group retries used to INSERT the local row again; duplicate
          // msg_uids blow up every uid-keyed widget key (red screens).
          // keep the original row per uid, drop the copies.
          await db.execute('''
            DELETE FROM messages WHERE msg_uid IS NOT NULL AND id NOT IN (
              SELECT MIN(id) FROM messages WHERE msg_uid IS NOT NULL
              GROUP BY msg_uid
            )
          ''');
        }
        if (oldV < 30) {
          try {
            await db.execute(
              'ALTER TABLE contacts ADD COLUMN peer_bundle TEXT',
            );
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 29) {
          try {
            await db.execute('ALTER TABLE groups ADD COLUMN atmosphere TEXT');
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 28) {
          try {
            await db.execute(
              'ALTER TABLE groups ADD COLUMN unread INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 27) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS seen_msgs (
              hash TEXT PRIMARY KEY,
              ts INTEGER NOT NULL
            )
          ''');
        }
        if (oldV < 26) {
          // message requests: existing contacts stay accepted (default 1),
          // only new unknown senders arrive unaccepted.
          try {
            await db.execute(
              'ALTER TABLE contacts ADD COLUMN accepted INTEGER NOT NULL DEFAULT 1',
            );
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 25) {
          try {
            await db.execute('ALTER TABLE groups ADD COLUMN admin_id TEXT');
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 24) {
          try {
            await db.execute('ALTER TABLE groups ADD COLUMN description TEXT');
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 23) {
          try {
            await db.execute('ALTER TABLE messages ADD COLUMN preview TEXT');
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 22) {
          try {
            await db.execute(
              'ALTER TABLE messages ADD COLUMN voice_disguised INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
          try {
            await db.execute(
              'ALTER TABLE messages ADD COLUMN saved INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 21) {
          try {
            await db.execute('ALTER TABLE messages ADD COLUMN file_path TEXT');
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
          try {
            await db.execute('ALTER TABLE messages ADD COLUMN file_name TEXT');
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 20) {
          try {
            await db.execute(
              'ALTER TABLE contacts ADD COLUMN key_changed INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 19) {
          try {
            await db.execute(
              'ALTER TABLE messages ADD COLUMN sent INTEGER NOT NULL DEFAULT 1',
            );
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 2) await _signalTables(db);
        if (oldV < 3) {
          try {
            await db.execute('ALTER TABLE messages ADD COLUMN burn_at INTEGER');
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 4) {
          try {
            await db.execute(
              'ALTER TABLE contacts ADD COLUMN back_paired INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 5) {
          try {
            await db.execute('ALTER TABLE messages ADD COLUMN msg_uid TEXT');
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_messages_msg_uid ON messages(msg_uid)',
          );
          await db.execute('''
            CREATE TABLE reactions (
              msg_uid TEXT NOT NULL,
              reactor TEXT NOT NULL,
              emoji TEXT NOT NULL,
              reacted_at INTEGER NOT NULL,
              PRIMARY KEY (msg_uid, reactor)
            )
          ''');
        }
        if (oldV < 6) {
          try {
            await db.execute('ALTER TABLE messages ADD COLUMN reply_to TEXT');
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 8) {
          try {
            await db.execute('ALTER TABLE contacts ADD COLUMN nickname TEXT');
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 9) {
          try {
            await db.execute(
              'ALTER TABLE messages ADD COLUMN edited INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 10) {
          try {
            await db.execute(
              'ALTER TABLE contacts ADD COLUMN blocked INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 11) {
          try {
            await db.execute(
              'ALTER TABLE contacts ADD COLUMN muted INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 12) {
          try {
            await db.execute(
              'ALTER TABLE contacts ADD COLUMN archived INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 13) {
          try {
            await db.execute(
              'ALTER TABLE messages ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 14) {
          try {
            await db.execute(
              'ALTER TABLE contacts ADD COLUMN verified INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 16) {
          try {
            await db.execute(
              'ALTER TABLE contacts ADD COLUMN unread INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 17) {
          try {
            await db.execute('ALTER TABLE contacts ADD COLUMN atmosphere TEXT');
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 18) {
          try {
            await db.execute('ALTER TABLE contacts ADD COLUMN note TEXT');
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
          try {
            await db.execute(
              'ALTER TABLE contacts ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 15) {
          try {
            await db.execute('ALTER TABLE messages ADD COLUMN media_path TEXT');
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
        }
        if (oldV < 7) {
          try {
            await db.execute('ALTER TABLE messages ADD COLUMN group_id TEXT');
          } catch (_) {
            // already present - a migration must be safe to re-run
          }
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_messages_group_id ON messages(group_id)',
          );
          await db.execute('''
            CREATE TABLE groups (
              group_id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              is_admin INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE group_members (
              group_id TEXT NOT NULL,
              halo_id TEXT NOT NULL,
              joined_at INTEGER NOT NULL,
              PRIMARY KEY (group_id, halo_id),
              FOREIGN KEY (group_id) REFERENCES groups(group_id) ON DELETE CASCADE
            )
          ''');
        }
      },
    );
    return _db!;
  }

  Future<Map<String, String>?> loadIdentity() async {
    final db = await open();
    final rows = await db.query('identity', limit: 1);
    if (rows.isEmpty) return null;
    return {
      'id': rows.first['id'] as String,
      'ed_priv': rows.first['ed_priv'] as String,
      'x_priv': rows.first['x_priv'] as String,
    };
  }

  Future<void> saveIdentity(String id, String edPriv, String xPriv) async {
    final db = await open();
    await db.delete('identity');
    await db.insert('identity', {
      'id': id,
      'ed_priv': edPriv,
      'x_priv': xPriv,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> setNote(String haloId, String note) async {
    final db = await open();
    await db.update(
      'contacts',
      {'note': note},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<void> setContactPinned(String haloId, bool pinned) async {
    final db = await open();
    await db.update(
      'contacts',
      {'pinned': pinned ? 1 : 0},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<void> setPeerBundle(String haloId, String bundleB64) async {
    final db = await open();
    await db.update(
      'contacts',
      {'peer_bundle': bundleB64},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<Map<String, Object?>?> getContact(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  // upsert a contact stub from group invite info. preserves existing rows
  // (won't overwrite onion/xpub if we already know this peer).
  Future<void> upsertContactStub(
    String haloId,
    String onion,
    String xpub,
  ) async {
    final db = await open();
    final existing = await db.query(
      'contacts',
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('contacts', {
      'halo_id': haloId,
      'onion': onion,
      'xpub': xpub,
      'first_seen': now,
      'last_seen': now,
      'back_paired': 0,
      // being in a group with someone is not knowing them. the key is kept
      // so their messages decrypt; the row stays out of the contact list
      // until you add them yourself.
      'accepted': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<bool> keyChanged(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['key_changed'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['key_changed'] as int? ?? 0) == 1;
  }

  // flag that a known peer's identity key changed (reinstall or mitm).
  // the chat surfaces this so the user verifies before trusting.
  Future<void> setKeyChanged(String haloId, bool changed) async {
    final db = await open();
    await db.update(
      'contacts',
      {'key_changed': changed ? 1 : 0},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<void> clearKeyChanged(String haloId) async {
    final db = await open();
    await db.update(
      'contacts',
      {'key_changed': 0},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<String?> contactXPub(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['xpub'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['xpub'] as String?;
  }

  // backfill the xpub a v2 pair left empty. plain write, no key-change check:
  // upsertContact would read an empty prior as a change and raise the flag.
  Future<void> setContactBadge(String haloId, String? tier) async {
    final d = await open();
    await d.update(
      'contacts',
      {'supporter_badge': tier},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<void> setContactXPub(String haloId, String xpub) async {
    final db = await open();
    await db.update(
      'contacts',
      {'xpub': xpub},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<List<Map<String, Object?>>> contacts() async {
    final db = await open();
    return db.query(
      'contacts',
      where: 'accepted = 1',
      orderBy: 'last_seen DESC',
    );
  }

  Future<void> deleteConversation(String haloId) async {
    final d = await open();
    await d.transaction((t) async {
      final rows = await t.query(
        'messages',
        columns: ['msg_uid'],
        where: 'peer_id = ?',
        whereArgs: [haloId],
      );
      for (final r in rows) {
        final uid = r['msg_uid'] as String?;
        if (uid != null) {
          await t.delete('reactions', where: 'msg_uid = ?', whereArgs: [uid]);
        }
      }
      await t.delete('messages', where: 'peer_id = ?', whereArgs: [haloId]);
      // the row stays: it carries the xpub our nostr subscription is built
      // from. archived + unaccepted = invisible everywhere until they write.
      await t.update(
        'contacts',
        {'accepted': 0, 'archived': 1, 'unread': 0},
        where: 'halo_id = ?',
        whereArgs: [haloId],
      );
    });
  }

  // they wrote after we deleted them: bring the row back as a request.
  Future<void> unparkIfArchived(String haloId) async {
    final d = await open();
    final r = await d.query(
      'contacts',
      columns: ['archived', 'accepted'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (r.isEmpty) return;
    final arch = (r.first['archived'] as int?) ?? 0;
    final acc = (r.first['accepted'] as int?) ?? 0;
    if (arch == 1 && acc == 0) {
      await d.update(
        'contacts',
        {'archived': 0},
        where: 'halo_id = ?',
        whereArgs: [haloId],
      );
    }
  }

  Future<void> setArchived(String haloId, bool archived) async {
    final db = await open();
    await db.update(
      'contacts',
      {'archived': archived ? 1 : 0},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<void> setMuted(String haloId, bool muted) async {
    final db = await open();
    await db.update(
      'contacts',
      {'muted': muted ? 1 : 0},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<bool> isMuted(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['muted'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['muted'] as int? ?? 0) == 1;
  }

  Future<void> setVerified(String haloId, bool verified) async {
    final db = await open();
    await db.update(
      'contacts',
      {'verified': verified ? 1 : 0},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<bool> isVerified(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['verified'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['verified'] as int? ?? 0) == 1;
  }

  Future<void> setBlocked(String haloId, bool blocked) async {
    final db = await open();
    await db.update(
      'contacts',
      {'blocked': blocked ? 1 : 0},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<bool> isBlocked(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['blocked'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['blocked'] as int? ?? 0) == 1;
  }

  // true only when we've accepted this sender. unknown senders read false.
  Future<bool> isAccepted(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['accepted'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['accepted'] as int? ?? 0) == 1;
  }

  // how many messages we already hold from a sender - caps strangers.
  Future<int> countMessagesFrom(String peerId) async {
    final db = await open();
    final r = await db.rawQuery(
      'SELECT COUNT(*) c FROM messages WHERE peer_id = ? AND direction = ?',
      [peerId, 'in'],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  // how many messages we've sent a peer - caps our own request messages.
  Future<int> countMessagesTo(String peerId) async {
    final db = await open();
    final r = await db.rawQuery(
      'SELECT COUNT(*) c FROM messages WHERE peer_id = ? AND direction = ?',
      [peerId, 'out'],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  Future<void> setNickname(String haloId, String? name) async {
    final db = await open();
    final v = (name == null || name.trim().isEmpty) ? null : name.trim();
    await db.update(
      'contacts',
      {'nickname': v},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  // unknown senders waiting for accept/block. blocked ones stay hidden.
  Future<List<Map<String, Object?>>> pendingRequests() async {
    final db = await open();
    return db.query(
      'contacts',
      where: 'accepted = 0 AND blocked = 0 AND IFNULL(archived, 0) = 0',
      orderBy: 'last_seen DESC',
    );
  }

  Future<int> pendingRequestCount() async {
    final db = await open();
    final r = await db.rawQuery(
      'SELECT COUNT(*) c FROM contacts WHERE accepted = 0 AND blocked = 0 AND IFNULL(archived, 0) = 0',
    );
    return (r.first['c'] as int?) ?? 0;
  }

  // accept a request: the stranger becomes a normal contact.
  Future<void> acceptRequest(String haloId) async {
    final db = await open();
    await db.update(
      'contacts',
      {'accepted': 1},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  // quietly dismiss a request: drop the stranger's row and pending messages.
  // not a block - they can reach us again later.
  Future<void> declineRequest(String haloId) async {
    final d = await open();
    await d.transaction((t) async {
      final rows = await t.query(
        'messages',
        columns: ['msg_uid'],
        where: 'peer_id = ?',
        whereArgs: [haloId],
      );
      for (final r in rows) {
        final uid = r['msg_uid'] as String?;
        if (uid != null) {
          await t.delete('reactions', where: 'msg_uid = ?', whereArgs: [uid]);
        }
      }
      await t.delete('messages', where: 'peer_id = ?', whereArgs: [haloId]);
      // park, don't delete - the row carries the xpub the relay subscription
      // is built from. wiping it left a declined peer with nowhere to land.
      // they write again -> unparkIfArchived surfaces them as a new request.
      await t.update(
        'contacts',
        {'accepted': 0, 'archived': 1, 'unread': 0},
        where: 'halo_id = ?',
        whereArgs: [haloId],
      );
    });
  }

  Future<void> upsertContact(
    String haloId,
    String onion,
    String xpub, {
    int accepted = 1,
  }) async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await db.query(
      'contacts',
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert('contacts', {
        'halo_id': haloId,
        'onion': onion,
        'xpub': xpub,
        'first_seen': now,
        'last_seen': now,
        'accepted': accepted,
      });
    } else {
      // xpub changed on someone we already know = they reinstalled, or its a
      // mitm. dont just swap the key silently, flag it so the chat warns
      final priorX = existing.first['xpub'] as String?;
      final changed =
          priorX != null &&
          priorX.isNotEmpty &&
          xpub.isNotEmpty &&
          priorX != xpub;
      // only ever raise accepted (0->1 on an explicit re-pair), never lower
      // it: a back-pair passing accepted:0 must not demote a real contact.
      final priorAccepted = (existing.first['accepted'] as int?) ?? 0;
      final nextAccepted = accepted == 1 ? 1 : priorAccepted;
      // parked = deleted (archived AND unaccepted). a real archived chat is
      // still accepted, so this can't un-archive one the user archived on
      // purpose. any touch on a parked row brings it back as a request.
      final wasParked =
          ((existing.first['archived'] as int?) ?? 0) == 1 &&
          priorAccepted == 0;
      await db.update(
        'contacts',
        {
          'onion': onion,
          // v2 links pass '' here - never wipe a key we already learned
          if (xpub.isNotEmpty) 'xpub': xpub,
          'last_seen': now,
          'accepted': nextAccepted,
          if (wasParked) 'archived': 0,
          if (changed) 'key_changed': 1,
          if (changed) 'verified': 0,
        },
        where: 'halo_id = ?',
        whereArgs: [haloId],
      );
    }
  }

  Future<void> saveMessage(
    String peerId,
    String direction,
    String plaintext, {
    int? burnAt,
    String? msgUid,
    String? replyTo,
    String? groupId,
    String? mediaPath,
    String? filePath,
    String? fileName,
    bool voiceDisguised = false,
    bool saved = false,
    int sent = 1,
    String? preview,
    bool secure = false,
  }) async {
    final db = await open();
    await db.insert('messages', {
      'peer_id': peerId,
      'direction': direction,
      'plaintext': plaintext,
      'sent_at': DateTime.now().millisecondsSinceEpoch,
      'burn_at': burnAt,
      'msg_uid': msgUid,
      'reply_to': replyTo,
      'group_id': groupId,
      'media_path': mediaPath,
      'file_path': filePath,
      'file_name': fileName,
      'voice_disguised': voiceDisguised ? 1 : 0,
      'preview': preview,
      'saved': saved ? 1 : 0,
      'sent': sent,
      'secure': secure ? 1 : 0,
    });
    // any inbound message proves the peer knows us, so flip back_paired.
    // subsequent sends to them can use nostr safely.
    if (direction == 'in') {
      await db.update(
        'contacts',
        {'back_paired': 1},
        where: 'halo_id = ?',
        whereArgs: [peerId],
      );
    }
  }

  // dedup: skip a message we've already handled. duplicates arrive because
  // tor times out and the same msg comes via nostr too (plus retries). the
  // first copy sets up the session; a duplicate crashes on the used-up
  // prekey, so drop it before any decrypt.
  Future<bool> alreadySeen(String hash) async {
    final db = await open();
    final rows = await db.query(
      'seen_msgs',
      where: 'hash = ?',
      whereArgs: [hash],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> markSeen(String hash) async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('seen_msgs', {
      'hash': hash,
      'ts': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    // prune anything older than a day so the table stays tiny
    await db.delete('seen_msgs', where: 'ts < ?', whereArgs: [now - 86400000]);
  }

  // like markSeen but stamped a month ahead of the daily prune: buried
  // undecryptable ciphers must STAY buried - a pruned hash resurrects the
  // whole bad-mac replay the next day. relays age the events out well
  // before the month is up.
  Future<void> markSeenLong(String hash) async {
    final db = await open();
    await db.insert('seen_msgs', {
      'hash': hash,
      'ts': DateTime.now().millisecondsSinceEpoch + 30 * 86400000,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // load back_paired for a contact. true = peer has confirmed they know us
  // (via a received message). false = we should still use direct-onion to
  // give them a chance to back-pair.
  // assign a msg_uid to an existing row that lacks one (used to enable
  // reactions on messages that predate the v5 migration). returns the
  // uid. matches by (peer_id, sent_at) which is unique enough in practice.
  Future<void> assignUidIfMissing(
    String peerId,
    int sentAtMs,
    String uid,
  ) async {
    final db = await open();
    await db.update(
      'messages',
      {'msg_uid': uid},
      where: 'peer_id = ? AND sent_at = ? AND msg_uid IS NULL',
      whereArgs: [peerId, sentAtMs],
    );
  }

  Future<void> markBackPaired(String peerId) async {
    final d = await open();
    await d.update(
      'contacts',
      {'back_paired': 1},
      where: 'halo_id = ?',
      whereArgs: [peerId],
    );
  }

  Future<bool> isBackPaired(String peerId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['back_paired'],
      where: 'halo_id = ?',
      whereArgs: [peerId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['back_paired'] as int? ?? 0) == 1;
  }

  // ---- groups ----

  // create a group locally. members is the full set INCLUDING the creator
  // (caller must include their own kryfo id if they want to appear in member
  // list). isAdmin = true for groups we created; false for groups we joined.
  Future<void> createGroup(
    String groupId,
    String name,
    List<String> members, {
    required bool isAdmin,
    String? adminId,
  }) async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('groups', {
      'group_id': groupId,
      'name': name,
      'created_at': now,
      'is_admin': isAdmin ? 1 : 0,
      'admin_id': adminId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final batch = db.batch();
    for (final m in members) {
      batch.insert('group_members', {
        'group_id': groupId,
        'halo_id': m,
        'joined_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<bool> groupExists(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'groups',
      columns: ['group_id'],
      where: 'group_id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<Map<String, Object?>>> loadGroups() async {
    final db = await open();
    return db.query('groups', orderBy: 'created_at DESC');
  }

  Future<Map<String, Object?>?> getGroup(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'groups',
      where: 'group_id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  // the group creator/admin kryfo id. used to verify a roster self-heal
  // really came from the admin, not a member spoofing membership changes.
  Future<String?> groupAdminId(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'groups',
      columns: ['admin_id'],
      where: 'group_id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['admin_id'] as String?;
  }

  Future<List<String>> getGroupMembers(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'group_members',
      columns: ['halo_id'],
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'joined_at ASC',
    );
    return rows.map((r) => r['halo_id'] as String).toList();
  }

  Future<void> addGroupMember(String groupId, String haloId) async {
    final db = await open();
    await db.insert('group_members', {
      'group_id': groupId,
      'halo_id': haloId,
      'joined_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // replace the whole member set for a group with the authoritative list.
  // used when a create/reconcile control arrives so a re-add or membership
  // change syncs cleanly instead of leaving stale or missing rows.
  Future<void> syncGroupMembers(String groupId, List<String> members) async {
    final db = await open();
    final batch = db.batch();
    batch.delete('group_members', where: 'group_id = ?', whereArgs: [groupId]);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final h in members) {
      batch.insert('group_members', {
        'group_id': groupId,
        'halo_id': h,
        'joined_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> removeGroupMember(String groupId, String haloId) async {
    final db = await open();
    await db.delete(
      'group_members',
      where: 'group_id = ? AND halo_id = ?',
      whereArgs: [groupId, haloId],
    );
  }

  Future<void> renameGroup(String groupId, String name) async {
    final db = await open();
    await db.update(
      'groups',
      {'name': name},
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }

  Future<void> deleteGroup(String groupId) async {
    final db = await open();
    await db.delete(
      'group_members',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    await db.delete('groups', where: 'group_id = ?', whereArgs: [groupId]);
  }

  // load all messages for a group, oldest-first. peer_id on each row is the
  // SENDER's kryfo id (for our own messages this is our kryfo id).
  Future<List<Map<String, Object?>>> loadGroupMessages(String groupId) async {
    final db = await open();
    return db.query(
      'messages',
      columns: ['*', 'rowid'],
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'sent_at ASC',
    );
  }

  // group messages newer than a rowid, for the append-fast-path (mirrors
  // messagesAfter but scoped to a group).
  Future<List<Map<String, Object?>>> groupMessagesPage(
    String groupId, {
    int? beforeRowid,
    int limit = 60,
  }) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['*', 'rowid'],
      where: beforeRowid == null
          ? 'group_id = ?'
          : 'group_id = ? AND rowid < ?',
      whereArgs: beforeRowid == null ? [groupId] : [groupId, beforeRowid],
      orderBy: 'rowid DESC',
      limit: limit,
    );
    return rows.reversed.toList();
  }

  Future<List<Map<String, Object?>>> groupMessagesAfter(
    String groupId,
    int afterRowid,
  ) async {
    final db = await open();
    return db.query(
      'messages',
      columns: ['*', 'rowid'],
      where: 'group_id = ? AND rowid > ?',
      whereArgs: [groupId, afterRowid],
      orderBy: 'sent_at ASC',
    );
  }

  // add or replace a reaction. reactor is '' for self, peer's kryfo id
  // for theirs. one reaction per (msgUid, reactor) - re-reacting replaces.
  Future<void> setPinned(String msgUid, bool pinned) async {
    final db = await open();
    await db.update(
      'messages',
      {'pinned': pinned ? 1 : 0},
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  Future<void> setSaved(String msgUid, bool saved) async {
    final db = await open();
    await db.update(
      'messages',
      {'saved': saved ? 1 : 0},
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  // every saved message across all chats, newest first. peer_id rides along
  // so the saved screen can show who it's from.
  Future<List<Map<String, Object?>>> savedMessages() async {
    final db = await open();
    return db.query(
      'messages',
      where: 'saved = 1',
      orderBy: 'sent_at DESC',
      limit: 500,
    );
  }

  // kill the jpgs too, not just the rows. otherwise a burned photo is still
  // sitting on disk
  Future<void> _scrubMedia(List<Map<String, Object?>> rows) async {
    for (final r in rows) {
      final mp = r['media_path'] as String?;
      if (mp != null && mp.isNotEmpty) {
        try {
          final f = File(mp);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> deleteMessage(String msgUid) async {
    final db = await open();
    final media = await db.query(
      'messages',
      columns: ['media_path'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
    await db.delete('reactions', where: 'msg_uid = ?', whereArgs: [msgUid]);
    await db.delete('messages', where: 'msg_uid = ?', whereArgs: [msgUid]);
    await _scrubMedia(media);
  }

  Future<void> purgeExpiredBurns() async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'messages',
      columns: ['msg_uid'],
      where: 'burn_at IS NOT NULL AND burn_at < ?',
      whereArgs: [now],
    );
    for (final r in rows) {
      final uid = r['msg_uid'] as String?;
      if (uid != null) {
        await db.delete('reactions', where: 'msg_uid = ?', whereArgs: [uid]);
      }
    }
    await db.delete(
      'messages',
      where: 'burn_at IS NOT NULL AND burn_at < ?',
      whereArgs: [now],
    );
    await _scrubMedia(rows);
  }

  Future<void> bumpUnread(String peerId) async {
    final db = await open();
    await db.rawUpdate(
      'UPDATE contacts SET unread = unread + 1 WHERE halo_id = ?',
      [peerId],
    );
  }

  Future<void> clearUnread(String peerId) async {
    final db = await open();
    await db.update(
      'contacts',
      {'unread': 0},
      where: 'halo_id = ?',
      whereArgs: [peerId],
    );
  }

  Future<void> bumpGroupUnread(String groupId) async {
    final db = await open();
    await db.rawUpdate(
      'UPDATE groups SET unread = unread + 1 WHERE group_id = ?',
      [groupId],
    );
  }

  Future<void> clearGroupUnread(String groupId) async {
    final db = await open();
    await db.update(
      'groups',
      {'unread': 0},
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }

  Future<void> setGroupAtmosphere(String groupId, String atmosphere) async {
    final db = await open();
    await db.update(
      'groups',
      {'atmosphere': atmosphere},
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }

  Future<String?> getGroupAtmosphere(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'groups',
      columns: ['atmosphere'],
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    if (rows.isEmpty) return null;
    return rows.first['atmosphere'] as String?;
  }

  Future<void> setAtmosphere(String peerId, String atmosphere) async {
    final db = await open();
    await db.update(
      'contacts',
      {'atmosphere': atmosphere},
      where: 'halo_id = ?',
      whereArgs: [peerId],
    );
  }

  Future<String?> getAtmosphere(String peerId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['atmosphere'],
      where: 'halo_id = ?',
      whereArgs: [peerId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['atmosphere'] as String?;
  }

  Future<void> clearConversation(String peerId) async {
    final db = await open();
    final media = await db.query(
      'messages',
      columns: ['media_path'],
      where: 'peer_id = ?',
      whereArgs: [peerId],
    );
    await db.rawDelete(
      'DELETE FROM reactions WHERE msg_uid IN '
      '(SELECT msg_uid FROM messages WHERE peer_id = ? AND msg_uid IS NOT NULL)',
      [peerId],
    );
    await db.delete('messages', where: 'peer_id = ?', whereArgs: [peerId]);
    await _scrubMedia(media);
  }

  Future<void> clearGroupConversation(String groupId) async {
    final db = await open();
    final media = await db.query(
      'messages',
      columns: ['media_path'],
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    await db.rawDelete(
      'DELETE FROM reactions WHERE msg_uid IN '
      '(SELECT msg_uid FROM messages WHERE group_id = ? AND msg_uid IS NOT NULL)',
      [groupId],
    );
    await db.delete('messages', where: 'group_id = ?', whereArgs: [groupId]);
    await _scrubMedia(media);
  }

  Future<void> editMessage(String msgUid, String newText) async {
    final db = await open();
    await db.update(
      'messages',
      {'plaintext': newText, 'edited': 1},
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  Future<bool> messageExists(String msgUid) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['rowid'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<String?> getMsgPreview(String msgUid) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['preview'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['preview'] as String?;
  }

  Future<int> setMsgPreview(String msgUid, String previewJson) async {
    final db = await open();
    return db.update(
      'messages',
      {'preview': previewJson},
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  Future<void> setMsgBurnAt(String msgUid, int burnAt) async {
    final db = await open();
    await db.update(
      'messages',
      {'burn_at': burnAt},
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  Future<void> addReaction(String msgUid, String reactor, String emoji) async {
    final db = await open();
    await db.insert('reactions', {
      'msg_uid': msgUid,
      'reactor': reactor,
      'emoji': emoji,
      'reacted_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeReaction(String msgUid, String reactor) async {
    final db = await open();
    await db.delete(
      'reactions',
      where: 'msg_uid = ? AND reactor = ?',
      whereArgs: [msgUid, reactor],
    );
  }

  // load reactions for a batch of messages. returns
  // { msgUid: [ (reactor, emoji), ... ] }.
  Future<Map<String, List<MapEntry<String, String>>>> loadReactionsFor(
    List<String> msgUids,
  ) async {
    if (msgUids.isEmpty) return {};
    final db = await open();
    final placeholders = List.filled(msgUids.length, '?').join(',');
    final rows = await db.query(
      'reactions',
      columns: ['msg_uid', 'reactor', 'emoji'],
      where: 'msg_uid IN ($placeholders)',
      whereArgs: msgUids,
    );
    final out = <String, List<MapEntry<String, String>>>{};
    for (final r in rows) {
      final uid = r['msg_uid'] as String;
      final reactor = r['reactor'] as String;
      final emoji = r['emoji'] as String;
      out.putIfAbsent(uid, () => []).add(MapEntry(reactor, emoji));
    }
    return out;
  }

  // delete messages whose burn_at is past. called by the periodic
  // sweep started in boot().
  Future<int> purgeExpired() async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    final media = await db.query(
      'messages',
      columns: ['media_path'],
      where: 'burn_at IS NOT NULL AND burn_at < ?',
      whereArgs: [now],
    );
    final n = await db.delete(
      'messages',
      where: 'burn_at IS NOT NULL AND burn_at < ?',
      whereArgs: [now],
    );
    await _scrubMedia(media);
    return n;
  }

  Future<bool> isSent(String msgUid) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: ['sent'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    if (r.isEmpty) return false;
    return (r.first['sent'] as int? ?? 0) == 1;
  }

  // every outgoing row the wire never accepted, oldest first. the drainer
  // walks this on a timer so a send survives tor warmup, backing out of the
  // chat, and a cold restart.
  //
  // deliberately keyed on `sent`, not `delivered`: a message that went out
  // but hasn't been acked is not a message that needs sending again, and
  // retrying on a missing ack loops forever when the ack never comes.
  Future<List<Map<String, Object?>>> unsentOutbox() async {
    final db = await open();
    return db.query(
      'messages',
      where:
          "direction = 'out' AND sent = 0 AND msg_uid IS NOT NULL "
          "AND (group_id IS NULL OR group_id = '')",
      orderBy: 'sent_at ASC',
      limit: 40,
    );
  }

  // --- chunked media, buffered on disk so a restart doesn't lose a transfer ---

  // store one slice, return how many of this media's slices we now hold.
  Future<int> putMediaChunk(
    String mediaId,
    int idx,
    String slice,
    int total,
    int? burn,
  ) async {
    final db = await open();
    await db.rawInsert(
      'INSERT OR REPLACE INTO media_chunks '
      '(media_id, idx, slice, total, burn, at) VALUES (?, ?, ?, ?, ?, ?)',
      [mediaId, idx, slice, total, burn, DateTime.now().millisecondsSinceEpoch],
    );
    final r = await db.rawQuery(
      'SELECT COUNT(*) c FROM media_chunks WHERE media_id = ?',
      [mediaId],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  // burn window rides the slices so it survives a restart too.
  Future<int?> mediaChunkBurn(String mediaId) async {
    final db = await open();
    final r = await db.query(
      'media_chunks',
      columns: ['burn'],
      where: 'media_id = ? AND burn IS NOT NULL',
      whereArgs: [mediaId],
      limit: 1,
    );
    if (r.isEmpty) return null;
    return r.first['burn'] as int?;
  }

  Future<List<String>> mediaChunkSlices(String mediaId) async {
    final db = await open();
    final r = await db.query(
      'media_chunks',
      columns: ['slice'],
      where: 'media_id = ?',
      whereArgs: [mediaId],
      orderBy: 'idx ASC',
    );
    return [for (final row in r) (row['slice'] as String?) ?? ''];
  }

  Future<int> dropMediaChunks(String mediaId) async {
    final db = await open();
    return db.delete(
      'media_chunks',
      where: 'media_id = ?',
      whereArgs: [mediaId],
    );
  }

  // a transfer nobody ever finished shouldn't sit in the db forever.
  Future<void> sweepMediaChunks() async {
    final db = await open();
    final cutoff =
        DateTime.now().millisecondsSinceEpoch -
        const Duration(days: 7).inMilliseconds;
    final n = await db.delete(
      'media_chunks',
      where: 'at < ?',
      whereArgs: [cutoff],
    );
    if (n > 0) debugPrint('swept $n stale media chunks');
  }

  Future<bool> isDelivered(String msgUid) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: ['delivered'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    if (r.isEmpty) return false;
    return (r.first['delivered'] as int? ?? 0) == 1;
  }

  Future<void> markDelivered(String msgUid) async {
    final db = await open();
    await db.update(
      'messages',
      {'sent': 1, 'delivered': 1},
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  Future<void> markSent(String msgUid) async {
    final db = await open();
    await db.update(
      'messages',
      {'sent': 1},
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  Future<List<Map<String, Object?>>> messagesFor(String peerId) async {
    final db = await open();
    return db.query(
      'messages',
      columns: ['*', 'rowid'],
      // group_id IS NULL keeps group messages out of the 1:1 thread - a group
      // row carries peer_id = sender AND a group_id, so without this it leaked
      // into the direct chat with that sender.
      where: 'peer_id = ? AND group_id IS NULL',
      whereArgs: [peerId],
      orderBy: 'sent_at ASC',
    );
  }

  // newest page of a 1:1 thread. beforeRowid pages older on scroll-up so a
  // 5000-message chat doesn't parse the world on open.
  Future<List<Map<String, Object?>>> messagesPage(
    String peerId, {
    int? beforeRowid,
    int limit = 60,
  }) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['*', 'rowid'],
      where: beforeRowid == null
          ? 'peer_id = ? AND group_id IS NULL'
          : 'peer_id = ? AND group_id IS NULL AND rowid < ?',
      whereArgs: beforeRowid == null ? [peerId] : [peerId, beforeRowid],
      orderBy: 'rowid DESC',
      limit: limit,
    );
    return rows.reversed.toList();
  }

  // only messages newer than a timestamp, oldest-first. used by the chat's
  // append-on-receive fast path so a live message doesn't reload the world.
  Future<List<Map<String, Object?>>> messagesAfter(
    String peerId,
    int afterRowid,
  ) async {
    final db = await open();
    // key off rowid (insertion order), not sent_at - a received note can carry
    // a sent_at older than our local newest (clock skew) and would be missed by
    // a timestamp filter. rowid always climbs as rows are saved.
    return db.query(
      'messages',
      columns: ['*', 'rowid'],
      where: "peer_id = ? AND group_id IS NULL AND rowid > ?",
      whereArgs: [peerId, afterRowid],
      orderBy: 'rowid ASC',
    );
  }

  // newest message for a peer (or null) - drives the home-list preview and
  // ordering without loading the whole conversation.
  Future<Map<String, Object?>?> lastMessageFor(String peerId) async {
    final db = await open();
    // order by rowid (insertion order), not sent_at - a received note can carry
    // a sent_at older than our local newest (clock skew between phones) and
    // would otherwise never surface as the latest. rowid always climbs.
    // group_id IS NULL: a group message is stored under the sender's peer_id
    // too, and without this filter it leaked into their 1:1 preview + unread.
    final rows = await db.query(
      'messages',
      where: 'peer_id = ? AND group_id IS NULL',
      whereArgs: [peerId],
      orderBy: 'rowid DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }
}

Future<void> _signalTables(Database db) async {
  await db.execute(
    'CREATE TABLE IF NOT EXISTS prekeys (id INTEGER PRIMARY KEY, record BLOB NOT NULL)',
  );
  await db.execute(
    'CREATE TABLE IF NOT EXISTS signed_prekeys (id INTEGER PRIMARY KEY, record BLOB NOT NULL, created_at INTEGER NOT NULL)',
  );
  await db.execute(
    'CREATE TABLE IF NOT EXISTS sessions (address TEXT NOT NULL, device_id INTEGER NOT NULL, record BLOB NOT NULL, PRIMARY KEY (address, device_id))',
  );
  await db.execute(
    'CREATE TABLE IF NOT EXISTS peer_identities (address TEXT PRIMARY KEY, identity_key BLOB NOT NULL)',
  );
  await db.execute(
    'CREATE TABLE IF NOT EXISTS signal_meta (k TEXT PRIMARY KEY, v TEXT NOT NULL)',
  );
}

Future<String> makePreKeyBundleB64() async {
  final spk = await signalSession.signedPreKeyStore.loadSignedPreKey(1);
  final database = await db.open();
  final pkRows = await database.query('prekeys', limit: 1, orderBy: 'id ASC');
  if (pkRows.isEmpty) throw 'no prekeys';
  final pk = await signalSession.preKeyStore.loadPreKey(
    pkRows.first['id'] as int,
  );
  final bundle = {
    'registrationId': signalSession.registrationId,
    'deviceId': 1,
    'preKeyId': pk.id,
    'preKeyPublic': base64Encode(pk.getKeyPair().publicKey.serialize()),
    'signedPreKeyId': spk.id,
    'signedPreKeyPublic': base64Encode(spk.getKeyPair().publicKey.serialize()),
    'signedPreKeySignature': base64Encode(spk.signature),
    'identityKey': base64Encode(
      signalSession.identityKeyPair.getPublicKey().serialize(),
    ),
  };
  return base64Encode(utf8.encode(jsonEncode(bundle)));
}

Future<void> processPeerBundle(String haloId, String bundleB64) async {
  final j =
      jsonDecode(utf8.decode(base64Decode(bundleB64))) as Map<String, dynamic>;
  final preKeyBundle = PreKeyBundle(
    j['registrationId'] as int,
    j['deviceId'] as int,
    j['preKeyId'] as int,
    Curve.decodePoint(base64Decode(j['preKeyPublic'] as String), 0),
    j['signedPreKeyId'] as int,
    Curve.decodePoint(base64Decode(j['signedPreKeyPublic'] as String), 0),
    base64Decode(j['signedPreKeySignature'] as String),
    IdentityKey(Curve.decodePoint(base64Decode(j['identityKey'] as String), 0)),
  );
  final addr = SignalProtocolAddress(haloId, 1);
  final builder = SessionBuilder(
    signalSession.sessionStore,
    signalSession.preKeyStore,
    signalSession.signedPreKeyStore,
    signalSession.identityStore,
    addr,
  );
  await builder.processPreKeyBundle(preKeyBundle);
}

// overwrite a byte buffer with zeros - best-effort wipe of key/plaintext
// material from ram. dart strings cant be wiped (immutable+gc), only lists.
void _zeroBytes(List<int> b) {
  for (var i = 0; i < b.length; i++) {
    b[i] = 0;
  }
}

Future<String> signalEncrypt(String peerId, String plaintext) async {
  final addr = SignalProtocolAddress(peerId, 1);
  final cipher = SessionCipher(
    signalSession.sessionStore,
    signalSession.preKeyStore,
    signalSession.signedPreKeyStore,
    signalSession.identityStore,
    addr,
  );
  final msg = await cipher.encrypt(Uint8List.fromList(utf8.encode(plaintext)));
  final wire = Uint8List.fromList([msg.getType(), ...msg.serialize()]);
  return base64Encode(wire);
}

bool _eqBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _isPreKeyWire(String wireB64) {
  try {
    final w = base64Decode(wireB64);
    return w.isNotEmpty && w[0] == CiphertextMessage.prekeyType;
  } catch (_) {
    return false;
  }
}

Future<String?> signalDecrypt(
  String peerId,
  String wireB64, {
  bool flagKeyChange = false,
}) async {
  try {
    final wire = base64Decode(wireB64);
    if (wire.isEmpty) return null;
    final type = wire[0];
    final body = Uint8List.fromList(wire.sublist(1));
    final addr = SignalProtocolAddress(peerId, 1);
    final cipher = SessionCipher(
      signalSession.sessionStore,
      signalSession.preKeyStore,
      signalSession.signedPreKeyStore,
      signalSession.identityStore,
      addr,
    );
    Uint8List plain;
    if (type == CiphertextMessage.prekeyType) {
      final pkm = PreKeySignalMessage(body);
      // trial decrypt: if this prekey carries a different identity than the
      // one on file for this contact, it's not them - it's a wiped peer with
      // new keys. refuse so the caller falls through to back-pair and it
      // arrives as a new person, id matching key. targeted decrypts (a real
      // reply, flagKeyChange) skip this and keep deliver-and-warn for mitm.
      if (!flagKeyChange && peerId != '_pending_back_pair_') {
        final known = await signalSession.identityStore.getIdentity(addr);
        if (known != null &&
            !_eqBytes(known.serialize(), pkm.getIdentityKey().serialize())) {
          return null;
        }
      }
      if (await signalSession.sessionStore.containsSession(addr)) {
        // session exists - use it. rebuilding from the prekey record here is
        // wrong when the slot was refilled with a fresh key (old bundle refs
        // would bad-mac the rebuilt session).
        try {
          plain = await cipher.decryptFromSignal(pkm.getWhisperMessage());
        } catch (e) {
          debugPrint(
            'signalDecrypt: session path failed ($e), prekey fallback',
          );
          plain = await cipher.decrypt(pkm);
        }
      } else {
        final pkId = pkm.getPreKeyId();
        final havePk =
            !pkId.isPresent ||
            await signalSession.preKeyStore.containsPreKey(pkId.value);
        if (!havePk) {
          debugPrint('signalDecrypt: prekey gone, no session for $peerId');
          return null;
        }
        plain = await cipher.decrypt(pkm);
      }
    } else {
      plain = await cipher.decryptFromSignal(
        SignalMessage.fromSerialized(body),
      );
    }
    final text = utf8.decode(plain);
    _zeroBytes(plain); // cleartext decoded out, wipe the raw buffer
    return text;
  } on DuplicateMessageException catch (_) {
    debugPrint('signalDecrypt: duplicate from $peerId, dropped');
    // store-and-forward re-delivers messages - a duplicate is expected and
    // benign. the original already decrypted, so drop this one quietly.
    return null;
  } on UntrustedIdentityException catch (_) {
    // known peer's identity key no longer matches - reinstall or mitm.
    // only flag when the caller knows this cipher was really for this peer
    // (targeted decrypt). trial-decrypt callers pass flagKeyChange:false so a
    // normal no-match against the wrong contact never sets the flag.
    if (flagKeyChange) {
      await db.setKeyChanged(peerId, true);
      appState.notifyListeners();
    }
    return null;
  } on InvalidKeyIdException catch (_) {
    // one-time prekey already used up. if a session with this peer
    // exists, an earlier copy set it up (tor+nostr both delivered, or a
    // retry) so this is a duplicate - drop quietly. no session = can't
    // read this one.
    final addr = SignalProtocolAddress(peerId, 1);
    if (await signalSession.sessionStore.containsSession(addr)) {
      return null;
    }
    return null;
  } catch (e) {
    debugPrint('signalDecrypt: $e');
    return null;
  }
}

Future<String> handleHaloUri(String raw) async {
  final parsed = parseHaloUri(raw);
  if (parsed == null) return 'invalid uri';
  if (parsed['v'] == '2' || parsed['v'] == '3') {
    final already = await db.getContact(parsed['id']!) != null;
    try {
      await processPeerBundle(parsed['id']!, parsed['bundle']!);
    } catch (e) {
      return 'bundle error: $e';
    }
    await db.upsertContact(parsed['id']!, parsed['onion']!, '');
    await db.setPeerBundle(parsed['id']!, parsed['bundle']!);
    final fc = parsed['fc'];
    debugPrint(
      fc == null || fc.isEmpty
          ? 'pair: v${parsed['v']} invite, no first-contact addr'
          : 'pair: v${parsed['v']} invite carries first-contact addr',
    );
    if (fc != null && fc.isNotEmpty) {
      await appState.rememberPeerFc(parsed['id']!, fc);
    }
    await appState.subscribePeer(parsed['id']!);
    return already
        ? 'already saved: ${parsed['id']}'
        : 'added ${parsed['id']} · you can message them now';
  } else {
    await db.upsertContact(parsed['id']!, parsed['onion']!, parsed['xpub']!);
    await appState.subscribePeer(parsed['id']!);
    return 'peer imported (v1): ${parsed['id']}';
  }
}

Future<String> saveFileBytes(List<int> bytes, String uid, String name) async {
  final dir = await getApplicationDocumentsDirectory();
  final mediaDir = Directory('${dir.path}/media');
  if (!await mediaDir.exists()) await mediaDir.create(recursive: true);
  final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final file = File('${mediaDir.path}/f_${uid}_$safe');
  await file.writeAsBytes(bytes);
  return file.path;
}

Future<String> saveMediaBytes(List<int> bytes, String name) async {
  final dir = await getApplicationDocumentsDirectory();
  final mediaDir = Directory('${dir.path}/media');
  if (!await mediaDir.exists()) await mediaDir.create(recursive: true);
  final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final file = File('${mediaDir.path}/$safe.jpg');
  await file.writeAsBytes(bytes);
  return file.path;
}

String buildHaloUri(String id, String onion, String xpub) {
  return 'kryfo://share?id=$id&onion=$onion&xpub=$xpub';
}

Future<String> buildHaloUriV2(String id, String onion) async {
  final bundle = await makePreKeyBundleB64();
  return 'kryfo://share?id=$id&onion=$onion&v=2&bundle=$bundle';
}

// v3 carries a first-contact address alongside the bundle. without it the
// only way a stranger can introduce themselves is our onion, and when that
// will not publish a one-way scan silently never works.
Future<String> buildHaloUriV3(String id, String onion, int fcCounter) async {
  final bundle = await makePreKeyBundleB64();
  final fc = engine.firstContactPk(fcCounter);
  if (fc.isEmpty || fc.startsWith('error')) {
    return buildHaloUriV2(id, onion);
  }
  return 'kryfo://share?id=$id&onion=$onion&v=3&bundle=$bundle&fc=$fc';
}

Map<String, String>? parseHaloUri(String raw) {
  raw = raw.trim();
  if (!raw.startsWith('kryfo://share')) return null;
  try {
    final uri = Uri.parse(raw);
    final id = uri.queryParameters['id'];
    final onion = uri.queryParameters['onion'];
    if (id == null || onion == null) return null;
    final v = uri.queryParameters['v'] ?? '1';
    if (v == '3') {
      final bundle = uri.queryParameters['bundle'];
      if (bundle == null) return null;
      final out = {'id': id, 'onion': onion, 'bundle': bundle, 'v': '3'};
      final fc = uri.queryParameters['fc'];
      // an old build reading a v3 link still pairs, it just falls back to
      // onion-only first contact.
      if (fc != null && fc.length == 64) out['fc'] = fc;
      return out;
    }
    if (v == '2') {
      final bundle = uri.queryParameters['bundle'];
      if (bundle == null) return null;
      return {'id': id, 'onion': onion, 'bundle': bundle, 'v': '2'};
    }
    final xpub = uri.queryParameters['xpub'];
    if (xpub == null) return null;
    return {'id': id, 'onion': onion, 'xpub': xpub, 'v': '1'};
  } catch (_) {
    return null;
  }
}

// shared singletons + state

final engine = HaloEngine();
final db = HaloDb();

// open ChatScreen for a given kryfo id. used by notification taps
// (both warm - onDidReceiveNotificationResponse - and cold starts
// via getNotificationAppLaunchDetails). reads contact details from
// the db and pushes the route on the root navigator.
Future<void> openChatForHalo(String? haloId) async {
  if (haloId == null || haloId.isEmpty) return;
  final nav = rootNavKey.currentState;
  if (nav == null) return;
  final rows = await db.contacts();
  final matches = rows.where((r) => r['halo_id'] == haloId).toList();
  if (matches.isEmpty) return;
  final row = matches.first;
  if (haloId == currentChatPeer) return;
  nav.push(
    haloRoute(
      ChatScreen(
        peerHaloId: haloId,
        peerOnion: row['onion'] as String,
        peerXPub: row['xpub'] as String,
        avatarSeed: haloId,
      ),
    ),
  );
}

// kryfo id of the peer whose chat is currently on screen. set by
// ChatScreen.initState, cleared on dispose. used to suppress
// notifications for the conversation the user is already in.
String? currentChatPeer;

final GlobalKey<NavigatorState> rootNavKey = GlobalKey<NavigatorState>();

int _msgUidCounter = 0;
// stable cross-device message id. used by reactions + replies + group
// fan-out so every recipient sees the same uid. base36 timestamp + random.
String newMsgUid() {
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final r = (DateTime.now().microsecondsSinceEpoch ^ _msgUidCounter++)
      .abs()
      .toRadixString(36);
  return '${t.padLeft(8, '0').substring(0, 8)}${r.substring(0, 4).padLeft(4, '0')}';
}

class GroupPreview {
  final String groupId;
  final String name;
  final int memberCount;
  final bool isAdmin;
  final DateTime createdAt;
  final int unread;
  const GroupPreview({
    required this.groupId,
    required this.name,
    required this.memberCount,
    required this.isAdmin,
    required this.createdAt,
    this.unread = 0,
  });
}

class AppState extends ChangeNotifier {
  // uids being processed right now, to dedup near-simultaneous arrivals
  // (preview re-send racing a manual retry) before the db write lands.
  final Set<String> _inflightUids = <String>{};
  // previews that arrived before their message (fetch runs parallel to the
  // send now, so the frames can race). patched on right after the row saves.
  final Map<String, String> _pendingPreviews = {};
  // group media slices already accepted by at least one member, per msg_uid,
  // so tap-to-retry resumes instead of re-sending the whole file.
  final Map<String, Set<int>> _grpChunkDone = {};
  final Map<String, int> _grpChunkDoneAt = {};
  // uids the drainer is mid-flight on, so a slow send isn't fired twice by
  // the next sweep.
  final Set<String> _outboxInflight = <String>{};
  // re-fire count per uid this session. caps the loop so an unreachable peer
  // stops grinding; tap-to-retry in the chat still forces a send.
  final Map<String, int> _outboxTries = <String, int>{};
  // earliest ms a uid may be tried again. every retry builds a fresh gift
  // wrap, so a flat cadence leaves one copy per attempt sitting on every
  // relay forever - the receiver then decrypts and acks all of them.
  final Map<String, int> _outboxNextAt = <String, int>{};

  // how many messages are sitting unsent, and for whom. the offline strip
  // reads this so it can say "2 waiting" instead of just "offline".
  int _queued = 0;
  final Map<String, int> _queuedPerPeer = <String, int>{};
  int get queued => _queued;
  int queuedFor(String haloId) => _queuedPerPeer[haloId] ?? 0;
  Timer? _outboxTimer;
  bool _outboxWasReady = false;

  // start the outbox drainer. safe to call more than once.
  void startOutboxDrain() {
    _outboxTimer?.cancel();
    _outboxTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (haloWiping) return;
      unawaited(drainOutbox());
    });
  }

  // re-send anything the wire never confirmed. cheap when there's nothing to
  // do (one indexed query). skipped entirely while tor can't carry traffic.
  Future<void> drainOutbox() async {
    // torReady already knows the mode - outside onion there is nothing to
    // wait for and a queued message should just go.
    final ready = torReady;
    if (!ready) {
      _outboxWasReady = false;
      return;
    }
    _outboxWasReady = true;
    final rows = await db.unsentOutbox();
    if (rows.isEmpty) {
      if (_outboxTries.isNotEmpty) {
        _outboxTries.clear();
        _outboxNextAt.clear();
      }
      if (_queued != 0) {
        _queued = 0;
        _queuedPerPeer.clear();
        notifyListeners();
      }
      return;
    }
    _queued = rows.length;
    _queuedPerPeer.clear();
    for (final r in rows) {
      final to = r['to_halo_id'] as String?;
      if (to != null) _queuedPerPeer[to] = (_queuedPerPeer[to] ?? 0) + 1;
    }
    notifyListeners();
    // anything that landed since the last sweep stops costing us bookkeeping.
    final live = {for (final r in rows) r['msg_uid'] as String?};
    _outboxTries.removeWhere((k, _) => !live.contains(k));
    _outboxNextAt.removeWhere((k, _) => !live.contains(k));
    for (final r in rows) {
      final uid = r['msg_uid'] as String?;
      if (uid == null || _outboxInflight.contains(uid)) continue;
      // a send fired seconds ago still has its own future running; leave it be.
      final age = DateTime.now().millisecondsSinceEpoch - (r['sent_at'] as int);
      if (age < 45000) continue;
      final tries = _outboxTries[uid] ?? 0;
      if (tries >= 8) continue;
      final now = DateTime.now().millisecondsSinceEpoch;
      final nextAt = _outboxNextAt[uid];
      if (nextAt != null && now < nextAt) continue;
      // doubling gap, capped at ten minutes. eight tries now covers about an
      // hour instead of fifteen tries covering five, and leaves half as many
      // copies on the relays.
      var gap = 45000 << tries;
      if (gap > 600000) gap = 600000;
      _outboxNextAt[uid] = now + gap;
      _outboxTries[uid] = tries + 1;
      _outboxInflight.add(uid);
      unawaited(_drainOne(r).whenComplete(() => _outboxInflight.remove(uid)));
    }
  }

  Future<void> _drainOne(Map<String, Object?> r) async {
    final uid = r['msg_uid'] as String;
    final peer = r['peer_id'] as String;
    final groupId = r['group_id'] as String?;
    // media rows re-send through their own chunked path; text is what the
    // drainer owns. a stranded media row stays tap-to-retry in the chat.
    if ((r['media_path'] as String?) != null ||
        (r['file_path'] as String?) != null) {
      return;
    }
    try {
      final wrapped = await wrapMessage(
        r['plaintext'] as String,
        msgUid: uid,
        replyTo: r['reply_to'] as String?,
        groupId: groupId,
        supporterBadge: await sharedBadge(),
        sender: _mySender(),
      );
      if (groupId != null) {
        final members = await db.getGroupMembers(groupId);
        final results = await Future.wait([
          for (final m in members)
            if (m != myId) _sendOneEnvelope(m, wrapped),
        ]);
        if (results.any((ok) => ok)) {
          await db.markSent(uid);
          notifyListeners();
        }
        return;
      }
      final ok = await _sendOneEnvelope(peer, wrapped);
      if (ok) {
        debugPrint('OUTBOX: redelivered $uid');
        await db.markSent(uid);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('OUTBOX: $uid still stuck ($e)');
    }
  }

  // global send-privacy mode: 'private' | 'balanced' | 'fast'. private is
  // tor and is the default; the other two are pickable in the ui but don't
  // change routing yet - everything still goes over tor until the transport
  // work lands. 'normal' is the old name for private, migrated on load.
  String _sendMode = 'private';
  String get sendMode => _sendMode;

  Future<void> saveGhostPref(bool on, int secs) async {
    const s = FlutterSecureStorage();
    await s.write(key: 'ghost_on', value: on ? '1' : '0');
    await s.write(key: 'ghost_secs', value: '$secs');
  }

  Future<(bool, int)> loadGhostPref() async {
    const s = FlutterSecureStorage();
    final on = (await s.read(key: 'ghost_on')) == '1';
    final secs = int.tryParse(await s.read(key: 'ghost_secs') ?? '') ?? 300;
    return (on, secs);
  }

  Future<bool> loadDisguisePref() async {
    const s = FlutterSecureStorage();
    return (await s.read(key: 'disguise_on')) == '1';
  }

  Future<void> saveDisguisePref(bool on) async {
    const s = FlutterSecureStorage();
    await s.write(key: 'disguise_on', value: on ? '1' : '0');
  }

  // the handle we claimed, if any. local only - the registry is the source
  // of truth and this is just so the screen knows what to show.
  String? _myHandle;
  String? get myHandle => _myHandle;

  // the avatar someone picked, or null for the one their id produces. local
  // only - it is drawn from a number on every device that has the number, and
  // what they picked for themselves is nobody else's business.
  int? _myAvatar;
  int? get myAvatar => _myAvatar;

  Future<void> loadMyAvatar() async {
    final v = await const FlutterSecureStorage().read(key: 'my_avatar');
    _myAvatar = v == null ? null : int.tryParse(v);
    notifyListeners();
  }

  Future<void> setMyAvatar(int? v) async {
    _myAvatar = v;
    final st = const FlutterSecureStorage();
    if (v == null) {
      await st.delete(key: 'my_avatar');
    } else {
      await st.write(key: 'my_avatar', value: '$v');
    }
    notifyListeners();
  }

  Future<void> loadMyHandle() async {
    _myHandle = await const FlutterSecureStorage().read(key: 'my_handle');
    notifyListeners();
  }

  Future<void> setMyHandle(String? h) async {
    _myHandle = h;
    final st = const FlutterSecureStorage();
    if (h == null) {
      await st.delete(key: 'my_handle');
    } else {
      await st.write(key: 'my_handle', value: h);
    }
    notifyListeners();
  }

  Future<void> loadSendMode() async {
    _sendMode =
        await const FlutterSecureStorage().read(key: 'send_mode') ?? 'private';
    notifyListeners();
  }

  // private goes through tor to everything. balanced talks plain tls to our
  // own relay and nothing else, so only we see an ip. fast talks plain tls to
  // every relay, so they all do.
  static const _clearnetRelay = 'wss://relay.kryfo.app';
  // one list. two copies drift, and the drift is invisible until someone
  // cannot receive on one route.
  static const _publicRelays =
      'wss://nos.lol,wss://relay.primal.net,wss://nostr.mom,'
      'wss://nostr.oxtr.dev';

  String relaysFor(String mode) {
    switch (mode) {
      case 'balanced':
        return _clearnetRelay;
      case 'fast':
        return '$_clearnetRelay,$_publicRelays';
      default:
        return 'ws://z4waup3c6j6gknkjba72cqjjuffhgg6gtgqfu3vetzcvgoluvr42srid'
            '.onion,$_publicRelays';
    }
  }

  Future<void> setSendMode(String m) async {
    final changed = _sendMode != m;
    _sendMode = m;
    notifyListeners();
    await const FlutterSecureStorage().write(key: 'send_mode', value: m);
    if (!changed) return;
    // the engine caches one http client per route, so the mode has to land
    // before the relay list is rebuilt or the first connection uses the old
    // one.
    engine.setTransportMode(m);
    _nostrInitOnIsolate(relaysFor(m));
    for (final c in contacts) {
      await subscribePeer(c.haloId);
    }
    debugPrint('mode: $m, relays rebuilt');
  }

  String _displayName = '';
  String get displayName => _displayName;
  Future<void> loadDisplayName() async {
    _displayName =
        await const FlutterSecureStorage().read(key: 'display_name') ?? '';
    notifyListeners();
  }

  Future<void> setDisplayName(String name) async {
    _displayName = name;
    notifyListeners();
    await const FlutterSecureStorage().write(key: 'display_name', value: name);
  }

  static const _platformChannel = MethodChannel('halo/platform');
  bool _blockScreenshots = false;
  bool get blockScreenshots => _blockScreenshots;

  // when on, every chat screen sets FLAG_SECURE while it is open - so
  // screenshots of conversations are blocked on this phone whoever took them.
  // it protects a conversation only if both sides have it on, and a camera
  // pointed at the screen still works. the ui says so.
  bool _secureChats = false;
  bool get secureChats => _secureChats;

  // a chat currently showing a message the sender marked. their app asked
  // for this, and ours is the one that has to honour it - the same way
  // instagram and signal view-once work, because both ends run the same app.
  Future<void> setSecureChats(bool v) async {
    _secureChats = v;
    await const FlutterSecureStorage().write(
      key: 'secure_chats',
      value: v ? '1' : '0',
    );
    notifyListeners();
  }

  Future<void> loadScreenshotPref() async {
    _blockScreenshots =
        (await const FlutterSecureStorage().read(key: 'block_screenshots')) ==
        'true';
    _secureChats =
        (await const FlutterSecureStorage().read(key: 'secure_chats')) == '1';
    await _applyScreenSecure();
    notifyListeners();
  }

  Future<void> setBlockScreenshots(bool v) async {
    _blockScreenshots = v;
    notifyListeners();
    await const FlutterSecureStorage().write(
      key: 'block_screenshots',
      value: v.toString(),
    );
    await _applyScreenSecure();
  }

  Future<void> loadThemePref() async {
    try {
      final v =
          (await const FlutterSecureStorage().read(key: 'theme_light')) ==
          'true';
      HaloColors.setLight(v);
    } catch (_) {}
  }

  Future<void> setLight(bool v) async {
    HaloColors.setLight(v);
    themeRevision.value++;
    notifyListeners();
    await const FlutterSecureStorage().write(
      key: 'theme_light',
      value: v.toString(),
    );
  }

  // bridges. off by default, because they are slower and most people are not
  // being filtered - but the people who are cannot use kryfo at all without
  // them.
  bool _bridgesOn = false;
  String _bridgeLines = '';
  bool get bridgesOn => _bridgesOn;
  String get bridgeLines => _bridgeLines;

  Future<void> _loadBridges() async {
    const st = FlutterSecureStorage();
    _bridgeLines = await st.read(key: 'bridge_lines') ?? '';
    _bridgesOn = (await st.read(key: 'bridges_on')) == '1';
    _bridgeHintOff = (await st.read(key: 'bridge_hint_off')) == '1';
    if (_bridgesOn && _bridgeLines.isNotEmpty) {
      final r = engine.setBridges(_bridgeLines, true);
      debugPrint('bridges: $r');
    }
    notifyListeners();
  }

  // returns the engine's summary so the ui can say how many lines it liked.
  Future<String> applyBridges(String lines, bool on) async {
    _bridgeLines = lines;
    _bridgesOn = on;
    const st = FlutterSecureStorage();
    await st.write(key: 'bridge_lines', value: lines);
    await st.write(key: 'bridges_on', value: on ? '1' : '0');
    final r = engine.setBridges(lines, on);
    notifyListeners();
    return r;
  }

  // which first-contact address our invites currently point at. an invite can
  // end up in a bio or a screenshot, so it has to be retirable without
  // burning the identity - bumping this does exactly that and leaves every
  // existing conversation alone.
  int _fcCounter = 0;
  int get fcCounter => _fcCounter;

  // a stranger's first-contact address, kept only until they back-pair.
  // after that the normal per-conversation addresses take over.
  final Map<String, String> _peerFc = <String, String>{};

  Future<void> _loadFirstContact() async {
    const st = FlutterSecureStorage();
    _fcCounter = int.tryParse(await st.read(key: 'fc_counter') ?? '') ?? 0;
    try {
      final raw = await st.read(key: 'peer_fc');
      if (raw != null && raw.isNotEmpty) {
        (jsonDecode(raw) as Map<String, dynamic>).forEach((k, v) {
          _peerFc[k] = v as String;
        });
      }
    } catch (_) {}
    engine.subscribeFirstContactBg(_fcCounter);
    notifyListeners();
  }

  String? peerFcFor(String haloId) => _peerFc[haloId];

  Future<void> rememberPeerFc(String haloId, String fcPk) async {
    _peerFc[haloId] = fcPk;
    await const FlutterSecureStorage().write(
      key: 'peer_fc',
      value: jsonEncode(_peerFc),
    );
  }

  Future<void> forgetPeerFc(String haloId) async {
    if (_peerFc.remove(haloId) == null) return;
    await const FlutterSecureStorage().write(
      key: 'peer_fc',
      value: jsonEncode(_peerFc),
    );
  }

  // retires every invite handed out so far. contacts, sessions and history
  // are untouched; only the address strangers use to reach us moves.
  // the registry holds a copy of the invite, so a reset has to reach it or
  // the public page keeps handing out an address that no longer answers.
  Future<void> _repointHandle() async {
    final h = _myHandle;
    if (h == null) return;
    try {
      final uri = await buildHaloUriV3(myId, myOnion, _fcCounter);
      engine.handleClaim(h, uri, '');
    } catch (_) {
      // offline, or the registry is down. the handle stays claimed and
      // stale rather than lost, and the next claim fixes it.
    }
  }

  Future<void> resetInviteAddress() async {
    _fcCounter++;
    await const FlutterSecureStorage().write(
      key: 'fc_counter',
      value: '$_fcCounter',
    );
    engine.subscribeFirstContactBg(_fcCounter);
    await _repointHandle();
    notifyListeners();
  }

  // people lose accounts because nothing ever asked them to write the words
  // down. one card on home, dismissible, never shown again once they have a
  // backup or once they say no.
  bool _hasBackup = true;
  bool _nudgeOff = true;
  bool get showBackupNudge => !_hasBackup && !_nudgeOff;

  Future<void> _loadBackupFlags() async {
    const st = FlutterSecureStorage();
    _hasBackup = (await st.read(key: 'backup_made')) == '1';
    _nudgeOff = (await st.read(key: 'backup_nudge_off')) == '1';
    notifyListeners();
  }

  Future<void> markBackupMade() async {
    _hasBackup = true;
    await const FlutterSecureStorage().write(key: 'backup_made', value: '1');
    notifyListeners();
  }

  Future<void> dismissBackupNudge() async {
    _nudgeOff = true;
    await const FlutterSecureStorage().write(
      key: 'backup_nudge_off',
      value: '1',
    );
    notifyListeners();
  }

  // some screens are not optional. recovery shows the whole key, so it turns
  // the flag on whatever the user picked in settings, and hands it back on
  // the way out.
  bool _secureForced = false;
  Future<void> forceSecure(bool on) async {
    _secureForced = on;
    try {
      await _platformChannel.invokeMethod('setSecure', {
        'on': on || _blockScreenshots,
      });
    } catch (_) {}
  }

  Future<void> _applyScreenSecure() async {
    try {
      await _platformChannel.invokeMethod('setSecure', {
        'on': _blockScreenshots || _secureForced,
      });
    } catch (_) {}
  }

  NtfyListener? _ntfyListener;

  Future<void> applyPushMode(PushMode m) async {
    await savePushMode(m);
    if (m == PushMode.ntfy) {
      _ntfyListener ??= NtfyListener(
        onPing: () {},
        log: (msg) => debugPrint(msg),
      );
      await _ntfyListener!.start();
    } else {
      await _ntfyListener?.stop();
      _ntfyListener = null;
    }
  }

  // unified incoming routing. handles three payload variants:
  //   1) group control msg (no chat row, no notif)
  //   2) reaction       (add/remove on a target uid, no chat row, no notif)
  //   3) data message   (1:1 or group - save + maybe notify)
  // called from all three receive paths (back-pair-from-cipher, tor drain,
  // nostr poll) so the routing rules live in exactly one place.
  Future<void> _applyIncomingPayload(
    String senderHaloId,
    UnwrappedMessage env, {
    bool fromBackPair = false,
  }) async {
    _bumpChatRev(senderHaloId);
    if (env.groupId != null) _bumpChatRev('group:${env.groupId}');
    await db.markBackPaired(senderHaloId);
    debugPrint(
      'INCOMING len=${env.message.length} hasPreview=${env.preview != null} uid=${env.msgUid}',
    );
    // delivery receipt: the peer stored a message we sent. flip its tick and
    // stop the outbox chasing it. handled before the stranger gate + dedup so
    // an ack is never itself treated as a message or counted toward the cap.
    if (env.deliveredUid != null) {
      await db.markDelivered(env.deliveredUid!);
      _bumpChatRev(senderHaloId);
      notifyListeners();
      return;
    }
    if (await db.isBlocked(senderHaloId)) return;
    // 1) group control
    if (env.groupControl != null) {
      await _applyGroupControl(senderHaloId, env);
      return;
    }
    // shared pin - every member mirrors it
    if (env.pin != null) {
      await db.setPinned(env.pin!.targetUid, env.pin!.pinned);
      notifyListeners();
      return;
    }
    // 2) reaction
    if (env.reaction != null) {
      final r = env.reaction!;
      if (r.emoji.isEmpty) {
        await db.removeReaction(r.targetUid, senderHaloId);
      } else {
        await db.addReaction(r.targetUid, senderHaloId, r.emoji);
      }
      return;
    }
    // 2.5) edit - swap the text of an existing message
    if (env.edit != null) {
      await db.editMessage(env.edit!.targetUid, env.edit!.newText);
      notifyListeners();
      return;
    }
    // 2.6) unsend - sender recalled a message; delete our copy
    if (env.unsend != null) {
      await db.deleteMessage(env.unsend!);
      // a recall mid-transfer would otherwise leave a half-filled buffer and
      // a progress bar that never completes. drop both.
      if (await db.dropMediaChunks(env.unsend!) > 0) {
        incomingMediaDone(env.groupId != null ? env.groupId! : senderHaloId);
      }
      // refresh so it vanishes live if the peer's looking at the chat now,
      // not only after they leave and come back.
      notifyListeners();
      return;
    }
    // 3) data message - could be 1:1 or group
    final isGroup = env.groupId != null;
    if (isGroup && !await db.groupExists(env.groupId!)) {
      // unknown group - drop. prevents random senders from injecting rows
      // into groups we never joined.
      debugPrint('dropping group msg for unknown group ${env.groupId}');
      return;
    }
    // badge rides real chat rows only. present = set, absent = clear so
    // turning it off propagates. control frames and preview patches never
    // get here with a fresh row, so they can't wipe it.
    if (env.preview == null && env.msgUid != null) {
      await db.setContactBadge(senderHaloId, env.supporterBadge);
    }
    // roster self-heal: if the admin rode their full member list on this
    // message and our copy drifted, reconcile. only trust it from the real
    // admin so a member can't rewrite membership by spoofing a roster.
    if (isGroup && env.roster != null) {
      final adminId = await db.groupAdminId(env.groupId!);
      if (adminId != null && senderHaloId == adminId) {
        await db.syncGroupMembers(env.groupId!, env.roster!);
        // create contact stubs for self-healed members so we can actually
        // encrypt to them - ids alone aren't enough, we need their keys.
        if (env.rosterParticipants != null) {
          for (final p in env.rosterParticipants!) {
            final h = p['h'];
            final o = p['o'];
            final x = p['x'];
            if (h != null && o != null && x != null && h != myId) {
              await db.upsertContactStub(h, o, x);
            }
          }
          await refreshContacts();
        }
      }
    }
    // stranger lock + proof-of-work gate (1:1 only, unaccepted senders).
    if (!isGroup && !await db.isAccepted(senderHaloId)) {
      // pow: only the back-pair message (true first contact) must carry a
      // valid nonce - that's the one lane a cold stranger can arrive on. a
      // whisper through an existing session already paid pow once, and a
      // deleted peer's client has no idea it needs to grind again. drop
      // silently - the spammer learns nothing.
      if (fromBackPair &&
          (env.powNonce == null ||
              !verifyPow(env.message, env.powNonce!, powBits))) {
        debugPrint(
          'pow: dropping first-contact from $senderHaloId (nonce=${env.powNonce} bits=${env.powBitsUsed})',
        );
        return;
      }
      // 2-message cap: a stranger gets 2 into requests, then the chat is locked
      // until we accept them. drop past the cap - no receipt.
      final have = await db.countMessagesFrom(senderHaloId);
      if (have >= 2) {
        debugPrint('stranger lock: dropping from $senderHaloId (cap hit)');
        return;
      }
    }
    // chunked media: a big image/file arrives as several envelopes sharing one
    // mediaId. buffer the slices until all chunkTotal are in, then rebuild the
    // full base64. single-chunk (or unchunked) media skips this entirely.
    String? imgB64 = env.imageB64;
    String? fileB64v = env.fileB64;
    // burn seconds can ride on any slice (older senders only put it on the
    // first). hold onto whichever one carried it so the rebuilt message keeps
    // its timer instead of landing permanent on the receiver.
    int? chunkBurn = env.burnSeconds;
    if (env.mediaId != null && env.chunkTotal != null && env.chunkTotal! > 1) {
      final mid = env.mediaId!;
      final progressKey = isGroup ? env.groupId! : senderHaloId;
      final slice = (env.imageB64 ?? env.fileB64) ?? '';
      // slices land on disk as they arrive, so closing the app mid-transfer
      // no longer throws the partial away. the count is over rows, which is
      // what makes a restart resume instead of start over.
      final have = await db.putMediaChunk(
        mid,
        env.chunkIndex ?? 0,
        slice,
        env.chunkTotal!,
        (env.burnSeconds != null && env.burnSeconds! > 0)
            ? env.burnSeconds
            : null,
      );
      chunkBurn = await db.mediaChunkBurn(mid) ?? chunkBurn;
      if (have < env.chunkTotal!) {
        // still waiting on more pieces - surface how far along we are.
        incomingMediaUpdate(progressKey, have, env.chunkTotal!);
        return;
      }
      // all pieces in: stitch them back in index order.
      final full = StringBuffer();
      for (final part in await db.mediaChunkSlices(mid)) {
        full.write(part);
      }
      await db.dropMediaChunks(mid);
      incomingMediaDone(progressKey);
      // preview thumbnail: reassembled chunks patch onto the card of the
      // message with this uid, not a new media bubble. update + refresh, done.
      if (env.pvImg && env.msgUid != null) {
        final existing = await db.getMsgPreview(env.msgUid!);
        final pv = existing != null
            ? Map<String, String>.from(jsonDecode(existing) as Map)
            : <String, String>{};
        pv['img'] = full.toString();
        await db.setMsgPreview(env.msgUid!, jsonEncode(pv));
        await refreshContacts();
        return;
      }
      // which field it belonged to: file if a name was sent, else image.
      if (env.fileName != null) {
        fileB64v = full.toString();
      } else {
        imgB64 = full.toString();
      }
    }
    String? mediaPath;
    if (imgB64 != null && imgB64.isNotEmpty) {
      try {
        mediaPath = await saveMediaBytes(
          base64Decode(imgB64),
          env.msgUid ?? DateTime.now().millisecondsSinceEpoch.toString(),
        );
      } catch (_) {}
    }
    String? filePath;
    final fileName = env.fileName;
    if (fileB64v != null && fileB64v.isNotEmpty) {
      try {
        filePath = await saveFileBytes(
          base64Decode(fileB64v),
          env.msgUid ?? DateTime.now().millisecondsSinceEpoch.toString(),
          fileName ?? 'file',
        );
      } catch (_) {}
    }
    // dedup: a message can arrive twice - the original, then the preview re-send
    // (option A), and sometimes a manual retry too. the db check alone races when
    // two copies arrive in the same instant (both pass before either saves), so
    // we also hold an in-memory set of uids currently being processed. first one
    // in claims the uid; any twin takes the update path instead of inserting.
    final uid = env.msgUid;
    if (uid != null) {
      final known = _inflightUids.contains(uid) || await db.messageExists(uid);
      // preview-only frame that beat its message here: saving it as a row
      // would swallow the real text when it lands. stash and patch later.
      final previewOnly =
          env.preview != null &&
          env.message.isEmpty &&
          env.imageB64 == null &&
          env.fileB64 == null;
      if (previewOnly && !known) {
        _pendingPreviews[uid] = jsonEncode(env.preview);
        return;
      }
      if (known) {
        if (env.preview != null) {
          await db.setMsgPreview(uid, jsonEncode(env.preview));
        }
        // already have it, but a re-send means our receipt never landed. ack
        // again so the sender's tick flips and the outbox stops redelivering.
        if (!isGroup &&
            env.deliveredUid == null &&
            env.reaction == null &&
            env.edit == null &&
            senderHaloId != myId) {
          unawaited(_sendDeliveryReceipt(senderHaloId, uid));
        }
        notifyListeners();
        return;
      }
      _inflightUids.add(uid);
    }
    // a stranger doesn't get to set disappearing rules in the inbox: burned
    // rows refund the 2-message cap and can vanish before the request is even
    // seen. burn only counts once they're accepted.
    // a deleted (parked) peer writing again surfaces as a fresh request.
    if (!isGroup) await db.unparkIfArchived(senderHaloId);
    final burnOk = isGroup || await db.isAccepted(senderHaloId);
    await db.saveMessage(
      senderHaloId,
      'in',
      env.message,
      burnAt: burnOk && chunkBurn != null && chunkBurn > 0
          ? DateTime.now().millisecondsSinceEpoch + chunkBurn * 1000
          : null,
      msgUid: env.msgUid,
      replyTo: env.replyTo,
      groupId: env.groupId,
      voiceDisguised: env.voiceDisguised,
      mediaPath: mediaPath,
      filePath: filePath,
      fileName: fileName,
      preview: env.preview != null ? jsonEncode(env.preview) : null,
      secure: env.secure,
    );
    // a preview that raced ahead of this message was stashed - patch it on.
    if (uid != null) {
      final pending = _pendingPreviews.remove(uid);
      if (pending != null) await db.setMsgPreview(uid, pending);
      // saved now, messageExists covers dedup from here - drop the guard
      _inflightUids.remove(uid);
    }
    // send a delivery receipt back for 1:1 messages we just stored, so the
    // sender's tick means "on your phone" not "a relay took it". groups skip
    // this (N acks per message is noise); receipts themselves carry no uid of
    // their own and are handled before any gate on the far side.
    if (!isGroup && uid != null && senderHaloId != myId) {
      unawaited(_sendDeliveryReceipt(senderHaloId, uid));
    }
    // notification context - for groups, title = group name and body
    // prefixes the sender. payload uses "group:<id>" so tap-to-open can
    // route to the right screen.
    if (!isGroup && currentChatPeer != senderHaloId) {
      await db.bumpUnread(senderHaloId);
    } else if (!isGroup && currentChatPeer == senderHaloId) {
      // already reading this chat - clear any stale badge instead of leaving it.
      await db.clearUnread(senderHaloId);
    } else if (isGroup && env.groupId != null) {
      final openGroup = 'group:${env.groupId}';
      if (currentChatPeer != openGroup) {
        await db.bumpGroupUnread(env.groupId!);
      } else {
        await db.clearGroupUnread(env.groupId!);
      }
    }
    // a message landed: rebuild the contact list so the home shows the
    // new preview, time and unread dot without needing the chat opened.
    await refreshContacts();
    if (isGroup) await refreshGroups();
    final String notifTitle;
    final String notifBody;
    final String notifPayload;
    final bool suppress;
    if (isGroup) {
      final g = await db.getGroup(env.groupId!);
      notifTitle = (g?['name'] as String?) ?? 'group';
      final gBody = env.message.isNotEmpty
          ? env.message
          : (fileName == 'voice.wav'
                ? 'voice message'
                : fileName != null
                ? fileName
                : (mediaPath != null ? 'photo' : ''));
      notifBody = '$senderHaloId: $gBody';
      notifPayload = 'group:${env.groupId}';
      suppress = currentChatPeer == notifPayload;
    } else {
      notifTitle = senderHaloId;
      notifBody = env.message.isNotEmpty
          ? env.message
          : (fileName != null
                ? fileName
                : (mediaPath != null ? 'photo' : env.message));
      notifPayload = senderHaloId;
      suppress =
          currentChatPeer == senderHaloId || await db.isMuted(senderHaloId);
    }
    if (!suppress) {
      await showMessageNotification(
        title: notifTitle,
        body: notifBody,
        payload: notifPayload,
      );
    }
  }

  // apply a group control message. sender is the kryfo id that sent the
  // control; env.groupId is the target group; env.groupControl carries the
  // action and payload.
  Future<void> _applyGroupControl(
    String senderHaloId,
    UnwrappedMessage env,
  ) async {
    final gc = env.groupControl!;
    final groupId = env.groupId;
    if (groupId == null) return;
    switch (gc.type) {
      case 'create':
        // someone added us to a new group. they are the admin; we are
        // a regular member. group.is_admin stays 0.
        if (gc.members == null || gc.name == null) return;
        if (!await db.groupExists(groupId)) {
          await db.createGroup(
            groupId,
            gc.name!,
            gc.members!,
            isAdmin: false,
            adminId: senderHaloId,
          );
        } else {
          // already in the group - reconcile the member list so a re-add or
          // membership change syncs instead of leaving a stale count.
          await db.syncGroupMembers(groupId, gc.members!);
          await db.renameGroup(groupId, gc.name!);
        }
        // auto-create contact stubs for unknown participants so we can
        // immediately send to them.
        if (gc.participants != null) {
          for (final p in gc.participants!) {
            final h = p['h'];
            final o = p['o'];
            final x = p['x'];
            if (h != null && o != null && x != null && h != myId) {
              await db.upsertContactStub(h, o, x);
            }
          }
        }
        await refreshContacts();
        await refreshGroups();
        break;
      case 'add':
        if (gc.members == null) return;
        for (final h in gc.members!) {
          await db.addGroupMember(groupId, h);
        }
        if (gc.participants != null) {
          for (final p in gc.participants!) {
            final h = p['h'];
            final o = p['o'];
            final x = p['x'];
            if (h != null && o != null && x != null && h != myId) {
              await db.upsertContactStub(h, o, x);
            }
          }
        }
        await refreshContacts();
        await refreshGroups();
        break;
      case 'remove':
        if (gc.members == null) return;
        for (final h in gc.members!) {
          await db.removeGroupMember(groupId, h);
          // removed person drops the whole group locally so it leaves
          // their list and they stop multicasting into it.
          if (h == myId) await db.deleteGroup(groupId);
        }
        await refreshGroups();
        break;
      case 'rename':
        if (gc.name == null) return;
        await db.renameGroup(groupId, gc.name!);
        await refreshGroups();
        break;
      case 'leave':
        await db.removeGroupMember(groupId, senderHaloId);
        await refreshGroups();
        break;
    }
  }

  Future<void> applyNtfyServerChange(String url) async {
    await saveNtfyServer(url);
    if (_ntfyListener != null) {
      await _ntfyListener!.stop();
      _ntfyListener = NtfyListener(
        onPing: () {},
        log: (msg) => debugPrint(msg),
      );
      await _ntfyListener!.start();
    }
  }

  bool onboardingComplete = false;
  late AppLinks _appLinks;
  String myId = '';
  String myOnion = '';
  List<GroupPreview> groups = [];
  String myXPub = '';
  bool restored = false;
  bool ready = false;
  bool _booting = false;
  // live tor state; the home kryfo breathes off this.
  // bumped whenever something changes for a peer's thread. open chats
  // compare against this instead of reloading on every notify.
  final Map<String, int> _chatRev = {};
  int chatRevOf(String haloId) => _chatRev[haloId] ?? 0;
  void _bumpChatRev(String haloId) {
    _chatRev[haloId] = (_chatRev[haloId] ?? 0) + 1;
  }

  bool _draining = false;
  bool _polling = false;
  TorStatus _torStatus = TorStatus.off;
  int _bootstrapPct = 0;
  TorStatus get torStatus => _torStatus;

  // called from the status poll. the clock runs while tor is trying and
  // resets the moment it can carry traffic.
  void _noteTorProgress() {
    // the transport state carries the subscription count; a relay that is up
    // has at least one.
    try {
      final tx = engine.transportState();
      _noteRelayHealth(tx['sub_count'] as int? ?? 0);
    } catch (_) {
      // transport not readable yet - nothing to conclude
    }
    if (_bootstrapPct != _lastPct) {
      _lastPct = _bootstrapPct;
      _pctMovedAt = DateTime.now();
    }
    if (torReady) {
      _torTryingSince = null;
    } else {
      _torTryingSince ??= DateTime.now();
    }
  }

  // tor can carry traffic. same test the outbox uses, exposed so the
  // transport screen and the ui agree instead of each deciding for itself.
  // mirrors torReadyNow() in the engine. outside onion nothing is waiting on
  // a bootstrap, so "ready" is simply whether we have a network - otherwise
  // the stale-send reaper never runs in relay mode and failed sends sit
  // frozen with no way to retry them.
  bool get torReady =>
      _sendMode != 'private' ||
      _torStatus == TorStatus.bootstrapped ||
      _torStatus == TorStatus.publishing ||
      _torStatus == TorStatus.reachable;
  int get bootstrapPct => _bootstrapPct;
  // when tor first started trying this session. a network that
  // blocks tor looks exactly like a slow one for the first
  // minute or two, so we wait before suggesting anything.
  DateTime? _torTryingSince;
  bool _bridgeHintOff = false;
  // when the bootstrap percentage last moved. a climbing bar is a slow
  // network; a stuck one under half way is a blocked one.
  int _lastPct = -1;
  DateTime? _pctMovedAt;

  bool get _torLooksBlocked {
    if (_sendMode != 'private') return false;
    if (torReady) return false;
    final t = _torTryingSince;
    if (t == null) return false;
    // still early - give it room before calling anything wrong
    if (DateTime.now().difference(t).inSeconds < 120) return false;
    // it is climbing, just not quickly. that is a slow network, not a wall.
    final moved = _pctMovedAt;
    if (moved != null && DateTime.now().difference(moved).inSeconds < 90) {
      return false;
    }
    // past halfway it is talking to the network fine and something else is
    // wrong. blocking bites at the start, not the end.
    return _bootstrapPct < 50;
  }

  bool get suggestBridges {
    if (_bridgeHintOff || _bridgesOn || !_online) return false;
    return _torLooksBlocked;
  }

  // bridges are on and tor still cannot connect. bridges are slower and some
  // of them are simply dead, so the honest suggestion is to try without.
  // our relay is not answering and it is the only one relay mode uses.
  DateTime? _relayDownSince;
  bool _relayHintOff = false;

  bool get suggestFastFallback {
    if (_relayHintOff || _sendMode != 'balanced' || !_online) return false;
    final t = _relayDownSince;
    if (t == null) return false;
    return DateTime.now().difference(t).inSeconds > 90;
  }

  Future<void> dismissRelayHint() async {
    _relayHintOff = true;
    notifyListeners();
  }

  // fed by the transport poll: subscriptions are the honest signal that our
  // relay is actually answering.
  void _noteRelayHealth(int subs) {
    if (_sendMode != 'balanced') {
      _relayDownSince = null;
      return;
    }
    if (subs > 0) {
      _relayDownSince = null;
    } else {
      _relayDownSince ??= DateTime.now();
    }
  }

  bool get suggestBridgesOff {
    if (!_bridgesOn || !_online) return false;
    return _torLooksBlocked;
  }

  Future<void> dismissBridgeHint() async {
    _bridgeHintOff = true;
    await const FlutterSecureStorage().write(
      key: 'bridge_hint_off',
      value: '1',
    );
    notifyListeners();
  }

  bool _online = true;
  bool get online => _online;
  List<ContactPreview> contacts = [];
  int pendingCount = 0;
  final Map<String, String> _xPubToHaloId = {};
  // bundle-exchange heal state: peers we asked for a fresh bundle, ctl
  // rate-limit stamps, and per-cipher decrypt-failure strikes so relay
  // backlog replays get buried instead of bad-mac spamming forever.
  final Set<String> _healPending = {};
  final Map<String, int> _bundleCtlSentAt = {};
  final Map<String, int> _decryptFails = {};

  // relay backlog replays any cipher we can't land on every reconnect. give
  // it 3 lifetime chances (a session may still be forming), then mark it
  // seen so it stops bad-mac spamming every contact on every poll.
  void _strikeUndecryptable(String h, String lane) {
    final tries = (_decryptFails[h] ?? 0) + 1;
    _decryptFails[h] = tries;
    if (tries >= 3) {
      _decryptFails.remove(h);
      unawaited(db.markSeenLong(h));
      debugPrint('$lane: buried undecryptable after $tries tries');
    } else if (_decryptFails.length > 512) {
      _decryptFails.clear();
    }
  }

  // when an unknown sender's PreKey message arrives via
  // direct onion, decrypt under a placeholder peerId, then verify the
  // sender's claimed identity (via envelope) and move the libsignal
  // session to the real HaloID.
  Future<String?> backPairFromCipher(String cipher) async {
    const tempPeer = '_pending_back_pair_';
    final tempAddr = SignalProtocolAddress(tempPeer, 1);
    try {
      // always start clean: a leftover temp session or parked identity from
      // a prior pairing would poison this prekey decrypt.
      await signalSession.sessionStore.deleteSession(tempAddr);
      await signalSession.identityStore.removePeerIdentity(tempAddr);
      final plain = await signalDecrypt(tempPeer, cipher);
      if (plain == null) {
        await signalSession.sessionStore.deleteSession(tempAddr);
        return null;
      }
      final env = unwrapMessage(plain);
      final h = env.senderHaloId;
      final e = env.senderEdPub;
      if (h == null || e == null) {
        await signalSession.sessionStore.deleteSession(tempAddr);
        debugPrint('back-pair: envelope missing identity fields');
        return null;
      }
      final derived = engine.idFromEdPub(e);
      if (derived != h) {
        await signalSession.sessionStore.deleteSession(tempAddr);
        debugPrint('back-pair: HaloID mismatch');
        return null;
      }
      // move session from temp to real HaloID
      final record = await signalSession.sessionStore.loadSession(tempAddr);
      final realAddr = SignalProtocolAddress(h, 1);
      await signalSession.sessionStore.storeSession(realAddr, record);
      await signalSession.sessionStore.deleteSession(tempAddr);
      // persist contact + nostr sub. a stranger who back-paired to us lands
      // unaccepted - their message waits in requests until we accept.
      await db.upsertContact(
        h,
        env.senderOnion ?? '',
        env.senderXPub ?? '',
        accepted: 0,
      );
      if (env.senderXPub != null && env.senderXPub!.isNotEmpty) {
        _xPubToHaloId[env.senderXPub!] = h;
        engine.nostrSubscribeBg(env.senderXPub!);
      }
      if (env.endpoint != null) {
        await savePeerEndpoint(h, env.endpoint!);
      }
      await _applyIncomingPayload(h, env, fromBackPair: true);
      await refreshContacts();
      notifyListeners();
      await forgetPeerFc(h);
      debugPrint('back-pair: created contact for $h');
      return h;
    } catch (e) {
      debugPrint('back-pair error: $e');
      try {
        await signalSession.sessionStore.deleteSession(tempAddr);
      } catch (_) {}
      return null;
    }
  }

  Future<Map<String, String>> _loadXPubCache() async {
    try {
      final raw = await const FlutterSecureStorage().read(key: 'xpub_cache');
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveXPubCache(Map<String, String> cache) async {
    try {
      await const FlutterSecureStorage().write(
        key: 'xpub_cache',
        value: jsonEncode(cache),
      );
    } catch (_) {}
  }

  Future<void> boot() async {
    final _bsw = Stopwatch()..start();
    // both _OnboardingGate and _RootShell call boot() on cold start, before
    // ready flips. without this guard they raced through generateIdentity +
    // db open together and froze a fresh-wipe launch solid.
    if (ready || _booting) return;
    _booting = true;
    // let the splash paint one frame before any heavy native call. sqlcipher
    // key derivation + the first go ffi hop block the ui thread long enough
    // that android's anr watchdog fired on weak phones during cold start.
    await Future.delayed(const Duration(milliseconds: 16));
    final docsDir = await getApplicationDocumentsDirectory();
    final saved = await db.loadIdentity();
    if (saved != null) {
      myId = engine.restoreIdentity(saved['ed_priv']!, saved['x_priv']!);
      restored = true;
    } else {
      myId = engine.generateIdentity();
      await db.saveIdentity(myId, engine.myEdPrivkey(), engine.myXPrivkey());
    }
    myXPub = engine.myXPubkey();
    debugPrint('BOOT identity +${_bsw.elapsedMilliseconds}ms');
    _appLinks = AppLinks();
    _appLinks.uriLinkStream.listen((uri) async {
      if (uri.scheme == 'kryfo') {
        final result = await handleHaloUri(uri.toString());
        debugPrint('deep link: $result');
        await refreshContacts();
        notifyListeners();
      }
    });
    // the stream only fires while we're already running. a link tapped with
    // kryfo closed cold-starts the app and would otherwise be dropped.
    unawaited(
      _appLinks
          .getInitialLink()
          .then((uri) async {
            if (uri == null || uri.scheme != 'kryfo') return;
            final result = await handleHaloUri(uri.toString());
            debugPrint('deep link (cold start): $result');
            await refreshContacts();
            notifyListeners();
          })
          .catchError((Object e) {
            debugPrint('deep link (cold start) failed: $e');
          }),
    );

    await refreshContacts();
    debugPrint('BOOT contacts +${_bsw.elapsedMilliseconds}ms');
    await refreshGroups();
    debugPrint('BOOT groups +${_bsw.elapsedMilliseconds}ms');
    // paint the home as soon as contacts/groups are ready; notifications,
    // nostr subscriptions and ntfy keep warming up in the background.
    onboardingComplete =
        (await const FlutterSecureStorage().read(key: 'onboarding_done')) ==
        'true';
    // let the onion linger a beat before the home appears
    if (onboardingComplete) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
    ready = true;
    debugPrint('BOOT ready +${_bsw.elapsedMilliseconds}ms');
    notifyListeners();
    // signal prekey gen is cpu-heavy (~5s on a fresh identity) and nothing
    // above needs it - defer it so the home paints first. tor + nostr also
    // start after this, and both take longer to warm than the prekeys, so
    // the session is ready well before any message can arrive.
    _bootSignal().then((_) => debugPrint('BOOT signal (deferred) done'));
    // outbox drainer: anything the wire never confirmed gets re-sent for the
    // life of the app, whatever screen you're on and across restarts.
    startOutboxDrain();
    _loadBackupFlags();
    await _loadBridges();
    // drop week-old partial transfers nobody ever completed.
    unawaited(db.sweepMediaChunks());
    // start tor last, after all sync identity + signal work. nothing
    // above needs it, and starting it earlier stalled the main thread
    // while tor bootstrapped.
    _startListenerOnIsolate(docsDir.path).then((addr) {
      if (addr.isNotEmpty && !addr.startsWith('error')) {
        myOnion = addr;
        notifyListeners();
      }
    });
    // poll bootstrap so the kryfo can breathe while the listener warms up.
    // this used to cancel itself once tor went green - which meant a tor
    // death later on had no witness and no comeback. now it runs for the
    // life of the app and doubles as the watchdog.
    var torKickedAt = DateTime.now();
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (haloWiping) return;
      final raw = engine.getStatus();
      final st = parseTorStatus(raw);
      final pct = parseBootstrapPct(raw);
      if (st != _torStatus || pct != _bootstrapPct) {
        _torStatus = st;
        _noteTorProgress();
        _bootstrapPct = pct;
        notifyListeners();
      }
      // tor just became usable: flush anything the outbox is holding instead
      // of waiting out the next 20s tick.
      final nowReady =
          st == TorStatus.bootstrapped ||
          st == TorStatus.publishing ||
          st == TorStatus.reachable;
      if (nowReady && !_outboxWasReady) unawaited(drainOutbox());
      // tor died or never came up in this process. nothing else
      // restarts it, so we do. throttled - a start takes a while.
      if (st == TorStatus.off &&
          DateTime.now().difference(torKickedAt).inSeconds > 45) {
        torKickedAt = DateTime.now();
        debugPrint('TOR_WATCHDOG: tor off, restarting listener');
        _startListenerOnIsolate(docsDir.path).then((addr) {
          if (addr.isNotEmpty && !addr.startsWith('error')) {
            myOnion = addr;
            notifyListeners();
          }
        });
      }
    });
    _initConnectivity();
    // spares are worth having - one live relay holding every offline message
    // is how a bad night turns into lost mail. but a relay that never answers
    // is not a spare, it is a tor circuit burned every ten seconds. damus
    // returned 503 on fifty-three straight attempts and snort tls-timed-out
    // on every one, so both are out. the engine benches the rest on its own
    // if they start behaving the same way.
    // read the saved mode before anything touches the network, tell the
    // engine, and pick the matching relay list. doing this after would start
    // every session on tor regardless of what the person chose.
    await loadSendMode();
    await loadMyHandle();
    await loadMyAvatar();
    // 'normal' was the old name for private. migrating here rather than on
    // the modes screen means the rest of the app never sees it.
    if (_sendMode == 'normal') await setSendMode('private');
    engine.setTransportMode(_sendMode);
    debugPrint('transport: booting in $_sendMode');
    _nostrInitOnIsolate(relaysFor(_sendMode));
    // has to follow the relay list: the runner snapshots it on start and
    // gives up if it is empty.
    _loadFirstContact();
    await loadDisplayName();
    await loadScreenshotPref();
    await initNotifications(onTap: openChatForHalo);

    // periodic sweep: delete messages whose burn_at has passed.
    Timer.periodic(const Duration(seconds: 5), (_) async {
      if (haloWiping) return;
      try {
        await db.purgeExpired();
      } catch (_) {}
    });
    // warm up signal sessions + nostr subs after the first frame. a cached
    // xpub→haloId map (encrypted) lets returning users skip the per-contact
    // crypto entirely; only uncached contacts hit the heavy lookup.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      // subscribe off the xpub stored on the contact row - the same key the
      // send path uses. the old version asked the signal store for it, which
      // returns null until a session exists, so the side that got *scanned*
      // never subscribed and could never receive the first message that
      // would have created the session. deadlock. (the store
      // does eventually hold the right x25519 key - kryfo derives the signal
      // identity from it - but not until that first message exists.)
      final rows = await db.contacts();
      final fresh = <String, String>{};
      for (final r in rows) {
        final haloId = r['halo_id'] as String?;
        if (haloId == null) continue;
        var xPub = r['xpub'] as String?;
        // v2 bundle pairing stores an empty xpub on the row - the key only
        // lands in the signal store, which processPeerBundle fills at pair
        // time. v1 stores it on the row and has no session yet. take
        // whichever exists, then backfill the row so the next boot is cheap.
        if (xPub == null || xPub.isEmpty) {
          xPub = await signalSession.peerXPubHex(haloId);
          if (xPub != null && xPub.isNotEmpty) {
            await db.setContactXPub(haloId, xPub);
          }
        }
        if (xPub == null || xPub.isEmpty) continue;
        _xPubToHaloId[xPub] = haloId;
        engine.nostrSubscribeBg(xPub);
        fresh[xPub] = haloId;
      }
      await _saveXPubCache(fresh);
    });
    // open ntfy websocket when push mode is ntfy. on incoming
    // ping, the existing 1s drain loop catches up - we just log for now.
    final mode = await loadPushMode();
    if (mode == PushMode.ntfy) {
      _ntfyListener = NtfyListener(onPing: () {}, log: (m) => debugPrint(m));
      _ntfyListener!.start();
    }

    // continuous drain of direct-onion inbox. handles back-
    // pair from strangers + falls back to trial-decrypt against known
    // contacts for in-session direct-onion messages.
    Timer.periodic(const Duration(seconds: 1), (_) async {
      if (haloWiping) return;
      // reentrancy guard: the ffi drain + decrypt can outrun the 1s tick
      // while tor is still warming, and stacked calls pinned the main
      // thread hard enough to anr on weak phones. skip if one's running.
      // draining our own onion inbox only needs tor's client side (up at
      // bootstrapped) - the bytes are already sitting in the go inbox. it
      // does NOT need our own onion published, so don't wait for reachable
      // or a message that landed while still publishing sits unread.
      if (_sendMode == 'private' &&
          _torStatus != TorStatus.reachable &&
          _torStatus != TorStatus.bootstrapped &&
          _torStatus != TorStatus.publishing) {
        return;
      }
      if (_draining) return;
      _draining = true;
      try {
        final ciphers = engine.drainInbox();
        if (ciphers.isEmpty) return;
        for (final cipher in ciphers) {
          // dedup: same msg can arrive twice (tor late + nostr, or a retry).
          // the first copy consumes the one-time prekey; a duplicate would
          // crash on it, so skip anything we've already handled.
          final h = sha256.convert(utf8.encode(cipher)).toString();
          if (await db.alreadySeen(h)) continue;
          if (cipher.startsWith('{')) {
            // ctl frames only ride the authenticated relay lane. raw json
            // in the onion inbox is junk - bury it without trial decrypts.
            _strikeUndecryptable(h, 'drain');
            continue;
          }
          var handled = false;
          for (final c in contacts) {
            final plain = await signalDecrypt(c.haloId, cipher);
            if (plain != null) {
              final env = unwrapMessage(plain);
              if (env.endpoint != null) {
                await savePeerEndpoint(c.haloId, env.endpoint!);
              }
              await _applyIncomingPayload(c.haloId, env);
              notifyListeners();
              handled = true;
              break;
            }
          }
          if (!handled) {
            // request contacts sit outside the accepted list - try them before
            // treating this as a brand new stranger.
            for (final r in await db.pendingRequests()) {
              final id = r['halo_id'] as String;
              final plain = await signalDecrypt(id, cipher);
              if (plain != null) {
                final env = unwrapMessage(plain);
                await _applyIncomingPayload(id, env);
                notifyListeners();
                handled = true;
                break;
              }
            }
          }
          if (!handled) {
            // a peer we deleted keeps its session but loses its contact row,
            // so the loops above skip it. their next msg is a plain whisper
            // back-pair can't rebuild - try any sessioned address that isn't
            // a live contact, and re-file it as a fresh request.
            final liveIds = contacts.map((c) => c.haloId).toSet();
            for (final addr
                in await signalSession.sessionStore.allSessionAddresses()) {
              if (liveIds.contains(addr) || addr == '_pending_back_pair_') {
                continue;
              }
              final plain = await signalDecrypt(addr, cipher);
              if (plain != null) {
                final env = unwrapMessage(plain);
                await db.upsertContact(
                  addr,
                  env.senderOnion ?? '',
                  env.senderXPub ?? '',
                  accepted: 0,
                );
                if (env.senderXPub != null && env.senderXPub!.isNotEmpty) {
                  _xPubToHaloId[env.senderXPub!] = addr;
                }
                await _applyIncomingPayload(addr, env);
                await refreshContacts();
                notifyListeners();
                handled = true;
                debugPrint('drain: recovered deleted peer $addr into requests');
                break;
              }
            }
          }
          if (!handled && _isPreKeyWire(cipher)) {
            final paired = await backPairFromCipher(cipher);
            handled = paired != null;
            debugPrint(
              'drain: back-pair ${paired != null ? "ok $paired" : "failed"}',
            );
          }
          // only now is it safe to burn the dedup hash: the prekey is spent
          // and the message is filed. an unhandled cipher stays un-seen so a
          // later pass (or the relay replay) can still land it.
          if (handled) {
            await db.markSeen(h);
          } else {
            _strikeUndecryptable(h, 'drain');
          }
        }
      } finally {
        _draining = false;
      }
    });

    Timer.periodic(const Duration(seconds: 1), (_) async {
      if (haloWiping) return;
      // reading mail off a relay only needs tor's client side, which is up at
      // bootstrapped. this used to wait for `reachable` - our own onion being
      // published - which is a different thing entirely and minutes later.
      // queued messages just sat there while the app looked connected.
      if (_sendMode == 'private' &&
          _torStatus != TorStatus.reachable &&
          _torStatus != TorStatus.bootstrapped &&
          _torStatus != TorStatus.publishing) {
        return;
      }
      if (_polling) return;
      _polling = true;
      try {
        final msgs = engine.nostrPoll();
        if (msgs.isEmpty) return;
        for (final m in msgs) {
          // dedup: skip a message we've already handled (see direct-onion note).
          final h = sha256.convert(utf8.encode(m.cipher)).toString();
          if (await db.alreadySeen(h)) continue;
          if (m.cipher.startsWith('{')) {
            // control frame riding the transport outside signal (bundle
            // exchange). signal wire is base64 - never starts with '{'.
            await _handleBundleCtl(m.peer, m.cipher, h);
            continue;
          }
          var haloId = _xPubToHaloId[m.peer];
          String? wrapped = haloId == null
              ? null
              : await signalDecrypt(haloId, m.cipher, flagKeyChange: true);
          // fallback: xpub not mapped yet (or it decrypted wrong) - trial
          // against known contacts like the direct path, then remember it.
          if (wrapped == null) {
            for (final c in contacts) {
              if (c.haloId == haloId) continue;
              final p = await signalDecrypt(c.haloId, m.cipher);
              if (p != null) {
                wrapped = p;
                haloId = c.haloId;
                _xPubToHaloId[m.peer] = c.haloId;
                break;
              }
            }
          }
          if (wrapped == null) {
            for (final r in await db.pendingRequests()) {
              final id = r['halo_id'] as String;
              final p = await signalDecrypt(id, m.cipher);
              if (p != null) {
                wrapped = p;
                haloId = id;
                _xPubToHaloId[m.peer] = id;
                break;
              }
            }
          }
          if (wrapped == null) {
            // a peer we deleted keeps its session but loses its contact row.
            // their next message is a plain whisper, so back-pair can't help -
            // try every sessioned address that isn't a live contact and re-file
            // them as a fresh request.
            final liveIds = contacts.map((c) => c.haloId).toSet();
            for (final addr
                in await signalSession.sessionStore.allSessionAddresses()) {
              if (liveIds.contains(addr) || addr == '_pending_back_pair_') {
                continue;
              }
              final p = await signalDecrypt(addr, m.cipher);
              if (p != null) {
                wrapped = p;
                haloId = addr;
                _xPubToHaloId[m.peer] = addr;
                final env0 = unwrapMessage(p);
                await db.upsertContact(
                  addr,
                  env0.senderOnion ?? '',
                  env0.senderXPub ?? '',
                  accepted: 0,
                );
                await refreshContacts();
                debugPrint('relay: recovered deleted peer $addr into requests');
                break;
              }
            }
          }
          if (wrapped == null) {
            // only a prekey can bootstrap a new session. a whisper nothing
            // could decrypt is undeliverable - drop it without the noise.
            var landed = false;
            if (_isPreKeyWire(m.cipher)) {
              final paired = await backPairFromCipher(m.cipher);
              debugPrint(
                'nostr: back-pair ${paired != null ? "ok $paired" : "failed"}',
              );
              if (paired != null) {
                if (m.peer != 'firstcontact') _xPubToHaloId[m.peer] = paired;
                await db.markSeen(h);
                landed = true;
              }
            }
            if (!landed) _strikeUndecryptable(h, 'nostr');
            continue;
          }
          final env = unwrapMessage(wrapped);
          if (env.endpoint != null) {
            await savePeerEndpoint(haloId!, env.endpoint!);
          }
          await _applyIncomingPayload(haloId!, env);
          await db.markSeen(h);
          notifyListeners();
        }
      } finally {
        _polling = false;
      }
    });
    final _stored = await const FlutterSecureStorage().read(
      key: 'onboarding_done',
    );
    onboardingComplete = _stored == 'true';
    ready = true;
    notifyListeners();
  }

  Future<void> _initConnectivity() async {
    try {
      final init = await Connectivity().checkConnectivity();
      _online = init.any((r) => r != ConnectivityResult.none);
      notifyListeners();
    } catch (_) {}
    Connectivity().onConnectivityChanged.listen((results) {
      final on = results.any((r) => r != ConnectivityResult.none);
      if (on != _online) {
        _online = on;
        notifyListeners();
      }
    });
  }

  Future<void> _bootSignal() async {
    try {
      final database = await db.open();
      final xpb = _hexDecode(engine.myXPrivkey());
      await signalSession.bootstrap(
        database: database,
        xPubBytes: _hexDecode(engine.myXPubkey()),
        xPrivBytes: xpb,
      );
      _zeroBytes(xpb); // priv bytes consumed by bootstrap, wipe from ram
    } catch (e, st) {
      debugPrint('signal bootstrap failed: $e\n$st');
    }
  }

  Uint8List _hexDecode(String s) {
    final bytes = Uint8List(s.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  // wipe a conversation end to end: messages, the contact row, and the
  // signal session. they become a stranger again - a later message from
  // them back-pairs into requests like anyone else.
  Future<void> deleteConversation(String haloId) async {
    // messages + contact row only. the signal session stays: the peer still
    // holds a live session and their next message is a plain whisper, which
    // back-pair (prekey-only) can't rebuild. keeping the session lets it
    // decrypt, find no contact, and land in requests like a new stranger.
    await db.deleteConversation(haloId);
    // keep _xPubToHaloId: the row and subscription both survive so they can
    // still reach us - they just land in requests instead of a live chat.
    await refreshContacts();
    notifyListeners();
  }

  Future<void> archive(String haloId) async {
    await db.setArchived(haloId, true);
    await refreshContacts();
  }

  Future<void> unarchive(String haloId) async {
    await db.setArchived(haloId, false);
    await refreshContacts();
  }

  Future<void> mute(String haloId) async {
    await db.setMuted(haloId, true);
    await refreshContacts();
  }

  Future<void> unmute(String haloId) async {
    await db.setMuted(haloId, false);
    await refreshContacts();
  }

  Future<void> block(String haloId) async {
    await db.setBlocked(haloId, true);
    await refreshContacts();
  }

  Future<void> unblock(String haloId) async {
    await db.setBlocked(haloId, false);
    await refreshContacts();
  }

  Future<List<({String haloId, String? nickname})>> blockedContacts() async {
    final rows = await db.contacts();
    return [
      for (final r in rows)
        if ((r['blocked'] as int? ?? 0) == 1)
          (haloId: r['halo_id'] as String, nickname: r['nickname'] as String?),
    ];
  }

  Future<void> refreshContacts() async {
    final rows = await db.contacts();
    final list = <ContactPreview>[];
    for (final r in rows) {
      final haloId = r['halo_id'] as String;
      final last = await db.lastMessageFor(haloId);
      String? preview;
      // default to the contact's last_seen; a real message overrides it.
      DateTime when = DateTime.fromMillisecondsSinceEpoch(
        r['last_seen'] as int,
      );
      if (last != null) {
        final dir = last['direction'] as String?;
        final text = (last['plaintext'] as String?) ?? '';
        final media = last['media_path'] as String?;
        final fileName = last['file_name'] as String?;
        String body;
        if (text.isNotEmpty) {
          body = text;
        } else if (fileName == 'voice.wav') {
          body = 'voice message';
        } else if (fileName != null) {
          body = fileName;
        } else if (media != null) {
          body = 'photo';
        } else {
          body = '';
        }
        if (body.isNotEmpty) preview = dir == 'out' ? 'you: $body' : body;
        final sentAt = last['sent_at'] as int?;
        if (sentAt != null) {
          when = DateTime.fromMillisecondsSinceEpoch(sentAt);
        }
      }
      list.add(
        ContactPreview(
          haloId: haloId,
          nickname: r['nickname'] as String?,
          avatarSeed: haloId,
          preview: preview,
          when: when,
          blocked: (r['blocked'] as int? ?? 0) == 1,
          archived: (r['archived'] as int? ?? 0) == 1,
          muted: (r['muted'] as int? ?? 0) == 1,
          verified: (r['verified'] as int? ?? 0) == 1,
          unread: (r['unread'] as int? ?? 0),
          pinned: (r['pinned'] as int? ?? 0) == 1,
          supporterBadge: r['supporter_badge'] as String?,
        ),
      );
    }
    // most-recent conversation floats to the top
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return (b.when ?? DateTime(0)).compareTo(a.when ?? DateTime(0));
    });
    contacts = list;
    pendingCount = await db.pendingRequestCount();
    notifyListeners();
  }

  // ---- groups ----

  Future<void> refreshGroups() async {
    final rows = await db.loadGroups();
    final list = <GroupPreview>[];
    for (final r in rows) {
      final gid = r['group_id'] as String;
      final members = await db.getGroupMembers(gid);
      list.add(
        GroupPreview(
          groupId: gid,
          name: r['name'] as String,
          memberCount: members.length,
          isAdmin: (r['is_admin'] as int? ?? 0) == 1,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            r['created_at'] as int,
          ),
          unread: (r['unread'] as int? ?? 0),
        ),
      );
    }
    groups = list;
    notifyListeners();
  }

  // the tier to advertise to contacts, or null when sharing is off.
  Future<String?> sharedBadge() async {
    if (!await loadShareBadge()) return null;
    final t = await loadSupporterTier();
    if (t == SupporterTier.none) return null;
    return t.name;
  }

  // last ack per uid, so a burst of duplicates costs one receipt not twenty.
  final Map<String, int> _ackedAt = <String, int>{};

  // user tapped retry. clears the backoff so the next sweep goes out now
  // rather than waiting out the doubling gap.
  Future<void> flushOutboxNow() async {
    _outboxNextAt.clear();
    _outboxTries.clear();
    await drainOutbox();
  }

  // tiny ack: tells the original sender their message landed. reuses the
  // gift-wrap transport; carries only the uid, no body, no sender bundle.
  Future<void> _sendDeliveryReceipt(String toHaloId, String uid) async {
    // a relay replaying its backlog hands us the same message many times over
    // and each copy used to buy a full fan-out. re-acking still matters (the
    // first receipt may have died) so this throttles rather than blocks.
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _ackedAt[uid];
    if (last != null && now - last < 30000) return;
    _ackedAt[uid] = now;
    if (_ackedAt.length > 500) {
      _ackedAt.removeWhere((_, t) => now - t > 300000);
    }
    try {
      final wrapped = await wrapMessage(
        '',
        deliveredUid: uid,
        sender: _mySender(),
      );
      await _sendOneEnvelope(toHaloId, wrapped);
    } catch (e) {
      debugPrint('receipt for $uid failed: $e');
    }
  }

  SenderInfo _mySender() => SenderInfo(
    haloId: myId,
    edPub: engine.myEdPubkey(),
    onion: myOnion,
    xPub: engine.myXPubkey(),
  );

  // pairwise envelope send. wraps libsignal encrypt + transport choice
  // (direct-onion if peer hasn't back-paired yet, nostr otherwise).
  // wipe a corrupt outbound session and rebuild it from the peer's stored
  // prekey bundle. returns false if we never kept a bundle (paired by a path
  // that didn't save one) - caller then surfaces the original failure.
  Future<bool> _healSession(String memberId) async {
    final c = await db.getContact(memberId);
    final bundle = c?['peer_bundle'] as String?;
    if (bundle == null || bundle.isEmpty) return false;
    try {
      final addr = SignalProtocolAddress(memberId, 1);
      await signalSession.sessionStore.deleteSession(addr);
      await processPeerBundle(memberId, bundle);
      debugPrint('healed session for $memberId');
      return true;
    } catch (e) {
      debugPrint('heal session failed for $memberId: $e');
      return false;
    }
  }

  // ship our prekey bundle to a peer over the gift-wrap transport - no
  // signal session needed, which is the point: ours to them is broken.
  // want=true asks them to reset their session with us and send theirs back.
  Future<void> _sendBundleCtl(String memberId, {required bool want}) async {
    final key = '$memberId:$want';
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_bundleCtlSentAt[key] ?? 0) < 60000)
      return; // 1/min, not 1/chunk
    _bundleCtlSentAt[key] = now;
    try {
      final contact = await db.getContact(memberId);
      if (contact == null) return;
      final xpub = contact['xpub'] as String? ?? '';
      if (xpub.isEmpty) return;
      final payload = jsonEncode({
        'halo_ctl': 'bundle',
        'from': myId,
        'bundle': await makePreKeyBundleB64(),
        'want': want,
      });
      final r = await Future(() => engine.nostrSend(xpub, payload));
      debugPrint('bundle ctl (want=$want) to $memberId: $r');
    } catch (e) {
      debugPrint('bundle ctl to $memberId failed: $e');
    }
  }

  // a bundle ctl frame arrived off the relay. peerXPub is transport-
  // authenticated by the nip17 seal, so it must match the claimed sender's
  // stored xpub, and the bundle's identity key must match the pinned signal
  // identity. a valid frame backfills peer_bundle (pre-v30 pairings) and
  // rebuilds the corrupt session, so both sides converge without re-pairing.
  Future<void> _handleBundleCtl(String peerXPub, String raw, String h) async {
    try {
      final j = jsonDecode(raw);
      if (j is! Map || j['halo_ctl'] != 'bundle') return;
      final from = j['from'] as String?;
      final bundle = j['bundle'] as String?;
      final want = j['want'] == true;
      if (from == null || bundle == null) return;
      final contact = await db.getContact(from);
      if (contact == null) return;
      if ((contact['xpub'] as String? ?? '') != peerXPub) {
        debugPrint('bundle ctl: xpub mismatch for $from, dropped');
        return;
      }
      final bj =
          jsonDecode(utf8.decode(base64Decode(bundle))) as Map<String, dynamic>;
      final claimed = base64Decode(bj['identityKey'] as String);
      final addr = SignalProtocolAddress(from, 1);
      final known = await signalSession.identityStore.getIdentity(addr);
      if (known != null && !_eqBytes(known.serialize(), claimed)) {
        debugPrint('bundle ctl: identity mismatch for $from, dropped');
        return;
      }
      await db.setPeerBundle(from, bundle);
      if (want || _healPending.remove(from)) {
        await signalSession.sessionStore.deleteSession(addr);
        await processPeerBundle(from, bundle);
        debugPrint('healed session for $from (bundle exchange)');
      }
      if (want) unawaited(_sendBundleCtl(from, want: false));
    } catch (e) {
      debugPrint('bundle ctl handle failed: $e');
    } finally {
      await db.markSeen(h);
    }
  }

  Future<bool> _sendOneEnvelope(String memberId, String wrapped) async {
    // one honest attempt. the engine calls already carry their own timeouts
    // (onion 15s, relay 60s), so retrying here just stacks those timeouts -
    // 3x turned a slow member into a ~4min hang that froze the send pill for
    // the whole group. a permanent InvalidKeyException can never succeed on
    // retry either. if this send fails the message is marked failed and the
    // user gets tap-to-retry, which is the right place for a human decision.
    try {
      final contact = await db.getContact(memberId);
      if (contact == null) {
        debugPrint('send: no contact for $memberId');
        return false;
      }
      String cipher;
      // a member with no session AND no stored bundle can't be reached
      // (e.g. a dead identity still in the roster). don't burn a relay
      // timeout on it every send - skip fast so live members deliver now.
      if (!await signalSession.sessionStore.containsSession(
            SignalProtocolAddress(memberId, 1),
          ) &&
          (await db.getContact(memberId))?['peer_bundle'] == null) {
        debugPrint('send: $memberId unreachable (no session/bundle), skipping');
        return false;
      }
      try {
        cipher = await signalEncrypt(memberId, wrapped);
      } catch (e) {
        // a corrupt session (InvalidKeyException / bad state from heavy
        // reinstall testing) can't encrypt. if we kept the peer's bundle at
        // pairing, wipe the broken session and rebuild it, then try once more.
        final healed = await _healSession(memberId);
        if (!healed) {
          // no stored bundle (paired before v30 kept them). ask the peer
          // for a fresh one over the gift-wrap transport - the reply heals
          // the session and the user's tap-to-retry then goes through.
          _healPending.add(memberId);
          unawaited(_sendBundleCtl(memberId, want: true));
          rethrow;
        }
        cipher = await signalEncrypt(memberId, wrapped);
      }
      final backPaired = await db.isBackPaired(memberId);
      final xpub = contact['xpub'] as String;
      final onion = contact['onion'] as String;

      // back-paired: onion-only, already fast and leaks the least.
      if (backPaired || onion.isEmpty) {
        final n = await Future(() => engine.nostrSend(xpub, cipher));
        if (n == 'ok') return true;
        debugPrint('send: nostr failed ($n)');
        return false;
      }

      // not back-paired: RACE onion and relay instead of waiting out the
      // onion timeout before trying relays. delivery = whichever lands
      // first, so a slow/dead onion no longer costs the full 15s.
      final done = Completer<bool>();
      var pending = 2;
      void settle(String tag, String r) {
        if (r == 'ok') {
          if (!done.isCompleted) done.complete(true);
        } else {
          debugPrint('send: $tag failed ($r)');
          if (--pending == 0 && !done.isCompleted) done.complete(false);
        }
      }

      unawaited(
        Future(() => engine.sendTo(onion, cipher))
            .then((r) => settle('onion', r))
            .catchError((_) => settle('onion', 'err')),
      );
      unawaited(
        Future(() => engine.nostrSend(xpub, cipher))
            .then((r) => settle('nostr', r))
            .catchError((_) => settle('nostr', 'err')),
      );
      final fc = _peerFc[memberId];
      debugPrint(
        fc == null || fc.isEmpty
            ? 'send: no first-contact addr for $memberId (v2 invite?)'
            : 'send: racing onion + relay + first-contact for $memberId',
      );
      if (fc != null && fc.isNotEmpty) {
        pending++;
        unawaited(
          engine
              .sendFirstContact(xpub, fc, cipher)
              .then((r) => settle('firstcontact', r))
              .catchError((_) => settle('firstcontact', 'err')),
        );
      }
      return done.future;
    } catch (e) {
      debugPrint('send to $memberId failed: $e');
      return false;
    }
  }

  // tells a just-accepted stranger they're in. the empty frame flips their
  // back_paired on arrival, which melts their request lock without waiting
  // for our first reply.
  Future<void> sendAcceptAck(String haloId) async {
    try {
      final wrapped = await wrapMessage('', sender: _mySender());
      await _sendOneEnvelope(haloId, wrapped);
    } catch (e) {
      debugPrint('accept ack failed: $e');
    }
  }

  Future<void> _sendControlToGroup(String groupId, GroupControl gc) async {
    final wrapped = await wrapMessage(
      '',
      groupId: groupId,
      groupControl: gc,
      sender: _mySender(),
    );
    final members = await db.getGroupMembers(groupId);
    await Future.wait([
      for (final memberId in members)
        if (memberId != myId) _sendOneEnvelope(memberId, wrapped),
    ]);
  }

  // send a normal text message into a group. saves the local row, then
  // multicasts pairwise to every other member. returns true if at least
  // one recipient acknowledged.
  Future<bool> sendToGroup(
    String groupId,
    String plain, {
    String? msgUid,
    String? replyTo,
    int? burnSeconds,
  }) async {
    msgUid ??= newMsgUid();
    final burnAt = (burnSeconds != null && burnSeconds > 0)
        ? DateTime.now().millisecondsSinceEpoch + burnSeconds * 1000
        : null;
    // save the local row up-front so the chat list shows it immediately.
    // peer_id = self so we render it as outgoing. a RETRY passes the same
    // uid - inserting again duplicated the row and blew up every uid-keyed
    // widget key. one row per uid, ever.
    if (!await db.messageExists(msgUid)) {
      await db.saveMessage(
        myId,
        'out',
        plain,
        groupId: groupId,
        msgUid: msgUid,
        replyTo: replyTo,
        burnAt: burnAt,
        // born UNSENT: the default sent=1 made a dead send reload as a
        // ticked message nobody ever received. media already does this.
        sent: 0,
      );
    }
    final members = await db.getGroupMembers(groupId);
    // if we are the group admin, ride the full roster on the message so any
    // member whose list drifted self-heals the moment they receive it.
    final adminId = await db.groupAdminId(groupId);
    final amAdmin = adminId == myId;
    // ride the member key bundles too, not just ids - a self-healed member the
    // receiver had no contact for would otherwise throw InvalidKeyException on
    // encrypt. participants let the receiver upsert a stub and encrypt to them.
    final rosterParts = amAdmin ? await _buildParticipants(members) : null;
    final wrapped = await wrapMessage(
      plain,
      msgUid: msgUid,
      replyTo: replyTo,
      burnSeconds: burnSeconds,
      groupId: groupId,
      roster: amAdmin ? members : null,
      rosterParticipants: rosterParts,
      supporterBadge: await sharedBadge(),
      sender: _mySender(),
    );
    debugPrint(
      'GRPSEND group=$groupId members=$members me=$myId admin=$amAdmin',
    );
    final results = await Future.wait([
      for (final memberId in members)
        if (memberId != myId) _sendOneEnvelope(memberId, wrapped),
    ]);
    final anyOk = results.any((ok) => ok);
    // the tick is earned, not assumed: only a delivery to at least one
    // member flips the row to sent.
    if (anyOk) await db.markSent(msgUid);
    notifyListeners();
    return anyOk;
  }

  // chunked media multicast for groups. mirrors the 1:1 chunk engine but fans
  // every 16k slice out to each member. the local row is saved by the caller;
  // this only puts bytes on the wire. returns 'ok' or an error string.
  Future<String> sendMediaToGroup(
    String groupId,
    String b64, {
    required String msgUid,
    String caption = '',
    String? fileName,
    bool voice = false,
    bool voiceDisguised = false,
    int? burnSeconds,
  }) async {
    // 16k chunks. bigger sizes trip nip-44's 65535 plaintext ceiling once
    // base64'd + double-wrapped (envelope + signal + gift wrap ~= x2.4):
    // 24k measured at 66-77k on the wire and public relays rejected it
    // ("event too large"), so delivery only worked through our own
    // uncapped onion relay. 16k lands ~38-51k, safe on every relay.
    // receivers reassemble by index/total, so chunk size is free to change.
    const chunkSize = 16 * 1024;
    final chunks = <String>[];
    for (var i = 0; i < b64.length; i += chunkSize) {
      chunks.add(
        b64.substring(
          i,
          i + chunkSize > b64.length ? b64.length : i + chunkSize,
        ),
      );
    }
    final total = chunks.length;
    if (total > 1) mediaProgressStart(msgUid, chatKey: groupId);
    final members = await db.getGroupMembers(groupId);
    final adminId = await db.groupAdminId(groupId);
    final amAdmin = adminId == myId;
    final rosterParts = amAdmin ? await _buildParticipants(members) : null;
    Future<bool> sendChunk(int i) async {
      final wrapped = await wrapMessage(
        caption,
        msgUid: msgUid,
        imageB64: fileName == null && !voice ? chunks[i] : null,
        fileB64: fileName != null || voice ? chunks[i] : null,
        fileName: fileName,
        voice: voice,
        voiceDisguised: voiceDisguised,
        mediaId: total > 1 ? msgUid : null,
        chunkIndex: total > 1 ? i : null,
        chunkTotal: total > 1 ? total : null,
        burnSeconds: burnSeconds,
        groupId: groupId,
        roster: amAdmin ? members : null,
        rosterParticipants: rosterParts,
        supporterBadge: await sharedBadge(),
        sender: _mySender(),
      );
      var chunkOk = false;
      for (var tryN = 0; tryN < 3 && !chunkOk; tryN++) {
        final results = await Future.wait([
          for (final memberId in members)
            if (memberId != myId) _sendOneEnvelope(memberId, wrapped),
        ]);
        chunkOk = results.any((ok) => ok);
        if (!chunkOk) {
          debugPrint('GRP MEDIA chunk $i/$total try ${tryN + 1} failed');
          if (tryN < 2) await Future.delayed(const Duration(seconds: 1));
        }
      }
      if (!chunkOk) debugPrint('GRP MEDIA chunk $i/$total gave up');
      return chunkOk;
    }

    // sequential on purpose: parallel waves dropped chunks on the circuit
    // (receiver got the row but never the full file). the breather is down
    // from 400ms to 150ms which is all the safe speedup there is dart-side;
    // the real fix is batched publish in the engine.
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_grpChunkDoneAt[msgUid] ?? now) > 240000) {
      _grpChunkDone.remove(msgUid); // stale - a member may have restarted
    }
    _grpChunkDoneAt[msgUid] = now;
    final done = _grpChunkDone.putIfAbsent(msgUid, () => <int>{});
    if (done.isNotEmpty && total > 1) {
      debugPrint('GRP MEDIA resume $msgUid: ${done.length}/$total already out');
      mediaProgressUpdate(msgUid, done.length / total);
    }
    for (var i = 0; i < total; i++) {
      if (done.contains(i)) continue;
      final chunkOk = await sendChunk(i);
      if (!chunkOk) return 'error: chunk $i undeliverable';
      done.add(i);
      _grpChunkDoneAt[msgUid] = DateTime.now().millisecondsSinceEpoch;
      mediaProgressUpdate(msgUid, done.length / total);
      if (total > 1 && i < total - 1) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }
    _grpChunkDone.remove(msgUid);
    _grpChunkDoneAt.remove(msgUid);
    return 'ok';
  }

  // discord-style shared pin: everyone in the group sees the same pins.
  Future<void> pinInGroup(
    String groupId,
    String targetMsgUid,
    bool pinned,
  ) async {
    await db.setPinned(targetMsgUid, pinned);
    notifyListeners();
    final wrapped = await wrapMessage(
      '',
      groupId: groupId,
      pin: PinFrame(targetUid: targetMsgUid, pinned: pinned),
      sender: _mySender(),
    );
    final members = await db.getGroupMembers(groupId);
    await Future.wait([
      for (final memberId in members)
        if (memberId != myId) _sendOneEnvelope(memberId, wrapped),
    ]);
  }

  // pairwise reaction multicast for group messages.
  Future<void> reactInGroup(
    String groupId,
    String targetMsgUid,
    String emoji,
  ) async {
    if (emoji.isEmpty) {
      await db.removeReaction(targetMsgUid, '');
    } else {
      await db.addReaction(targetMsgUid, '', emoji);
    }
    // show it instantly - don't wait on the tor multicast to update the ui.
    notifyListeners();
    final wrapped = await wrapMessage(
      '',
      groupId: groupId,
      reaction: ReactionFrame(targetUid: targetMsgUid, emoji: emoji),
      sender: _mySender(),
    );
    final members = await db.getGroupMembers(groupId);
    // fan out in the background; the reaction is already on screen.
    unawaited(
      Future.wait([
        for (final memberId in members)
          if (memberId != myId) _sendOneEnvelope(memberId, wrapped),
      ]),
    );
  }

  // recall a group message everywhere: delete locally, tell every member.
  // receiver handles 'un' group-agnostically (deletes by uid).
  Future<void> unsendInGroup(String groupId, String targetMsgUid) async {
    await db.deleteMessage(targetMsgUid);
    final wrapped = await wrapMessage(
      '',
      groupId: groupId,
      unsend: targetMsgUid,
      sender: _mySender(),
    );
    final members = await db.getGroupMembers(groupId);
    await Future.wait([
      for (final memberId in members)
        if (memberId != myId) _sendOneEnvelope(memberId, wrapped),
    ]);
    notifyListeners();
  }

  // edit a group message everywhere: swap text locally, tell every member.
  Future<void> editInGroup(
    String groupId,
    String targetMsgUid,
    String newText,
  ) async {
    await db.editMessage(targetMsgUid, newText);
    final wrapped = await wrapMessage(
      '',
      groupId: groupId,
      edit: EditFrame(targetUid: targetMsgUid, newText: newText),
      sender: _mySender(),
    );
    final members = await db.getGroupMembers(groupId);
    await Future.wait([
      for (final memberId in members)
        if (memberId != myId) _sendOneEnvelope(memberId, wrapped),
    ]);
    notifyListeners();
  }

  // re-multicast a resolved link preview onto an already-sent group message.
  // same uid: every receiver takes the known-uid update path and patches the
  // card onto the bubble it already has.
  Future<void> sendGroupPreview(
    String groupId,
    String targetMsgUid,
    Map<String, String> pv,
  ) async {
    final wrapped = await wrapMessage(
      '',
      groupId: groupId,
      msgUid: targetMsgUid,
      preview: pv,
      sender: _mySender(),
    );
    final members = await db.getGroupMembers(groupId);
    await Future.wait([
      for (final memberId in members)
        if (memberId != myId) _sendOneEnvelope(memberId, wrapped),
    ]);
  }

  // build participant info {h,o,x} for each halo_id we have as a contact
  // (or for our own kryfo). used to give group invites enough info that
  // recipients can fan-out to members they don't yet know.
  Future<List<Map<String, String>>> _buildParticipants(
    List<String> haloIds,
  ) async {
    final out = <Map<String, String>>[];
    for (final h in haloIds) {
      if (h == myId) {
        out.add({'h': myId, 'o': myOnion, 'x': engine.myXPubkey()});
      } else {
        final c = await db.getContact(h);
        if (c != null) {
          out.add({
            'h': h,
            'o': c['onion'] as String,
            'x': c['xpub'] as String,
          });
        }
      }
    }
    return out;
  }

  // create a group locally and announce it to invited members. memberHaloIds
  // is the set of OTHER members (caller's kryfo id is added automatically).
  // returns the new group id.
  // phase-3 cap. small groups on purpose - keeps multicast cheap and dodges
  // the moderation trap big rooms bring.
  static const int kGroupMemberCap = 50;

  Future<String> createGroupAndAnnounce(
    String name,
    List<String> memberHaloIds,
  ) async {
    final groupId = newMsgUid();
    final full = [myId, ...memberHaloIds];
    if (full.length > kGroupMemberCap) {
      throw StateError('a group can hold up to $kGroupMemberCap people.');
    }
    await db.createGroup(groupId, name, full, isAdmin: true, adminId: myId);
    final participants = await _buildParticipants(full);
    final gc = GroupControl(
      type: 'create',
      name: name,
      members: full,
      participants: participants,
    );
    await _sendControlToGroup(groupId, gc);
    await refreshGroups();
    return groupId;
  }

  // admin-only. adds members locally, sends 'add' to existing members
  // (with participants for the new ones), and sends a full 'create' to
  // each new member so they bootstrap the group.
  Future<void> addMembersToGroup(
    String groupId,
    List<String> newHaloIds,
  ) async {
    final group = await db.getGroup(groupId);
    if (group == null) return;
    if ((group['is_admin'] as int? ?? 0) != 1) return;
    final existingMembers = await db.getGroupMembers(groupId);
    if (existingMembers.length + newHaloIds.length > kGroupMemberCap) {
      throw StateError('a group can hold up to $kGroupMemberCap people.');
    }
    for (final h in newHaloIds) {
      await db.addGroupMember(groupId, h);
    }
    final newParticipants = await _buildParticipants(newHaloIds);
    final addGc = GroupControl(
      type: 'add',
      members: newHaloIds,
      participants: newParticipants,
    );
    for (final memberId in existingMembers) {
      if (memberId == myId) continue;
      final wrapped = await wrapMessage(
        '',
        groupId: groupId,
        groupControl: addGc,
        sender: _mySender(),
      );
      await _sendOneEnvelope(memberId, wrapped);
    }
    final allMembers = await db.getGroupMembers(groupId);
    final allParticipants = await _buildParticipants(allMembers);
    final createGc = GroupControl(
      type: 'create',
      name: group['name'] as String,
      members: allMembers,
      participants: allParticipants,
    );
    for (final newMember in newHaloIds) {
      final wrapped = await wrapMessage(
        '',
        groupId: groupId,
        groupControl: createGc,
        sender: _mySender(),
      );
      await _sendOneEnvelope(newMember, wrapped);
    }
    await refreshGroups();
  }

  // admin-only. removes locally and tells everyone (including removed) so
  // both sides converge on the new member list.
  Future<void> removeMembersFromGroup(
    String groupId,
    List<String> removedHaloIds,
  ) async {
    final group = await db.getGroup(groupId);
    if (group == null) return;
    if ((group['is_admin'] as int? ?? 0) != 1) return;
    final allMembers = await db.getGroupMembers(groupId);
    for (final h in removedHaloIds) {
      await db.removeGroupMember(groupId, h);
    }
    final gc = GroupControl(type: 'remove', members: removedHaloIds);
    for (final memberId in allMembers) {
      if (memberId == myId) continue;
      final wrapped = await wrapMessage(
        '',
        groupId: groupId,
        groupControl: gc,
        sender: _mySender(),
      );
      await _sendOneEnvelope(memberId, wrapped);
    }
    await refreshGroups();
  }

  Future<void> renameGroupAndAnnounce(String groupId, String newName) async {
    final group = await db.getGroup(groupId);
    if (group == null) return;
    if ((group['is_admin'] as int? ?? 0) != 1) return;
    await db.renameGroup(groupId, newName);
    final gc = GroupControl(type: 'rename', name: newName);
    await _sendControlToGroup(groupId, gc);
    await refreshGroups();
  }

  // anyone can leave. tells the remaining members so they can drop us from
  // their copies. caller deletes the group locally.
  Future<void> leaveGroupAndAnnounce(String groupId) async {
    final gc = GroupControl(type: 'leave');
    await _sendControlToGroup(groupId, gc);
    await db.deleteGroup(groupId);
    await refreshGroups();
  }

  Future<void> regenerateIdentity() async {
    myId = engine.generateIdentity();
    await db.saveIdentity(myId, engine.myEdPrivkey(), engine.myXPrivkey());
    myXPub = engine.myXPubkey();
    restored = false;
    notifyListeners();
  }

  Future<void> subscribePeer(String haloId) async {
    // the row xpub is set by v1 pairing and is there before any session
    // exists; v2 bundle pairing leaves it empty and puts the key in the
    // signal store instead. try both, backfill the row when we learn it.
    var xPub = await db.contactXPub(haloId);
    if (xPub == null || xPub.isEmpty) {
      xPub = await signalSession.peerXPubHex(haloId);
      if (xPub != null && xPub.isNotEmpty) {
        await db.setContactXPub(haloId, xPub);
      }
    }
    if (xPub == null || xPub.isEmpty) return;
    _xPubToHaloId[xPub] = haloId;
    engine.nostrSubscribeBg(xPub);
  }

  Future<void> markOnboardingComplete() async {
    onboardingComplete = true;
    await const FlutterSecureStorage().write(
      key: 'onboarding_done',
      value: 'true',
    );
    notifyListeners();
  }
}

final appState = AppState();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await appState.loadThemePref();
  runApp(const HaloApp());
  // cold-start: if launched from a notification tap, open the chat
  // after the first frame so rootNavKey has a navigator.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final details = await notifPlugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      final payload = details?.notificationResponse?.payload;
      Future.delayed(
        const Duration(milliseconds: 500),
        () => openChatForHalo(payload),
      );
    }
  });
}

final themeRevision = ValueNotifier<int>(0);

class HaloApp extends StatelessWidget {
  const HaloApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: themeRevision,
      builder: (context, _, __) => MaterialApp(
        navigatorKey: rootNavKey,
        scaffoldMessengerKey: haloMessengerKey,
        title: 'Kryfo',
        theme: buildHaloTheme(),
        // one place for the two accessibility settings everything else
        // should obey. clamped rather than uncapped - past 1.6 the chat
        // bubbles stop being readable, which helps nobody.
        builder: (ctx, child) {
          final mq = MediaQuery.of(ctx);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: mq.textScaler.clamp(
                minScaleFactor: 0.85,
                maxScaleFactor: 1.6,
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        // one scroll feel everywhere: ios-style rubber-band on every
        // platform, no stretch-glow. the single biggest "premium" tell,
        // and it was unset so android fell back to the clamp+glow default.
        scrollBehavior: const _HaloScrollBehavior(),
        home: _LockGate(child: _OnboardingGate(child: RootShell())),
      ),
    );
  }
}

// true when the phone asks for less movement. widgets check this before
// running anything decorative.
bool reduceMotion(BuildContext c) => MediaQuery.of(c).disableAnimations;

class _HaloScrollBehavior extends ScrollBehavior {
  const _HaloScrollBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, _) =>
      child; // no glow - the bounce is the feedback
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  @override
  void initState() {
    super.initState();
    appState.addListener(_onChange);
    // boot after the first frame is on screen. loading libhalo.so pulls in the
    // whole go runtime + embedded tor and blocks briefly; doing it before the
    // first paint let android's anr watchdog kill a cold start on weak phones.
    WidgetsBinding.instance.addPostFrameCallback((_) => appState.boot());
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    appState.removeListener(_onChange);
    super.dispose();
  }

  void _open(Widget w) {
    Navigator.push(context, haloRoute(w));
  }

  @override
  Widget build(BuildContext context) {
    if (!appState.ready) {
      return Scaffold(
        backgroundColor: HaloColors.surface,
        body: Center(
          child: Text(
            appState.onboardingComplete
                ? 'booting...'
                : 'setting up your identity...',
            style: HaloType.mono(size: 11, color: HaloColors.text2),
          ),
        ),
      );
    }
    return HomeScreen(
      haloId: appState.myId,
      contacts: appState.contacts,
      pendingCount: appState.pendingCount,
      groups: appState.groups
          .map(
            (g) => GroupSummary(
              groupId: g.groupId,
              name: g.name,
              memberCount: g.memberCount,
              unread: g.unread,
            ),
          )
          .toList(),
      onAddContact: () => showAddContact(context),
      onNewGroup: () => _open(const NewGroupScreen()),
      onOpenDev: () => _open(const DevScreen()),
      onOpenSettings: () => _open(const ProfileScreen()),
      onOpenSettingsDirect: () => _open(SettingsScreen()),
      onOpenChat: (id) async {
        final rows = await db.contacts();
        final matches = rows.where((r) => r['halo_id'] == id).toList();
        if (matches.isEmpty || !mounted) return;
        final row = matches.first;
        Navigator.push(
          context,
          haloRoute(
            ChatScreen(
              peerHaloId: id,
              peerOnion: row['onion'] as String,
              peerXPub: row['xpub'] as String,
              avatarSeed: id,
            ),
          ),
        );
      },
      onOpenGroup: (groupId) async {
        if (!mounted) return;
        Navigator.push(context, haloRoute(GroupChatScreen(groupId: groupId)));
      },
    );
  }
}

Future<void> showAddContact(BuildContext context) async {
  final ctrl = TextEditingController();
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: HaloColors.surface2,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        18,
        22,
        24 + MediaQuery.of(sheetCtx).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: HaloColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'add a contact',
            style: HaloType.serif(
              size: 22,
              italic: true,
              color: HaloColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'scan their code in person, or paste an invite link',
            style: HaloType.sans(size: 12.5, color: HaloColors.text),
          ),
          const SizedBox(height: 14),
          _Pressable(
            onTap: () => Navigator.pop(sheetCtx, 'scan'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: HaloColors.amber,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33F59E0B),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    size: 19,
                    color: HaloColors.onAmber,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    'scan qr code',
                    style: HaloType.sans(
                      size: 14,
                      weight: FontWeight.w600,
                      color: HaloColors.onAmber,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Pressable(
            onTap: () => Navigator.pop(sheetCtx, 'mine'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_2, size: 16, color: HaloColors.amber),
                const SizedBox(width: 7),
                Text(
                  'show my own code',
                  style: HaloType.sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: HaloColors.amber,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Divider(color: HaloColors.line, height: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'or paste a link',
                  style: HaloType.sans(size: 11, color: HaloColors.text2),
                ),
              ),
              Expanded(child: Divider(color: HaloColors.line, height: 1)),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: HaloColors.surface3,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HaloColors.line, width: 0.5),
            ),
            child: TextField(
              controller: ctrl,
              minLines: 1,
              maxLines: 3,
              style: HaloType.mono(size: 12, color: HaloColors.text),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'kryfo://share?...',
                hintStyle: HaloType.mono(size: 12, color: HaloColors.text3),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _Pressable(
            onTap: () => Navigator.pop(sheetCtx, 'paste'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: HaloColors.amber, width: 1),
              ),
              child: Center(
                child: Text(
                  'import from link',
                  style: HaloType.sans(
                    size: 13.5,
                    weight: FontWeight.w600,
                    color: HaloColors.amber,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    ),
  );
  if (action == null) return;
  if (action == 'mine') {
    await Navigator.of(context).push(haloRoute(const MyKryfoScreen()));
    return;
  }

  String uri;
  if (action == 'scan') {
    final result = await Navigator.of(
      context,
    ).push<String>(haloRoute<String>(const ScanScreen()));
    if (result == null) return;
    uri = result;
  } else {
    uri = ctrl.text.trim();
    if (uri.isEmpty) return;
  }

  final status = await handleHaloUri(uri);
  await appState.refreshContacts();
  if (!context.mounted) return;
  showHaloToast(context, status);
}

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Pressable({required this.child, required this.onTap});
  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  double _scale = 1;
  void _set(double v) {
    if (mounted) setState(() => _scale = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(0.96),
      onTapUp: (_) => _set(1),
      onTapCancel: () => _set(1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class DevScreen extends StatefulWidget {
  const DevScreen({super.key});
  @override
  State<DevScreen> createState() => _DevScreenState();
}

class _DevScreenState extends State<DevScreen> {
  final _msgCtrl = TextEditingController(text: 'hello from the other side');
  String _myAddr = '';
  String _status = '';
  TorStatus _torStatus = TorStatus.off;
  int _bootstrapPct = 0;
  String _peerId = '';
  String _peerOnion = '';
  String _peerXPub = '';

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _status = appState.restored ? 'identity restored' : 'identity created';
    _loadLastPeer();
  }

  Future<void> _loadLastPeer() async {
    final rows = await db.contacts();
    if (rows.isEmpty) return;
    setState(() {
      _peerId = rows.first['halo_id'] as String;
      _peerOnion = rows.first['onion'] as String;
      _peerXPub = rows.first['xpub'] as String;
    });
  }

  Future<void> _startListener() async {
    setState(() => _status = 'starting tor (~30s)...');
    final docsDir = await getApplicationDocumentsDirectory();
    // must run off the ui thread - starting tor blocks on socket i/o long
    // enough that android anr'd the onboarding page. isolate twin already
    // used on the main boot path.
    final addr = await _startListenerOnIsolate(docsDir.path);
    setState(() {
      if (addr.startsWith('error')) {
        _status = addr;
      } else {
        _myAddr = addr;
        _status = '';
      }
    });
    _pollTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final raw = engine.getStatus();
      final newStatus = parseTorStatus(raw);
      final newPct = parseBootstrapPct(raw);
      if ((newStatus != _torStatus || newPct != _bootstrapPct) && mounted) {
        setState(() {
          _torStatus = newStatus;
          _bootstrapPct = newPct;
        });
      }
      final msgs = engine.drainInbox();
      if (msgs.isEmpty || _peerXPub.isEmpty) return;
      for (final r in msgs) {
        final plain = engine.decryptFrom(_peerXPub, r);
        if (!plain.startsWith('error')) {
          db.saveMessage(_peerId, 'in', plain);
        }
        setState(() {});
      }
    });
  }

  Future<void> _send() async {
    if (_peerOnion.isEmpty || _peerXPub.isEmpty) {
      setState(() => _status = 'scan or import a peer first');
      return;
    }
    setState(() => _status = 'encrypting + sending (~30s)...');
    final plain = _msgCtrl.text;
    final cipher = engine.encryptFor(_peerXPub, plain);
    if (cipher.startsWith('error')) {
      setState(() => _status = cipher);
      return;
    }
    final result = await Future(() => engine.sendTo(_peerOnion, cipher));
    if (result == 'ok') {
      await db.saveMessage(_peerId, 'out', plain);
    }
    setState(() => _status = result);
  }

  Future<void> _showMyQr() async {
    if (_myAddr.isEmpty) {
      setState(() => _status = 'tap start listening first');
      return;
    }
    final uri = await buildHaloUriV3(
      appState.myId,
      _myAddr,
      appState.fcCounter,
    );
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: HaloColors.onAmber,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'your kryfo',
                style: HaloType.serif(
                  size: 14,
                  italic: true,
                  color: HaloColors.amber,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                appState.myId,
                style: HaloType.mono(size: 18, color: HaloColors.amber),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                color: Colors.white,
                child: QrImageView(
                  data: uri,
                  version: QrVersions.auto,
                  size: 240,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: HaloColors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(
                  uri,
                  style: HaloType.mono(size: 9, color: HaloColors.amber),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  copySensitive(uri);
                  showHaloToast(context, 'uri copied');
                },
                child: Text(
                  'copy uri',
                  style: HaloType.sans(color: HaloColors.amber),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importPeer() async {
    final ctrl = TextEditingController();
    final action = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: HaloColors.surface2,
        title: Text(
          'add a kryfo',
          style: HaloType.sans(color: HaloColors.amber),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.maxFinite,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, 'scan'),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('scan qr'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HaloColors.amber,
                  foregroundColor: HaloColors.onAmber,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.maxFinite,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 'code'),
                icon: const Icon(Icons.dialpad, size: 18),
                label: const Text('pairing code'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HaloColors.text2,
                  side: BorderSide(color: HaloColors.line),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '- or paste -',
              style: HaloType.sans(size: 11, color: HaloColors.text3),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 4,
              style: HaloType.mono(size: 11, color: HaloColors.text),
              decoration: InputDecoration(
                hintText: 'kryfo://share?...',
                hintStyle: HaloType.mono(size: 11, color: HaloColors.text3),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'paste'),
            child: Text(
              'import',
              style: HaloType.sans(color: HaloColors.amber),
            ),
          ),
        ],
      ),
    );
    if (action == null) return;

    if (action == 'code') {
      if (!context.mounted) return;
      await Navigator.of(context).push(haloRoute(const PairCodeScreen()));
      await appState.refreshContacts();
      return;
    }

    String uri;
    if (action == 'scan') {
      final result = await Navigator.of(
        context,
      ).push<String>(haloRoute<String>(const ScanScreen()));
      if (result == null) return;
      uri = result;
    } else {
      uri = ctrl.text;
    }

    final status = await handleHaloUri(uri);
    await appState.refreshContacts();
    final parsed = parseHaloUri(uri);
    if (!mounted) return;
    setState(() {
      if (parsed != null) {
        _peerId = parsed['id'] ?? '';
        _peerOnion = parsed['onion'] ?? '';
        _peerXPub = parsed['xpub'] ?? '';
      }
      _status = status;
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        title: Text(
          'dev',
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                'kryfo',
                style: HaloType.serif(
                  size: 56,
                  weight: FontWeight.w300,
                  italic: true,
                  color: HaloColors.amber,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                engine.version(),
                style: HaloType.sans(size: 11, color: HaloColors.text3),
              ),
              const SizedBox(height: 16),
              Text(
                'your kryfo:',
                style: HaloType.sans(size: 11, color: HaloColors.text2),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: HaloColors.onAmber,
                  border: Border.all(color: HaloColors.amber, width: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  appState.myId.isEmpty ? '...' : appState.myId,
                  style: HaloType.mono(
                    size: 18,
                    color: HaloColors.amber,
                    letter: 0.04,
                  ),
                ),
              ),
              if (appState.restored)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'restored from disk',
                    style: HaloType.mono(size: 9, color: HaloColors.green),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _myAddr.isEmpty ? _startListener : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HaloColors.amber,
                  foregroundColor: HaloColors.onAmber,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(_myAddr.isEmpty ? 'start listening' : 'listening'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.qr_code, color: HaloColors.amber),
                      label: const Text('show my qr'),
                      onPressed: _showMyQr,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.content_paste, color: HaloColors.violet),
                      label: const Text('import peer'),
                      onPressed: _importPeer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_peerId.isNotEmpty) ...[
                Text(
                  'peer:',
                  style: HaloType.sans(size: 11, color: HaloColors.text2),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: HaloColors.surface3,
                    border: Border.all(color: HaloColors.green, width: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _peerId,
                    style: HaloType.mono(size: 14, color: HaloColors.green),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _msgCtrl,
                style: HaloType.sans(color: HaloColors.text),
                decoration: InputDecoration(
                  labelText: 'message (will be encrypted)',
                  labelStyle: HaloType.sans(color: HaloColors.text2),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: (_myAddr.isEmpty || _peerOnion.isEmpty)
                    ? null
                    : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HaloColors.amber,
                  foregroundColor: HaloColors.onAmber,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('encrypt + send'),
              ),
              const SizedBox(height: 16),
              TorWarmupGraph(status: _torStatus, bootstrapPct: _bootstrapPct),
              const SizedBox(height: 12),
              if (_status.isNotEmpty)
                Text(
                  'status: $_status',
                  style: HaloType.sans(size: 12, color: HaloColors.text2),
                ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () =>
                    Navigator.of(context).push(haloRoute(const ModesScreen())),
                child: Text(
                  'speed & privacy →',
                  style: HaloType.mono(size: 11, color: HaloColors.amber),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => Navigator.of(
                  context,
                ).push(haloRoute(const PushSettingsScreen())),
                child: Text(
                  'notifications →',
                  style: HaloType.mono(size: 11, color: HaloColors.amber),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  if (lockState.enabled) {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: HaloColors.surface3,
                        title: Text(
                          'disable app lock?',
                          style: HaloType.serif(
                            size: 18,
                            color: HaloColors.text,
                          ),
                        ),
                        content: Text(
                          'the pin will be removed. anyone with your phone will see kryfo when they open it.',
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
                              'disable',
                              style: HaloType.sans(
                                size: 13,
                                color: HaloColors.rose,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) await lockState.disable();
                  } else {
                    Navigator.of(
                      context,
                    ).push(haloRoute(const LockSetupScreen()));
                  }
                },
                child: AnimatedBuilder(
                  animation: lockState,
                  builder: (_, __) => Text(
                    lockState.enabled ? 'app lock · on →' : 'app lock · off →',
                    style: HaloType.mono(size: 11, color: HaloColors.amber),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingGate extends StatefulWidget {
  final Widget child;
  const _OnboardingGate({required this.child});
  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<_OnboardingGate> {
  // boot is ~450ms now, the onion was gone before it registered. hold the
  // splash a beat on cold start so it gets seen. warm reopens skip it.
  bool _hold = false;

  @override
  void initState() {
    super.initState();
    if (!appState.ready) {
      appState.boot();
      _hold = true;
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _hold = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        if (!appState.ready || _hold) {
          return const TorBootSplash();
        }
        if (!appState.onboardingComplete) {
          return OnboardingScreen(
            appState: appState,
            onComplete: () => appState.markOnboardingComplete(),
          );
        }
        return widget.child;
      },
    );
  }
}

class _LockGate extends StatefulWidget {
  final Widget child;
  const _LockGate({required this.child});
  @override
  State<_LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<_LockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    lockState.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      lockState.lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: lockState,
      builder: (_, __) {
        if (lockState.locked) return const LockScreen();
        return widget.child;
      },
    );
  }
}

class TorHalo extends StatefulWidget {
  final bool label;
  const TorHalo({this.label = false});
  @override
  State<TorHalo> createState() => TorHaloState();
}

class TorHaloState extends State<TorHalo> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  bool get _isConnecting {
    final s = appState.torStatus;
    return s == TorStatus.starting ||
        s == TorStatus.bootstrapped ||
        s == TorStatus.publishing;
  }

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    appState.addListener(_sync);
    _sync();
  }

  void _sync() {
    if (_isConnecting && !_c.isAnimating) {
      _c.repeat();
    } else if (!_isConnecting && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    appState.removeListener(_sync);
    _c.dispose();
    super.dispose();
  }

  void _explain() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: HaloColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final s = appState.torStatus;
          final pct = appState.bootstrapPct;
          // bootstrapped and publishing both mean tor's client side is live:
          // messages send and arrive over relays, full 3 hops. the remaining
          // wait only publishes our own address so peers can dial us direct.
          final line = s == TorStatus.off
              ? 'tor is off'
              : s == TorStatus.reachable
              ? 'connected · routed through 3 relays'
              : s == TorStatus.publishing
              ? 'ready to send · publishing your address'
              : s == TorStatus.bootstrapped
              ? 'ready to send · finishing setup'
              : 'connecting · $pct%';
          return Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'tor',
                  style: HaloType.serif(
                    size: 20,
                    italic: true,
                    color: HaloColors.text,
                  ),
                ),
                const SizedBox(height: 16),
                TorWarmupGraph(status: s, bootstrapPct: pct),
                const SizedBox(height: 16),
                Text(
                  line,
                  style: HaloType.mono(size: 12, color: HaloColors.text),
                ),
                if (s != TorStatus.reachable) ...[
                  const SizedBox(height: 16),
                  Text(
                    s == TorStatus.off
                        ? 'tor is off. turn it on to connect privately.'
                        : 'the first connection takes a minute or two while tor builds a private route. after that it is cached, so opening kryfo later is much faster.',
                    style: HaloType.sans(
                      size: 12.5,
                      color: HaloColors.text,
                    ).copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'a faster mode that skips tor (and reveals your ip) is coming soon.',
                    style: HaloType.sans(size: 11, color: HaloColors.text2),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _ring(double size, Color color, double w) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: w),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // nothing to explain outside onion - no bootstrap, no circuit, no
      // descriptor. a tap that opens a page about tor while you are on the
      // relay is worse than a tap that does nothing.
      onTap: appState.sendMode == 'private' ? _explain : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([appState, _c]),
        builder: (context, _) {
          final s = appState.torStatus;
          final off = s == TorStatus.off;
          final secured = s == TorStatus.reachable;
          final connecting = !off && !secured;
          final usable =
              s == TorStatus.bootstrapped || s == TorStatus.publishing;
          const torGreen = Color(0xFF34D399);
          final accent = off
              ? HaloColors.text3
              // one route, one colour. onion stays violet whether tor is
              // merely usable or fully published - going green on the way
              // made it look like a different state.
              : appState.sendMode == 'balanced'
              ? const Color(0xFF4BB8C9)
              : appState.sendMode == 'fast'
              ? torGreen
              : (secured || usable)
              ? const Color(0xFFB79CFF)
              : HaloColors.amber;
          final t = _c.value;
          final dot = SizedBox(
            width: 18,
            height: 18,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (connecting)
                  Transform.scale(
                    scale: 0.5 + t,
                    child: Opacity(
                      opacity: (1 - t) * 0.7,
                      child: _ring(12, accent, 1.4),
                    ),
                  ),
                _ring(
                  12,
                  off
                      ? HaloColors.text3.withValues(alpha: 0.4)
                      : accent.withValues(alpha: secured ? 1.0 : 0.85),
                  1.4,
                ),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                  ),
                ),
              ],
            ),
          );
          if (!widget.label) {
            return SizedBox(width: 20, height: 20, child: Center(child: dot));
          }
          final mode = appState.sendMode;
          final txt = mode == 'balanced'
              ? (appState.online ? 'Via Relay' : 'Offline')
              : mode == 'fast'
              ? (appState.online ? 'Fast' : 'Offline')
              : off
              ? 'Tor Off'
              : (secured || usable)
              ? 'Tor Ready'
              : 'Connecting';
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              dot,
              const SizedBox(width: 6),
              Text(txt, style: HaloType.mono(size: 11, color: accent)),
            ],
          );
        },
      ),
    );
  }
}
