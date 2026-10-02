// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'secure_store.dart';
import 'widgets/boot_failed.dart';
import 'widgets/tor_boot_splash.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'dart:ffi';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Curve;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'notifications.dart';
import 'backup.dart' show sweepBackupLeftovers;
import 'picked.dart' show sweepPickerLeftovers;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'theme.dart';
import 'wipe.dart';
import 'group_media_send.dart';
import 'media_progress.dart';
import 'media_send.dart';
import 'send_order.dart';
import 'media_resend.dart';
import 'delivery_mode.dart';
import 'offline_gate.dart';
import 'helper_push.dart';
import 'screens/getting_messages_screen.dart';
import 'screens/home_screen.dart';
import 'screens/new_group_screen.dart';
import 'screens/room_create_sheet.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'screens/group_chat_screen.dart';
import 'screens/requests_screen.dart' show RequestsScreen;
import 'screens/chat_screen.dart';
import 'screens/dev_about_sheet.dart' show devChatRoute;
import 'devchat/dev_start.dart' show DevKeyCheckFailed, DevStart;
import 'screens/pair_code_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/modes_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/my_kryfo_screen.dart';
import 'screens/onboarding_screen.dart';
import 'container.dart';
import 'lock_state.dart';
import 'app_shell.dart';
import 'lock_guard.dart';
import 'lock_layer.dart';
import 'screens/lock_screen.dart';
import 'screens/lock_setup_screen.dart';
import 'screens/moved_screen.dart';
import 'pin_gate.dart';
import 'widgets/pins.dart' show kMaxPins;
import 'push_mode.dart';
import 'intro_prefs.dart';
import 'scam_prefs.dart';
import 'scam_shield.dart';
import 'rooms.dart';
import 'outbox.dart';
import 'supporter.dart';
import 'message_envelope.dart';
import 'polls.dart';
import 'open_file.dart' show nameSaysVideo;
import 'search.dart';
import 'search_bench.dart';
import 'session.dart';
import 'router.dart';
import 'vault_life.dart';
import 'devchat/dev_chat.dart';
import 'devchat/dev_frame.dart' show DevSelf, devInFrame;
import 'devchat/dev_gate.dart';
import 'devchat/dev_key.dart';
import 'devchat/dev_lane.dart';
import 'devchat/support.dart';
import 'screens/support_screen.dart' show openSupportTap;
import 'stickers/sticker_pack.dart' show StickerLibrary;
import 'stickers/sticker_wire.dart' show StickerWire, stickerText;
import 'widgets/motion.dart';
import 'widgets/pair_join.dart' show pairUnreached;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:app_links/app_links.dart';
import 'signal_session.dart';
import 'signal_stores.dart' show invitePreKeyId, kDevSignalPrefix;
import 'dart:isolate';
import 'dlog.dart';
import 'stranger_gate.dart';
import 'fast_gate.dart';
import 'mentions.dart';
import 'handle_lookup.dart';
import 'handle_repoint.dart';
import 'widgets/sheet_handle.dart';
import 'widgets/halo_sheet.dart';
import 'bidi_safe.dart';
import 'engine_strings.dart';
import 'relay_poll.dart';
import 'l10n/l10n.dart';
import 'l10n/numbers.dart';
import 'l10n/app_locale.dart';

typedef IntArgFn = Void Function(Int32);
typedef IntArgFnDart = void Function(int);
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
typedef FourArgFn =
    Pointer<Utf8> Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
    );
typedef FourArgFnDart =
    Pointer<Utf8> Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
    );
typedef CounterFn = Pointer<Utf8> Function(Int32);
typedef CounterFnDart = Pointer<Utf8> Function(int);
typedef StrCounterFn = Pointer<Utf8> Function(Pointer<Utf8>, Int32);
typedef StrCounterFnDart = Pointer<Utf8> Function(Pointer<Utf8>, int);

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
  late final IntArgFnDart _setDebug;
  late final CStrFnDart _getStatus;
  late final CStrFnDart _nostrKick;
  late final CStrFnDart _memStats;
  late final OneArgFnDart _nostrInit;
  late final OneArgFnDart _nostrSubscribe;
  late final CStrFnDart _nostrPoll;
  late final CounterFnDart _fcPk;
  late final CStrFnDart _txState;
  late final TwoArgFnDart _setBridges;
  late final CStrFnDart _bridgeState;
  late final int Function() _torPaused;
  late final CStrFnDart _restartTor;
  late final OneArgFnDart _setMode;
  late final OneArgFnDart _idFromEdPub;
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
    _getStatus = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloGetStatus');
    _nostrKick = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloNostrKick');
    _memStats = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloMemStats');
    _nostrInit = _lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloNostrInit');
    _nostrSubscribe = _lib.lookupFunction<OneArgFn, OneArgFnDart>(
      'HaloNostrSubscribe',
    );
    _nostrPoll = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloNostrPoll');
    _fcPk = _lib.lookupFunction<CounterFn, CounterFnDart>('HaloFirstContactPk');
    _txState = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloTransportState');
    _setBridges = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloSetBridges');
    _bridgeState = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloBridgeState');
    _torPaused = _lib.lookupFunction<Int32 Function(), int Function()>(
      'HaloTorPaused',
    );
    _restartTor = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloRestartTor');
    _setMode = _lib.lookupFunction<OneArgFn, OneArgFnDart>(
      'HaloSetTransportMode',
    );
    _idFromEdPub = _lib.lookupFunction<OneArgFn, OneArgFnDart>(
      'HaloIdFromEdPub',
    );
    _decryptBackup = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>(
      'HaloDecryptBackup',
    );
    _setDebug = _lib.lookupFunction<IntArgFn, IntArgFnDart>('HaloSetDebug');
    // engine logs to logcat only in debug. release builds stay silent so no
    // onion address, peer id, or tor timing ever lands in the log.
    _setDebug(kDebugMode ? 1 : 0);
  }

  // every string back from the engine is copied and freed through
  // engineTake (engine_strings.dart), the ones that can hold a key or
  // plaintext through engineTakeSecret
  String version() => engineTake(_version());
  String generateIdentity() => engineTake(_genIdentity());
  String myId() => engineTake(_myId());
  String myEdPubkey() => engineTake(_myEdPub());
  String myXPubkey() => engineTake(_myXPub());
  String myEdPrivkey() => engineTakeSecret(_myEdPriv());
  String myXPrivkey() => engineTakeSecret(_myXPriv());
  String startListener(String dataDir) {
    final ptr = dataDir.toNativeUtf8();
    try {
      return engineTake(_start(ptr));
    } finally {
      malloc.free(ptr);
    }
  }

  List<String> drainInbox() {
    final raw = engineTake(_drainInbox());
    if (raw.isEmpty) return const [];
    return raw.split('\n');
  }

  // polled every second by the watchdog
  String getStatus() => _take(_getStatus());

  // every relay socket dropped and reopened now, since window and all
  String nostrKick() => engineTake(_nostrKick());

  // looked up on first use so older engines still load
  late final CStrFnDart _catchupState = _lib.lookupFunction<CStrFn, CStrFnDart>(
    'HaloCatchupState',
  );

  /// (connections still fetching what they missed, connections begun so far)
  (int, int) catchupState() {
    try {
      final p = engineTake(_catchupState()).split(' ');
      return (int.parse(p[0]), int.parse(p[1]));
    } catch (_) {
      return (0, 0);
    }
  }

  // where the last tor reconnect got to. looked up on first use so older
  // engines still load.
  late final CStrFnDart _lastReconnect = _lib
      .lookupFunction<CStrFn, CStrFnDart>('HaloLastReconnect');

  // the transport screen reads it on every refresh
  String lastReconnect() {
    try {
      return engineTake(_lastReconnect());
    } catch (_) {
      // an older engine without the call: nothing to show
      return '';
    }
  }

  // what the go side holds, json
  Map<String, dynamic> memStats() {
    try {
      return jsonDecode(engineTake(_memStats())) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }

  String nostrInit(String relaysCSV) {
    final ptr = relaysCSV.toNativeUtf8();
    try {
      return engineTake(_nostrInit(ptr));
    } finally {
      malloc.free(ptr);
    }
  }

  String idFromEdPub(String hexPub) {
    final ptr = hexPub.toNativeUtf8();
    try {
      return engineTake(_idFromEdPub(ptr));
    } finally {
      calloc.free(ptr);
    }
  }

  String decryptBackup(String blob, String passphrase) {
    final p1 = blob.toNativeUtf8();
    final p2 = passphrase.toNativeUtf8();
    try {
      return engineTakeSecret(_decryptBackup(p1, p2));
    } finally {
      calloc.free(p1);
      freeSecret(p2);
    }
  }

  // offloaded to a background isolate so a slow relay never freezes the ui.
  // the 1:1 doors ask the dev gate first: a pinned key's lane is the dev
  // chat's alone
  Future<String> nostrSend(String peerXPubHex, String b64Cipher) =>
      devGate.nostrSend(
        peerXPubHex,
        b64Cipher,
        out: () =>
            _sendOnIsolate((nostr: true, a: peerXPubHex, b: b64Cipher)).timeout(
              const Duration(seconds: 60),
              onTimeout: () => 'error: relay timeout',
            ),
        room: (priv) => roomSend(priv, peerXPubHex, b64Cipher),
      );

  void nostrSubscribeBg(String peerXPubHex) {
    _background(
      devGate.listen(
        peerXPubHex,
        out: () => _subscribeOnIsolate(peerXPubHex),
        room: (priv) async {
          roomSubscribeBg(priv, peerXPubHex);
          return 'ok';
        },
      ),
      'relay listen',
    );
  }

  // bridge lines in, a summary out. tor only reads its config at startup, so
  // callers restart it after changing this or nothing happens.
  String setBridges(String lines, bool on) {
    final a = lines.toNativeUtf8();
    final b = (on ? '1' : '0').toNativeUtf8();
    try {
      return engineTake(_setBridges(a, b));
    } finally {
      malloc.free(a);
      malloc.free(b);
    }
  }

  // "on|count|port"
  String bridgeState() => engineTake(_bridgeState());

  void restartTor() => _take(_restartTor());

  // android reports a new default network: tor is bounced once it has been
  // quiet a few seconds. looked up on first use so older engines still load.
  late final CStrFnDart _networkChanged = _lib
      .lookupFunction<CStrFn, CStrFnDart>('HaloNetworkChanged');
  void networkChanged() {
    try {
      _take(_networkChanged());
    } catch (_) {
      // an older engine without the call: tor keeps its own schedule
    }
  }

  static String _take(Pointer<Utf8> p) => engineTake(p);

  // the registry is a request over tor, so it runs off the ui thread
  Future<String> handleCheck(String h) => _ffiOnIsolate('HaloHandleCheck', [h]);

  Future<String> handleClaim(String h, String invite, String bio) =>
      _ffiOnIsolate('HaloHandleClaim', [h, invite, bio]);

  Future<String> handleRelease(String h) =>
      _ffiOnIsolate('HaloHandleRelease', [h]);

  Future<String> handleListing(String h, bool listed, String name) =>
      _ffiOnIsolate('HaloHandleListing', [h, listed ? '1' : '0', name]);

  // tell the engine whether to route through tor. it decides the route; the
  // relay list for each mode is chosen below.
  String setTransportMode(String mode) {
    final p = mode.toNativeUtf8();
    try {
      return engineTake(_setMode(p));
    } finally {
      malloc.free(p);
    }
  }

  // both moat calls block on a network round trip, so they run off the ui
  // isolate. the request is plain https on purpose: tor being unreachable is
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

  // everything the transport knows, in one read. no inference on this side.
  Map<String, dynamic> transportState() {
    try {
      return jsonDecode(engineTake(_txState())) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }

  String firstContactPk(int counter) => engineTake(_fcPk(counter));

  // put an invite where a six digit code points, and look for one there. a
  // look that never came back heard from no relay, so it says nothing about
  // the code
  Future<String> pairCodePublish(String code, String payload) =>
      _pairCodeOnIsolate(
        code,
        payload,
      ).timeout(const Duration(seconds: 50), onTimeout: () => pairUnreached);

  Future<String> pairCodeFetch(String code) => _pairCodeOnIsolate(
    code,
    null,
  ).timeout(const Duration(seconds: 40), onTimeout: () => pairUnreached);

  // unlike every other subscription this needs no contacts
  void subscribeFirstContactBg(int counter) {
    _background(_fcSubscribeOnIsolate(counter), 'first contact listen');
  }

  // introduce ourselves to someone who has never heard of us.
  Future<String> sendFirstContact(
    String peerXPubHex,
    String fcPk,
    String b64Cipher,
  ) => devGate.sendFirstContact(
    peerXPubHex,
    fcPk,
    b64Cipher,
    out: () => _fcSendOnIsolate(peerXPubHex, fcPk, b64Cipher).timeout(
      const Duration(seconds: 60),
      onTimeout: () => 'error: relay timeout',
    ),
    room: (priv) => roomSendFirstContact(priv, peerXPubHex, fcPk, b64Cipher),
  );

  // it cannot wait on the dev chat, so it never names a pinned key
  String nostrSubscribe(String peerXPubHex) {
    if (devGate.names(xPub: peerXPubHex)) return kDevRefused;
    final ptr = peerXPubHex.toNativeUtf8();
    try {
      return engineTake(_nostrSubscribe(ptr));
    } finally {
      malloc.free(ptr);
    }
  }

  // POST json over tor (badge invoices). keeps 2xx bodies, unlike torGet.
  // off the ui thread, since it waits on a rendezvous and a round trip.
  Future<String> torPost(String url, String body) => _ffiOnIsolate(
    'HaloTorPost',
    [url, body],
    wait: const Duration(seconds: 80),
    what: 'tor',
  );

  // GET over tor that accepts any 2xx: the badge service replies 202 while
  // a donation is still unconfirmed. off the ui thread, as above.
  Future<String> torGetJson(String url) => _ffiOnIsolate(
    'HaloTorGetJSON',
    [url],
    wait: const Duration(seconds: 80),
    what: 'tor',
  );

  // what the relays delivered, one entry per event (relay_poll.dart). room
  // frames in it are plaintext, so it is zeroed on the way back
  List<({String peer, String cipher})> nostrPoll() =>
      parseRelayPoll(engineTakeSecret(_nostrPoll()));

  // the wipe stops every relay listener and takes tor off the network before
  // it deletes, so nothing is written back into the folders it empties
  Future<String> wipeHold() => _torCtlOnIsolate('HaloWipeHold');

  // check-ins put tor to sleep and wake it, off the ui thread
  Future<String> torStop() => _torCtlOnIsolate('HaloTorStop');
  Future<String> torResume() => _torCtlOnIsolate('HaloTorResume');
  Future<String> startListenerBg(String dataDir) =>
      _startListenerOnIsolate(dataDir);
  // whether the engine holds tor asleep. a wake that failed has let it run
  // already, whatever the app thinks
  bool torPaused() => _torPaused() == 1;

  // the decoy's identity: pure engine calls that touch no engine state and
  // log nothing (engine/quiet.go)
  late final CStrFnDart _quietNew = _lib.lookupFunction<CStrFn, CStrFnDart>(
    'HaloQuietIdentity',
  );
  late final ThreeArgFnDart _quietDescribe = _lib
      .lookupFunction<ThreeArgFn, ThreeArgFnDart>('HaloQuietDescribe');
  late final StrCounterFnDart _quietFc = _lib
      .lookupFunction<StrCounterFn, StrCounterFnDart>(
        'HaloQuietFirstContactPk',
      );

  // {ed_priv, x_priv, onion_key, id, ed_pub, x_pub, onion}, or null
  Map<String, dynamic>? quietIdentity() => _quietJson(_quietNew());

  Map<String, dynamic>? quietDescribe(String ed, String x, String onion) {
    final a = ed.toNativeUtf8(), b = x.toNativeUtf8(), c = onion.toNativeUtf8();
    try {
      return _quietJson(_quietDescribe(a, b, c));
    } finally {
      freeSecret(a);
      freeSecret(b);
      freeSecret(c);
    }
  }

  String quietFirstContactPk(String xPriv, int counter) {
    final a = xPriv.toNativeUtf8();
    try {
      return engineTake(_quietFc(a, counter));
    } finally {
      freeSecret(a);
    }
  }

  // the hidden chats' sealing (engine/vault.go): pure calls that touch no
  // engine state and log nothing. looked up on first use
  late final CStrFnDart _vaultKeys = _lib.lookupFunction<CStrFn, CStrFnDart>(
    'HaloVaultKeys',
  );
  late final TwoArgFnDart _vaultSeal = _lib
      .lookupFunction<TwoArgFn, TwoArgFnDart>('HaloVaultSeal');
  late final TwoArgFnDart _vaultOpenMany = _lib
      .lookupFunction<TwoArgFn, TwoArgFnDart>('HaloVaultOpenMany');

  // a new vault's sealing pair: the public half for the everyday side, the
  // private half kept in the vault
  ({String pub, String priv}) vaultKeys() {
    final out = engineTakeSecret(_vaultKeys());
    // the engine's errors never carry a key
    if (out.isEmpty || out.startsWith('error')) throw StateError(out);
    final j = jsonDecode(out) as Map<String, dynamic>;
    return (pub: j['pub'] as String, priv: j['priv'] as String);
  }

  // the bytes in b64 sealed to pub, as base64, or an error line
  String vaultSeal(String pub, String b64) {
    final a = pub.toNativeUtf8(), b = b64.toNativeUtf8();
    try {
      return _take(_vaultSeal(a, b));
    } finally {
      malloc.free(a);
      malloc.free(b);
    }
  }

  // sealed items opened in one call, in order: base64, or null where one
  // will not open. a call that fails as a whole throws
  List<String?> vaultOpenMany(String priv, List<String> b64s) {
    final a = priv.toNativeUtf8(), b = jsonEncode(b64s).toNativeUtf8();
    try {
      final out = engineTakeSecret(_vaultOpenMany(a, b));
      // the engine's errors never carry a key
      if (out.startsWith('error')) throw StateError(out);
      final list = [for (final s in jsonDecode(out) as List) s as String?];
      if (list.length != b64s.length) throw StateError('vault open: count');
      return list;
    } finally {
      freeSecret(a);
      malloc.free(b);
    }
  }

  Map<String, dynamic>? _quietJson(Pointer<Utf8> p) {
    final s = engineTakeSecret(p);
    if (s.startsWith('error')) return null;
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String restoreIdentity(String edPriv, String xPriv) {
    final c1 = edPriv.toNativeUtf8();
    final c2 = xPriv.toNativeUtf8();
    try {
      return engineTake(_restoreIdentity(c1, c2));
    } finally {
      freeSecret(c1);
      freeSecret(c2);
    }
  }

  String encryptFor(String peerPub, String plain) {
    final cPub = peerPub.toNativeUtf8();
    final cPlain = plain.toNativeUtf8();
    try {
      return engineTake(_encryptFor(cPub, cPlain));
    } finally {
      calloc.free(cPub);
      calloc.free(cPlain);
    }
  }

  String decryptFrom(String peerPub, String b64) {
    final cPub = peerPub.toNativeUtf8();
    final cB64 = b64.toNativeUtf8();
    try {
      return engineTakeSecret(_decryptFrom(cPub, cB64));
    } finally {
      calloc.free(cPub);
      calloc.free(cB64);
    }
  }

  // offloaded to a background isolate so a slow tor dial never freezes the ui.
  Future<String> sendTo(String addr, String msg) => devGate.sendTo(
    addr,
    out: () => _sendOnIsolate((nostr: false, a: addr, b: msg)).timeout(
      const Duration(seconds: 15),
      onTimeout: () => 'error: onion timeout',
    ),
  );

  // burner rooms. every call hands the room's own private key back to the
  // engine, which never keeps it: the key lives in the room row and dies
  // with it.
  ({String priv, String pub})? roomKeygen() {
    final r = engineTakeSecret(
      _lib.lookupFunction<CStrFn, CStrFnDart>('HaloRoomKeygen')(),
    );
    final i = r.indexOf(':');
    if (r.startsWith('error') || i < 0) return null;
    return (priv: r.substring(0, i), pub: r.substring(i + 1));
  }

  String roomFcPk(String priv) {
    final fn = _lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloRoomFcPk');
    final p = priv.toNativeUtf8();
    try {
      return engineTake(fn(p));
    } finally {
      freeSecret(p);
    }
  }

  // a pinned key is reached this way only as the anonymous dev chat's name
  Future<String> roomSend(String priv, String peerPub, String msg) =>
      devGate.roomSend(
        priv,
        peerPub,
        msg,
        out: () =>
            _roomFfiOnIsolate('HaloRoomSend', [priv, peerPub, msg]).timeout(
              const Duration(seconds: 60),
              onTimeout: () => 'error: relay timeout',
            ),
      );

  Future<String> roomSendFirstContact(
    String priv,
    String peerPub,
    String fcPk,
    String msg,
  ) => devGate.roomSendFirstContact(
    priv,
    peerPub,
    fcPk,
    msg,
    out: () =>
        _roomFfiOnIsolate('HaloRoomSendFirstContact', [
          priv,
          peerPub,
          fcPk,
          msg,
        ]).timeout(
          const Duration(seconds: 60),
          onTimeout: () => 'error: relay timeout',
        ),
  );

  void roomSubscribeBg(String priv, String peerPub) => _background(
    devGate.roomListen(
      priv,
      peerPub,
      out: () => _roomFfiOnIsolate('HaloRoomSubscribe', [priv, peerPub]),
    ),
    'room listen',
  );
  void roomSubscribeFcBg(String priv) => _background(
    _roomFfiOnIsolate('HaloRoomSubscribeFirstContact', [priv]),
    'room first contact',
  );
  void roomUnsubscribeBg(String pub) => _background(
    _roomFfiOnIsolate('HaloRoomUnsubscribe', [pub]),
    'room unlisten',
  );

  // what a room's addresses kept on disk, gone with the room: its key and
  // its members' keys name every address it had
  void roomForgetBg(String priv, List<String> members) => _background(
    _roomFfiOnIsolate('HaloRoomForget', [priv, jsonEncode(members)]),
    'room forget',
  );

  // no more listening for a peer, and its address's files gone
  void nostrUnsubscribeBg(String peerXPubHex) => _background(
    _roomFfiOnIsolate('HaloNostrUnsubscribe', [peerXPubHex]),
    'unlisten',
  );
}

// a call nobody waits on: what it threw still shows in a debug log
void _background(Future<Object?> call, String where) =>
    unawaited(call.then((_) {}, onError: (Object e) => dlog('$where: $e')));

// one to four string args in, a string out, on its own isolate like every
// other relay call.
Future<String> _roomFfiOnIsolate(String name, List<String> args) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final ptrs = [for (final a in args) a.toNativeUtf8()];
    try {
      switch (ptrs.length) {
        case 1:
          return engineTake(
            lib.lookupFunction<OneArgFn, OneArgFnDart>(name)(ptrs[0]),
          );
        case 2:
          return engineTake(
            lib.lookupFunction<TwoArgFn, TwoArgFnDart>(name)(ptrs[0], ptrs[1]),
          );
        case 3:
          return engineTake(
            lib.lookupFunction<ThreeArgFn, ThreeArgFnDart>(name)(
              ptrs[0],
              ptrs[1],
              ptrs[2],
            ),
          );
        default:
          return engineTake(
            lib.lookupFunction<FourArgFn, FourArgFnDart>(name)(
              ptrs[0],
              ptrs[1],
              ptrs[2],
              ptrs[3],
            ),
          );
      }
    } finally {
      // a room's private key, and what is sent under it
      for (final p in ptrs) {
        freeSecret(p);
      }
    }
  });
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
      return engineTake(fn(a, b, c));
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
      return engineTake(fn());
    }
    final fn = lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloMoatSolve');
    final a = challenge.toNativeUtf8();
    final b = (answer ?? '').toNativeUtf8();
    try {
      return engineTake(fn(a, b));
    } finally {
      malloc.free(a);
      malloc.free(b);
    }
  });
}

// one read through the engine's http route, off the ui thread. used for the
// handle lookup, which can wait on tor.
Future<String> _torGetJsonOnIsolate(String url) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final fn = lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloTorGetJSON');
    final u = url.toNativeUtf8();
    try {
      return engineTake(fn(u));
    } finally {
      malloc.free(u);
    }
  });
}

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
        return engineTake(fn(c));
      }
      final fn = lib.lookupFunction<TwoArgFn, TwoArgFnDart>(
        'HaloPairCodePublish',
      );
      final pl = payload.toNativeUtf8();
      try {
        return engineTake(fn(c, pl));
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
    return engineTake(fn(counter));
  });
}

// tor's control port answers fast, but never on the ui thread
Future<String> _torCtlOnIsolate(String symbol) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    return engineTake(lib.lookupFunction<CStrFn, CStrFnDart>(symbol)());
  }).timeout(const Duration(seconds: 70), onTimeout: () => 'error: timeout');
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
      return engineTake(fn(p));
    } finally {
      malloc.free(p);
    }
  });
}

// one, two or three strings in, one string out, on a background isolate
// with a ceiling so a registry that never answers cannot hold a screen
Future<String> _ffiOnIsolate(
  String symbol,
  List<String> args, {
  Duration wait = const Duration(seconds: 45),
  String what = 'registry',
}) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final ps = [for (final a in args) a.toNativeUtf8()];
    try {
      switch (ps.length) {
        case 1:
          return engineTake(
            lib.lookupFunction<OneArgFn, OneArgFnDart>(symbol)(ps[0]),
          );
        case 2:
          return engineTake(
            lib.lookupFunction<TwoArgFn, TwoArgFnDart>(symbol)(ps[0], ps[1]),
          );
        default:
          return engineTake(
            lib.lookupFunction<ThreeArgFn, ThreeArgFnDart>(symbol)(
              ps[0],
              ps[1],
              ps[2],
            ),
          );
      }
    } finally {
      for (final p in ps) {
        malloc.free(p);
      }
    }
  }).timeout(wait, onTimeout: () => 'error: $what timeout');
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
      return engineTake(fn(p1, p2));
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
      return engineTake(fn(p));
    } finally {
      malloc.free(p);
    }
  });
}

// the json stored for a shipped preview, or null when there is none or
// the sender is not someone accepted. only the url and a one-line title
// survive; anything else the sender put in the map is dropped here
String? shippedPreview(Map<String, String>? pv, {required bool accepted}) {
  if (pv == null || !accepted) return null;
  final url = pv['url'];
  final title = pv['title'];
  if (url == null || title == null || title.trim().isEmpty) return null;
  final clean = title.replaceAll(RegExp(r'\s+'), ' ').trim();
  return jsonEncode({
    'url': url,
    'title': clean.length > 120 ? clean.substring(0, 120) : clean,
    'by': 'sender',
  });
}

Future<String> torStrictGetOnIsolate(String url) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final fn = lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloTorGetStrict');
    final p = url.toNativeUtf8();
    try {
      return engineTake(fn(p));
    } finally {
      malloc.free(p);
    }
  });
}

class HaloDb implements GroupOwedStore {
  HaloDb([this.container = HaloContainer.everyday]);

  // a wrapped container, under the key its pin entry unwrapped. storage is
  // never read or written for it, and the key goes on close
  HaloDb.withKey(this.container, String keyHex) : _given = "x'$keyHex'" {
    if (!container.wrapped) {
      throw ArgumentError('${container.dbFile} has a key of its own');
    }
    // anything else would be taken as a passphrase and open another file
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(keyHex)) {
      throw ArgumentError('a raw key is 64 hex characters');
    }
  }

  // whose database this is: its file, and where its key sits
  final HaloContainer container;

  static const _storage = secureStoreEsp;

  Database? _db;
  String? _given;

  // 32 bytes from the platform csprng, made once, before its database
  // file. a read that fails throws, and boot shows it: a new key is made
  // only while no file exists that the old one opens
  Future<String> _passphrase() async {
    final given = _given;
    if (given != null) return given;
    final name = container.keyName;
    if (name == null) throw StateError('${container.dbFile} has no key here');
    var pw = await _storage.read(key: name);
    if (pw != null) return pw;
    if (await File(await container.dbPath()).exists()) {
      throw StateError('${container.dbFile} has no key here');
    }
    pw = container.newKey();
    await _storage.write(key: name, value: pw);
    return pw;
  }

  // folds the write-ahead log into the file before it is copied. a
  // backup reads halo.db as bytes, and without this the last minutes of
  // messages could still be sitting in the sidecar. a failure is passed on:
  // a copy made without it would miss them and still look whole. a reader
  // holding the log says busy, and is waited out a few times before that
  Future<void> checkpoint() async {
    final db = _db;
    if (db == null) return;
    for (var i = 1; ; i++) {
      final r = await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      if (r.isEmpty || r.first['busy'] != 1) return;
      if (i == 5) throw StateError('the log stayed busy');
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  // before its files go
  Future<void> close() async {
    final d = _db;
    _db = null;
    _given = null;
    _unfinished = null;
    _strandedLit = false;
    await d?.close();
  }

  // the file copied to [to] whole: a read holds the lock that keeps every
  // writer out until the copy is done
  Future<void> copyTo(String to) async {
    final db = await open();
    await checkpoint();
    await db.transaction((t) async {
      await t.rawQuery('SELECT COUNT(*) FROM sqlite_master');
      await File(await container.dbPath()).copy(to);
    });
  }

  // a wrapped container copied for a backup, and the key it opens with,
  // which the backup carries inside its own encryption
  Future<String> copyWithKey(String to) async {
    final key = _given;
    if (key == null) throw StateError('${container.dbFile} has no key here');
    await copyTo(to);
    return key.substring(2, key.length - 1);
  }

  // a wrapped container attached to another database's connection under
  // its own key, so rows move between the two a statement at a time. the
  // key stays in here
  Future<void> attachTo(Database db, String schema) async {
    final key = _given;
    if (key == null) throw StateError('${container.dbFile} has no key here');
    await db.execute('ATTACH DATABASE ? AS $schema KEY ?', [
      await container.dbPath(),
      key,
    ]);
  }

  Future<Database> open() async {
    if (_db != null) return _db!;
    final path = await container.dbPath();
    final pw = await _passphrase();
    _db = await openDatabase(
      path,
      password: pw,
      version: 60,
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
            supporter_badge TEXT,
            avatar INTEGER,
            vouched_by TEXT,
            vouched_at INTEGER
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
            pinned_at INTEGER,
            secure INTEGER NOT NULL DEFAULT 0,
            media_path TEXT,
            file_path TEXT,
            file_name TEXT,
            voice_disguised INTEGER NOT NULL DEFAULT 0,
            saved INTEGER NOT NULL DEFAULT 0,
            sent INTEGER NOT NULL DEFAULT 1,
            delivered INTEGER NOT NULL DEFAULT 0,
            preview TEXT,
            pow_nonce INTEGER,
            burn_secs INTEGER,
            poll TEXT,
            sticker TEXT,
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
            atmosphere TEXT,
            room_priv TEXT,
            room_pub TEXT,
            expires_at INTEGER,
            creator_pub TEXT,
            fc_pk TEXT,
            member_cap INTEGER,
            room_seen INTEGER NOT NULL DEFAULT 0,
            mentioned INTEGER NOT NULL DEFAULT 0
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
            sender TEXT,
            PRIMARY KEY (media_id, idx)
          )
        ''');
        await _vouchTable(db);
        await _shieldTable(db);
        await _editsTable(db);
        await _pinsTable(db);
        await _framesTable(db);
        await _mediaWantsTable(db);
        await _heldTable(db);
        await _signalTables(db);
        await _pollTables(db);
        await searchTables(db, fresh: true);
        await routerTables(db);
        await _devChatTables(db);
        await _devSignalTables(db);
        await _supportTables(db);
        await groupOwedTables(db);
        await groupCtlTables(db);
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 60) {
          // group controls queued per member, and each group's roster stamp
          await groupCtlTables(db);
        }
        if (oldV < 59) {
          // what a group file's send left owed, member by member
          await groupOwedTables(db);
        }
        if (oldV < 58) {
          // unsends and reactions queue like edits
          await _framesTable(db);
        }
        if (oldV < 57) {
          // who sent each slice of an unfinished file
          await addColumn(
            db,
            'ALTER TABLE media_chunks ADD COLUMN sender TEXT',
          );
        }
        if (oldV < 56) {
          // the developer's own phone: its support inbox
          await _supportTables(db);
        }
        if (oldV < 55) {
          // the anonymous dev chat's own signal store
          await _devSignalTables(db);
        }
        if (oldV < 54) {
          // the developer chat's row: an upgrade shows it once, as a fresh
          // install does
          await _devChatTables(db);
        }
        if (oldV < 53) {
          // the hidden chats' list, their sealing key and what came sealed
          await routerTables(db);
        }
        if (oldV < 52) {
          // stickers: the wire value on the row
          await addColumn(db, 'ALTER TABLE messages ADD COLUMN sticker TEXT');
        }
        if (oldV < 51) {
          // search: the index starts empty and fills from the oldest
          // message up, in the background, a batch at a time
          await searchTables(db);
        }
        if (oldV < 50) {
          // polls: the options on the row, the votes beside it
          await addColumn(db, 'ALTER TABLE messages ADD COLUMN poll TEXT');
          await _pollTables(db);
        }
        if (oldV < 49) {
          await _mediaWantsTable(db);
        }
        if (oldV < 48) {
          // when a message was pinned, so the list of pins can run newest
          // first. pins from before have none and sort by their own time.
          await _pinsTable(db);
          await addColumn(
            db,
            'ALTER TABLE messages ADD COLUMN pinned_at INTEGER',
          );
        }
        if (oldV < 47) {
          // the reader-side title cache is unused
          try {
            await db.execute('DROP TABLE IF EXISTS link_titles');
          } catch (e) {
            dlog('migration 47: $e');
          }
        }
        if (oldV < 46) {
          // onion-lane messages past the stranger cap, kept for accept
          await _heldTable(db);
        }
        if (oldV < 45) {
          // edits that have not reached the other side yet
          await _editsTable(db);
        }
        if (oldV < 44) {
          // the burn window a queued message was sent with, since burn_at is
          // only set on delivery
          await addColumn(
            db,
            'ALTER TABLE messages ADD COLUMN burn_secs INTEGER',
          );
        }
        if (oldV < 43) {
          // the link title cache rides the same helper as the shield table
          // (create if missing), so an existing phone gets it too
          await _shieldTable(db);
        }
        if (oldV < 42) {
          // a group where someone wrote your three words after an @, so the
          // home row can say so. cleared with the unread count.
          await addColumn(
            db,
            'ALTER TABLE groups ADD COLUMN mentioned INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 41) {
          // the proof-of-work a stranger's first message was sent with, so
          // an opener the outbox retries is not dropped on the far side
          await addColumn(
            db,
            'ALTER TABLE messages ADD COLUMN pow_nonce INTEGER',
          );
        }
        if (oldV < 40) {
          // burner rooms live in the groups table with their own key and a
          // clock
          for (final col in const [
            'room_priv TEXT',
            'room_pub TEXT',
            'expires_at INTEGER',
            'creator_pub TEXT',
            'fc_pk TEXT',
            'member_cap INTEGER',
            'room_seen INTEGER NOT NULL DEFAULT 0',
          ]) {
            await addColumn(db, 'ALTER TABLE groups ADD COLUMN $col');
          }
        }
        if (oldV < 39) {
          // what the scam shield flagged on a stranger, and whether the
          // person told it to drop the matter.
          await _shieldTable(db);
        }
        if (oldV < 38) {
          // one person can be vouched for by several people we know. the
          // single vouched_by column stays but is unused: dropping columns on
          // a phone is not worth it.
          await _vouchTable(db);
          try {
            await db.execute('''
              INSERT OR IGNORE INTO vouches (halo_id, voucher_id, note, created_at)
              SELECT halo_id, vouched_by, NULL,
                     IFNULL(vouched_at, first_seen)
              FROM contacts WHERE vouched_by IS NOT NULL
            ''');
          } catch (e) {
            dlog('migrate v38: backfill skipped ($e)');
          }
        }
        if (oldV < 37) {
          // who introduced this contact, so their request skips the stranger
          // gate
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN vouched_by TEXT',
          );
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN vouched_at INTEGER',
          );
        }
        if (oldV < 36) {
          // the face a contact picked, so we draw theirs and not a
          // default derived from their id.
          await addColumn(db, 'ALTER TABLE contacts ADD COLUMN avatar INTEGER');
        }
        if (oldV < 35) {
          // the sender can ask that a message not be screenshotted. we
          // keep the flag so it still holds after a restart
          await addColumn(
            db,
            'ALTER TABLE messages ADD COLUMN secure INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 34) {
          // partial media on disk, so a restart does not lose it
          await db.execute('''
            CREATE TABLE IF NOT EXISTS media_chunks (
              media_id TEXT NOT NULL,
              idx INTEGER NOT NULL,
              slice TEXT NOT NULL,
              total INTEGER NOT NULL,
              burn INTEGER,
              at INTEGER NOT NULL,
              sender TEXT,
              PRIMARY KEY (media_id, idx)
            )
          ''');
        }
        if (oldV < 33) {
          await addColumn(
            db,
            'ALTER TABLE messages ADD COLUMN delivered INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 32) {
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN supporter_badge TEXT',
          );
        }
        if (oldV < 31) {
          // duplicate msg_uids break every uid-keyed widget key. keep the
          // original row per uid, drop the copies.
          await db.execute('''
            DELETE FROM messages WHERE msg_uid IS NOT NULL AND id NOT IN (
              SELECT MIN(id) FROM messages WHERE msg_uid IS NOT NULL
              GROUP BY msg_uid
            )
          ''');
        }
        if (oldV < 30) {
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN peer_bundle TEXT',
          );
        }
        if (oldV < 29) {
          await addColumn(db, 'ALTER TABLE groups ADD COLUMN atmosphere TEXT');
        }
        if (oldV < 28) {
          await addColumn(
            db,
            'ALTER TABLE groups ADD COLUMN unread INTEGER NOT NULL DEFAULT 0',
          );
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
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN accepted INTEGER NOT NULL DEFAULT 1',
          );
        }
        if (oldV < 25) {
          await addColumn(db, 'ALTER TABLE groups ADD COLUMN admin_id TEXT');
        }
        if (oldV < 24) {
          await addColumn(db, 'ALTER TABLE groups ADD COLUMN description TEXT');
        }
        if (oldV < 23) {
          await addColumn(db, 'ALTER TABLE messages ADD COLUMN preview TEXT');
        }
        if (oldV < 22) {
          await addColumn(
            db,
            'ALTER TABLE messages ADD COLUMN voice_disguised INTEGER NOT NULL DEFAULT 0',
          );
          await addColumn(
            db,
            'ALTER TABLE messages ADD COLUMN saved INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 21) {
          await addColumn(db, 'ALTER TABLE messages ADD COLUMN file_path TEXT');
          await addColumn(db, 'ALTER TABLE messages ADD COLUMN file_name TEXT');
        }
        if (oldV < 20) {
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN key_changed INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 19) {
          await addColumn(
            db,
            'ALTER TABLE messages ADD COLUMN sent INTEGER NOT NULL DEFAULT 1',
          );
        }
        if (oldV < 2) await _signalTables(db);
        if (oldV < 3) {
          await addColumn(
            db,
            'ALTER TABLE messages ADD COLUMN burn_at INTEGER',
          );
        }
        if (oldV < 4) {
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN back_paired INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 5) {
          await addColumn(db, 'ALTER TABLE messages ADD COLUMN msg_uid TEXT');
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
          await addColumn(db, 'ALTER TABLE messages ADD COLUMN reply_to TEXT');
        }
        if (oldV < 8) {
          await addColumn(db, 'ALTER TABLE contacts ADD COLUMN nickname TEXT');
        }
        if (oldV < 9) {
          await addColumn(
            db,
            'ALTER TABLE messages ADD COLUMN edited INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 10) {
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN blocked INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 11) {
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN muted INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 12) {
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN archived INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 13) {
          await addColumn(
            db,
            'ALTER TABLE messages ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 14) {
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN verified INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 16) {
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN unread INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 17) {
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN atmosphere TEXT',
          );
        }
        if (oldV < 18) {
          await addColumn(db, 'ALTER TABLE contacts ADD COLUMN note TEXT');
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 15) {
          await addColumn(
            db,
            'ALTER TABLE messages ADD COLUMN media_path TEXT',
          );
        }
        if (oldV < 7) {
          await addColumn(db, 'ALTER TABLE messages ADD COLUMN group_id TEXT');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_messages_group_id ON messages(group_id)',
          );
          // the whole table as a fresh install gets it: the later column
          // migrations run before this block
          await db.execute('''
            CREATE TABLE groups (
              group_id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              description TEXT,
              created_at INTEGER NOT NULL,
              is_admin INTEGER NOT NULL DEFAULT 0,
              admin_id TEXT,
              unread INTEGER NOT NULL DEFAULT 0,
              atmosphere TEXT,
              room_priv TEXT,
              room_pub TEXT,
              expires_at INTEGER,
              creator_pub TEXT,
              fc_pk TEXT,
              member_cap INTEGER,
              room_seen INTEGER NOT NULL DEFAULT 0,
              mentioned INTEGER NOT NULL DEFAULT 0
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
    // the dev chat's bundle is the pinned one, and his is no one else's
    if (isDevId(haloId) || devKeyByBundle(bundleB64) != null) return;
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

  // a contact stub from group invite info. a peer we already know is left
  // as is.
  Future<void> upsertContactStub(
    String haloId,
    String onion,
    String xpub,
  ) async {
    // only the dev chat's own code writes its row, and no one else gets
    // the developer's words or key
    if (devCardClaim(id: haloId, xPub: xpub)) return;
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
    // the dev chat never warns: a key that is not the pinned one is dropped
    if (isDevId(haloId)) return;
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

  Future<void> setContactBadge(String haloId, String? tier) async {
    final d = await open();
    await d.update(
      'contacts',
      {'supporter_badge': tier},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  // who vouched for whom. a row only ever lands when the voucher is a
  // contact we accepted, which is what makes the count mean anything.
  Future<void> addVouch(
    String haloId,
    String voucherId,
    String? note, {
    int? at,
  }) async {
    final db = await open();
    final v = await db.query(
      'contacts',
      columns: ['accepted'],
      where: 'halo_id = ?',
      whereArgs: [voucherId],
      limit: 1,
    );
    if (v.isEmpty || (v.first['accepted'] as int? ?? 0) != 1) {
      dlog('vouch: $voucherId is not an accepted contact, dropped');
      return;
    }
    final n = (note ?? '').trim();
    await db.insert('vouches', {
      'halo_id': haloId,
      'voucher_id': voucherId,
      'note': n.isEmpty ? null : (n.length > 40 ? n.substring(0, 40) : n),
      'created_at': at ?? DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // every vouch for one person, joined to what we know about the voucher.
  // only vouchers we still hold as accepted contacts count: a deleted or
  // blocked one drops out here rather than lingering as a name.
  Future<List<Map<String, Object?>>> vouchesFor(String haloId) async {
    final db = await open();
    return db.rawQuery(
      '''
      SELECT v.voucher_id, v.note, v.created_at,
             c.nickname, c.avatar, c.verified
      FROM vouches v JOIN contacts c ON c.halo_id = v.voucher_id
      WHERE v.halo_id = ? AND c.accepted = 1 AND c.blocked = 0
      ORDER BY v.created_at ASC
      ''',
      [haloId],
    );
  }

  Future<bool> isVouched(String haloId) async {
    final db = await open();
    final r = await db.rawQuery(
      '''
      SELECT 1 FROM vouches v JOIN contacts c ON c.halo_id = v.voucher_id
      WHERE v.halo_id = ? AND c.accepted = 1 AND c.blocked = 0 LIMIT 1
      ''',
      [haloId],
    );
    return r.isNotEmpty;
  }

  // introduced people we have not accepted yet. they need a relay
  // subscription like a real contact or their first message never lands.
  Future<List<Map<String, Object?>>> vouchedPending() async {
    final db = await open();
    return db.rawQuery('''
      SELECT DISTINCT c.* FROM contacts c
      JOIN vouches v ON v.halo_id = c.halo_id
      WHERE c.accepted = 0 AND c.blocked = 0
    ''');
  }

  // headline and lines are stored as shield codes (ShieldHit.toJson), and
  // worded when shown. an empty headline is a clean check.
  Future<void> setShield(
    String haloId,
    String headline,
    List<Map<String, String>> lines,
  ) async {
    final db = await open();
    await db.insert('shield', {
      'halo_id': haloId,
      'headline': headline,
      'lines': jsonEncode(lines),
      'dismissed': 0,
      'at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<Map<String, Object?>?> shieldFor(String haloId) async {
    final db = await open();
    final r = await db.query(
      'shield',
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    return r.isEmpty ? null : r.first;
  }

  // ignore = for good. the row stays so the check never re-runs on them.
  Future<void> dismissShield(String haloId) async {
    final db = await open();
    await db.update(
      'shield',
      {'dismissed': 1},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<int?> powNonceOf(String msgUid) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['pow_nonce'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['pow_nonce'] as num?)?.toInt();
  }

  Future<void> setPowNonce(String msgUid, int nonce) async {
    final db = await open();
    await db.update(
      'messages',
      {'pow_nonce': nonce},
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  Future<void> setContactAvatar(String haloId, int? av) async {
    final db = await open();
    await db.update(
      'contacts',
      {'avatar': av},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<void> setContactXPub(String haloId, String xpub) async {
    // the dev chat's row keeps the key it was made with, and no one else
    // gets his
    if (devCardClaim(id: haloId, xPub: xpub)) return;
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

  // every person held, true for a contact and false for a key only, and
  // every group: what a session reads to know whose a chat is
  Future<({Map<String, bool> people, Set<String> groups})> heldChats() async {
    final db = await open();
    final people = await db.query('contacts', columns: ['halo_id', 'accepted']);
    final groups = await db.query('groups', columns: ['group_id']);
    return (
      people: {
        for (final r in people)
          r['halo_id'] as String: (r['accepted'] as int? ?? 0) == 1,
      },
      groups: {for (final r in groups) r['group_id'] as String},
    );
  }

  // the developer chat's row: its flags, its start and its delete
  DevChat get devChat => DevChat(open, shred: shredFile);

  // the developer's own phone: the chats people start from the Marios row
  SupportChats get support => SupportChats(open);

  Future<void> deleteConversation(String haloId) async {
    final d = await open();
    final files = await d.transaction((t) async {
      final rows = await t.query(
        'messages',
        columns: ['msg_uid', ..._kFileCols],
        where: _kOneToOne,
        whereArgs: [haloId],
      );
      for (final r in rows) {
        final uid = r['msg_uid'] as String?;
        if (uid != null) {
          await t.delete('reactions', where: 'msg_uid = ?', whereArgs: [uid]);
        }
      }
      await t.delete('messages', where: _kOneToOne, whereArgs: [haloId]);
      await _dropFilesComingFrom(t, haloId);
      // the row stays: it carries the xpub our nostr subscription is built
      // from. archived + unaccepted = invisible everywhere until they write.
      await t.update(
        'contacts',
        {'accepted': 0, 'archived': 1, 'unread': 0},
        where: 'halo_id = ?',
        whereArgs: [haloId],
      );
      return rows;
    });
    await _scrubMedia(files);
  }

  // a request that never became one: its row and its shield line
  Future<void> forgetRequest(String haloId) async {
    final db = await open();
    await db.delete(
      'contacts',
      where: 'halo_id = ? AND accepted = ?',
      whereArgs: [haloId, 0],
    );
    await db.delete('shield', where: 'halo_id = ?', whereArgs: [haloId]);
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

  // every blocked id, accepted or not. contacts() is accepted-only, so a
  // caller built on it never sees someone blocked while still a stranger.
  Future<Set<String>> blockedIds() async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['halo_id'],
      where: 'blocked = 1',
    );
    return {for (final r in rows) r['halo_id'] as String};
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

  // how many messages we already hold from a sender in their own chat:
  // caps strangers. [inGroups] counts what they wrote in groups as well
  Future<int> countMessagesFrom(String peerId, {bool inGroups = false}) async {
    final db = await open();
    final r = await db.rawQuery(
      inGroups
          ? 'SELECT COUNT(*) c FROM messages WHERE peer_id = ? AND direction = ?'
          : 'SELECT COUNT(*) c FROM messages WHERE $_kOneToOne AND direction = ?',
      [peerId, 'in'],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  // how many messages we've sent a peer: caps our own request messages
  Future<int> countMessagesTo(String peerId) async {
    final db = await open();
    final r = await db.rawQuery(
      'SELECT COUNT(*) c FROM messages WHERE $_kOneToOne AND direction = ?',
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
  // the receive side tries and listens for all of these, a group member
  // known only by key included
  Future<List<Map<String, Object?>>> pendingRequests() async {
    final db = await open();
    return db.query(
      'contacts',
      where: 'accepted = 0 AND blocked = 0 AND IFNULL(archived, 0) = 0',
      orderBy: 'last_seen DESC',
    );
  }

  // of those, the ones who asked: what the requests inbox shows
  Future<List<Map<String, Object?>>> askedRequests() async {
    final db = await open();
    return db.query('contacts', where: kRequestRows, orderBy: 'last_seen DESC');
  }

  // declined and parked: out of the inbox, but a second message still has
  // to reach us so the row can resurface
  Future<List<Map<String, Object?>>> parkedRequests() async {
    final db = await open();
    return db.query(
      'contacts',
      where: 'accepted = 0 AND blocked = 0 AND IFNULL(archived, 0) = 1',
    );
  }

  // the requests inbox: support chats wait in their own, though the
  // receive side still tries them as requests
  Future<List<Map<String, Object?>>> requestsInbox() async {
    final rows = await askedRequests();
    if (rows.isEmpty) return rows;
    return withoutSupport(rows, await support.ids());
  }

  Future<int> pendingRequestCount() async {
    final db = await open();
    final r = await db.rawQuery(
      'SELECT COUNT(*) c FROM contacts WHERE $kRequestRows',
    );
    final n = (r.first['c'] as int?) ?? 0;
    if (n == 0 || (await support.ids()).isEmpty) return n;
    return (await requestsInbox()).length;
  }

  // someone who asked, or asked and was let go: adding them by their card
  // is the accept they were waiting for
  Future<bool> askedBefore(String haloId) async {
    final db = await open();
    final r = await db.rawQuery(
      'SELECT COUNT(*) c FROM contacts WHERE halo_id = ? AND ($kAskedRows)',
      [haloId],
    );
    return ((r.first['c'] as int?) ?? 0) > 0;
  }

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
  // not a block: they can reach us again later.
  Future<void> declineRequest(String haloId) async {
    final d = await open();
    final files = await d.transaction((t) async {
      final rows = await t.query(
        'messages',
        columns: ['msg_uid', ..._kFileCols],
        where: _kOneToOne,
        whereArgs: [haloId],
      );
      for (final r in rows) {
        final uid = r['msg_uid'] as String?;
        if (uid != null) {
          await t.delete('reactions', where: 'msg_uid = ?', whereArgs: [uid]);
        }
      }
      await t.delete('messages', where: _kOneToOne, whereArgs: [haloId]);
      await t.delete('held_onion', where: 'peer_id = ?', whereArgs: [haloId]);
      await _dropFilesComingFrom(t, haloId);
      // park, don't delete: the row carries the xpub the relay subscription
      // is built from. if they write again, unparkIfArchived surfaces them as
      // a new request.
      await t.update(
        'contacts',
        {'accepted': 0, 'archived': 1, 'unread': 0},
        where: 'halo_id = ?',
        whereArgs: [haloId],
      );
      return rows;
    });
    await _scrubMedia(files);
  }

  Future<void> upsertContact(
    String haloId,
    String onion,
    String xpub, {
    int accepted = 1,
  }) async {
    // only the dev chat's own code writes its row, and no one else gets
    // the developer's words or key
    if (devCardClaim(id: haloId, xPub: xpub)) return;
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
          // v2 links pass '' here: never wipe a key we already learned
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
    int? burnSecs,
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
    String? poll,
    String? sticker,
    // when it came, if not now: an arrival opened from the seal
    int? sentAt,
  }) async {
    final db = await open();
    final id = await db.insert('messages', {
      'peer_id': peerId,
      'direction': direction,
      // your own words too (a pasted caption, a forward): no direction
      // controls reach the screen from here (bidi_safe.dart)
      'plaintext': unmarked(plaintext),
      'sent_at': sentAt ?? DateTime.now().millisecondsSinceEpoch,
      'burn_at': burnAt,
      'burn_secs': burnSecs,
      'msg_uid': msgUid,
      'reply_to': replyTo,
      'group_id': groupId,
      'media_path': mediaPath,
      'file_path': filePath,
      'file_name': fileName == null ? null : unmarked(fileName),
      'voice_disguised': voiceDisguised ? 1 : 0,
      'preview': preview,
      'saved': saved ? 1 : 0,
      'sent': sent,
      'secure': secure ? 1 : 0,
      'poll': ?poll,
      'sticker': ?sticker,
    });
    try {
      await indexSearchRow(db, id, {
        'plaintext': plaintext,
        'poll': poll,
        'file_name': fileName,
        'preview': preview,
        'sticker': sticker,
      });
    } catch (e) {
      // a message is never lost to its index; the fill catches it up
      dlog('search: not indexed now: $e');
    }
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

  // the same message can come via tor and nostr, plus retries. a duplicate
  // crashes on the used-up prekey, so it is dropped before any decrypt.
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

  // like markSeen but stamped a month ahead of the daily prune: a pruned
  // hash of an undecryptable cipher replays the bad mac the next day. relays
  // age the events out well before the month is up.
  Future<void> markSeenLong(String hash) async {
    final db = await open();
    await db.insert('seen_msgs', {
      'hash': hash,
      'ts': DateTime.now().millisecondsSinceEpoch + 30 * 86400000,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // a msg_uid for a row from before the v5 migration, so it can take
  // reactions. (peer_id, sent_at) is unique enough in practice.
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

  // members is the full set, including the creator. isAdmin is true for
  // groups we created.
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

  // the authoritative list from a create or reconcile control replaces the
  // whole member set
  Future<void> syncGroupMembers(String groupId, List<String> members) async {
    await keepGroupOwedTo(groupId, members);
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
    await db.transaction(
      (t) => _owedGone(t, 'group_id = ? AND member = ?', [groupId, haloId]),
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
    for (final table in const [
      'group_media_owed',
      'group_ctl_out',
      'group_roster',
    ]) {
      await db.delete(table, where: 'group_id = ?', whereArgs: [groupId]);
    }
    await db.delete(
      'group_members',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    await db.delete('groups', where: 'group_id = ?', whereArgs: [groupId]);
  }

  // a burner room: a group row with a key of its own and an end time.
  // members are room keys, not kryfo ids; admin_id is the creator's key.
  Future<void> createRoom({
    required String groupId,
    required String name,
    required String priv,
    required String pub,
    required int expiresAt,
    required String creatorPub,
    required String fcPk,
    int? cap,
    required List<String> members,
  }) async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('groups', {
      'group_id': groupId,
      'name': name,
      'created_at': now,
      'is_admin': creatorPub == pub ? 1 : 0,
      'admin_id': creatorPub,
      'room_priv': priv,
      'room_pub': pub,
      'expires_at': expiresAt,
      'creator_pub': creatorPub,
      'fc_pk': fcPk,
      'member_cap': cap,
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

  Future<Map<String, Object?>?> roomByPub(String pub) async {
    final db = await open();
    final rows = await db.query(
      'groups',
      where: 'room_pub = ?',
      whereArgs: [pub],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> rooms() async {
    final db = await open();
    return db.query('groups', where: 'room_pub IS NOT NULL');
  }

  Future<List<Map<String, Object?>>> expiredRooms(int now) async {
    final db = await open();
    return db.query(
      'groups',
      where: 'room_pub IS NOT NULL AND expires_at <= ?',
      whereArgs: [now],
    );
  }

  Future<void> markRoomSeen(String groupId) async {
    final db = await open();
    await db.update(
      'groups',
      {'room_seen': 1},
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }

  // every file a group's messages point at, so expiry can shred them
  Future<List<String>> groupFilePaths(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['media_path', 'file_path'],
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    return [
      for (final r in rows)
        for (final k in const ['media_path', 'file_path'])
          if ((r[k] as String?)?.isNotEmpty == true) r[k] as String,
    ];
  }

  Future<void> deleteGroupMessages(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['msg_uid'],
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    for (final r in rows) {
      final uid = r['msg_uid'] as String?;
      if (uid != null) {
        await db.delete('reactions', where: 'msg_uid = ?', whereArgs: [uid]);
      }
    }
    await db.delete(
      'group_media_owed',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    await db.delete('messages', where: 'group_id = ?', whereArgs: [groupId]);
  }

  // peer_id on each row is the sender's kryfo id, ours on our own messages
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
      orderBy: 'Rowid DESC',
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

  // the chat a row lives in: (peer_id, group_id), or null when there is no
  // such row
  Future<(String, String?)?> chatOf(String msgUid) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: ['peer_id', 'group_id'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    if (r.isEmpty) return null;
    return (r.first['peer_id'] as String, r.first['group_id'] as String?);
  }

  Future<void> setPinned(String msgUid, bool pinned, {int? at}) async {
    final db = await open();
    await db.update(
      'messages',
      {
        'pinned': pinned ? 1 : 0,
        'pinned_at': pinned
            ? at ?? DateTime.now().millisecondsSinceEpoch
            : null,
      },
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  // every pin in one chat, newest pin first, whatever part of the thread
  // the screen has loaded. a 1:1 chat by the other person's id, a group by
  // its own.
  Future<List<Map<String, Object?>>> pinnedIn({
    String? peerId,
    String? groupId,
  }) async {
    final db = await open();
    return db.query(
      'messages',
      columns: [
        'msg_uid',
        'peer_id',
        'direction',
        'plaintext',
        'sent_at',
        'media_path',
        'file_name',
        'pinned_at',
        'sticker',
      ],
      where: groupId != null
          ? 'pinned = 1 AND msg_uid IS NOT NULL AND group_id = ?'
          : "pinned = 1 AND msg_uid IS NOT NULL AND peer_id = ? "
                "AND (group_id IS NULL OR group_id = '')",
      whereArgs: [groupId ?? peerId],
      orderBy: 'COALESCE(pinned_at, sent_at) DESC',
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

  // every column that names a file of a message: a photo, or a voice note,
  // a video or any other file
  static const _kFileCols = ['media_path', 'file_path'];
  // a person's own chat: what they wrote in groups is the groups'
  static const _kOneToOne = 'peer_id = ? AND group_id IS NULL';

  // the files go too, not just the rows. zeros first, then unlink, so a raw
  // read of the flash finds nothing either.
  Future<void> _scrubMedia(List<Map<String, Object?>> rows) async {
    for (final r in rows) {
      for (final k in const ['media_path', 'file_path']) {
        final mp = r[k] as String?;
        if (mp != null && mp.isNotEmpty) await shredFile(mp);
      }
    }
  }

  /// the files in this container's media folder that no message names,
  /// last written before [before]: what a delete left behind. a file is
  /// matched by its name in the folder, so rows written under another
  /// path to the same folder still hold theirs. folders are left alone
  Future<List<File>> unnamedMedia({required DateTime before}) async {
    final db = await open();
    final named = <String>{};
    for (final col in _kFileCols) {
      for (final r in await db.query(
        'messages',
        columns: [col],
        where: '$col IS NOT NULL',
      )) {
        final v = r[col];
        if (v is String && v.isNotEmpty) named.add(p.basename(v));
      }
    }
    final dir = await container.mediaDir();
    final out = <File>[];
    await for (final e in dir.list(followLinks: false)) {
      if (e is! File || named.contains(p.basename(e.path))) continue;
      if ((await e.lastModified()).isBefore(before)) out.add(e);
    }
    return out;
  }

  Future<void> deleteMessage(String msgUid) async {
    final db = await open();
    final media = await db.query(
      'messages',
      columns: [..._kFileCols, ..._kUnreadCols],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
    await _unreadGo(db, media);
    await db.delete('reactions', where: 'msg_uid = ?', whereArgs: [msgUid]);
    await db.delete(
      'group_media_owed',
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
    await db.delete('messages', where: 'msg_uid = ?', whereArgs: [msgUid]);
    await _scrubMedia(media);
  }

  // what a row needs for _unreadGo to place it
  static const _kUnreadCols = ['id', 'peer_id', 'group_id', 'direction'];

  // rows that came in and go before they were read take their unread mark
  // with them. the unread ones are the newest that many that came in
  Future<void> _unreadGo(Database db, List<Map<String, Object?>> rows) async {
    final gone = <(String, bool), Set<int>>{};
    for (final r in rows) {
      final id = r['id'];
      if (r['direction'] != 'in' || id is! int) continue;
      final g = r['group_id'] as String?;
      final peer = r['peer_id'] as String?;
      final chat = g != null ? (g, true) : (peer, false);
      if (chat.$1 == null) continue;
      (gone[(chat.$1!, chat.$2)] ??= {}).add(id);
    }
    for (final MapEntry(key: (chat, group), value: ids) in gone.entries) {
      final table = group ? 'groups' : 'contacts';
      final key = group ? 'group_id = ?' : 'halo_id = ?';
      final c = await db.query(
        table,
        columns: ['unread'],
        where: key,
        whereArgs: [chat],
        limit: 1,
      );
      final unread = c.isEmpty ? 0 : (c.first['unread'] as int? ?? 0);
      if (unread <= 0) continue;
      final newest = await db.query(
        'messages',
        columns: ['id'],
        where: group
            ? "group_id = ? AND direction = 'in'"
            : "$_kOneToOne AND direction = 'in'",
        whereArgs: [chat],
        orderBy: 'id DESC',
        limit: unread,
      );
      final n = newest.where((r) => ids.contains(r['id'])).length;
      if (n == 0) continue;
      await db.update(
        table,
        {'unread': unread - n},
        where: key,
        whereArgs: [chat],
      );
    }
  }

  // a timed message of ours that went but never had its clock started:
  // from before receipts lit it, or a stop between marking it sent and
  // lighting it. once per open is enough, nothing makes new ones after
  bool _strandedLit = false;
  Future<void> _lightStrandedOnce() async {
    if (_strandedLit) return;
    await lightStrandedBurns();
    _strandedLit = true;
  }

  Future<int> lightStrandedBurns() async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['id', 'burn_secs'],
      where:
          "direction = 'out' AND sent = 1 AND burn_secs IS NOT NULL "
          'AND burn_at IS NULL',
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final r in rows) {
      final secs = (r['burn_secs'] as num).toInt();
      await db.update(
        'messages',
        {'burn_at': now + secs * 1000},
        where: 'id = ? AND burn_at IS NULL',
        whereArgs: [r['id']],
      );
    }
    return rows.length;
  }

  Future<void> purgeExpiredBurns() async {
    await _lightStrandedOnce();
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'messages',
      columns: ['msg_uid', 'media_path', 'file_path', ..._kUnreadCols],
      where: 'burn_at IS NOT NULL AND burn_at < ?',
      whereArgs: [now],
    );
    await _unreadGo(db, rows);
    for (final r in rows) {
      final uid = r['msg_uid'] as String?;
      if (uid != null) {
        await db.delete('reactions', where: 'msg_uid = ?', whereArgs: [uid]);
        await db.delete(
          'group_media_owed',
          where: 'msg_uid = ?',
          whereArgs: [uid],
        );
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

  Future<void> setGroupMentioned(String groupId) async {
    final db = await open();
    await db.update(
      'groups',
      {'mentioned': 1},
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }

  Future<void> clearGroupUnread(String groupId) async {
    final db = await open();
    await db.update(
      'groups',
      {'unread': 0, 'mentioned': 0},
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
      columns: _kFileCols,
      where: _kOneToOne,
      whereArgs: [peerId],
    );
    await db.rawDelete(
      'DELETE FROM reactions WHERE msg_uid IN '
      '(SELECT msg_uid FROM messages WHERE $_kOneToOne AND msg_uid IS NOT NULL)',
      [peerId],
    );
    await db.delete('messages', where: _kOneToOne, whereArgs: [peerId]);
    await _dropFilesComingFrom(db, peerId);
    await _scrubMedia(media);
  }

  Future<void> clearGroupConversation(String groupId) async {
    final db = await open();
    final media = await db.query(
      'messages',
      columns: _kFileCols,
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    await db.rawDelete(
      'DELETE FROM reactions WHERE msg_uid IN '
      '(SELECT msg_uid FROM messages WHERE group_id = ? AND msg_uid IS NOT NULL)',
      [groupId],
    );
    await db.delete(
      'group_media_owed',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    await db.delete('messages', where: 'group_id = ?', whereArgs: [groupId]);
    await _scrubMedia(media);
  }

  // what a group left by an older version kept, and the paths of its files
  Future<List<String>> dropGroupLeftovers() async {
    final db = await open();
    final rows = await db.transaction(dropGroupLeftoversIn);
    return [
      for (final r in rows)
        for (final k in _kFileCols)
          if ((r[k] as String?)?.isNotEmpty == true) r[k] as String,
    ];
  }

  Future<void> holdCipher(String peerId, String cipher) async {
    final db = await open();
    // a stranger past the cap gets a small shelf, not a disk
    final n = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM held_onion WHERE peer_id = ?', [
        peerId,
      ]),
    );
    if ((n ?? 0) >= 20) return;
    await db.insert('held_onion', {
      'peer_id': peerId,
      'cipher': cipher,
      'at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<String>> takeHeld(String peerId) async {
    final db = await open();
    final rows = await db.query(
      'held_onion',
      columns: ['cipher'],
      where: 'peer_id = ?',
      whereArgs: [peerId],
      orderBy: 'id ASC',
    );
    await db.delete('held_onion', where: 'peer_id = ?', whereArgs: [peerId]);
    return [for (final r in rows) r['cipher'] as String];
  }

  Future<void> dropHeld(String peerId) async {
    final db = await open();
    await db.delete('held_onion', where: 'peer_id = ?', whereArgs: [peerId]);
  }

  Future<void> queuePin(String msgUid, String peerId, bool pinned) async {
    final db = await open();
    // one row a message: the latest word replaces the last
    await db.insert('pins_out', {
      'msg_uid': msgUid,
      'peer_id': peerId,
      'pinned': pinned ? 1 : 0,
      'at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> unsentPins() async {
    final db = await open();
    return db.query('pins_out', orderBy: 'at ASC', limit: 40);
  }

  // only the word that was sent: a newer one queued meanwhile stays
  Future<void> dropPin(String msgUid, bool pinned) async {
    final db = await open();
    await db.delete(
      'pins_out',
      where: 'msg_uid = ? AND pinned = ?',
      whereArgs: [msgUid, pinned ? 1 : 0],
    );
  }

  Future<void> queueFrame(
    String msgUid,
    String kind,
    String peerId,
    String body,
  ) async {
    final db = await open();
    await db.transaction((t) async {
      // a message taken back has nothing left to edit, pin or react to
      if (kind == kFrameUnsend) {
        for (final table in const ['edits_out', 'pins_out', 'frames_out']) {
          await t.delete(table, where: 'msg_uid = ?', whereArgs: [msgUid]);
        }
      }
      await t.insert('frames_out', {
        'msg_uid': msgUid,
        'kind': kind,
        'peer_id': peerId,
        'body': body,
        'at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<Map<String, Object?>>> unsentFrames() async {
    final db = await open();
    return db.query('frames_out', orderBy: 'at ASC', limit: 40);
  }

  // only the word that was sent: a newer one queued meanwhile stays
  Future<void> dropFrame(String msgUid, String kind, String body) async {
    final db = await open();
    await db.delete(
      'frames_out',
      where: 'msg_uid = ? AND kind = ? AND body = ?',
      whereArgs: [msgUid, kind, body],
    );
  }

  Future<void> queueEdit(String msgUid, String peerId, String newText) async {
    final db = await open();
    await db.insert('edits_out', {
      'msg_uid': msgUid,
      'peer_id': peerId,
      'new_text': newText,
      'at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> unsentEdits() async {
    final db = await open();
    return db.query('edits_out', orderBy: 'at ASC', limit: 40);
  }

  Future<void> dropEdit(String msgUid) async {
    final db = await open();
    await db.delete('edits_out', where: 'msg_uid = ?', whereArgs: [msgUid]);
  }

  /// the sticker on a row, as it goes on the wire
  Future<String?> stickerOf(String uid) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: ['sticker'],
      where: 'msg_uid = ? AND sticker IS NOT NULL',
      whereArgs: [uid],
      limit: 1,
    );
    return r.isEmpty ? null : StickerWire.parse(r.first['sticker'])?.value;
  }

  // ---- polls ----

  /// the poll on a row, the chat it is in, and whether it is ours
  Future<({PollSpec spec, String? groupId, bool mine})?> pollRow(
    String uid,
  ) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: ['poll', 'group_id', 'direction'],
      where: 'msg_uid = ? AND poll IS NOT NULL',
      whereArgs: [uid],
      limit: 1,
    );
    if (r.isEmpty) return null;
    final spec = PollSpec.parse(r.first['poll']);
    if (spec == null) return null;
    return (
      spec: spec,
      groupId: r.first['group_id'] as String?,
      mine: r.first['direction'] == 'out',
    );
  }

  Future<int?> pollVoteSeq(String pollUid, String voter) async {
    final db = await open();
    final r = await db.query(
      'poll_votes',
      columns: ['seq'],
      where: 'poll_uid = ? AND voter = ?',
      whereArgs: [pollUid, voter],
      limit: 1,
    );
    return r.isEmpty ? null : (r.first['seq'] as num).toInt();
  }

  /// keeps the vote when it is newer than the one held. false when it was
  /// a duplicate or an old vote arriving late.
  Future<bool> putPollVote(
    String pollUid,
    String voter,
    String? groupId,
    List<int> choices,
    int seq,
  ) async {
    final db = await open();
    return db.transaction((tx) async {
      final r = await tx.query(
        'poll_votes',
        columns: ['seq'],
        where: 'poll_uid = ? AND voter = ?',
        whereArgs: [pollUid, voter],
        limit: 1,
      );
      final held = r.isEmpty ? null : (r.first['seq'] as num).toInt();
      if (!voteIsNewer(held, seq)) return false;
      await tx.insert('poll_votes', {
        'poll_uid': pollUid,
        'voter': voter,
        'group_id': groupId,
        'choices': jsonEncode(choices),
        'seq': seq,
        'at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    });
  }

  /// every vote held for these polls, voter by voter
  Future<Map<String, Map<String, PollVote>>> pollVotesFor(
    List<String> uids,
  ) async {
    final out = <String, Map<String, PollVote>>{};
    if (uids.isEmpty) return out;
    final db = await open();
    for (var i = 0; i < uids.length; i += 400) {
      final part = uids.sublist(
        i,
        i + 400 > uids.length ? uids.length : i + 400,
      );
      final rows = await db.query(
        'poll_votes',
        where: 'poll_uid IN (${List.filled(part.length, '?').join(',')})',
        whereArgs: part,
      );
      for (final r in rows) {
        List<int> picks;
        try {
          picks = (jsonDecode(r['choices'] as String) as List)
              .whereType<int>()
              .toList();
        } catch (_) {
          continue;
        }
        out.putIfAbsent(r['poll_uid'] as String, () => {})[r['voter']
            as String] = PollVote(
          picks,
          (r['seq'] as num).toInt(),
        );
      }
    }
    return out;
  }

  /// the poll is closed: the row says so, and the votes are the final ones
  /// from the close. held above any seq a voter can send, so nothing late
  /// moves them.
  Future<void> closePollRow(
    String uid,
    PollSpec spec,
    Map<String, List<int>> finals,
    String? groupId,
  ) async {
    final db = await open();
    await db.transaction((tx) async {
      await tx.update(
        'messages',
        {'poll': spec.closedNow().toRow()},
        where: 'msg_uid = ?',
        whereArgs: [uid],
      );
      await tx.delete('poll_votes', where: 'poll_uid = ?', whereArgs: [uid]);
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final e in finals.entries) {
        await tx.insert('poll_votes', {
          'poll_uid': uid,
          'voter': e.key,
          'group_id': groupId,
          'choices': jsonEncode(e.value),
          'seq': kPollFinalSeq,
          'at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<bool> pollGone(String uid) async {
    final db = await open();
    final r = await db.query(
      'polls_gone',
      where: 'uid = ?',
      whereArgs: [uid],
      limit: 1,
    );
    return r.isNotEmpty;
  }

  /// votes still waiting for a poll that never came: after an hour the
  /// poll is not coming, it burned or was deleted. dropped, and the marks
  /// of polls that went with them.
  Future<void> purgeStrayVotes({
    Duration after = const Duration(hours: 1),
  }) async {
    final db = await open();
    final cut = DateTime.now().subtract(after).millisecondsSinceEpoch;
    await db.rawDelete(
      'DELETE FROM poll_votes WHERE at < ? AND poll_uid NOT IN '
      '(SELECT msg_uid FROM messages WHERE msg_uid IS NOT NULL '
      'AND poll IS NOT NULL)',
      [cut],
    );
    await db.delete('polls_gone', where: 'at < ?', whereArgs: [cut]);
  }

  // did this sender write this row. what edit and unsend frames check.
  Future<bool> isTheirs(String msgUid, String sender) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: ['id'],
      where: "msg_uid = ? AND direction = 'in' AND peer_id = ?",
      whereArgs: [msgUid, sender],
      limit: 1,
    );
    return r.isNotEmpty;
  }

  Future<void> editMessage(String msgUid, String newText) async {
    final db = await open();
    await db.update(
      'messages',
      {'plaintext': unmarked(newText), 'edited': 1},
      // a sticker has no words to edit: its text stays its emoji
      where: 'msg_uid = ? AND sticker IS NULL',
      whereArgs: [msgUid],
    );
    // the old words must not find it any more
    final rows = await db.query(
      'messages',
      columns: ['id', 'plaintext', 'poll', 'file_name', 'preview', 'sticker'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
    for (final r in rows) {
      await indexSearchRow(db, r['id'] as int, r);
    }
  }

  // ---- search ----

  /// one batch of the first fill, oldest first. how far it got, of how
  /// many; done when [at] reaches [to].
  Future<({int at, int to})> fillSearchIndex({int batch = 300}) async {
    final db = await open();
    int meta(List<Map<String, Object?>> r) =>
        r.isEmpty ? 0 : (r.first['v'] as num).toInt();
    final to = meta(
      await db.query('search_meta', where: "k = 'fill_to'", limit: 1),
    );
    var at = meta(
      await db.query('search_meta', where: "k = 'fill_at'", limit: 1),
    );
    if (at >= to) return (at: at, to: to);
    final rows = await db.query(
      'messages',
      columns: ['id', 'plaintext', 'poll', 'file_name', 'preview', 'sticker'],
      where: 'id > ? AND id <= ?',
      whereArgs: [at, to],
      orderBy: 'id ASC',
      limit: batch,
    );
    at = rows.isEmpty ? to : rows.last['id'] as int;
    final b = db.batch();
    for (final r in rows) {
      indexSearchRowIn(b, r['id'] as int, r);
    }
    b.update('search_meta', {'v': at}, where: "k = 'fill_at'");
    await b.commit(noResult: true);
    return (at: at, to: to);
  }

  /// messages that match [match] (a full-text match, or null for every
  /// message) and [kind], newest first. never a blocked contact's, never a
  /// stranger's who has not been accepted.
  Future<List<Map<String, Object?>>> searchMessages(
    String? match,
    SearchKind kind, {
    int limit = 300,
  }) async => runSearchQuery(await open(), match, kind, limit: limit);

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

  Future<void> setMsgBurnAt(String msgUid, int burnAt) async {
    final db = await open();
    await db.update(
      'messages',
      {'burn_at': burnAt},
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  // add or replace a reaction. reactor is '' for self, peer's kryfo id
  // for theirs. one reaction per (msgUid, reactor): re-reacting replaces.
  Future<void> addReaction(
    String msgUid,
    String reactor,
    String emoji, {
    int? at,
  }) async {
    final db = await open();
    await db.insert('reactions', {
      'msg_uid': msgUid,
      'reactor': reactor,
      'emoji': emoji,
      'reacted_at': at ?? DateTime.now().millisecondsSinceEpoch,
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
  // sweep started in boot(). [gone] hears each one that came in
  Future<int> purgeExpired({void Function(String msgUid)? gone}) async {
    await _lightStrandedOnce();
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    final media = await db.query(
      'messages',
      columns: [..._kFileCols, ..._kUnreadCols, 'msg_uid'],
      where: 'burn_at IS NOT NULL AND burn_at < ?',
      whereArgs: [now],
    );
    await _unreadGo(db, media);
    if (gone != null) {
      for (final r in media) {
        final uid = r['msg_uid'] as String?;
        if (uid != null && r['direction'] == 'in') gone(uid);
      }
    }
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
  // chat, and a cold restart. keyed on `sent`, not `delivered`: retrying on
  // a missing ack loops forever when the ack never comes.
  Future<List<Map<String, Object?>>> unsentOutbox() async {
    final db = await open();
    return db.query(
      'messages',
      // group text stays out: a group send marks sent on the first ack, so
      // a row still at 0 is one nobody could take, and the screen owns its
      // retry. group media comes along, it has the same chunked path as 1:1.
      where:
          "direction = 'out' AND sent = 0 AND msg_uid IS NOT NULL "
          "AND (group_id IS NULL OR group_id = '' "
          "OR media_path IS NOT NULL OR file_path IS NOT NULL)",
      orderBy: 'sent_at ASC',
      limit: 40,
    );
  }

  // --- chunked media, buffered on disk so a restart doesn't lose a transfer ---

  // store one slice from [from], return how many of this media's slices we
  // now hold.
  Future<int> putMediaChunk(
    String mediaId,
    int idx,
    String slice,
    int total,
    int? burn, {
    required String from,
  }) async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    // a slice sent again replaces the one held, and weighs only once
    final held = _unfinished;
    final was = held == null
        ? const <Map<String, Object?>>[]
        : await db.query(
            'media_chunks',
            columns: ['length(slice) AS n'],
            where: 'media_id = ? AND idx = ?',
            whereArgs: [mediaId, idx],
            limit: 1,
          );
    await db.rawInsert(
      'INSERT OR REPLACE INTO media_chunks '
      '(media_id, idx, slice, total, burn, at, sender) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      [mediaId, idx, slice, total, burn, now, from],
    );
    if (held != null && identical(held, _unfinished)) {
      final old = was.isEmpty
          ? 0
          : sliceWeight((was.first['n'] as num? ?? 0).toInt());
      final f = held[mediaId];
      held[mediaId] = (
        bytes: (f?.bytes ?? 0) + sliceWeight(slice.length) - old,
        at: now,
      );
    }
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

  // one slice, so a file is rebuilt piece by piece instead of all its
  // slices sitting in one list
  Future<String?> mediaChunkSlice(String mediaId, int idx) async {
    final db = await open();
    final r = await db.query(
      'media_chunks',
      columns: ['slice'],
      where: 'media_id = ? AND idx = ?',
      whereArgs: [mediaId, idx],
      limit: 1,
    );
    return r.isEmpty ? null : r.first['slice'] as String?;
  }

  // a file's slices, or with [from] only the ones that sender sent
  Future<int> dropMediaChunks(String mediaId, {String? from}) async {
    final db = await open();
    final n = await db.delete(
      'media_chunks',
      where: from == null ? 'media_id = ?' : 'media_id = ? AND sender = ?',
      whereArgs: [mediaId, ?from],
    );
    if (n > 0 && _unfinished != null) await _reweigh(mediaId);
    return n;
  }

  // the unfinished files here, each with what its slices weigh and when its
  // last slice came. read whole the first time it is needed, then kept up
  // as slices come and go
  Map<String, ({int bytes, int at})>? _unfinished;

  Future<Map<String, ({int bytes, int at})>> _unfinishedFiles() async {
    final have = _unfinished;
    if (have != null) return have;
    final db = await open();
    final rows = await db.query(
      'media_chunks',
      columns: ['media_id', 'length(slice) AS n', 'at'],
    );
    final out = <String, ({int bytes, int at})>{};
    for (final r in rows) {
      final id = r['media_id'] as String;
      final at = (r['at'] as num).toInt();
      final f = out[id];
      out[id] = (
        bytes: (f?.bytes ?? 0) + sliceWeight((r['n'] as num? ?? 0).toInt()),
        at: f == null || at > f.at ? at : f.at,
      );
    }
    return _unfinished = out;
  }

  // one file's entry read again from what is left of it
  Future<void> _reweigh(String mediaId) async {
    final db = await open();
    final rows = await db.query(
      'media_chunks',
      columns: ['length(slice) AS n', 'at'],
      where: 'media_id = ?',
      whereArgs: [mediaId],
    );
    final held = _unfinished;
    if (held == null) return;
    if (rows.isEmpty) {
      held.remove(mediaId);
      return;
    }
    var bytes = 0;
    var at = 0;
    for (final r in rows) {
      bytes += sliceWeight((r['n'] as num? ?? 0).toInt());
      final t = (r['at'] as num).toInt();
      if (t > at) at = t;
    }
    held[mediaId] = (bytes: bytes, at: at);
  }

  // unfinished files past the cap go, whole, the one whose last slice came
  // longest ago first. a file in [keep] is being put together and stays;
  // finished messages are never touched. the files that went
  Future<Set<String>> trimUnfinishedMedia({
    Set<String> keep = const {},
    int bytes = kUnfinishedBytes,
    int files = kUnfinishedFiles,
  }) async {
    final held = await _unfinishedFiles();
    final drop = unfinishedPastCap(
      held,
      bytes: bytes,
      files: files,
      keep: keep,
    );
    if (drop.isEmpty) return const <String>{};
    final db = await open();
    final gone = <String>{};
    for (final id in drop) {
      // one that began to be put together meanwhile stays
      if (keep.contains(id)) continue;
      await db.delete('media_chunks', where: 'media_id = ?', whereArgs: [id]);
      await dropMediaWant(id);
      _unfinished?.remove(id);
      gone.add(id);
    }
    dlog('unfinished files past the cap: ${gone.length} dropped');
    return gone;
  }

  // who sent the slices held for a file, null for none or for slices kept
  // before senders were noted
  Future<String?> mediaChunkSender(String mediaId) async {
    final db = await open();
    final r = await db.query(
      'media_chunks',
      columns: ['sender'],
      where: 'media_id = ? AND sender IS NOT NULL',
      whereArgs: [mediaId],
      limit: 1,
    );
    return r.isEmpty ? null : r.first['sender'] as String?;
  }

  // how many unfinished files [from] is sending in their own chat, [except]
  // not counted. only those have a want row: a file they post in a group
  // counts for the group, not against their chat
  Future<int> filesInFlightFrom(String from, {String? except}) async {
    final db = await open();
    final r = await db.query(
      'media_chunks',
      distinct: true,
      columns: ['media_id'],
      where: 'sender = ?',
      whereArgs: [from],
    );
    final direct = {
      for (final w in await db.query(
        'media_wants',
        columns: ['media_id'],
        where: 'peer_id = ?',
        whereArgs: [from],
      ))
        w['media_id'],
    };
    return r
        .where((x) => x['media_id'] != except && direct.contains(x['media_id']))
        .length;
  }

  // a slice of an unfinished file just came in. can_resend only ever goes
  // up: one slice from a sender that can answer is enough to know it can.
  Future<void> noteMediaWant(
    String mediaId,
    String peerId,
    int total,
    bool canResend,
  ) async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.rawInsert(
      'INSERT INTO media_wants (media_id, peer_id, total, can_resend, last_at) '
      'VALUES (?, ?, ?, ?, ?) '
      'ON CONFLICT(media_id) DO UPDATE SET last_at = excluded.last_at, '
      'can_resend = MAX(can_resend, excluded.can_resend)',
      [mediaId, peerId, total, canResend ? 1 : 0, now],
    );
  }

  Future<List<Map<String, Object?>>> mediaWants() async {
    final db = await open();
    return db.query('media_wants', where: 'can_resend = 1');
  }

  Future<Set<int>> heldSlices(String mediaId) async {
    final db = await open();
    final r = await db.query(
      'media_chunks',
      columns: ['idx'],
      where: 'media_id = ?',
      whereArgs: [mediaId],
    );
    return {for (final row in r) (row['idx'] as num).toInt()};
  }

  // [at] is the time the ask was decided on, stamped before it goes. read
  // and written in one go, so a slice landing meanwhile is not missed
  Future<void> markMediaAsked(String mediaId, int at) async {
    final db = await open();
    await db.transaction((t) async {
      final r = await t.query(
        'media_wants',
        columns: ['last_at', 'asked_at', 'asks'],
        where: 'media_id = ?',
        whereArgs: [mediaId],
        limit: 1,
      );
      if (r.isEmpty) return;
      final w = r.first;
      await t.update(
        'media_wants',
        {
          'asked_at': at,
          'asks': asksAfterAsk(
            lastSliceAt: (w['last_at'] as num).toInt(),
            askedAt: (w['asked_at'] as num).toInt(),
            asks: (w['asks'] as num).toInt(),
          ),
        },
        where: 'media_id = ?',
        whereArgs: [mediaId],
      );
    });
  }

  // a chat put away takes the files still coming in it: their slices, and
  // the asks for the rest that would tell its person to send them again
  Future<void> _dropFilesComingFrom(DatabaseExecutor t, String peerId) async {
    await t.rawDelete(
      'DELETE FROM media_chunks WHERE media_id IN '
      '(SELECT media_id FROM media_wants WHERE peer_id = ?)',
      [peerId],
    );
    await t.delete('media_wants', where: 'peer_id = ?', whereArgs: [peerId]);
    // weighed again from what is left
    _unfinished = null;
    // nothing more comes for them, so the banner would stay paused for a day
    incomingMediaDone(container.chatKey(peerId));
  }

  Future<void> dropMediaWant(String mediaId) async {
    final db = await open();
    await db.delete('media_wants', where: 'media_id = ?', whereArgs: [mediaId]);
  }

  // ---- group messages and files some members still lack ----

  /// a send of [msgUid] to [tried] ended with [short] still lacking slices.
  /// the rest of [tried] have it all and are owed nothing. a short member
  /// keeps its row with what it holds; [first] sends add the ones new to
  /// it, waiting from [now]. a row gone meanwhile leaves nothing owed
  Future<void> settleGroupOwed(
    String msgUid,
    String groupId, {
    required int total,
    required Iterable<String> tried,
    required Map<String, Set<int>> short,
    required int sentTo,
    required bool first,
    required int now,
  }) async {
    final db = await open();
    await db.transaction((t) async {
      final row = await t.query(
        'messages',
        columns: ['msg_uid'],
        where: 'msg_uid = ?',
        whereArgs: [msgUid],
        limit: 1,
      );
      if (row.isEmpty) {
        await t.delete(
          'group_media_owed',
          where: 'msg_uid = ?',
          whereArgs: [msgUid],
        );
        return;
      }
      for (final m in tried) {
        if (short.containsKey(m)) continue;
        await t.delete(
          'group_media_owed',
          where: 'msg_uid = ? AND member = ?',
          whereArgs: [msgUid, m],
        );
      }
      for (final MapEntry(key: m, value: have) in short.entries) {
        final n = await t.update(
          'group_media_owed',
          {'have': packSlices(have), 'total': total},
          where: 'msg_uid = ? AND member = ?',
          whereArgs: [msgUid, m],
        );
        if (n > 0 || !first) continue;
        await t.insert('group_media_owed', {
          'msg_uid': msgUid,
          'group_id': groupId,
          'member': m,
          'total': total,
          'have': packSlices(have),
          'sent_to': sentTo,
          'since': now,
          'tries': 0,
          'next_at': now + groupOwedGap(0),
        });
      }
    });
  }

  @override
  Future<List<GroupOwed>> dueGroupOwed(int now) async {
    final db = await open();
    // a member past its tries is not tried again, and keeps its row
    final rows = await db.query(
      'group_media_owed',
      where: 'next_at < ? AND tries < ?',
      whereArgs: [now + 1, kGroupOwedTries],
      orderBy: 'next_at ASC',
    );
    return [for (final r in rows) GroupOwed.fromRow(r)];
  }

  @override
  Future<void> triedGroupOwed(
    String msgUid,
    Iterable<String> members,
    int now,
  ) async {
    final db = await open();
    await db.transaction((t) async {
      for (final m in members) {
        final r = await t.query(
          'group_media_owed',
          columns: ['tries'],
          where: 'msg_uid = ? AND member = ?',
          whereArgs: [msgUid, m],
          limit: 1,
        );
        if (r.isEmpty) continue;
        final tries = (r.first['tries'] as int? ?? 0) + 1;
        await t.update(
          'group_media_owed',
          {'tries': tries, 'next_at': now + groupOwedGap(tries)},
          where: 'msg_uid = ? AND member = ?',
          whereArgs: [msgUid, m],
        );
      }
    });
  }

  @override
  Future<void> dropGroupOwed(String msgUid) async {
    final db = await open();
    await db.delete(
      'group_media_owed',
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  /// the members of [groupId] no longer in [members] are owed nothing
  Future<void> keepGroupOwedTo(String groupId, List<String> members) async {
    final db = await open();
    await db.transaction((t) async {
      final rows = await t.query(
        'group_media_owed',
        columns: ['member'],
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
      for (final m in {for (final r in rows) r['member'] as String}) {
        if (members.contains(m)) continue;
        await _owedGone(t, 'group_id = ? AND member = ?', [groupId, m]);
      }
    });
  }

  /// [member]'s session is there now: what they are owed is due at once,
  /// with a try more for one past its tries
  Future<int> groupOwedDueNow(String member) async {
    final db = await open();
    return db.transaction((t) async {
      final rows = await t.query(
        'group_media_owed',
        columns: ['msg_uid', 'tries'],
        where: 'member = ?',
        whereArgs: [member],
      );
      for (final r in rows) {
        final tries = r['tries'] as int? ?? 0;
        await t.update(
          'group_media_owed',
          {'next_at': 0, 'tries': min(tries, kGroupOwedTries - 1)},
          where: 'msg_uid = ? AND member = ?',
          whereArgs: [r['msg_uid'], member],
        );
      }
      return rows.length;
    });
  }

  /// a group's messages some members still lack, by uid: how many of the
  /// members each went to have it
  Future<Map<String, ({int have, int of})>> groupFileReach(
    String groupId,
  ) async {
    final db = await open();
    final rows = await db.query(
      'group_media_owed',
      columns: ['msg_uid', 'sent_to'],
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    final owed = <String, int>{};
    final of = <String, int>{};
    for (final r in rows) {
      final uid = r['msg_uid'] as String;
      owed[uid] = (owed[uid] ?? 0) + 1;
      of[uid] = max(of[uid] ?? 0, r['sent_to'] as int? ?? 0);
    }
    return {
      for (final MapEntry(key: uid, value: n) in owed.entries)
        uid: (have: max(0, of[uid]! - n), of: max(of[uid]!, n)),
    };
  }

  // members who left or were taken out: their rows go, and each file they
  // were owed counts one fewer it went to, so the others' line stays true
  static Future<void> _owedGone(
    DatabaseExecutor t,
    String where,
    List<Object?> args,
  ) async {
    final rows = await t.query(
      'group_media_owed',
      columns: ['msg_uid', 'member', 'sent_to'],
      where: where,
      whereArgs: args,
    );
    for (final r in rows) {
      final uid = r['msg_uid'] as String;
      final to = r['sent_to'] as int? ?? 1;
      await t.delete(
        'group_media_owed',
        where: 'msg_uid = ? AND member = ?',
        whereArgs: [uid, r['member']],
      );
      await t.update(
        'group_media_owed',
        {'sent_to': to > 1 ? to - 1 : 1},
        where: 'msg_uid = ?',
        whereArgs: [uid],
      );
    }
  }

  // ---- group controls on their way to each member ----

  /// [ctl] for each of [members], after what each is still to get of
  /// [groupId]. due at once
  Future<void> queueGroupCtl(
    String groupId,
    Iterable<String> members,
    GroupControl ctl, {
    required int now,
  }) async {
    final body = jsonEncode(ctl.toWire());
    final db = await open();
    await db.transaction((t) async {
      for (final m in members) {
        await t.insert('group_ctl_out', {
          'group_id': groupId,
          'member': m,
          'ctl': body,
          'since': now,
          'tries': 0,
          'next_at': now,
        });
      }
    });
  }

  /// every control still to go, oldest first
  Future<List<Map<String, Object?>>> groupCtlOut() async {
    final db = await open();
    return db.query('group_ctl_out', orderBy: 'id ASC');
  }

  /// what [member] is still to get of [groupId], oldest first
  Future<List<Map<String, Object?>>> groupCtlFor(
    String groupId,
    String member,
  ) async {
    final db = await open();
    return db.query(
      'group_ctl_out',
      where: 'group_id = ? AND member = ?',
      whereArgs: [groupId, member],
      orderBy: 'id ASC',
    );
  }

  /// a try of [id] is starting: its count goes up and the next wait is set
  Future<void> triedGroupCtl(int id, int now) async {
    final db = await open();
    await db.transaction((t) async {
      final r = await t.query(
        'group_ctl_out',
        columns: ['tries'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (r.isEmpty) return;
      final tries = (r.first['tries'] as int? ?? 0) + 1;
      await t.update(
        'group_ctl_out',
        {'tries': tries, 'next_at': now + groupOwedGap(tries)},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> dropGroupCtl(int id) async {
    final db = await open();
    await db.delete('group_ctl_out', where: 'id = ?', whereArgs: [id]);
  }

  /// the members still to get a control of [groupId]
  Future<Set<String>> groupCtlWaiting(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'group_ctl_out',
      columns: ['member'],
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    return {for (final r in rows) r['member'] as String};
  }

  /// [member]'s session is there now: what it is still to get is due at
  /// once, with a try more for one past its tries
  Future<int> groupCtlDueNow(String member) async {
    final db = await open();
    return db.transaction((t) async {
      final rows = await t.query(
        'group_ctl_out',
        columns: ['id', 'tries'],
        where: 'member = ?',
        whereArgs: [member],
      );
      for (final r in rows) {
        final tries = r['tries'] as int? ?? 0;
        await t.update(
          'group_ctl_out',
          {'next_at': 0, 'tries': min(tries, kGroupOwedTries - 1)},
          where: 'id = ?',
          whereArgs: [r['id']],
        );
      }
      return rows.length;
    });
  }

  // ---- the newest roster each group took ----

  /// the stamp for a roster this phone makes of [groupId]: above the last
  /// one, and the clock when that is higher
  Future<int> nextRosterStamp(String groupId, int now) async {
    final db = await open();
    return db.transaction((t) async {
      final held = await _rosterRow(t, groupId);
      final stamp = max(now, ((held?['stamp'] as int?) ?? 0) + 1);
      await _putRoster(t, groupId, stamp: stamp, had: held != null);
      return stamp;
    });
  }

  /// keeps [stamp] when it is newer than the last roster [groupId] took.
  /// false for an older one, or the same one again
  Future<bool> takeRosterStamp(String groupId, int stamp) async {
    final db = await open();
    return db.transaction((t) async {
      final held = await _rosterRow(t, groupId);
      if (stamp <= ((held?['stamp'] as int?) ?? 0)) return false;
      await _putRoster(t, groupId, stamp: stamp, had: held != null);
      return true;
    });
  }

  /// the room keys that left [groupId] or were taken out
  Future<Set<String>> rosterGone(String groupId) async {
    final db = await open();
    final held = await _rosterRow(db, groupId);
    return {
      for (final k in ((held?['gone'] as String?) ?? '').split(','))
        if (k.isNotEmpty) k,
    };
  }

  Future<void> noteRosterGone(String groupId, Iterable<String> keys) async {
    final db = await open();
    await db.transaction((t) async {
      final held = await _rosterRow(t, groupId);
      final gone = {
        for (final k in ((held?['gone'] as String?) ?? '').split(','))
          if (k.isNotEmpty) k,
        for (final k in keys)
          if (k.isNotEmpty && !k.contains(',')) k,
      };
      await _putRoster(t, groupId, gone: gone.join(','), had: held != null);
    });
  }

  static Future<Map<String, Object?>?> _rosterRow(
    DatabaseExecutor t,
    String groupId,
  ) async {
    final r = await t.query(
      'group_roster',
      where: 'group_id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    return r.isEmpty ? null : r.first;
  }

  static Future<void> _putRoster(
    DatabaseExecutor t,
    String groupId, {
    int? stamp,
    String? gone,
    required bool had,
  }) async {
    final cols = {'stamp': ?stamp, 'gone': ?gone};
    if (had) {
      await t.update(
        'group_roster',
        cols,
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
    } else {
      await t.insert('group_roster', {'group_id': groupId, ...cols});
    }
  }

  // what a request for slices is checked against and answered from
  Future<Map<String, Object?>?> sentMediaRow(String msgUid) async {
    final db = await open();
    final r = await db.query(
      'messages',
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    return r.isEmpty ? null : r.first;
  }

  // a transfer nobody ever finished shouldn't sit in the db forever.
  // a week for a file from someone here, a day for one from a stranger:
  // someone not accepted and in no group
  Future<void> sweepMediaChunks({DateTime? now}) async {
    final db = await open();
    final at = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final cutoff = at - const Duration(days: 7).inMilliseconds;
    final strangers = at - const Duration(days: 1).inMilliseconds;
    var n = await db.delete(
      'media_chunks',
      where: 'at < ?',
      whereArgs: [cutoff],
    );
    final old = await db.query(
      'media_chunks',
      distinct: true,
      columns: ['media_id', 'sender'],
      where: 'at < ? AND sender IS NOT NULL',
      whereArgs: [strangers],
    );
    final known = <String, bool>{};
    for (final r in old) {
      final mid = r['media_id'] as String;
      final from = r['sender'] as String;
      if (known[from] ??= await _heldHere(from)) continue;
      n += await dropMediaChunks(mid, from: from);
      await dropMediaWant(mid);
    }
    if (n > 0) dlog('swept $n stale media chunks');
    await db.delete('media_wants', where: 'last_at < ?', whereArgs: [cutoff]);
    // counted again from what is left, and held to the cap
    _unfinished = null;
    await trimUnfinishedMedia();
  }

  // an accepted contact, or a member of a group here
  Future<bool> _heldHere(String id) async {
    final db = await open();
    final c = await db.query(
      'contacts',
      columns: ['halo_id'],
      where: 'halo_id = ? AND accepted = ?',
      whereArgs: [id, 1],
      limit: 1,
    );
    if (c.isNotEmpty) return true;
    final g = await db.query(
      'group_members',
      columns: ['group_id'],
      where: 'halo_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return g.isNotEmpty;
  }

  Future<bool> isDelivered(String msgUid) async =>
      (await sendState(msgUid)).delivered;

  // what the database knows about one of our messages: handed over
  // somewhere (sent), and acknowledged by the peer (delivered)
  Future<({bool sent, bool delivered})> sendState(String msgUid) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: ['sent', 'delivered'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    if (r.isEmpty) return (sent: false, delivered: false);
    return (
      sent: (r.first['sent'] as int? ?? 0) == 1,
      delivered: (r.first['delivered'] as int? ?? 0) == 1,
    );
  }

  // a receipt from [from]: it ticks only a message of ours that went to
  // them, or one in a group they are a member of
  Future<void> markDelivered(String msgUid, {required String from}) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['peer_id', 'group_id', 'burn_secs', 'burn_at'],
      where: 'msg_uid = ? AND direction = ?',
      whereArgs: [msgUid, 'out'],
    );
    for (final r in rows) {
      final g = r['group_id'] as String?;
      final ok = g == null || g.isEmpty
          ? r['peer_id'] == from
          : (await getGroupMembers(g)).contains(from);
      if (!ok) continue;
      // a timed message whose own send never came back ok is lit here,
      // or once it counts as sent nothing else ever starts its clock
      final secs = (r['burn_secs'] as num?)?.toInt();
      await db.update(
        'messages',
        {
          'sent': 1,
          'delivered': 1,
          if (secs != null && r['burn_at'] == null)
            'burn_at': DateTime.now().millisecondsSinceEpoch + secs * 1000,
        },
        where: g == null || g.isEmpty
            ? 'msg_uid = ? AND direction = ? AND peer_id = ?'
            : 'msg_uid = ? AND direction = ? AND group_id = ?',
        whereArgs: [msgUid, 'out', g == null || g.isEmpty ? from : g],
      );
    }
  }

  // the clock of a timed message of ours that went, started now if nothing
  // started it yet. null for a message with no timer
  Future<int?> lightBurn(String msgUid) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: ['burn_secs', 'burn_at'],
      where: 'msg_uid = ? AND direction = ?',
      whereArgs: [msgUid, 'out'],
      limit: 1,
    );
    if (r.isEmpty) return null;
    final lit = (r.first['burn_at'] as num?)?.toInt();
    final secs = (r.first['burn_secs'] as num?)?.toInt();
    if (lit != null || secs == null) return lit;
    final at = DateTime.now().millisecondsSinceEpoch + secs * 1000;
    await db.update(
      'messages',
      {'burn_at': at},
      where: 'msg_uid = ? AND direction = ? AND burn_at IS NULL',
      whereArgs: [msgUid, 'out'],
    );
    return at;
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
      // group_id IS NULL keeps group messages out of the 1:1 thread: a group
      // row carries peer_id = sender too
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
      orderBy: 'Rowid DESC',
      limit: limit,
    );
    return rows.reversed.toList();
  }

  // only messages after a rowid, oldest first, for the chat's
  // append-on-receive fast path
  Future<List<Map<String, Object?>>> messagesAfter(
    String peerId,
    int afterRowid,
  ) async {
    final db = await open();
    // rowid, not sent_at: clock skew can give a received note a sent_at older
    // than our local newest. rowid always climbs.
    return db.query(
      'messages',
      columns: ['*', 'rowid'],
      where: "peer_id = ? AND group_id IS NULL AND rowid > ?",
      whereArgs: [peerId, afterRowid],
      orderBy: 'Rowid ASC',
    );
  }

  // the newest 1:1 row per peer in one query, for the home list, which
  // refreshes after every send
  Future<Map<String, Map<String, Object?>>> lastMessages() async {
    final db = await open();
    final rows = await db.rawQuery('''
      SELECT m.peer_id, m.direction, m.plaintext, m.media_path, m.file_name,
             m.sent_at, m.sticker
      FROM messages m
      JOIN (
        SELECT peer_id, MAX(rowid) AS r FROM messages
        WHERE group_id IS NULL GROUP BY peer_id
      ) x ON x.r = m.rowid
    ''');
    return {for (final r in rows) r['peer_id'] as String: r};
  }

  // the media a chat holds, newest first, and nothing else about the
  // messages: a contact page has no use for the text.
  Future<List<Map<String, Object?>>> mediaFor(String peerId) async {
    final db = await open();
    return db.query(
      'messages',
      columns: ['media_path', 'secure'],
      where:
          "peer_id = ? AND group_id IS NULL AND media_path IS NOT NULL "
          "AND media_path != ''",
      whereArgs: [peerId],
      orderBy: 'Rowid DESC',
    );
  }

  // when the first message with a peer was, either way. null before any.
  Future<int?> firstMessageAt(String peerId) async {
    final db = await open();
    final r = await db.rawQuery(
      'SELECT MIN(sent_at) t FROM messages WHERE peer_id = ? AND group_id IS NULL',
      [peerId],
    );
    return r.isEmpty ? null : r.first['t'] as int?;
  }

  Future<Map<String, Object?>?> lastMessageFor(String peerId) async {
    final db = await open();
    // rowid, not sent_at: clock skew can give a received note a sent_at older
    // than our local newest. group_id IS NULL: a group message is stored
    // under the sender's peer_id too.
    final rows = await db.query(
      'messages',
      where: 'peer_id = ? AND group_id IS NULL',
      whereArgs: [peerId],
      orderBy: 'Rowid DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }
}

// search: every message's words in a full-text index, in this encrypted
// database and nowhere else. a trigger takes a message's words with it
// however it goes (burn, unsend, cleared chat), not each delete. search_meta
// says how far the first fill of an older history got.
Future<void> searchTables(Database db, {bool fresh = false}) async {
  await db.execute(
    'CREATE VIRTUAL TABLE IF NOT EXISTS msg_fts USING fts5('
    "body, tokenize = 'unicode61 remove_diacritics 2')",
  );
  await db.execute(
    'CREATE TRIGGER IF NOT EXISTS msg_fts_follow AFTER DELETE ON messages '
    'BEGIN DELETE FROM msg_fts WHERE rowid = old.id; END',
  );
  await db.execute('''
    CREATE TABLE IF NOT EXISTS search_meta (
      k TEXT PRIMARY KEY,
      v INTEGER NOT NULL
    )
  ''');
  // what the first fill has to cover: every message there is now. a fresh
  // install has none; later ones are indexed as they are saved
  final top = fresh
      ? 0
      : Sqflite.firstIntValue(
              await db.rawQuery('SELECT MAX(id) FROM messages'),
            ) ??
            0;
  await db.insert('search_meta', {
    'k': 'fill_to',
    'v': top,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
  await db.insert('search_meta', {
    'k': 'fill_at',
    'v': 0,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
}

/// the search query itself, on any database with the schema: the app's,
/// or the debug benchmark's scratch one
Future<List<Map<String, Object?>>> runSearchQuery(
  DatabaseExecutor db,
  String? match,
  SearchKind kind, {
  int limit = 300,
}) async {
  final where = <String>[
    'm.peer_id NOT IN (SELECT halo_id FROM contacts WHERE blocked = 1)',
    // a group's rows only while the group is here: one left before its
    // rows went with it opens nothing
    "(m.group_id IN (SELECT group_id FROM groups) OR (m.group_id IS NULL "
        "AND (m.direction = 'out' OR m.peer_id IN "
        '(SELECT halo_id FROM contacts WHERE accepted = 1))))',
  ];
  final args = <Object?>[];
  final kw = kindWhere(kind);
  if (kw.isNotEmpty) where.add(kw);
  // newest first by row id, the order messages arrived in: the index walks
  // its ids backwards and stops at the limit. sorting by time would sort
  // every match of a common word first
  final String from;
  final String order;
  if (match != null) {
    from = 'msg_fts JOIN messages m ON m.id = msg_fts.rowid';
    where.insert(0, 'msg_fts MATCH ?');
    args.add(match);
    order = 'msg_fts.rowid DESC';
  } else {
    if (kind == SearchKind.all) return const [];
    from = 'messages m';
    order = 'm.id DESC';
  }
  args.add(limit);
  return db.rawQuery(
    'SELECT m.id, m.msg_uid, m.peer_id, m.group_id, m.direction, '
    'm.plaintext, m.sent_at, m.media_path, m.file_path, m.file_name, '
    'm.poll, m.preview FROM $from WHERE ${where.join(' AND ')} '
    'ORDER BY $order LIMIT ?',
    args,
  );
}

// the rows of groups no longer here, which a leave in an older version
// kept: nothing opens them, yet their files sat in the outbox. gives back
// the file columns of what went, for shredding
Future<List<Map<String, Object?>>> dropGroupLeftoversIn(
  DatabaseExecutor db,
) async {
  const gone =
      "group_id IS NOT NULL AND group_id != '' "
      'AND group_id NOT IN (SELECT group_id FROM groups)';
  final files = await db.rawQuery(
    'SELECT media_path, file_path FROM messages WHERE $gone',
  );
  await db.rawDelete(
    'DELETE FROM reactions WHERE msg_uid IN '
    '(SELECT msg_uid FROM messages WHERE $gone AND msg_uid IS NOT NULL)',
  );
  await db.rawDelete('DELETE FROM messages WHERE $gone');
  return files;
}

/// the same, queued on a batch: one trip for many rows
void indexSearchRowIn(Batch b, int id, Map<String, Object?> r) {
  b.delete('msg_fts', where: 'rowid = ?', whereArgs: [id]);
  final body = searchBody(r);
  if (body.trim().isNotEmpty) b.insert('msg_fts', {'rowid': id, 'body': body});
}

Future<void> indexSearchRow(
  DatabaseExecutor db,
  int id,
  Map<String, Object?> r,
) async {
  await db.delete('msg_fts', where: 'rowid = ?', whereArgs: [id]);
  final body = searchBody(r);
  if (body.trim().isEmpty) return;
  await db.insert('msg_fts', {'rowid': id, 'body': body});
}

// a poll's votes: one row per voter, the highest seq they sent. a vote can
// overtake its poll (members write to us separately), so a row may wait a
// while for the poll it names. the trigger drops the votes however the
// poll's message goes, not each delete.
Future<void> _pollTables(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS poll_votes (
      poll_uid TEXT NOT NULL,
      voter TEXT NOT NULL,
      group_id TEXT,
      choices TEXT NOT NULL,
      seq INTEGER NOT NULL,
      at INTEGER NOT NULL,
      PRIMARY KEY (poll_uid, voter)
    )
  ''');
  await db.execute(
    'CREATE TRIGGER IF NOT EXISTS poll_votes_follow AFTER DELETE ON messages '
    'WHEN old.msg_uid IS NOT NULL BEGIN '
    'DELETE FROM poll_votes WHERE poll_uid = old.msg_uid; END',
  );
  // a poll that just went, for an hour: a vote naming it after that is
  // dropped at the door instead of waiting for a poll that is not coming
  await db.execute('''
    CREATE TABLE IF NOT EXISTS polls_gone (
      uid TEXT PRIMARY KEY,
      at INTEGER NOT NULL
    )
  ''');
  await db.execute(
    'CREATE TRIGGER IF NOT EXISTS polls_gone_mark AFTER DELETE ON messages '
    'WHEN old.poll IS NOT NULL AND old.msg_uid IS NOT NULL BEGIN '
    'INSERT OR REPLACE INTO polls_gone (uid, at) VALUES '
    "(old.msg_uid, CAST(strftime('%s','now') AS INTEGER) * 1000); END",
  );
}

/// an ALTER TABLE .. ADD COLUMN in an upgrade. two of sqlite's errors mean
/// there is nothing to do: the column is there (an upgrade cut short ran it
/// already), or the table is not there yet (an older step below makes it
/// whole). any other failure stops the upgrade, and the old version runs it
/// again on the next start
Future<void> addColumn(DatabaseExecutor db, String sql) async {
  try {
    await db.execute(sql);
  } catch (e) {
    final m = '$e';
    if (!m.contains('duplicate column name') && !m.contains('no such table')) {
      rethrow;
    }
  }
}

// wrapped: one throw in a migration and the app never opens again. without
// the table there is simply no developer row
Future<void> _devChatTables(Database db) async {
  try {
    await devChatTables(db);
  } catch (e) {
    dlog('devchat table: $e');
  }
}

// wrapped like the dev chat's: without the table there is no support
// inbox, and the app still opens
Future<void> _supportTables(Database db) async {
  try {
    await supportTables(db);
  } catch (e) {
    dlog('support table: $e');
  }
}

// a direct-onion message past a stranger's two has no relay to wait on. it
// waits here instead, still sealed, and opens when the person is accepted.
Future<void> _heldTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS held_onion (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      peer_id TEXT NOT NULL,
      cipher TEXT NOT NULL,
      at INTEGER NOT NULL
    )
  ''');
}

// a file coming in that is not whole yet: who is sending it, whether they
// can be asked for the missing slices, and how many asks in a row brought
// nothing.
Future<void> _mediaWantsTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS media_wants (
      media_id TEXT PRIMARY KEY,
      peer_id TEXT NOT NULL,
      total INTEGER NOT NULL,
      can_resend INTEGER NOT NULL,
      last_at INTEGER NOT NULL,
      asked_at INTEGER NOT NULL DEFAULT 0,
      asks INTEGER NOT NULL DEFAULT 0
    )
  ''');
}

// a pin in a 1:1 chat that has not reached the other person yet. a pin is
// shared state; sent once and lost, the two lists differ for good.
Future<void> _pinsTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS pins_out (
      msg_uid TEXT PRIMARY KEY,
      peer_id TEXT NOT NULL,
      pinned INTEGER NOT NULL,
      at INTEGER NOT NULL
    )
  ''');
}

// an edit made offline queues like a message, or it shows as edited here
// and never arrives there
Future<void> _editsTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS edits_out (
      msg_uid TEXT PRIMARY KEY,
      peer_id TEXT NOT NULL,
      new_text TEXT NOT NULL,
      at INTEGER NOT NULL
    )
  ''');
}

const kFrameUnsend = 'unsend';
const kFrameReaction = 'reaction';

// an unsend or a reaction in a 1:1 chat that has not reached the other
// person yet, one of each kind a message: the latest word replaces the last.
// a reaction's body is its emoji, empty when it was taken off
Future<void> _framesTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS frames_out (
      msg_uid TEXT NOT NULL,
      kind TEXT NOT NULL,
      peer_id TEXT NOT NULL,
      body TEXT NOT NULL,
      at INTEGER NOT NULL,
      PRIMARY KEY (msg_uid, kind)
    )
  ''');
}

// a group file some members still lack once its row reads sent: per member,
// the slices they hold and when to try them again. the trigger drops them
// however the message goes, as poll_votes does
Future<void> groupOwedTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS group_media_owed (
      msg_uid TEXT NOT NULL,
      group_id TEXT NOT NULL,
      member TEXT NOT NULL,
      total INTEGER NOT NULL,
      have TEXT NOT NULL DEFAULT '',
      sent_to INTEGER NOT NULL,
      since INTEGER NOT NULL,
      tries INTEGER NOT NULL DEFAULT 0,
      next_at INTEGER NOT NULL,
      PRIMARY KEY (msg_uid, member)
    )
  ''');
  await db.execute(
    'CREATE TRIGGER IF NOT EXISTS group_media_owed_follow AFTER DELETE ON '
    'messages WHEN old.msg_uid IS NOT NULL BEGIN '
    'DELETE FROM group_media_owed WHERE msg_uid = old.msg_uid; END',
  );
}

// a group control each member is still to get, in the order it was made: a
// member takes them one after the other. and per group, the stamp of the
// newest roster taken, with the room keys that left, which an older roster
// does not bring back
Future<void> groupCtlTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS group_ctl_out (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      group_id TEXT NOT NULL,
      member TEXT NOT NULL,
      ctl TEXT NOT NULL,
      since INTEGER NOT NULL,
      tries INTEGER NOT NULL DEFAULT 0,
      next_at INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS group_roster (
      group_id TEXT PRIMARY KEY,
      stamp INTEGER NOT NULL DEFAULT 0,
      gone TEXT NOT NULL DEFAULT ''
    )
  ''');
}

Future<void> _shieldTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS shield (
      halo_id TEXT PRIMARY KEY,
      headline TEXT NOT NULL,
      lines TEXT NOT NULL,
      dismissed INTEGER NOT NULL DEFAULT 0,
      at INTEGER NOT NULL
    )
  ''');
}

Future<void> _vouchTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS vouches (
      halo_id TEXT NOT NULL,
      voucher_id TEXT NOT NULL,
      note TEXT,
      created_at INTEGER NOT NULL,
      PRIMARY KEY (halo_id, voucher_id)
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_vouches_halo_id ON vouches(halo_id)',
  );
}

// one store's tables. under a prefix, another store in the same database
Future<void> _signalTables(Database db, {String prefix = ''}) async {
  await db.execute(
    'CREATE TABLE IF NOT EXISTS ${prefix}prekeys (id INTEGER PRIMARY KEY, record BLOB NOT NULL)',
  );
  await db.execute(
    'CREATE TABLE IF NOT EXISTS ${prefix}signed_prekeys (id INTEGER PRIMARY KEY, record BLOB NOT NULL, created_at INTEGER NOT NULL)',
  );
  await db.execute(
    'CREATE TABLE IF NOT EXISTS ${prefix}sessions (address TEXT NOT NULL, device_id INTEGER NOT NULL, record BLOB NOT NULL, PRIMARY KEY (address, device_id))',
  );
  await db.execute(
    'CREATE TABLE IF NOT EXISTS ${prefix}peer_identities (address TEXT PRIMARY KEY, identity_key BLOB NOT NULL)',
  );
  await db.execute(
    'CREATE TABLE IF NOT EXISTS ${prefix}signal_meta (k TEXT PRIMARY KEY, v TEXT NOT NULL)',
  );
}

// wrapped like the dev chat's row: without them an anonymous start fails
// closed, and the app still opens
Future<void> _devSignalTables(Database db) async {
  try {
    await _signalTables(db, prefix: kDevSignalPrefix);
  } catch (e) {
    dlog('dev signal tables: $e');
  }
}

/// the contacts rows the requests inbox holds: someone not accepted who
/// wrote one to one, waits sealed, or was introduced. a group member's
/// key-only row is none of these and asked for nothing
@visibleForTesting
const kRequestRows =
    'accepted = 0 AND blocked = 0 AND IFNULL(archived, 0) = 0 AND ('
    'EXISTS (SELECT 1 FROM messages m WHERE m.peer_id = contacts.halo_id '
    'AND m.group_id IS NULL) OR '
    'EXISTS (SELECT 1 FROM held_onion h WHERE h.peer_id = contacts.halo_id) OR '
    'EXISTS (SELECT 1 FROM vouches v WHERE v.halo_id = contacts.halo_id))';

/// a request as the inbox shows it, or one declined and parked since
@visibleForTesting
const kAskedRows =
    '($kRequestRows) OR '
    '(accepted = 0 AND blocked = 0 AND IFNULL(archived, 0) = 1)';

/// what a notification says for a message with no text: what kind of
/// file it is, never the name a voice note or a camera clip was saved under
String notifMediaLine(String? fileName, String? mediaPath) {
  if (fileName == 'voice.wav') return l10n.appVoiceMessage;
  if (nameSaysVideo(fileName)) return l10n.chatVideo;
  return fileName ?? (mediaPath != null ? l10n.appPhoto : '');
}

Future<String> makePreKeyBundleB64([SignalSession? of]) async {
  final ss = of ?? signalSession;
  final spk = await ss.signedPreKeyStore.loadSignedPreKey(1);
  // the kept invite prekey, never the lowest one-time key: a handle's
  // published invite is static, and a one-time key is gone after the first
  // person uses it
  final pk = await ss.preKeyStore.loadPreKey(invitePreKeyId);
  final bundle = {
    'registrationId': ss.registrationId,
    'deviceId': 1,
    'preKeyId': pk.id,
    'preKeyPublic': base64Encode(pk.getKeyPair().publicKey.serialize()),
    'signedPreKeyId': spk.id,
    'signedPreKeyPublic': base64Encode(spk.getKeyPair().publicKey.serialize()),
    'signedPreKeySignature': base64Encode(spk.signature),
    'identityKey': base64Encode(ss.identityKeyPair.getPublicKey().serialize()),
  };
  return base64Encode(utf8.encode(jsonEncode(bundle)));
}

// the store a peer's messages go through: the everyday one, and for the
// dev chat the one it was started with. null for a dev chat that has none
// (not started, deleted, restored without its made name) and for any other
// id shaped like one: nothing falls back to the everyday store for it
Future<SignalSession?> signalFor(String peer) async =>
    isDevId(peer) ? (await devLane.seat(peer))?.store : signalSession;

// a session with [haloId] built from their card, in [into] or the store
// signalFor names
Future<void> processPeerBundle(
  String haloId,
  String bundleB64, {
  SignalSession? into,
}) async {
  final ss = into ?? await signalFor(haloId);
  if (ss == null) throw StateError('no signal store for this chat');
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
    ss.sessionStore,
    ss.preKeyStore,
    ss.signedPreKeyStore,
    ss.identityStore,
    addr,
  );
  await ss.serial(haloId, () => builder.processPreKeyBundle(preKeyBundle));
}

// best-effort wipe of key or plaintext bytes from ram. dart strings are
// immutable and cannot be wiped, only lists.
void _zeroBytes(List<int> b) {
  for (var i = 0; i < b.length; i++) {
    b[i] = 0;
  }
}

// no session yet with this peer: the next message is an opener
Future<bool> hasSessionWith(String peerId) async {
  final ss = await signalFor(peerId);
  return ss != null &&
      await ss.sessionStore.containsSession(SignalProtocolAddress(peerId, 1));
}

// the one place a frame is sealed for a peer. every frame for the dev chat
// goes through its own seal instead: the allowlist, its store, the token
// the wire asks for. either store seals one frame at a time per peer
Future<String> signalEncrypt(String peerId, String plaintext) async {
  if (isDevId(peerId)) return devLane.encrypt(peerId, plaintext);
  return signalSession.encryptTo(peerId, plaintext);
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

// the identity a store holds for an address: the one it trusts, else the
// one its session was built with
Future<List<int>?> _storedIdentity(
  SignalSession ss,
  SignalProtocolAddress addr,
) async {
  final known = await ss.identityStore.getIdentity(addr);
  if (known != null) return known.serialize();
  if (!await ss.sessionStore.containsSession(addr)) return null;
  final record = await ss.sessionStore.loadSession(addr);
  return record.sessionState.getRemoteIdentityKey()?.serialize();
}

// the identity key a card's prekey bundle carries, null when it does not
// read
List<int>? _bundleIdentity(String bundleB64) {
  try {
    final j = jsonDecode(utf8.decode(base64Decode(bundleB64))) as Map;
    return base64Decode(j['identityKey'] as String);
  } catch (_) {
    return null;
  }
}

// an x key as signal writes it, null when it is not one
List<int>? _xIdentity(String xHex) {
  if (xHex.length != 64) return null;
  final out = <int>[0x05];
  for (var i = 0; i < 64; i += 2) {
    final b = int.tryParse(xHex.substring(i, i + 2), radix: 16);
    if (b == null) return null;
    out.add(b);
  }
  return out;
}

// the key a row holds for someone. a key that does not read still binds
// the row: it matches nothing
List<int>? _rowIdentity(Map<String, Object?>? row) {
  if (row == null) return null;
  final x = row['xpub'] as String?;
  if (x != null && x.isNotEmpty) {
    return _xIdentity(x.toLowerCase()) ?? utf8.encode('x $x');
  }
  final bundle = row['peer_bundle'] as String?;
  if (bundle != null && bundle.isNotEmpty) {
    return _bundleIdentity(bundle) ?? utf8.encode('b $bundle');
  }
  return null;
}

// the identity a name is bound to here: the key it was first seen with,
// from the signal store [ss] and then from the row [row] reads. null for a
// name with no key yet
Future<List<int>?> _boundIdentity(
  String id, {
  SignalSession? ss,
  Future<Map<String, Object?>?> Function(String id)? row,
}) async {
  if (ss != null) {
    try {
      final k = await _storedIdentity(ss, SignalProtocolAddress(id, 1));
      if (k != null) return k;
    } catch (e) {
      dlog('bound identity: store not read ($e)');
    }
  }
  return row == null ? null : _rowIdentity(await row(id));
}

/// whether [h], from the wire, has the shape of an id that stands for
/// someone: three words, or the id of one filed on their own key
/// ([unboundIdOf]). in a room, a room key
bool wireIdShaped(String h, {required bool room}) => room
    ? _roomKeyShape.hasMatch(h)
    : _wordsShape.hasMatch(h) || _ownIdShape.hasMatch(h);

final _wordsShape = RegExp(r'^[a-z]{1,16}-[a-z]{1,16}-[a-z]{1,16}$');
final _ownIdShape = RegExp(r'^[0-9a-f]{16}$');
final _roomKeyShape = RegExp(r'^[0-9a-f]{1,64}$');

/// where someone lands who writes under a name bound here to another key:
/// an id of their own, from their key, that is never three words
String unboundIdOf(List<int> identityKey) =>
    sha256.convert(identityKey).toString().substring(0, 16);

Future<String?> signalDecrypt(
  String peerId,
  String wireB64, {
  bool flagKeyChange = false,
}) async {
  final ss = await signalFor(peerId);
  if (ss == null) return null;
  try {
    final wire = base64Decode(wireB64);
    if (wire.isEmpty) return null;
    final type = wire[0];
    final body = Uint8List.fromList(wire.sublist(1));
    final addr = SignalProtocolAddress(peerId, 1);
    final cipher = SessionCipher(
      ss.sessionStore,
      ss.preKeyStore,
      ss.signedPreKeyStore,
      ss.identityStore,
      addr,
    );
    // opens share the per-peer queue with seals: both step the same record
    final plain = await ss.serial<Uint8List?>(peerId, () async {
      if (type != CiphertextMessage.prekeyType) {
        return cipher.decryptFromSignal(SignalMessage.fromSerialized(body));
      }
      final pkm = PreKeySignalMessage(body);
      // trial decrypt: a prekey opens only under the name its identity is
      // bound to. another identity, or a name with none yet, arrives as a
      // first contact and is checked there. targeted decrypts
      // (flagKeyChange) skip this and keep deliver-and-warn for mitm.
      if (!flagKeyChange && peerId != '_pending_back_pair_') {
        final known = await _storedIdentity(ss, addr);
        if (known == null ||
            !_eqBytes(known, pkm.getIdentityKey().serialize())) {
          return null;
        }
      }
      if (await ss.sessionStore.containsSession(addr)) {
        // session exists: use it. rebuilding from the prekey record bad-macs
        // when the slot was refilled with a fresh key.
        try {
          return await cipher.decryptFromSignal(pkm.getWhisperMessage());
        } catch (e) {
          dlog('signalDecrypt: session path failed ($e), prekey fallback');
          return cipher.decrypt(pkm);
        }
      }
      final pkId = pkm.getPreKeyId();
      final havePk =
          !pkId.isPresent || await ss.preKeyStore.containsPreKey(pkId.value);
      if (!havePk) {
        dlog('signalDecrypt: prekey gone, no session for $peerId');
        return null;
      }
      return cipher.decrypt(pkm);
    });
    if (plain == null) return null;
    final text = utf8.decode(plain);
    _zeroBytes(plain); // cleartext decoded out, wipe the raw buffer
    return text;
  } on DuplicateMessageException catch (_) {
    dlog('signalDecrypt: duplicate from $peerId, dropped');
    // store-and-forward re-delivers, so a duplicate is expected. the
    // original already decrypted.
    return null;
  } on UntrustedIdentityException catch (_) {
    // known peer's identity key no longer matches: reinstall or mitm. only
    // flagged on a targeted decrypt, so a trial against the wrong contact
    // never sets it.
    // the dev chat never warns: a key that is not the pinned one is dropped
    if (flagKeyChange && !isDevChat(peerId)) {
      await live.setKeyChanged(peerId, true);
      appState.keyChanged();
    }
    return null;
  } on InvalidKeyIdException catch (_) {
    // one-time prekey already used. with a session, an earlier copy set it
    // up and this is a duplicate; without one it cannot be read.
    final addr = SignalProtocolAddress(peerId, 1);
    if (await ss.sessionStore.containsSession(addr)) {
      return null;
    }
    return null;
  } catch (e) {
    dlog('signalDecrypt: $e');
    return null;
  }
}

int _outboxGrind(String seed) => grindPow(seed, powBits);

Future<String> handleHaloUri(String raw) async =>
    (await handleHaloUriAdded(raw)).$1;

// the result line, and whether the link left the person in the contacts
// (added now, or already there). a caller that acts on that asks this; the
// line is in the app's language and is not compared with anything.
Future<(String, bool)> handleHaloUriAdded(String raw) async {
  // @wren or the handle page link: ask the registry for the invite behind it
  // and carry on as if that had been pasted
  final h = handleFromInput(raw);
  if (h != null) {
    // a quiet session never reaches the registry
    if (sessionQuiet) return (l10n.handleRegistryFailed, false);
    // the invite has to be the claimer's own: its id is the words of the
    // key the handle was claimed with
    final r = await resolveHandle(
      h,
      _torGetJsonOnIsolate,
      idOf: engine.idFromEdPub,
    );
    // the lookup answers in fixed english words; the person reads their own
    if (r.startsWith('error:')) {
      return (
        r.contains('nobody has claimed')
            ? l10n.handleNobodyHasClaimed('@$h')
            : r.contains('not a handle')
            ? l10n.appInvalidUri
            : l10n.handleRegistryFailed,
        false,
      );
    }
    raw = r;
  }
  // the link, out of whatever was pasted around it
  raw = firstKryfoLink(raw) ?? raw;
  final room = RoomLink.parse(raw);
  if (room != null) {
    final r = await appState.joinRoom(room);
    // a join opens the room. compared with the words themselves, not a
    // prefix of the english
    if (r == l10n.appJoined(room.name) ||
        r == l10n.appJoinedButTheCreator(room.name) ||
        r == l10n.appJoinedButYourHello(room.name) ||
        r == l10n.appYouAreAlreadyIn) {
      openRoomSoon(room.roomId);
    }
    return (r, false);
  }
  final parsed = parseHaloUri(raw);
  if (parsed == null) return (l10n.appInvalidUri, false);
  // one's own invite adds no one: a row and a session with oneself would
  // only put oneself in the chat list
  if (parsed['id'] == appState.sessionId) return (l10n.appYourOwnInvite, false);
  // a card naming the developer is taken on his keys alone: his own opens
  // his chat and adds nothing, one with his words and another key is
  // refused, and a dev chat id is never a card's
  switch (devCardOf(
    id: parsed['id']!,
    bundle: parsed['bundle'],
    xPub: parsed['xpub'],
  )) {
    case DevCard.none:
      break;
    case DevCard.refused:
      return (l10n.appInvalidUri, false);
    case DevCard.mismatch:
      return (l10n.devLinkMismatch, false);
    case DevCard.dev:
      String? chat;
      try {
        final row = await session.devChat.load();
        // a deleted chat comes back only from its settings row
        if (row?.state == DevState.gone) return (l10n.devLinkGone, false);
        chat = row?.chatId;
      } catch (e) {
        dlog('dev link: $e');
      }
      chat ??= currentDevKey?.chatId;
      if (chat == null) return (l10n.appInvalidUri, false);
      openDevChatLater(chat);
      // nothing to say: the chat opening is the answer
      return ('', true);
  }
  // a name stays with the key first seen for it: a card that names someone
  // here with another key changes nothing, and a card has to carry a key
  // that reads to be checked at all
  final cardKey = parsed['bundle'] != null
      ? _bundleIdentity(parsed['bundle']!)
      : _xIdentity(parsed['xpub']!.toLowerCase());
  if (cardKey == null) return (l10n.appInvalidUri, false);
  final bound = await _boundIdentity(
    parsed['id']!,
    ss: sessionQuiet ? null : signalSession,
    row: session.getContact,
  );
  if (bound != null && !_eqBytes(bound, cardKey)) {
    return (l10n.appLinkOtherKey(parsed['id']!), false);
  }
  // someone blocked stays blocked: an add would say they can be written to
  // while nothing of theirs is heard. the blocked list lets them back
  if (await session.isBlocked(parsed['id']!)) {
    return (l10n.appTheyAreBlocked(parsed['id']!), false);
  }
  if (parsed['v'] == '2' || parsed['v'] == '3') {
    final id = parsed['id']!;
    // saved means accepted. a group member known by key, a request or one
    // let go has a row too, and this add is what takes them in
    final already = await session.isAccepted(id);
    final asked = !already && await session.askedBefore(id);
    // a quiet session keeps the contact on this phone and nothing more: the
    // session with them would live in the everyday identity's store
    if (!sessionQuiet) {
      try {
        await processPeerBundle(parsed['id']!, parsed['bundle']!);
      } catch (e) {
        return (l10n.appBundleError(e), false);
      }
    }
    await session.upsertContact(parsed['id']!, parsed['onion']!, '');
    await session.setPeerBundle(parsed['id']!, parsed['bundle']!);
    if (sessionQuiet) {
      await appState.refreshContacts();
      return (
        already
            ? l10n.appAlreadySaved('${parsed['id']}')
            : l10n.appAddedYouCanMessage('${parsed['id']}'),
        true,
      );
    }
    final fc = parsed['fc'];
    dlog(
      fc == null || fc.isEmpty
          ? 'pair: v${parsed['v']} invite, no first-contact addr'
          : 'pair: v${parsed['v']} invite carries first-contact addr',
    );
    if (fc != null && fc.isNotEmpty) {
      await appState.rememberPeerFc(parsed['id']!, fc);
    }
    await appState.subscribePeer(parsed['id']!);
    // as the accept button would: they hear they are in, and what was
    // held for them opens
    if (asked) await appState.afterAccept(id);
    // home, the pickers and the introductions show them now
    await appState.refreshContacts();
    return (
      already
          ? l10n.appAlreadySaved('${parsed['id']}')
          : l10n.appAddedYouCanMessage('${parsed['id']}'),
      true,
    );
  } else {
    final id = parsed['id']!;
    // an old card is an add all the same, and takes in who asked
    final asked =
        !await session.isAccepted(id) && await session.askedBefore(id);
    await session.upsertContact(id, parsed['onion']!, parsed['xpub']!);
    if (!sessionQuiet) await appState.subscribePeer(id);
    if (asked && !sessionQuiet) await appState.afterAccept(id);
    return (l10n.appPeerImportedV1(id), false);
  }
}

// overwrite with zeros, then unlink. best effort: flash wear levelling can
// keep an old block, but the easy read is gone.
Future<void> shredFile(String path) async {
  try {
    final f = File(path);
    if (!await f.exists()) return;
    final len = await f.length();
    final raf = await f.open(mode: FileMode.writeOnly);
    try {
      const chunk = 64 * 1024;
      final zeros = Uint8List(chunk);
      var left = len;
      while (left > 0) {
        final n = left < chunk ? left : chunk;
        await raf.writeFrom(zeros, 0, n);
        left -= n;
      }
      await raf.flush();
    } finally {
      await raf.close();
    }
    await f.delete();
  } catch (e) {
    dlog('shred: $e');
  }
}

// a copy of a capture into the phone's photos, only when asked for. the
// phone's own media store does the writing; below android 10 it says no.
Future<bool> exportToPictures(Uint8List bytes, String name, String mime) async {
  try {
    final ok = await const MethodChannel('halo/platform').invokeMethod<bool>(
      'saveToPictures',
      {'bytes': bytes, 'name': name, 'mime': mime},
    );
    return ok == true;
  } catch (e) {
    dlog('export: $e');
    return false;
  }
}

// captures that never got sent: a force quit mid-shot leaves the plugin's
// file in the cache and a clip in captures. gone at every boot.
Future<void> sweepCaptures() async {
  try {
    final sup = await getApplicationSupportDirectory();
    final caps = Directory('${sup.path}/captures');
    if (await caps.exists()) {
      await for (final f in caps.list()) {
        if (f is File) await shredFile(f.path);
      }
    }
    final tmp = await getTemporaryDirectory();
    await for (final f in tmp.list()) {
      if (f is! File) continue;
      final n = f.path.toLowerCase();
      // the plugin names its files itself; ours in here are cards and
      // voice notes, which keep their own names
      if ((n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.mp4')) &&
          !n.contains('/kryfo-')) {
        await shredFile(f.path);
      }
      // a backup copy that never got shredded, say the app died mid-save
      if (n.contains('/kryfo-backup-')) await shredFile(f.path);
    }
    await sweepShareCopies(tmp);
    // the gallery picker's whole copies, in folders of their own
    await sweepPickerLeftovers(tmp);
    // the file picker keeps its own folder of copies
    final picks = Directory('${tmp.path}/file_picker');
    if (await picks.exists()) {
      await for (final f in picks.list(recursive: true)) {
        if (f is File) await shredFile(f.path);
      }
      await picks.delete(recursive: true);
    }
  } catch (e) {
    dlog('sweep: $e');
  }
}

// a file handed to the share sheet is a plain copy in the share plugin's
// folder, kept there until the next share. the native side clears it on
// resume once it is a few minutes old; this is the start's turn
@visibleForTesting
Future<void> sweepShareCopies(Directory cache) async {
  final dir = Directory('${cache.path}/share_plus');
  if (!await dir.exists()) return;
  await for (final f in dir.list(recursive: true)) {
    if (f is File) await shredFile(f.path);
  }
  await dir.delete(recursive: true);
}

String _safeLeaf(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

final _leafRandom = Random.secure();

// a name for an arriving file that nothing on the wire chose: never a
// message id, and never the shape of the names our own files get
String _freshLeaf() {
  final b = [for (var i = 0; i < 16; i++) _leafRandom.nextInt(256)];
  return 'in_${b.map((x) => x.toRadixString(16).padLeft(2, '0')).join()}';
}

// where a received file lands: media/in_<random>_<name>, in the folder of
// the container the message goes to. the sender's name stays at the end so
// the file keeps its type
Future<File> receivedFileFor(
  String name, [
  HaloContainer c = HaloContainer.everyday,
]) async {
  final mediaDir = await c.mediaDir();
  return File('${mediaDir.path}/${_freshLeaf()}_${_safeLeaf(name)}');
}

// where a received picture lands: media/in_<random>.jpg
Future<File> receivedImageFor([
  HaloContainer c = HaloContainer.everyday,
]) async {
  final mediaDir = await c.mediaDir();
  return File('${mediaDir.path}/${_freshLeaf()}.jpg');
}

Future<String> saveFileBytes(
  List<int> bytes,
  String name, [
  HaloContainer c = HaloContainer.everyday,
]) async {
  final file = await receivedFileFor(name, c);
  await file.writeAsBytes(bytes);
  return file.path;
}

Future<String> saveMediaBytes(
  List<int> bytes, [
  HaloContainer c = HaloContainer.everyday,
]) async {
  final file = await receivedImageFor(c);
  await file.writeAsBytes(bytes);
  return file.path;
}

// a chunked file rebuilt one slice at a time. every slice but the last is
// a multiple of four base64 characters, so each decodes on its own and
// goes straight to disk. a slice that is missing or will not decode
// leaves no half file behind.
Future<String> saveSlices(
  File file,
  int total,
  Future<String?> Function(int i) slice,
) async {
  final sink = file.openWrite();
  try {
    for (var i = 0; i < total; i++) {
      final part = await slice(i);
      if (part == null) throw StateError('slice $i missing');
      sink.add(base64Decode(part));
    }
    await sink.flush();
    await sink.close();
  } catch (e) {
    try {
      await sink.close();
    } catch (_) {
      // the sink broke with the write: the error passed on is the first
    }
    try {
      await file.delete();
    } catch (e) {
      dlog('slices: half file left (${e.runtimeType})');
    }
    rethrow;
  }
  return file.path;
}

String buildHaloUri(String id, String onion, String xpub) {
  return 'kryfo://share?id=$id&onion=$onion&xpub=$xpub';
}

Future<String> buildHaloUriV2(String id, String onion) async {
  final bundle = await makePreKeyBundleB64();
  return 'kryfo://share?id=$id&onion=$onion&v=2&bundle=$bundle';
}

// v3 carries a first-contact address alongside the bundle, so a one-way scan
// still works when our onion will not publish
Future<String> buildHaloUriV3(String id, String onion, int fcCounter) async {
  final bundle = await makePreKeyBundleB64();
  final fc = engine.firstContactPk(fcCounter);
  if (fc.isEmpty || fc.startsWith('error')) {
    return buildHaloUriV2(id, onion);
  }
  return haloUriV3(id, onion, bundle, fc);
}

String haloUriV3(String id, String onion, String bundle, String fc) =>
    'kryfo://share?id=$id&onion=$onion&v=3&bundle=$bundle&fc=$fc';

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

HaloEngine _engine = HaloEngine();
HaloEngine get engine => _engine;

// tests stand a spy in for the engine, which needs the native library
@visibleForTesting
void useEngineForTest(HaloEngine e) => _engine = e;

// the decoy's identity, read from its own database when a decoy session
// opens. made at setup and registered nowhere
class QuietIdentity {
  const QuietIdentity({
    required this.id,
    required this.edPub,
    required this.xPub,
    required this.onion,
    required this.invite,
  });
  final String id;
  final String edPub;
  final String xPub;
  final String onion;
  final String invite;
}

// what home shows of a session: its chats, requests, groups, avatar and
// the developer chat's row
class _Shown {
  const _Shown(this.contacts, this.pending, this.groups, this.avatar, this.dev);
  final List<ContactPreview> contacts;
  final int pending;
  final List<GroupPreview> groups;
  final int? avatar;
  final DevRow? dev;
}

// the everyday container's database. what arrives lands here whichever
// session is open, but for the hidden chats; screens never touch it, they
// ask the session
HaloDb _live = HaloDb();
HaloDb get live => _live;
Session _session = Session(live);

// tests stand fakes in for the everyday database and the open session
@visibleForTesting
void useDatabasesForTest(HaloDb everyday, Session open) {
  _live = everyday;
  _session = open;
}

// what the screens read and write: the everyday database, or the decoy's
// while a decoy session is open
Session get session => _session;
// a quiet session sends nothing: what is typed in it stays queued
bool get sessionQuiet => _session.primary.container.quiet;

// opens a room on the root navigator, a beat later: whoever asked for the
// join is a sheet or a screen about to close itself, and a room pushed
// before that close would be the thing that got closed.
void openRoomSoon(String groupId) {
  Future.delayed(
    const Duration(milliseconds: 450),
    // one of a kind only while it waits for the lock: opened by hand twice
    // in a row, it opens twice
    () => lockGuard.afterUnlock(
      key: lockGuard.isLocked() ? 'room:$groupId' : null,
      () async {
        final nav = rootNavKey.currentState;
        if (nav == null || !await session.groupExists(groupId)) return;
        nav.push(haloRoute(GroupChatScreen(groupId: groupId)));
      },
    ),
  );
}

// a link naming the developer's own key opens his chat, a beat later, as a
// room link does. tests watch it here
@visibleForTesting
void Function(String chatId) openDevChatLater = _openChatSoon;

void _openChatSoon(String chatId) {
  Future.delayed(
    const Duration(milliseconds: 450),
    () => openChatForHalo(chatId),
  );
}

// what a link opened from outside the app came to, so an expired or full
// room does not look like nothing happening
void _sayLinkResult(String result) {
  final ctx = rootNavKey.currentContext;
  if (ctx != null && ctx.mounted) showHaloToast(ctx, result);
}

// a notification tap, warm or cold start, opens the chat once the app lock
// is open
Future<void> openChatForHalo(String? haloId) =>
    lockGuard.afterUnlock(() => _openChatFor(haloId), key: 'chat:$haloId');

// a group asked to hold more than the cap. its message is read when shown,
// in the language of that moment
class GroupFull implements Exception {
  const GroupFull();
  String get message => l10n.appGroupHoldsUpTo(AppState.kGroupMemberCap);
}

// what a tapped notification opens in the session on screen: a group or
// room, the requests for someone not yet let in, or an accepted chat
sealed class NotifTarget {
  const NotifTarget();
}

class NotifGroup extends NotifTarget {
  const NotifGroup(this.groupId);
  final String groupId;
}

class NotifRequests extends NotifTarget {
  const NotifRequests();
}

class NotifChat extends NotifTarget {
  const NotifChat(this.row);
  final Map<String, Object?> row;
}

// null when the chat is gone, is not this session's, or is the one open
@visibleForTesting
Future<NotifTarget?> notifTargetFor(String payload) async {
  if (payload == currentChatPeer) return null;
  if (payload.startsWith('group:')) {
    final id = payload.substring('group:'.length);
    if (id.isEmpty || !await session.groupExists(id)) return null;
    return NotifGroup(id);
  }
  final rows = await session.contacts();
  final row = rows.where((r) => r['halo_id'] == payload).firstOrNull;
  if (row != null) return NotifChat(row);
  // a request is read and answered on its own screen, where the shield is
  final c = await session.getContact(payload);
  if (c == null || (c['blocked'] as int? ?? 0) == 1) return null;
  if ((c['accepted'] as int? ?? 0) != 1) return const NotifRequests();
  return null;
}

Future<void> _openChatFor(String? haloId) async {
  if (haloId == null || haloId.isEmpty) return;
  final nav = rootNavKey.currentState;
  if (nav == null) return;
  // the developer's own phone: its support inbox, or one of its chats
  if (haloId.startsWith(kSupportPayload)) {
    return openSupportTap(nav, haloId.substring(kSupportPayload.length));
  }
  // the developer chat has its own door, and only while it is there
  if (isDevChat(haloId)) {
    if (haloId == currentChatPeer) return;
    if ((await session.devChat.load())?.chatId != haloId) return;
    nav.push(devChatRoute(haloId));
    return;
  }
  final target = await notifTargetFor(haloId);
  if (target == null) return;
  final Map<String, Object?> row;
  switch (target) {
    case NotifGroup(:final groupId):
      nav.push(haloRoute(GroupChatScreen(groupId: groupId)));
      return;
    case NotifRequests():
      nav.push(haloRoute(const RequestsScreen()));
      return;
    case NotifChat(row: final r):
      row = r;
  }
  nav.push(
    haloRoute(
      ChatScreen(
        peerHaloId: haloId,
        peerOnion: row['onion'] as String,
        peerXPub: row['xpub'] as String,
        avatarSeed: haloId,
        avatarChoice: (row['avatar'] as num?)?.toInt(),
      ),
    ),
  );
}

// the chat or group whose screen is open ('group:<id>' for a group), as the
// screens report it, and the container of the session it is open in
String? _chatOnScreen;
HaloContainer? _chatOnScreenIn;

// the chat being read: the one on screen, and only while the lock is down.
// a message for it is marked read and its notification suppressed, so under
// the lock there is none
String? get currentChatPeer => lockGuard.isLocked() ? null : _chatOnScreen;

void claimChat(String id) {
  _chatOnScreen = id;
  _chatOnScreenIn = session.container;
}

void releaseChat(String id) {
  if (_chatOnScreen != id) return;
  _chatOnScreen = null;
  _chatOnScreenIn = null;
}

// whether [id] is being read where the rows of [c] show: the chat on
// screen, in a session that holds [c]. the same id in another container is
// another chat
bool readingIn(String id, HaloContainer c) {
  final open = _chatOnScreenIn;
  return currentChatPeer == id &&
      open != null &&
      (c == open || c.extended == open);
}

// the root navigator. each session gets its own: switching sessions under
// the lock swaps the key, and every route, popping route, hero flight, toast
// and menu of the other session goes with the old navigator at once
GlobalKey<NavigatorState> _rootNavKey = GlobalKey<NavigatorState>();
GlobalKey<NavigatorState> get rootNavKey => _rootNavKey;
final navRevision = ValueNotifier<int>(0);

void renewRootNavigator() {
  haloClearToasts();
  _rootNavKey = GlobalKey<NavigatorState>();
  navRevision.value++;
}

final _msgUidRandom = Random.secure();
const _msgUidChars = '0123456789abcdefghijklmnopqrstuvwxyz';

// stable cross-device message id, also a group's and a room's id. used by
// reactions, replies and group fan-out so every recipient sees the same
// uid. 14 base36 characters from the platform csprng: over 72 bits, with
// nothing of the clock in it
String newMsgUid() => String.fromCharCodes([
  for (var i = 0; i < 14; i++)
    _msgUidChars.codeUnitAt(_msgUidRandom.nextInt(_msgUidChars.length)),
]);

class GroupPreview {
  final String groupId;
  final String name;
  final int memberCount;
  final bool isAdmin;
  final DateTime createdAt;
  final int unread;
  final bool mentioned; // someone wrote your three words since you last read
  final int? expiresAt; // a burner room's end, null for a group
  // one of the open vault's: only its session shows it
  final bool hidden;
  const GroupPreview({
    required this.groupId,
    required this.name,
    required this.memberCount,
    required this.isAdmin,
    required this.createdAt,
    this.unread = 0,
    this.mentioned = false,
    this.expiresAt,
    this.hidden = false,
  });
}

/// how far the first fill of the search index has got, for the search
/// screen's line while older messages are still being added
final searchFill = ValueNotifier<({int at, int to})>((at: 0, to: 0));

/// the fill [p] as the open session shows it: the index filling is the
/// everyday side's and the vault's, and a decoy has neither
({int at, int to}) shownSearchFill(({int at, int to}) p) =>
    sessionQuiet ? (at: 0, to: 0) : p;

// what receiving and reaching someone ask of signal, the engine and
// android, in one place so the paths through them can run on stand-ins
class AppIo {
  const AppIo();

  Future<String?> decrypt(
    String peer,
    String cipher, {
    bool flagKeyChange = false,
  }) => signalDecrypt(peer, cipher, flagKeyChange: flagKeyChange);

  Future<List<String>> sessionAddresses() =>
      signalSession.sessionStore.allSessionAddresses();

  Future<void> dropSession(String peer) =>
      signalSession.sessionStore.deleteSession(SignalProtocolAddress(peer, 1));

  // a first message from someone with no session yet: opened under a
  // placeholder, the sender's claim checked against their key, and the
  // session moved to them. a name bound here to another key keeps it: the
  // sender then gets an id of their own (unboundIdOf). null when any of it
  // fails
  Future<({String haloId, String plain, UnwrappedMessage env})?>
  openFirstContact(String cipher) async {
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
        dlog('back-pair: envelope missing identity fields');
        return null;
      }
      final derived = engine.idFromEdPub(e);
      if (derived != h) {
        await signalSession.sessionStore.deleteSession(tempAddr);
        dlog('back-pair: HaloID mismatch');
        return null;
      }
      // nobody starts a chat as the developer: his three words are only 33
      // bits and his keys are pinned. no session is kept under them
      if (devCardClaim(id: h, xPub: env.senderXPub)) {
        await signalSession.sessionStore.deleteSession(tempAddr);
        dlog('back-pair: claims the developer, dropped');
        return null;
      }
      final record = await signalSession.sessionStore.loadSession(tempAddr);
      final key = record.sessionState.getRemoteIdentityKey()?.serialize();
      // the x key it gives for itself is the one its session runs on
      final x = env.senderXPub;
      if (key == null ||
          (x != null &&
              x.isNotEmpty &&
              !_eqBytes(_xIdentity(x.toLowerCase()) ?? const [], key))) {
        await signalSession.sessionStore.deleteSession(tempAddr);
        dlog('back-pair: key mismatch');
        return null;
      }
      // a name stays with the key first seen for it
      var at = h;
      final bound = await _boundIdentity(
        h,
        ss: signalSession,
        row: live.getContact,
      );
      if (bound != null && !_eqBytes(bound, key)) {
        at = unboundIdOf(key);
        final held = await _boundIdentity(
          at,
          ss: signalSession,
          row: live.getContact,
        );
        if (held != null && !_eqBytes(held, key)) {
          await signalSession.sessionStore.deleteSession(tempAddr);
          return null;
        }
        dlog('back-pair: a name bound to another key, filed on its own');
      }
      // move session from temp to where it is filed
      final realAddr = SignalProtocolAddress(at, 1);
      await signalSession.sessionStore.storeSession(realAddr, record);
      await signalSession.sessionStore.deleteSession(tempAddr);
      return (haloId: at, plain: plain, env: env);
    } catch (e) {
      dlog('back-pair error: $e');
      try {
        await signalSession.sessionStore.deleteSession(tempAddr);
      } catch (_) {
        // the next first contact clears the placeholder before it starts
      }
      return null;
    }
  }

  Future<bool> hasSession(String peer) => hasSessionWith(peer);

  Future<String> encrypt(String peer, String plain) =>
      signalEncrypt(peer, plain);

  void listen(String xPub) => engine.nostrSubscribeBg(xPub);

  void unlisten(String xPub) => engine.nostrUnsubscribeBg(xPub);

  String edPub() => engine.myEdPubkey();

  String xPub() => engine.myXPubkey();

  Future<String> relaySend(String xPub, String cipher) =>
      engine.nostrSend(xPub, cipher);

  Future<String> onionSend(String onion, String cipher) =>
      engine.sendTo(onion, cipher);

  Future<String> firstContactSend(String xPub, String fc, String cipher) =>
      engine.sendFirstContact(xPub, fc, cipher);

  Future<void> notify({
    required String title,
    required String body,
    String? payload,
    String? msgUid,
  }) => showMessageNotification(
    title: title,
    body: body,
    payload: payload,
    msgUid: msgUid,
  );

  // what this process showed for a chat leaves the shade
  Future<void> unnotify(String payload) => clearNotificationsFor(payload);

  // one message's notification leaves the shade
  Future<void> unnotifyMessage(String msgUid) =>
      clearMessageNotification(msgUid);
}

// a first contact's session moved off a name a hidden chat binds to
// another key, onto the sender's own id. a name with a trusted key was
// settled when it opened, and stays. null when it cannot be moved
Future<String?> _refileFirstContact(String h) async {
  final addr = SignalProtocolAddress(h, 1);
  try {
    if (await signalSession.identityStore.getIdentity(addr) != null) return h;
    final record = await signalSession.sessionStore.loadSession(addr);
    final key = record.sessionState.getRemoteIdentityKey()?.serialize();
    await signalSession.sessionStore.deleteSession(addr);
    if (key == null) return null;
    final at = unboundIdOf(key);
    final held = await _boundIdentity(
      at,
      ss: signalSession,
      row: live.getContact,
    );
    if (held != null && !_eqBytes(held, key)) return null;
    await signalSession.sessionStore.storeSession(
      SignalProtocolAddress(at, 1),
      record,
    );
    return at;
  } catch (e) {
    dlog('back-pair: not refiled ($e)');
    return null;
  }
}

// the engine's sealing for the router
class EngineSeal implements VaultSeal {
  const EngineSeal();

  // a failure is one arrival not kept, never the rest of the batch
  @override
  String? seal(String pub, String b64) {
    try {
      final r = engine.vaultSeal(pub, b64);
      return r.isEmpty || r.startsWith('error') ? null : r;
    } catch (e) {
      dlog('seal: $e');
      return null;
    }
  }

  // a call that fails as a whole throws, so no row goes unopened
  @override
  List<String?> openMany(String priv, List<String> b64s) =>
      engine.vaultOpenMany(priv, b64s);
}

// a stranger's cap held a message back, in the container it was going to
class _HeldIn extends CapHeld {
  const _HeldIn(this.into);
  final HaloDb into;
}

// a first contact without its proof of work: nothing of it is kept
class _NoProof implements Exception {
  const _NoProof();
}

// one container's unsent rows: how many, how many wait on someone who has
// not added us back, how many for each person, and who has
class _Queue {
  const _Queue(this.n, this.parked, this.perPeer, this.paired);
  static const none = _Queue(0, 0, {}, {});

  final int n;
  final int parked;
  final Map<String, int> perPeer;
  final Map<String, bool> paired;

  bool same(_Queue o) {
    if (n != o.n || parked != o.parked) return false;
    if (perPeer.length != o.perPeer.length) return false;
    for (final e in perPeer.entries) {
      if (o.perPeer[e.key] != e.value) return false;
    }
    return true;
  }
}

class AppState extends ChangeNotifier {
  AppState({
    AppIo io = const AppIo(),
    VaultRouter? router,
    VaultHost host = const LiveVaultHost(),
    SupportBell bell = const SupportBell(),
  }) : _io = io,
       _host = host,
       _bell = bell,
       _router =
           router ??
           VaultRouter(SqlRouterStore(() => live.open()), const EngineSeal()) {
    // the wire asks the everyday container's dev chat, never a decoy's or
    // a vault's: only the everyday identity goes online. its seal and its
    // store read the same row
    devGate.chat = () => live.devChat.load();
    devLane.chat = () => live.devChat.load();
    devLane.open = () => live.open();
  }

  // signal, the engine and android, as the receive side reaches them
  final AppIo _io;
  // the hidden chats, as receiving sees them while their vault is shut
  final VaultRouter _router;
  // the pin entry, a new vault's file, the shade and the disk, as the
  // vault's life reaches them
  final VaultHost _host;

  // signalDecrypt lives outside this class but has to repaint the banners
  // when a peer's identity key changes.
  void keyChanged() => notifyListeners();

  // uids being processed right now, to dedup near-simultaneous arrivals
  // (preview re-send racing a manual retry) before the db write lands.
  final Set<String> _inflightUids = <String>{};
  // messages their sender took back, by sender and uid, with when. a
  // catch-up hands frames over in any order, and one that lands after its
  // unsend stays out
  final Map<String, int> _takenBack = {};
  static const _kTakenBackFor = Duration(days: 2);

  void _noteTakenBack(String sender, String uid) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _takenBack.remove('$sender $uid');
    _takenBack['$sender $uid'] = now;
    final cut = now - _kTakenBackFor.inMilliseconds;
    _takenBack.removeWhere((_, at) => at < cut);
    if (_takenBack.length > 1000) _takenBack.remove(_takenBack.keys.first);
  }

  bool _wasTakenBack(String sender, String uid) {
    final at = _takenBack['$sender $uid'];
    return at != null &&
        DateTime.now().millisecondsSinceEpoch - at <
            _kTakenBackFor.inMilliseconds;
  }

  // uids the drainer is mid-flight on, so a slow send isn't fired twice by
  // the next sweep.
  final Set<String> _outboxInflight = <String>{};
  // re-fire count per uid this session. caps the loop so an unreachable peer
  // stops grinding; tap-to-retry in the chat still forces a send.
  final Map<String, int> _outboxTries = <String, int>{};
  // earliest ms a uid may be tried again. every retry builds a fresh gift
  // wrap, so a flat cadence leaves one copy per attempt sitting on every
  // relay, and the receiver decrypts and acks all of them.
  final Map<String, int> _outboxNextAt = <String, int>{};

  // how many messages are sitting unsent, and for whom. the offline strip
  // reads this so it can say "2 waiting" instead of just "offline".
  _Queue _q = _Queue.none;
  // the open vault's, kept apart so they go the moment it closes
  _Queue _vq = _Queue.none;
  // counted off the everyday outbox, so a quiet session shows none of it
  int get queued => sessionQuiet ? 0 : _q.n + _vq.n;
  // of those, how many wait on a peer who has not added us back yet
  int get parkedQueued => sessionQuiet ? 0 : _q.parked + _vq.parked;
  int queuedFor(String haloId) =>
      sessionQuiet ? 0 : (_q.perPeer[haloId] ?? 0) + (_vq.perPeer[haloId] ?? 0);
  Timer? _outboxTimer;
  bool _outboxWasReady = false;

  // start the outbox drainer. safe to call more than once.
  void startOutboxDrain() {
    _outboxTimer?.cancel();
    _outboxTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (haloWiping) return;
      unawaited(drainOutbox());
    });
    _needTimer?.cancel();
    // the catch-up that comes with the start may not have begun yet
    _needRouteUp();
    _needTimer = Timer.periodic(const Duration(milliseconds: kNeedTickMs), (_) {
      if (haloWiping) return;
      unawaited(askForMissingSlices());
    });
  }

  Timer? _needTimer;
  // one pass at a time: a tick while an ask is still out waits for the next
  Future<void>? _askPass;
  // a walk may be bringing the missing slices, so asks wait for it
  final _needHold = CatchupHold();
  @visibleForTesting
  CatchupHold get needHoldForTest => _needHold;

  // read before the relays are asked again, so their catch-up counts
  void _needRouteUp() => _needHold.routeUp(
    DateTime.now().millisecondsSinceEpoch,
    engine.catchupState().$2,
  );

  // files that stopped arriving part way: ask each sender for what is
  // missing. quiet for a while first, so a catch-up still bringing slices
  // in is not mistaken for a loss. [walked]: the caller waited the catch-up
  // and its drain out itself.
  Future<void> askForMissingSlices({bool walked = false}) async {
    // a tick's pass may have held back for the walk the caller waited out
    while (walked && _askPass != null) {
      try {
        await _askPass;
      } catch (_) {
        // its own caller hears of it
      }
    }
    if (_askPass != null) return;
    final pass = _askPass = _askPassNow(walked);
    try {
      await pass;
    } finally {
      if (identical(_askPass, pass)) _askPass = null;
    }
  }

  Future<void> _askPassNow(bool walked) async {
    // an ask sent with no network still counts toward the cap
    if (!linkUp) {
      _needHold.down(DateTime.now().millisecondsSinceEpoch);
      return;
    }
    // the open vault's files too: while it is shut its wants wait in it
    final wants = <(HaloDb, List<Map<String, Object?>>)>[];
    for (final d in [live, ?_openVault]) {
      try {
        final ws = await d.mediaWants();
        if (ws.isNotEmpty) wants.add((d, ws));
      } catch (e) {
        if (identical(d, live)) rethrow;
      }
    }
    if (wants.isEmpty) return;
    final (active, begun) = engine.catchupState();
    final held = _needHold.look(
      now: DateTime.now().millisecondsSinceEpoch,
      active: active,
      begun: begun,
    );
    if (active > 0) return;
    // a check-in asks itself once its catch-up is in
    if (!walked && (held || _checking)) return;
    final heldAt = walked ? 0 : _needHold.heldAt;
    for (final (d, ws) in wants) {
      try {
        await _askForMissingIn(d, ws, heldAt);
      } catch (e) {
        if (identical(d, live)) rethrow;
      }
    }
  }

  Future<void> _askForMissingIn(
    HaloDb d,
    List<Map<String, Object?>> wants,
    int heldAt,
  ) async {
    for (final w in wants) {
      final mid = w['media_id'] as String;
      final peer = w['peer_id'] as String;
      final total = (w['total'] as num).toInt();
      final lastAt = (w['last_at'] as num).toInt();
      final askedAt = (w['asked_at'] as num).toInt();
      final asks = (w['asks'] as num).toInt();
      final now = DateTime.now().millisecondsSinceEpoch;
      // the row alone says whether it is due: most ticks read nothing more
      if (!askDue(
        now: now,
        lastSliceAt: lastAt,
        askedAt: askedAt,
        asks: asks,
        heldAt: heldAt,
      )) {
        continue;
      }
      if (await d.messageExists(mid)) {
        await d.dropMediaWant(mid);
        continue;
      }
      final have = await d.heldSlices(mid);
      final ask = shouldAskNow(
        now: now,
        lastSliceAt: lastAt,
        askedAt: askedAt,
        asks: asks,
        canResend: (w['can_resend'] as num).toInt() == 1,
        have: have.length,
        total: total,
        heldAt: heldAt,
      );
      if (!ask) continue;
      if (await d.isBlocked(peer)) continue;
      // a chat declined or deleted is asked nothing: the ask says this phone
      // is here, and the file it brings would put the chat back
      final c = await d.getContact(peer);
      if (c != null && c['archived'] == 1 && c['accepted'] == 0) {
        await d.dropMediaChunks(mid, from: peer);
        await d.dropMediaWant(mid);
        incomingMediaDone(d.container.chatKey(peer));
        continue;
      }
      final missing = missingSlices(have, total);
      if (missing.isEmpty) continue;
      dlog('NEED $mid: asking for ${missing.length} of $total');
      // stamped before it goes, with the time it was decided on: a send
      // takes seconds, and the tick its backoff ends on would miss it
      await d.markMediaAsked(mid, now);
      try {
        final wrapped = await wrapMessage(
          '',
          need: NeedFrame(mid, missing),
          sender: _mySender(),
        );
        await _sendOneEnvelope(peer, wrapped);
      } catch (e) {
        dlog('NEED $mid: ask failed: $e');
      }
    }
  }

  final Map<String, int> _needAnsweredAt = {};
  final Map<String, int> _needRounds = {};

  // the other side of it. the frame comes from outside and names a file to
  // read off this phone, so it is answered only for a row we sent, to the
  // one person it was sent to, a bounded number of times.
  Future<void> _answerNeed(String from, NeedFrame need, HaloDb db) async {
    final row = await db.sentMediaRow(need.mediaId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final ok =
        row != null &&
        resendAllowed(
          rowPeer: row['peer_id'] as String?,
          rowGroup: row['group_id'] as String?,
          rowDirection: row['direction'] as String?,
          requester: from,
          now: now,
          lastAnsweredAt: _needAnsweredAt[need.mediaId] ?? 0,
          rounds: _needRounds[need.mediaId] ?? 0,
        );
    if (!ok) {
      dlog('NEED ${need.mediaId}: not answered');
      return;
    }
    final filePath = row['file_path'] as String?;
    final mediaPath = row['media_path'] as String?;
    final isFile = filePath != null && filePath.isNotEmpty;
    final path = isFile ? filePath : mediaPath;
    if (path == null || path.isEmpty || !await File(path).exists()) return;
    final total = await mediaSliceCount(path);
    final only = answerable(need.indices, total);
    if (only.isEmpty) return;
    _needAnsweredAt[need.mediaId] = now;
    _needRounds[need.mediaId] = (_needRounds[need.mediaId] ?? 0) + 1;
    if (_needAnsweredAt.length > 200) {
      _needAnsweredAt.removeWhere((_, t) => now - t > 86400000);
    }
    dlog('NEED ${need.mediaId}: resending ${only.length} of $total');
    unawaited(
      _drainMedia(
        row,
        from,
        need.mediaId,
        path,
        isFile: isFile,
        only: only,
        on: db,
      ),
    );
  }

  // re-send anything the wire never confirmed. cheap when there's nothing to
  // do (one indexed query). skipped entirely while tor can't carry traffic.
  Future<void> drainOutbox() async {
    // count first, wire or no wire: the strip and the rows say what is
    // waiting whether or not anything can move yet
    final rows = await live.unsentOutbox();
    final q = await _queueOf(rows, live);
    // the open vault's rows go while it is open. shut, they wait in it for
    // the next open
    final v = _openVault;
    var vRows = const <Map<String, Object?>>[];
    var vq = _Queue.none;
    if (v != null) {
      try {
        vRows = await v.unsentOutbox();
        vq = await _queueOf(vRows, v);
      } catch (e) {
        vRows = const [];
      }
    }
    if (!identical(_openVault, v)) {
      vRows = const [];
      vq = _Queue.none;
    }
    if (!q.same(_q) || !vq.same(_vq)) {
      _q = q;
      _vq = vq;
      notifyListeners();
    }
    // torReady already knows the mode: outside onion there is nothing to
    // wait for and a queued message should just go. with no network a try
    // only uses up the cap
    final ready = linkUp;
    if (!ready) {
      _outboxWasReady = false;
      return;
    }
    _outboxWasReady = true;
    unawaited(_drainEdits());
    unawaited(_drainPins());
    unawaited(_drainFrames());
    unawaited(_drainGroupCtl());
    unawaited(_drainGroupOwed());
    if (rows.isEmpty && vRows.isEmpty) {
      if (_outboxTries.isNotEmpty) {
        _outboxTries.clear();
        _outboxNextAt.clear();
      }
      return;
    }
    // anything that landed since the last sweep stops costing us bookkeeping.
    final waiting = {
      for (final r in [...rows, ...vRows]) r['msg_uid'] as String?,
    };
    _outboxTries.removeWhere((k, _) => !waiting.contains(k));
    _outboxNextAt.removeWhere((k, _) => !waiting.contains(k));
    for (final (r, d, paired) in [
      for (final r in rows) (r, live, q.paired),
      if (v != null)
        for (final r in vRows) (r, v, vq.paired),
    ]) {
      final uid = r['msg_uid'] as String?;
      if (uid == null || _outboxInflight.contains(uid)) continue;
      // a send fired seconds ago still has its own future running; leave it be.
      final age = DateTime.now().millisecondsSinceEpoch - (r['sent_at'] as int);
      if (age < 45000) continue;
      final tries = _outboxTries[uid] ?? 0;
      // the cap is for a route that exists and fails. a peer who has not
      // added us back yet keeps their rows going at the ten-minute gap.
      if (tries >= 8) {
        final peer = r['peer_id'] as String?;
        if (peer == null || (paired[peer] ?? true)) continue;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final nextAt = _outboxNextAt[uid];
      if (nextAt != null && now < nextAt) continue;
      // doubling gap, capped at ten minutes: eight tries cover about an hour
      // and leave few copies on the relays
      var gap = 45000 << tries;
      if (gap > 600000) gap = 600000;
      _outboxNextAt[uid] = now + gap;
      _outboxTries[uid] = tries + 1;
      _outboxInflight.add(uid);
      unawaited(
        _drainOne(r, d).whenComplete(() => _outboxInflight.remove(uid)),
      );
    }
  }

  // what one container's unsent rows come to
  Future<_Queue> _queueOf(List<Map<String, Object?>> rows, HaloDb d) async {
    final perPeer = <String, int>{};
    final paired = <String, bool>{};
    var parked = 0;
    for (final r in rows) {
      final to = r['peer_id'] as String?;
      if (to != null) perPeer[to] = (perPeer[to] ?? 0) + 1;
      // a row for someone who has not added us back is waiting on them,
      // not on the wire. the strip says which.
      final g = r['group_id'] as String?;
      if (to != null && (g == null || g.isEmpty)) {
        paired[to] ??= await d.isBackPaired(to);
        if (!paired[to]!) parked++;
      }
    }
    return _Queue(rows.length, parked, perPeer, paired);
  }

  // one attempt per edit per pass, oldest first. the chat sends an edit
  // the moment it is made; this is for the ones that did not get through.
  final Set<String> _editsInflight = {};
  Future<void> _drainEdits() async {
    for (final d in [live, ?_openVault]) {
      final List<Map<String, Object?>> rows;
      try {
        rows = await d.unsentEdits();
      } catch (e) {
        // the vault closed part way: its edits wait for the next open
        continue;
      }
      for (final r in rows) {
        final uid = r['msg_uid'] as String;
        final age = DateTime.now().millisecondsSinceEpoch - (r['at'] as int);
        if (age < 45000 || _editsInflight.contains(uid)) continue;
        _editsInflight.add(uid);
        unawaited(
          sendEdit(
            r['peer_id'] as String,
            uid,
            r['new_text'] as String,
            on: d,
          ).whenComplete(() => _editsInflight.remove(uid)),
        );
      }
    }
  }

  final Set<String> _pinsInflight = {};
  Future<void> _drainPins() async {
    for (final d in [live, ?_openVault]) {
      final List<Map<String, Object?>> rows;
      try {
        rows = await d.unsentPins();
      } catch (e) {
        continue;
      }
      for (final r in rows) {
        final uid = r['msg_uid'] as String;
        final age = DateTime.now().millisecondsSinceEpoch - (r['at'] as int);
        if (age < 45000 || _pinsInflight.contains(uid)) continue;
        _pinsInflight.add(uid);
        unawaited(
          _sendPin(
            r['peer_id'] as String,
            uid,
            (r['pinned'] as int) == 1,
            on: d,
          ).whenComplete(() => _pinsInflight.remove(uid)),
        );
      }
    }
  }

  // pin or unpin in a 1:1 chat, for both of us. ours is written first; the
  // frame queues like an edit does, so it survives tor being down.
  Future<void> pinInChat(String peer, String uid, bool pinned) async {
    await session.setPinned(uid, pinned);
    await session.queuePin(uid, peer, pinned);
    notifyListeners();
    // a quiet session keeps it queued here: nothing leaves
    if (sessionQuiet) return;
    _pinsInflight.add(uid);
    unawaited(
      _sendPin(peer, uid, pinned).whenComplete(() => _pinsInflight.remove(uid)),
    );
  }

  Future<bool> _sendPin(
    String peer,
    String uid,
    bool pinned, {
    HaloDb? on,
  }) async {
    try {
      final wrapped = await wrapMessage(
        '',
        pin: PinFrame(targetUid: uid, pinned: pinned),
        sender: _mySender(),
      );
      final ok = await _sendOneEnvelope(peer, wrapped);
      if (ok) await (on ?? _ownerOf(peer)).dropPin(uid, pinned);
      return ok;
    } catch (e) {
      dlog('pin: $uid still stuck ($e)');
      return false;
    }
  }

  final Set<String> _framesInflight = {};
  Future<void> _drainFrames() async {
    for (final d in [live, ?_openVault]) {
      final List<Map<String, Object?>> rows;
      try {
        rows = await d.unsentFrames();
      } catch (e) {
        continue;
      }
      for (final r in rows) {
        final uid = r['msg_uid'] as String;
        final kind = r['kind'] as String;
        final age = DateTime.now().millisecondsSinceEpoch - (r['at'] as int);
        if (age < 45000 || !_framesInflight.add('$kind $uid')) continue;
        unawaited(
          _sendFrame(
            r['peer_id'] as String,
            uid,
            kind,
            r['body'] as String,
            on: d,
          ).whenComplete(() => _framesInflight.remove('$kind $uid')),
        );
      }
    }
  }

  // take a message back in a 1:1 chat. queued first, so one taken back
  // offline still reaches them
  Future<void> unsendInChat(String peer, String uid) async {
    await session.queueUnsend(uid, peer);
    await _frameNow(peer, uid, kFrameUnsend, '');
  }

  // a reaction in a 1:1 chat, empty to take it off. queued like a pin
  Future<void> reactInChat(String peer, String uid, String emoji) async {
    await session.queueReaction(uid, peer, emoji);
    await _frameNow(peer, uid, kFrameReaction, emoji);
  }

  Future<void> _frameNow(
    String peer,
    String uid,
    String kind,
    String body,
  ) async {
    // a quiet session keeps it queued here: nothing leaves
    if (sessionQuiet) return;
    if (!_framesInflight.add('$kind $uid')) return;
    unawaited(
      _sendFrame(
        peer,
        uid,
        kind,
        body,
      ).whenComplete(() => _framesInflight.remove('$kind $uid')),
    );
  }

  Future<bool> _sendFrame(
    String peer,
    String uid,
    String kind,
    String body, {
    HaloDb? on,
  }) async {
    try {
      final wrapped = kind == kFrameUnsend
          ? await wrapMessage('', unsend: uid, sender: _mySender())
          : await wrapMessage(
              '',
              reaction: ReactionFrame(targetUid: uid, emoji: body),
              sender: _mySender(),
            );
      final ok = await _sendOneEnvelope(peer, wrapped);
      if (ok) await (on ?? _ownerOf(peer)).dropFrame(uid, kind, body);
      return ok;
    } catch (e) {
      dlog('$kind: $uid still stuck ($e)');
      return false;
    }
  }

  // the edit frame, through the same routes a message takes. true when a
  // route that reaches them took it; the queued row goes with it.
  // on is the container its queued row is in, the chat's when not given
  Future<bool> sendEdit(
    String peer,
    String uid,
    String newText, {
    HaloDb? on,
  }) async {
    try {
      final wrapped = await wrapMessage(
        '',
        edit: EditFrame(targetUid: uid, newText: newText),
        sender: _mySender(),
      );
      final ok = await _sendOneEnvelope(peer, wrapped);
      if (ok) await (on ?? _ownerOf(peer)).dropEdit(uid);
      return ok;
    } catch (e) {
      dlog('edit: $uid still stuck ($e)');
      return false;
    }
  }

  // d is the container the row is in
  Future<void> _drainOne(Map<String, Object?> r, HaloDb d) async {
    final uid = r['msg_uid'] as String;
    final peer = r['peer_id'] as String;
    final groupId = r['group_id'] as String?;
    // a photo or file that never finished goes through the shared chunked
    // sender, which remembers the slices that landed
    final mediaPath = r['media_path'] as String?;
    final filePath = r['file_path'] as String?;
    if (mediaPath != null || filePath != null) {
      if (groupId == null) {
        await _drainMedia(
          r,
          peer,
          uid,
          mediaPath ?? filePath!,
          isFile: mediaPath == null,
          on: d,
        );
      } else {
        await _drainGroupMedia(
          r,
          groupId,
          uid,
          mediaPath ?? filePath!,
          isFile: mediaPath == null,
          on: d,
        );
      }
      return;
    }
    try {
      // a stranger's opener rides its nonce again. a row with none is ground
      // now, or the far side drops the retry.
      var row = r;
      if (groupId == null &&
          redeliveryNeedsPow(r, backPaired: await d.isBackPaired(peer))) {
        powBusy.value = DateTime.now();
        final int nonce;
        try {
          nonce = await compute(_outboxGrind, r['plaintext'] as String);
        } finally {
          powBusy.value = null;
        }
        await d.setPowNonce(uid, nonce);
        row = {...r, 'pow_nonce': nonce};
      }
      final wrapped = await wrapRedelivery(
        row,
        sender: _mySender(),
        badge: await sharedBadge(),
      );
      if (groupId != null) {
        final to = await _othersIn(d, groupId);
        final missed = await _fanOut(d, groupId, to, wrapped);
        if (missed.length < to.length) {
          await d.markSent(uid);
          await _oweText(d, uid, groupId, to: to, missed: missed, first: true);
          notifyListeners();
        }
        return;
      }
      final ok = await _sendOneEnvelope(peer, wrapped);
      if (ok) {
        dlog('OUTBOX: redelivered $uid');
        await d.markSent(uid);
        await _lightBurn(r, uid, d);
        // an open chat reloads and drops the waiting line
        _bumpChatRev(peer);
        notifyListeners();
      }
    } catch (e) {
      dlog('OUTBOX: $uid still stuck ($e)');
    }
  }

  // a timed message's clock starts when it is actually sent, and the
  // outbox is sometimes the one that sends it
  Future<void> _lightBurn(Map<String, Object?> r, String uid, HaloDb d) async {
    final secs = (r['burn_secs'] as num?)?.toInt();
    if (secs == null || r['burn_at'] != null) return;
    await d.setMsgBurnAt(
      uid,
      DateTime.now().millisecondsSinceEpoch + secs * 1000,
    );
  }

  Future<void> _drainGroupMedia(
    Map<String, Object?> r,
    String groupId,
    String uid,
    String path, {
    required bool isFile,
    required HaloDb on,
  }) async {
    final f = File(path);
    if (!await f.exists()) return;
    final fileName = isFile ? r['file_name'] as String? : null;
    String res;
    try {
      res = await sendMediaToGroup(
        groupId,
        path,
        msgUid: uid,
        caption: (r['plaintext'] as String?) ?? '',
        fileName: fileName,
        voice: fileName == 'voice.wav',
        voiceDisguised: ((r['voice_disguised'] as int?) ?? 0) == 1,
        burnSeconds: (r['burn_secs'] as num?)?.toInt(),
      );
    } catch (e) {
      res = 'error: $e';
    }
    if (res == 'ok') {
      dlog('OUTBOX: group media redelivered $uid');
      await on.markSent(uid);
      await _lightBurn(r, uid, on);
      // an open group re-reads the row, as the 1:1 drainer has it
      _bumpChatRev('group:$groupId');
      notifyListeners();
    } else if (res != 'busy') {
      dlog('OUTBOX: group media $uid still stuck ($res)');
      // a bubble a busy retry left spinning settles into failed
      _bumpChatRev('group:$groupId');
    }
  }

  // what a group file's send left owed goes to the members that lack it,
  // only the slices they lack, once their wait is up. one pass at a time,
  // the open vault's after the everyday's. a shut vault's rows wait in it
  Future<void>? _owedPass;
  Future<void> _drainGroupOwed() =>
      _owedPass ??= _owedRound().whenComplete(() => _owedPass = null);

  @visibleForTesting
  Future<void> get owedPassForTest => _owedPass ?? Future<void>.value();

  Future<void> _owedRound() async {
    for (final d in [live, ?_openVault]) {
      // a quiet session sends nothing, and a wipe takes the rows with it
      if (haloWiping || sessionQuiet) return;
      try {
        await resendGroupOwed(
          d,
          now: DateTime.now().millisecondsSinceEpoch,
          send: (uid, groupId, have, total) =>
              _sendOwed(d, uid, groupId, have, total),
        );
      } catch (e) {
        dlog('GRP MEDIA owed: ${e.runtimeType}');
      }
    }
  }

  // one file again, to the members owed it. 'later' when the chat is not
  // where this pass found it, or the row is still the outbox's
  Future<String> _sendOwed(
    HaloDb d,
    String uid,
    String groupId,
    Map<String, Set<int>> have,
    int total,
  ) async {
    // a wipe or a quiet session that began during the pass starts nothing
    if (haloWiping || sessionQuiet) return 'error: quiet';
    if (!identical(_ownerOf(groupId), d)) return 'later';
    final r = await d.sentMediaRow(uid);
    if (r == null || r['direction'] != 'out' || r['group_id'] != groupId) {
      return 'gone';
    }
    if ((r['sent'] as int? ?? 1) == 0) return 'later';
    final mediaPath = r['media_path'] as String?;
    final path = mediaPath ?? r['file_path'] as String?;
    if (path == null) return _sendOwedText(d, r, uid, groupId, have.keys);
    if (path.isEmpty || !await File(path).exists()) return 'gone';
    final members = await d.getGroupMembers(groupId);
    await d.keepGroupOwedTo(groupId, members);
    final to = [
      for (final m in have.keys)
        if (members.contains(m)) m,
    ];
    if (to.isEmpty) return 'gone';
    // the file is not the one their slices were of: all of it again
    final fresh = await mediaSliceCount(path) != total;
    final fileName = mediaPath == null ? r['file_name'] as String? : null;
    return sendMediaToGroup(
      groupId,
      path,
      msgUid: uid,
      caption: (r['plaintext'] as String?) ?? '',
      fileName: fileName,
      voice: fileName == 'voice.wav',
      voiceDisguised: ((r['voice_disguised'] as int?) ?? 0) == 1,
      burnSeconds: (r['burn_secs'] as num?)?.toInt(),
      owed: {for (final m in to) m: fresh ? <int>{} : have[m]!},
    );
  }

  // a text, a poll or a sticker again, to the members it missed
  Future<String> _sendOwedText(
    HaloDb d,
    Map<String, Object?> r,
    String uid,
    String groupId,
    Iterable<String> owed,
  ) async {
    final members = await d.getGroupMembers(groupId);
    await d.keepGroupOwedTo(groupId, members);
    final to = [
      for (final m in owed)
        if (members.contains(m)) m,
    ];
    if (to.isEmpty) return 'gone';
    final wrapped = await wrapRedelivery(
      r,
      sender: _mySender(),
      badge: await sharedBadge(),
    );
    final missed = await _fanOut(d, groupId, to, wrapped);
    await _oweText(d, uid, groupId, to: to, missed: missed, first: false);
    return missed.isEmpty ? 'ok' : 'error: ${missed.length} short';
  }

  // a group text, poll or sticker reads sent once a member has it. the
  // members it missed are owed it, as a file's are, and get it from the
  // outbox's tick
  Future<void> _oweText(
    HaloDb d,
    String uid,
    String groupId, {
    required List<String> to,
    required List<String> missed,
    required bool first,
  }) async {
    if (first && missed.isEmpty) return;
    try {
      await d.settleGroupOwed(
        uid,
        groupId,
        total: 1,
        tried: to,
        short: {for (final m in missed) m: <int>{}},
        sentTo: to.length,
        first: first,
        now: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      dlog('GRP $uid: owed not kept (${e.runtimeType})');
    }
    groupOwedTick.value++;
  }

  // a member's session just came up: the controls and messages they are
  // owed go now, not at the end of their wait
  Future<void> _owedDueFor(String member) async {
    var due = 0;
    var ctl = 0;
    for (final d in [live, ?_openVault]) {
      try {
        ctl += await d.groupCtlDueNow(member);
        due += await d.groupOwedDueNow(member);
      } catch (e) {
        dlog('GRP MEDIA owed: ${e.runtimeType}');
      }
    }
    if (ctl > 0) await _drainGroupCtl();
    if (due > 0 && torReady) await _drainGroupOwed();
  }

  @visibleForTesting
  Future<void> owedDueForTest(String member) => _owedDueFor(member);

  // ---- group controls, member by member ----

  // a lane is one group's controls to one member. they go in the order they
  // were made, the next once the one before went: an add or a message ahead
  // of the create that makes the group is dropped on the far side. one run
  // of a lane at a time; a lane asked for while it runs goes again after
  final Map<String, Future<bool>> _ctlLanes = {};
  final Set<String> _ctlLaneAgain = {};

  Future<void>? _ctlRound;

  @visibleForTesting
  Future<void> get ctlPassForTest async {
    await _ctlRound;
    while (_ctlLanes.isNotEmpty) {
      await Future.wait(_ctlLanes.values.toList());
    }
  }

  // every lane whose next control is due. a send that fails waits its turn
  // again, on the outbox's tick or when the member's session comes up
  Future<void> _drainGroupCtl() => _ctlRound = _ctlLanesDue();

  Future<void> _ctlLanesDue() async {
    for (final d in [live, ?_openVault]) {
      if (haloWiping || sessionQuiet) return;
      final List<Map<String, Object?>> rows;
      try {
        rows = await d.groupCtlOut();
      } catch (e) {
        continue;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final heads = <String, Map<String, Object?>>{};
      for (final r in rows) {
        heads.putIfAbsent('${r['group_id']} ${r['member']}', () => r);
      }
      for (final r in heads.values) {
        if ((r['next_at'] as int? ?? 0) > now) continue;
        unawaited(_ctlLane(d, r['group_id'] as String, r['member'] as String));
      }
    }
  }

  // true once [member] has every control of [groupId] queued for it.
  // [force] tries each one even while it waits, and costs none a try
  Future<bool> _ctlLane(
    HaloDb d,
    String groupId,
    String member, {
    bool force = false,
  }) {
    final key = '$groupId $member';
    final running = _ctlLanes[key];
    if (running != null) {
      _ctlLaneAgain.add(key);
      return running;
    }
    final run = _runCtlLane(d, groupId, member, force).whenComplete(() {
      _ctlLanes.remove(key);
      if (_ctlLaneAgain.remove(key)) unawaited(_ctlLane(d, groupId, member));
    });
    return _ctlLanes[key] = run;
  }

  Future<bool> _runCtlLane(
    HaloDb d,
    String groupId,
    String member,
    bool force,
  ) async {
    var sent = false;
    try {
      while (true) {
        // a wipe or a quiet session sends nothing more
        if (haloWiping || sessionQuiet) return false;
        final rows = await d.groupCtlFor(groupId, member);
        if (rows.isEmpty) break;
        final r = rows.first;
        final id = r['id'] as int;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (!force && (r['next_at'] as int? ?? 0) > now) return false;
        final gc = GroupControl.fromWire(_jsonOf(r['ctl']));
        // no longer theirs to get: the next one goes
        if (gc == null || !await _ctlStillOwed(d, groupId, member, gc)) {
          await d.dropGroupCtl(id);
          continue;
        }
        if ((r['tries'] as int? ?? 0) >= kGroupOwedTries) {
          // past its tries a create stays: the group is not there without
          // it, and what goes after would be dropped. it goes on a send of
          // ours to them, or when their session comes up
          if (gc.type != 'create') {
            await d.dropGroupCtl(id);
            continue;
          }
          if (!force) return false;
        }
        // only a pass on the lane's own schedule costs a try. one a send
        // forces is free, or a busy group would spend them in hours.
        // stamped before it goes, so a send cut short is not a free retry
        if (!force) await d.triedGroupCtl(id, now);
        final wrapped = await wrapMessage(
          '',
          groupId: groupId,
          groupControl: gc,
          sender: _mySender(),
        );
        if (!await _sendGroupEnvelope(groupId, member, wrapped)) {
          dlog('group ctl ${gc.type} to $member: waits');
          return false;
        }
        await d.dropGroupCtl(id);
        sent = true;
      }
    } catch (e) {
      dlog('group ctl: ${e.runtimeType}');
      return false;
    }
    // what was held back behind the controls goes now
    if (sent) {
      try {
        if (await d.groupOwedDueNow(member) > 0) unawaited(_drainGroupOwed());
      } catch (e) {
        dlog('GRP owed: ${e.runtimeType}');
      }
    }
    return true;
  }

  static Object? _jsonOf(Object? raw) {
    if (raw is! String) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  // a leave goes once the group went from here; a remove to the member it
  // takes out too; anything else only to a member of a group still here
  Future<bool> _ctlStillOwed(
    HaloDb d,
    String groupId,
    String member,
    GroupControl gc,
  ) async {
    final here = await d.groupExists(groupId);
    if (gc.type == 'leave') return !here;
    if (!here) return false;
    if ((await d.getGroupMembers(groupId)).contains(member)) return true;
    return gc.type == 'remove' && (gc.members?.contains(member) ?? false);
  }

  // everyone a group frame of ours goes to. in a room this phone is its
  // room key, which takes none
  Future<List<String>> _othersIn(
    HaloDb d,
    String groupId, [
    List<String>? members,
  ]) async {
    final room = await _roomOf(groupId, d);
    return [
      for (final m in members ?? await d.getGroupMembers(groupId))
        if (m != myId && m != room?.pub) m,
    ];
  }

  // one group message to [to], the members it missed back. a member still
  // to get a control of the group gets that first, and is missed while it
  // cannot
  Future<List<String>> _fanOut(
    HaloDb d,
    String groupId,
    List<String> to,
    String wrapped,
  ) async {
    final waiting = await d.groupCtlWaiting(groupId);
    Future<bool> one(String m) async {
      if (waiting.contains(m) && !await _ctlLane(d, groupId, m, force: true)) {
        return false;
      }
      return _sendGroupEnvelope(groupId, m, wrapped);
    }

    final ok = await Future.wait([for (final m in to) one(m)]);
    return [
      for (final (i, m) in to.indexed)
        if (!ok[i]) m,
    ];
  }

  // [gc] to each of [to], or everyone else in the group, through the lanes.
  // kept until it goes: the route can be down, or tor still starting
  Future<void> _queueControl(
    String groupId,
    GroupControl gc, {
    List<String>? to,
    HaloDb? on,
  }) async {
    final d = on ?? _ownerOf(groupId);
    await d.queueGroupCtl(
      groupId,
      await _othersIn(d, groupId, to),
      gc,
      now: DateTime.now().millisecondsSinceEpoch,
    );
    // the first try goes now, whatever the route says
    if (!haloWiping && !sessionQuiet) unawaited(_drainGroupCtl());
  }

  Future<void> _drainMedia(
    Map<String, Object?> r,
    String peer,
    String uid,
    String path, {
    required bool isFile,
    Set<int>? only,
    HaloDb? on,
  }) async {
    final f = File(path);
    if (!await f.exists()) return;
    // the container the row is in: the vault's rows reach its people
    final d = on ?? live;
    final contact = await d.getContact(peer);
    if (contact == null) return;
    final backPaired = await d.isBackPaired(peer);
    final fileName = isFile ? r['file_name'] as String? : null;
    final res = await sendChunkedMediaTo(
      peerId: peer,
      peerOnion: (contact['onion'] as String?) ?? '',
      peerXPub: contact['xpub'] as String?,
      backPaired: backPaired,
      needPow: !backPaired,
      path: path,
      msgUid: uid,
      caption: (r['plaintext'] as String?) ?? '',
      fileName: fileName,
      voice: fileName == 'voice.wav',
      voiceDisguised: ((r['voice_disguised'] as int?) ?? 0) == 1,
      burnSeconds: (r['burn_secs'] as num?)?.toInt(),
      secure: ((r['secure'] as int?) ?? 0) == 1,
      replyTo: r['reply_to'] as String?,
      sender: _mySender(),
      only: only,
      progressKey: d.container.chatKey(peer),
    );
    if (only != null) {
      dlog('NEED $uid: resend ended $res');
      return;
    }
    if (res == 'ok') {
      dlog('OUTBOX: media redelivered $uid');
      await d.markSent(uid);
      await _lightBurn(r, uid, d);
      _bumpChatRev(peer);
      notifyListeners();
    } else if (res != 'busy') {
      dlog('OUTBOX: media $uid still stuck ($res)');
      // an open chat re-reads the row, so a bubble left spinning by a
      // busy tap-to-retry settles into failed or waiting
      _bumpChatRev(peer);
    }
  }

  // send-privacy mode: 'private' | 'balanced' | 'fast'. private is tor and
  // is the default; 'normal' is an old name for it, migrated on load.
  String _sendMode = 'private';
  String get sendMode => _sendMode;
  @visibleForTesting
  set sendModeForTest(String m) => _sendMode = m;

  // the open session's own, like everything a screen sets for an identity
  Future<void> saveGhostPref(bool on, int secs) async {
    const s = secureStore;
    final c = session.container;
    await s.write(key: c.key('ghost_on'), value: on ? '1' : '0');
    await s.write(key: c.key('ghost_secs'), value: '$secs');
  }

  Future<(bool, int)> loadGhostPref() async {
    const s = secureStore;
    final c = session.container;
    final on = (await s.read(key: c.key('ghost_on'))) == '1';
    final secs =
        int.tryParse(await s.read(key: c.key('ghost_secs')) ?? '') ?? 300;
    return (on, secs);
  }

  Future<bool> loadDisguisePref() async {
    const s = secureStore;
    return (await s.read(key: session.container.key('disguise_on'))) == '1';
  }

  Future<void> saveDisguisePref(bool on) async {
    const s = secureStore;
    await s.write(
      key: session.container.key('disguise_on'),
      value: on ? '1' : '0',
    );
  }

  // the handle we claimed, if any. local only: the registry is the source
  // of truth and this is just so the screen knows what to show.
  String? _myHandle;
  String? get myHandle => sessionQuiet ? null : _myHandle;

  // the avatar someone picked, or null for the one their id produces. local
  // only: it is drawn from a number on every device that has the number, and
  // what they picked for themselves is nobody else's business.
  int? _myAvatar;
  int? _quietAvatar;
  int? get myAvatar => sessionQuiet ? _quietAvatar : _myAvatar;

  Future<void> loadMyAvatar() async {
    final v = await secureStore.read(key: 'my_avatar');
    _myAvatar = v == null ? null : int.tryParse(v);
    notifyListeners();
  }

  Future<void> setMyAvatar(int? v) async {
    sessionQuiet ? _quietAvatar = v : _myAvatar = v;
    final st = secureStore;
    final k = session.container.key('my_avatar');
    if (v == null) {
      await st.delete(key: k);
    } else {
      await st.write(key: k, value: '$v');
    }
    notifyListeners();
  }

  Future<void> loadMyHandle() async {
    const st = secureStore;
    _myHandle = await st.read(key: 'my_handle');
    _handleListed = (await st.read(key: 'my_handle_listed')) == '1';
    _handleName = await st.read(key: 'my_handle_name') ?? '';
    notifyListeners();
  }

  // a handle and being findable are separate: the registry's search shows
  // only handles whose owner asked, under a name they chose. off until then.
  bool _handleListed = false;
  String _handleName = '';
  bool get handleListed => !sessionQuiet && _handleListed;
  String get handleName => sessionQuiet ? '' : _handleName;

  Future<String> setHandleListing(bool on, {String name = ''}) async {
    final h = _myHandle;
    if (h == null || sessionQuiet) return 'error: no handle';
    final n = on ? name.trim() : '';
    final r = await engine.handleListing(h, on, n);
    if (r != 'ok') return r;
    _handleListed = on;
    _handleName = n;
    const st = secureStore;
    await st.write(key: 'my_handle_listed', value: on ? '1' : '0');
    await st.write(key: 'my_handle_name', value: n);
    notifyListeners();
    return r;
  }

  // the published invite is static; a phone whose invite changed since the
  // registry last took it claims again, once per run, only once the onion
  // and the first-contact counter are loaded, and at a random moment rather
  // than with the rest of start's traffic.
  bool _fcLoaded = false;
  bool _repointed = false;
  void _maybeRepoint() {
    if (_repointed || _myHandle == null) return;
    if (myOnion.isEmpty || !_fcLoaded) return;
    _repointed = true;
    Timer(repointDelay(Random.secure()), () => unawaited(_repointHandle()));
  }

  late final _handleRepoint = HandleRepoint(
    invite: () => buildHaloUriV3(myId, myOnion, _fcCounter),
    claim: (h, invite, bio) => engine.handleClaim(h, invite, bio),
    lookup: (url) => engine.torGetJson(url),
    myKey: () => engine.myEdPubkey(),
    read: (k) => secureStore.read(key: k),
    write: (k, v) => v == null
        ? secureStore.delete(key: k)
        : secureStore.write(key: k, value: v),
  );

  // [invite] is the one the registry just took for [h]
  Future<void> setMyHandle(String? h, {String bio = '', String? invite}) async {
    _myHandle = h;
    _handleForeign = false;
    final st = secureStore;
    if (h == null) {
      await _handleRepoint.forget();
      await st.delete(key: 'my_handle');
      await st.delete(key: 'my_handle_bio');
      // a released handle is gone from search with the rest of it
      await st.delete(key: 'my_handle_listed');
      await st.delete(key: 'my_handle_name');
      _handleListed = false;
      _handleName = '';
    } else {
      await st.write(key: 'my_handle', value: h);
      // kept so a republish carries the same bio rather than a blank one
      await st.write(key: 'my_handle_bio', value: bio);
      if (invite != null) await _handleRepoint.claimed(h, invite);
    }
    notifyListeners();
  }

  Future<void> loadSendMode() async {
    final stored = await secureStore.read(key: 'send_mode') ?? 'private';
    // fast is off after every reinstall: its marker lives in app data, which
    // an uninstall wipes, while the preference can come back from a backup
    final marker = await _fastMarker;
    _sendMode = sendModeAtBoot(stored, fastMarker: await marker.exists());
    if (_sendMode != stored) {
      await secureStore.write(key: 'send_mode', value: _sendMode);
    }
    notifyListeners();
  }

  Future<File> get _fastMarker async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/fast_ok');
  }

  Future<bool> fastConfirmedOnThisInstall() =>
      _fastMarker.then((f) => f.exists());

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
        // our relay's clearnet name rides along, dialled over tor like the
        // rest, since a friend in relay mode publishes only there
        return 'ws://z4waup3c6j6gknkjba72cqjjuffhgg6gtgqfu3vetzcvgoluvr42srid'
            '.onion,$_clearnetRelay,$_publicRelays';
    }
  }

  // one switch at a time: two quick taps must not leave the engine in one
  // mode with the other mode's relay list
  Future<void> _modeQueue = Future.value();

  Future<void> setSendMode(String m) {
    final run = _modeQueue.then((_) => _switchSendMode(m));
    _modeQueue = run.catchError((Object e) => dlog('mode: $e'));
    return run;
  }

  Future<void> _switchSendMode(String m) async {
    final changed = _sendMode != m;
    _sendMode = m;
    notifyListeners();
    await secureStore.write(key: 'send_mode', value: m);
    if (m == 'fast') {
      try {
        await (await _fastMarker).writeAsString('1');
      } catch (e) {
        dlog('fast marker: $e');
      }
    }
    if (!changed) return;
    // an outage seen on another mode is not this one's
    _relayDownSince = null;
    _fastHintShown = false;
    _newTorTry();
    // the engine caches one http client per route, so the mode has to land
    // before the relay list is rebuilt or the first connection uses the old
    // one. the list is in place before anything subscribes: each runner
    // copies it once, as it starts
    engine.setTransportMode(m);
    engine.nostrInit(relaysFor(m));
    await resubscribe();
    // the first-contact runner keeps the relay list it started with; it
    // has to follow the switch or strangers' openers go unread
    if (_fcLoaded) engine.subscribeFirstContactBg(_fcCounter);
    dlog('mode: $m, relays rebuilt');
  }

  // every key listened on, never the screen's list, on the relays of a new
  // mode: a runner left alone keeps the old mode's relays and route until
  // the app restarts. the dev chat's lane is its own, and only once it has
  // started
  @visibleForTesting
  Future<void> resubscribe() async {
    // rooms first and on their own, as at boot: a runner keeps the relays it
    // started with, and a contact that hangs must not leave a room on the
    // old ones
    try {
      await _listenToRooms();
    } catch (e) {
      dlog('rooms: not listened to again ($e)');
    }
    // whoever boot listens for, then whoever was listened for since: a
    // stranger who back-paired, a card filed in the vault, a chat deleted
    // while its runner lives on. once each
    final done = await _listenKnown();
    for (final e in _xPubToHaloId.entries.toList()) {
      if (done.contains(e.key) || isDevId(e.value) || devIdClaim(e.key)) {
        continue;
      }
      _io.listen(e.key);
    }
    await subscribeDevLane();
  }

  static const _platformChannel = MethodChannel('halo/platform');
  // the switch as saved, and as applied at this start. the flag is only
  // set at boot: changing it live recreates the window's surface, which
  // flashes.
  bool _blockScreenshots = false;
  bool get blockScreenshots => _blockScreenshots;
  bool _blockScreenshotsApplied = false;
  bool get blockScreenshotsApplied => _blockScreenshotsApplied;
  bool get blockScreenshotsPending =>
      _blockScreenshots != _blockScreenshotsApplied;

  // the heartbeat. listen is the last tick the relay queue was read, drain
  // the last time something came out of it. written once a minute, so after
  // a kill the transport screen can still say when this phone last listened.
  int _lastListenAt = 0;
  int _lastDrainAt = 0;
  int _beatWritten = 0;
  // every stretch of five minutes or more with no heartbeat, newest last,
  // as "from-to" pairs. a night's sleep shows up here as its gaps, and a
  // kill shows up as the gap between the last beat and the next boot
  final List<String> _gaps = [];
  // how many times the fifteen-minute job knocked, and when it last did
  int _jobRuns = 0;
  int _lastJobAt = 0;
  // since when the relay poll has ticked with no sleep in between
  int _awakeSince = 0;

  void _beat() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_awakeSince == 0 || now - _lastListenAt > kPollStallMs) {
      _awakeSince = now;
    }
    if (_lastListenAt > 0 && now - _lastListenAt > 5 * 60 * 1000) {
      _gaps.add('$_lastListenAt-$now');
      while (_gaps.length > 24) {
        _gaps.removeAt(0);
      }
      dlog('heartbeat: gap of ${(now - _lastListenAt) ~/ 60000}m');
      unawaited(_writeBeat());
    }
    _lastListenAt = now;
    if (now - _beatWritten > 60000) {
      _beatWritten = now;
      unawaited(_writeBeat());
    }
  }

  void noteJobRun() {
    _jobRuns++;
    _lastJobAt = DateTime.now().millisecondsSinceEpoch;
    unawaited(_writeBeat());
  }

  void _noteDrain() {
    _lastDrainAt = DateTime.now().millisecondsSinceEpoch;
    unawaited(_writeBeat());
  }

  Future<void> _writeBeat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('hb.listen', _lastListenAt);
      await prefs.setInt('hb.drain', _lastDrainAt);
      await prefs.setStringList('hb.gaps', _gaps);
      await prefs.setInt('hb.jobs', _jobRuns);
      await prefs.setInt('hb.jobAt', _lastJobAt);
    } catch (_) {
      // a record only: a miss reads as an older time
    }
  }

  // debug only: what is being held, every ten minutes, so a night's growth
  // shows up in the log with a shape rather than a single number at the end
  void startMemoryLog() {
    if (!kDebugMode) return;
    Timer.periodic(const Duration(minutes: 10), (_) {
      final m = engine.memStats();
      dlog(
        'MEM rss=${ProcessInfo.currentRss ~/ 1048576}mb '
        'go heap=${((m['heapAlloc'] as num?) ?? 0) ~/ 1048576}mb '
        'sys=${((m['sys'] as num?) ?? 0) ~/ 1048576}mb '
        'goroutines=${m['goroutines']} inbox=${m['inbox']} subs=${m['subs']} '
        'sent=${m['sentIds']} imgcache=${PaintingBinding.instance.imageCache.currentSizeBytes ~/ 1048576}mb',
      );
    });
  }

  Future<void> loadHeartbeat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastListenAt = prefs.getInt('hb.listen') ?? 0;
      _lastDrainAt = prefs.getInt('hb.drain') ?? 0;
      _gaps
        ..clear()
        ..addAll(prefs.getStringList('hb.gaps') ?? const []);
      _jobRuns = prefs.getInt('hb.jobs') ?? 0;
      _lastJobAt = prefs.getInt('hb.jobAt') ?? 0;
    } catch (_) {
      // unread, it starts from nothing, as on a first run
    }
  }

  // wipes the night's record so a new test starts clean
  Future<void> clearHeartbeatHistory() async {
    _gaps.clear();
    _jobRuns = 0;
    _lastJobAt = 0;
    await _writeBeat();
  }

  // ---- how messages arrive ----

  DeliveryMode _deliveryMode = DeliveryMode.always;
  DeliveryMode get deliveryMode => _deliveryMode;
  @visibleForTesting
  set deliveryModeForTest(DeliveryMode m) => _deliveryMode = m;
  String _docsPath = '';
  // tor is down because this side took it down
  bool _torHeld = false;
  bool get torHeld => _torHeld;
  bool _checking = false;
  bool get checkingIn => _checking;
  bool _inFront = false;
  Timer? _sleepTimer;
  Timer? _wakeAgain;
  int _lastCheckAt = 0;
  int _lastWakeAt = 0;
  // how the last check-in ended, for the transport screen, including one
  // that gave up
  String _lastCheckHow = '';
  // "relay.example 4.1s · other.example 30.0s dropped"
  String _lastCheckRelays = '';
  int _lastCheckTriedAt = 0;

  // what the screens are shown of all that: everything, or in a decoy
  // session only what happened since it opened, as a Kryfo just set up
  // would show
  int _quietSince = 0;
  int _quietJobs = 0;
  // a decoy with no opening time noted shows nothing from before
  bool _beforeQuiet(int at) =>
      sessionQuiet && (_quietSince <= 0 || at < _quietSince);
  int _since(int at) => _beforeQuiet(at) ? 0 : at;
  int get lastListenAt => _since(_lastListenAt);
  // a decoy never receives a message
  int get lastDrainAt => sessionQuiet ? 0 : _lastDrainAt;
  int get lastJobAt => _since(_lastJobAt);
  int get lastCheckAt => _since(_lastCheckAt);
  int get lastWakeAt => _since(_lastWakeAt);
  int get lastCheckTriedAt => _since(_lastCheckTriedAt);
  int get jobRuns => !sessionQuiet
      ? _jobRuns
      : _quietSince <= 0
      ? 0
      : max(0, _jobRuns - _quietJobs);
  String get lastCheckHow =>
      _since(_lastCheckTriedAt) == 0 && sessionQuiet ? '' : _lastCheckHow;
  // the catch-up counts the identity's subscriptions and events: a decoy
  // has neither
  String get lastCheckRelays => sessionQuiet ? '' : _lastCheckRelays;
  List<String> get gaps => sessionQuiet
      ? [
          for (final g in _gaps)
            if (!_beforeQuiet(int.tryParse(g.split('-').first) ?? 0)) g,
        ]
      : _gaps;

  // when an arrival was last sealed for the hidden chats, in this process
  int _lastSealAt = 0;

  // with hidden chats shut, a relay time at or before the newest sealed
  // arrival may be that arrival
  bool _maySealedAt(int atMs) =>
      _openVault == null &&
      _lastSealAt > 0 &&
      _lastSealAt >= _lastDrainAt &&
      atMs <= _lastSealAt + 1000;

  /// what the transport screen shows of the engine's traffic [tx]: in a
  /// decoy its own, which is nothing, as on a new install. with hidden
  /// chats shut nothing of theirs counts: not their subscriptions, and not
  /// an arrival sealed for them, which shows the last one the app showed
  ({int subs, int secsSinceRecv, int secsSinceSend}) shownTraffic(
    Map<String, dynamic> tx,
  ) {
    if (sessionQuiet) return (subs: 0, secsSinceRecv: -1, secsSinceSend: -1);
    final subs = tx['sub_count'] as int? ?? 0;
    final rx = tx['secs_since_recv'] as int? ?? -1;
    final sx = tx['secs_since_send'] as int? ?? -1;
    if (_openVault != null) {
      return (subs: subs, secsSinceRecv: rx, secsSinceSend: sx);
    }
    final hidden = _router.listenFor.keys.toSet();
    final listed = tx['subs'];
    final hiddenSubs = listed is List
        ? listed.where(hidden.contains).length
        : hidden.length;
    final now = DateTime.now().millisecondsSinceEpoch;
    final shownRx = rx >= 0 && _maySealedAt(now - rx * 1000)
        ? (_lastDrainAt <= 0 ? -1 : max(0, (now - _lastDrainAt) ~/ 1000))
        : rx;
    return (
      subs: max(0, subs - hiddenSubs),
      secsSinceRecv: shownRx,
      secsSinceSend: sx,
    );
  }

  /// when the newest relay event reached this phone, in unix seconds from
  /// the engine's [mem], as the transport screen shows it: never in a
  /// decoy, and never an arrival sealed for hidden chats that are shut
  int shownRelayIn(Map<String, dynamic> mem) {
    if (sessionQuiet) return 0;
    final at = (mem['lastEvRecv'] as num?)?.toInt() ?? 0;
    if (at > 0 && _maySealedAt(at * 1000)) return _lastDrainAt ~/ 1000;
    return at;
  }

  // the nudge. nothing vendor-specific is read: while kryfo is supposed to
  // be staying connected it writes the time every few minutes, and a start
  // that finds that time long past, on a phone that was not switched off in
  // between, was a kill. three in a day and the card is offered, once ever.
  bool _nudgeDue = false;
  bool get nudgeDue => !sessionQuiet && _nudgeDue;
  Timer? _beatTimer;

  Future<void> _judgeLastRun() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final booted =
          await _platformChannel.invokeMethod<int>('bootedAtMs') ?? 0;
      final v = judgeRestart(
        nowMs: DateTime.now().millisecondsSinceEpoch,
        lastBeatMs: prefs.getInt(kHeartbeatKey) ?? 0,
        bootedAtMs: booted,
        kills: prefs.getStringList(kKillsKey)?.map(int.parse).toList() ?? [],
        nudgeShown: prefs.getBool(kNudgeShownKey) ?? false,
        mode: _deliveryMode,
      );
      if (v.wasKill) {
        dlog('delivery: this phone stopped kryfo, ${v.kills.length} today');
        await prefs.setStringList(kKillsKey, v.kills.map((k) => '$k').toList());
      }
      _nudgeDue = v.showNudge;
    } catch (e) {
      dlog('delivery: could not judge the last run: $e');
    }
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _beatTimer?.cancel();
    if (_deliveryMode != DeliveryMode.always) return;
    unawaited(_writeDeliveryBeat());
    _beatTimer = Timer.periodic(
      const Duration(milliseconds: kHeartbeatEveryMs),
      (_) => unawaited(_writeDeliveryBeat()),
    );
  }

  Future<void> _writeDeliveryBeat() async {
    if (haloWiping) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kHeartbeatKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // the next beat writes it again
    }
  }

  /// the card was offered. never again, whatever the answer.
  Future<void> nudgeAnswered() async {
    _nudgeDue = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kNudgeShownKey, true);
    } catch (_) {
      // at worst the card is offered once more
    }
    notifyListeners();
  }

  Future<void> _loadDeliveryTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastCheckAt = prefs.getInt(kLastCheckKey) ?? 0;
      _lastWakeAt = prefs.getInt(kLastWakeKey) ?? 0;
      _lastCheckHow = prefs.getString(kLastCheckHowKey) ?? '';
      _lastCheckRelays = prefs.getString(kLastCheckRelaysKey) ?? '';
      _lastCheckTriedAt = prefs.getInt(kLastCheckTriedKey) ?? 0;
    } catch (_) {
      // shown on screen only: unread, it starts empty
    }
  }

  // the 15-minute job runs in its own isolate and writes these to prefs,
  // which this process never sees. the transport screen calls this when it
  // opens so what is on it came from disk, not from memory.
  Future<void> refreshFromDisk() async {
    // SharedPreferences keeps an in-memory cache per isolate, filled once
    try {
      await (await SharedPreferences.getInstance()).reload();
    } catch (_) {
      // the screen shows what this process already had
    }
    await loadHeartbeat();
    await _loadDeliveryTimes();
    notifyListeners();
  }

  // who took how long on the last catch-up, by relay host, no content. kept
  // as data and worded when shown (catchupLine), so it reads in whatever
  // language the app is in by then.
  String _relayCatchupData() {
    try {
      final rs = (engine.transportState()['relays'] as List?) ?? const [];
      final out = <Map<String, Object>>[];
      for (final r in rs) {
        final m = r as Map;
        if (m['catchup_seen'] != true) continue;
        final host = (m['url'] as String? ?? '')
            .replaceFirst(RegExp(r'^wss?://'), '')
            .split('/')
            .first;
        out.add({
          'host': host,
          'ms': m['catchup_ms'] as int? ?? 0,
          'long': m['catchup_long'] == true,
          'dropped': m['catchup_dropped'] == true,
          'connect_ms': m['connect_ms'] as int? ?? 0,
          'pages': m['catchup_pages'] as int? ?? 0,
          'events': m['catchup_events'] as int? ?? 0,
          'subs': m['catchup_subs'] as int? ?? 0,
          'held': m['catchup_subs_dropped'] as int? ?? 0,
        });
      }
      return out.isEmpty ? '' : jsonEncode(out);
    } catch (_) {
      return '';
    }
  }

  // the language changed: the notification channel's name and the service's
  // own notification are android's, and are told again. the chat list's
  // previews ("you: ...") were worded when the list was read, so it is read
  // again.
  Future<void> languageChanged() async {
    unawaited(refreshContacts());
    unawaited(refreshGroups());
    try {
      await nameNotificationChannel();
      if (!kIsWeb && Platform.isAndroid) {
        await _platformChannel.invokeMethod('applyDeliveryMode');
      }
    } catch (e) {
      dlog('language: android side not told: $e');
    }
  }

  Future<void> setDeliveryMode(DeliveryMode m) async {
    if (m == _deliveryMode) return;
    _deliveryMode = m;
    await saveDeliveryMode(m);
    try {
      await _platformChannel.invokeMethod('applyDeliveryMode');
    } catch (e) {
      dlog('delivery: platform did not take the mode: $e');
    }
    if (m == DeliveryMode.always) {
      _sleepTimer?.cancel();
      await _torWake();
    } else if (!_inFront) {
      _scheduleSleep();
    }
    _startHeartbeat();
    notifyListeners();
  }

  // the window came to the front, or left it
  void appInFront(bool front) {
    _inFront = front;
    if (_deliveryMode == DeliveryMode.always) return;
    if (front) {
      _sleepTimer?.cancel();
      unawaited(_torWake());
    } else {
      _scheduleSleep();
    }
  }

  // tor goes down a while after the person leaves, not the moment they do:
  // a message just sent has to get out first, and someone flicking between
  // two apps should not pay a bootstrap every time.
  void _scheduleSleep() {
    _sleepTimer?.cancel();
    var waited = 0;
    _sleepTimer = Timer.periodic(const Duration(seconds: 30), (t) {
      waited += 30;
      if (_inFront || _deliveryMode == DeliveryMode.always) {
        t.cancel();
        return;
      }
      final busy = _q.n > 0 || mediaInflight.isNotEmpty || _checking;
      if (waited < 90 || (busy && waited < 600)) return;
      t.cancel();
      unawaited(_torSleep());
    });
  }

  Future<void> _torSleep() async {
    if (haloWiping) return;
    _wakeAgain?.cancel();
    // held is only the app's word: a wake that failed half way has let the
    // engine run again, and then it is stopped once more
    if (_torHeld && engine.torPaused()) return;
    _torHeld = true;
    final r = await engine.torStop();
    dlog('delivery: tor stopped ($r)');
    notifyListeners();
  }

  Future<bool> _torWake() async {
    _wakeAgain?.cancel();
    if (!_torHeld) return true;
    // 'ok': tor was asleep and is waking. 'start': there is no tor in this
    // process yet. either way the start call below hands back the address
    // of the tor that is up, or makes one.
    final r = await engine.torResume();
    if (r.startsWith('error')) {
      dlog('delivery: tor would not wake: $r');
      _wakeLater();
      return false;
    }
    _torHeld = false;
    final addr = await engine.startListenerBg(_docsPath);
    if (addr.isEmpty || addr.startsWith('error')) {
      dlog('delivery: tor did not start: $addr');
      return false;
    }
    myOnion = addr;
    notifyListeners();
    return true;
  }

  // a wake that failed, most often a control port that stopped answering,
  // is tried again for as long as tor is wanted. the watchdog leaves a held
  // tor alone, so nothing else would
  void _wakeLater() {
    _wakeAgain?.cancel();
    _wakeAgain = Timer(const Duration(seconds: 15), () {
      if (!_torHeld || haloWiping) return;
      if (!_inFront && _deliveryMode != DeliveryMode.always) return;
      unawaited(_torWake());
    });
  }

  // one check-in: tor up, every relay asked for what it holds, tor down.
  // returns how many drains brought something. bounded all the way: the job
  // that calls this is given under three minutes.
  Future<int> checkIn({String why = 'job'}) async {
    if (_checking) return 0;
    _checking = true;
    final started = DateTime.now();
    final drainBefore = _lastDrainAt;
    final wasHeld = _torHeld;
    var how = 'started';
    try {
      if (!await _torWake()) {
        how = 'nowake';
        return 0;
      }
      // ready means the engine has a route a relay can be reached over
      for (var i = 0; i < 75 && !torReady; i++) {
        await Future.delayed(const Duration(seconds: 1));
      }
      if (!torReady) {
        how = 'notready';
        dlog('checkin($why): tor never became ready');
        return 0;
      }
      final begunBefore = engine.catchupState().$2;
      _needRouteUp();
      try {
        engine.nostrKick();
      } catch (e) {
        dlog('checkin: kick: $e');
      }
      // wait for the relays to be asked, then for every answer to be in. the
      // engine caps each relay at catchupCap (30s), so this ends when all
      // have finished or been given up on. the two escapes are for no relay
      // ever getting going.
      var quiet = 0;
      var began = false;
      var tail = '';
      while (true) {
        final secs = DateTime.now().difference(started).inSeconds;
        final (active, begun) = engine.catchupState();
        if (begun > begunBefore) began = true;
        if (began && active == 0) {
          quiet++;
          if (quiet >= 4) break;
        } else {
          quiet = 0;
        }
        if (!began && secs >= 45) {
          tail = '_norelay';
          break;
        }
        // relays are capped at 30s each, so this should never bite. if it
        // ever does, something is holding catchupActive up and the line on
        // the transport screen will say which relay.
        if (secs >= 90) {
          tail = '_capped';
          break;
        }
        await Future.delayed(const Duration(seconds: 1));
      }
      _lastCheckRelays = _relayCatchupData();
      // what came in is drained by the one-second poll. let it finish, and
      // let receipts and slice requests that answer it get out.
      await Future.delayed(const Duration(seconds: 3));
      await askForMissingSlices(walked: true);
      for (var i = 0; i < 10 && _q.n > 0; i++) {
        await Future.delayed(const Duration(seconds: 1));
      }
      how = 'ok$tail';
      _lastCheckAt = DateTime.now().millisecondsSinceEpoch;
      if (why == 'push') _lastWakeAt = _lastCheckAt;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(kLastCheckKey, _lastCheckAt);
        if (why == 'push') await prefs.setInt(kLastWakeKey, _lastWakeAt);
      } catch (_) {
        // shown on screen only: a miss shows an older time
      }
      dlog(
        'checkin($why): done in ${DateTime.now().difference(started).inSeconds}s',
      );
      return _lastDrainAt != drainBefore ? 1 : 0;
    } finally {
      _checking = false;
      _lastCheckHow = jsonEncode({
        'how': how,
        'secs': DateTime.now().difference(started).inSeconds,
        'why': why,
      });
      _lastCheckTriedAt = DateTime.now().millisecondsSinceEpoch;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(kLastCheckHowKey, _lastCheckHow);
        await prefs.setString(kLastCheckRelaysKey, _lastCheckRelays);
        await prefs.setInt(kLastCheckTriedKey, _lastCheckTriedAt);
      } catch (_) {
        // shown on screen only: a miss shows an older time
      }
      // only put it back to sleep if it was asleep: a check-in that ran
      // while the person had the app open leaves tor alone
      if (wasHeld && !_inFront && _deliveryMode != DeliveryMode.always) {
        await _torSleep();
      }
      notifyListeners();
    }
  }

  // [serviceUp]: the job found the listener service already running
  Future<int> drainNow({bool serviceUp = false}) async {
    // the job can knock before a cold boot has read the mode. wait for that,
    // or the first check-in after a kill does nothing
    for (var i = 0; i < 80 && _docsPath.isEmpty; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (_deliveryMode != DeliveryMode.always && (_torHeld || !_inFront)) {
      return checkIn();
    }
    if (jobMayRest(
      mode: _deliveryMode,
      serviceUp: serviceUp,
      torReady: torReady,
      nowMs: DateTime.now().millisecondsSinceEpoch,
      lastPollMs: _lastListenAt,
      awakeSinceMs: _awakeSince,
    )) {
      dlog('drainNow: listening all along, nothing to do');
      return 0;
    }
    final before = _lastDrainAt;
    _needRouteUp();
    try {
      engine.nostrKick();
    } catch (e) {
      dlog('drainNow: kick: $e');
    }
    for (var i = 0; i < 20; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (_lastDrainAt != before && i >= 3) break;
    }
    dlog('drainNow: drained=${_lastDrainAt != before}');
    return _lastDrainAt != before ? 1 : 0;
  }

  // three facts from the platform, null when no activity is attached
  Future<bool?> isBatteryExempt() async {
    try {
      return await _platformChannel.invokeMethod<bool>('isBatteryExempt');
    } catch (_) {
      return null;
    }
  }

  Future<int?> processUptimeMs() async {
    try {
      return await _platformChannel.invokeMethod<int>('processUptimeMs');
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> lastExit() async {
    if (sessionQuiet) return null;
    try {
      final r = await _platformChannel.invokeMethod<Map>('lastExit');
      return r?.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {
      return null;
    }
  }

  // the lock turned on or off: the window follows at once
  bool? _lockWasOn;
  void _lockMoved() {
    if (_lockWasOn == lockState.lockOn) return;
    _lockWasOn = lockState.lockOn;
    unawaited(_applyScreenSecure());
    notifyListeners();
  }

  Future<void> loadScreenshotPref() async {
    if (_lockWasOn == null) {
      _lockWasOn = lockState.lockOn;
      lockState.addListener(_lockMoved);
    }
    _blockScreenshots =
        (await secureStore.read(key: 'block_screenshots')) == 'true';
    _blockScreenshotsApplied = _blockScreenshots;
    await _applyScreenSecure();
    notifyListeners();
  }

  Future<void> setBlockScreenshots(bool v) async {
    _blockScreenshots = v;
    notifyListeners();
    await secureStore.write(key: 'block_screenshots', value: v.toString());
  }

  Future<void> loadThemePref() async {
    try {
      final v = (await secureStore.read(key: 'theme_light')) == 'true';
      HaloColors.setLight(v);
    } catch (e) {
      dlog('theme pref: $e');
    }
  }

  Future<void> setLight(bool v) async {
    HaloColors.setLight(v);
    themeRevision.value++;
    notifyListeners();
    await secureStore.write(key: 'theme_light', value: v.toString());
  }

  // bridges are off by default: they are slower and most people are not
  // being filtered
  bool _bridgesOn = false;
  String _bridgeLines = '';
  bool get bridgesOn => _bridgesOn;
  String get bridgeLines => _bridgeLines;

  Future<void> _loadBridges() async {
    const st = secureStore;
    _bridgeLines = await st.read(key: 'bridge_lines') ?? '';
    _bridgesOn = (await st.read(key: 'bridges_on')) == '1';
    _bridgeHintOff = (await st.read(key: 'bridge_hint_off')) == '1';
    if (_bridgesOn && _bridgeLines.isNotEmpty) {
      final r = engine.setBridges(_bridgeLines, true);
      _bridgesOn = _bridgesTaken(true);
      dlog('bridges: $r');
    }
    notifyListeners();
  }

  // whether the engine is using bridges now. lines it could not read leave
  // them off even with the switch on, and every hint and card goes by this
  bool _bridgesTaken(bool asked) {
    try {
      final on = engine.bridgeState().split('|').first;
      if (on == 'true' || on == 'false') return asked && on == 'true';
    } catch (e) {
      dlog('bridges: state unreadable ($e)');
    }
    return asked;
  }

  // returns the engine's summary so the ui can say how many lines it liked.
  Future<String> applyBridges(String lines, bool on) async {
    _bridgeLines = lines;
    final r = engine.setBridges(lines, on);
    _bridgesOn = _bridgesTaken(on);
    const st = secureStore;
    await st.write(key: 'bridge_lines', value: lines);
    await st.write(key: 'bridges_on', value: _bridgesOn ? '1' : '0');
    _newTorTry();
    notifyListeners();
    return r;
  }

  // which first-contact address our invites currently point at. an invite can
  // end up in a bio or a screenshot, so it has to be retirable without
  // burning the identity: bumping this leaves every conversation alone.
  int _fcCounter = 0;
  int get fcCounter => _fcCounter;

  // a stranger's first-contact address, kept only until they back-pair.
  // after that the normal per-conversation addresses take over.
  final Map<String, String> _peerFc = <String, String>{};
  // the stored map did not read: it is left as it is, never written over
  // with the part this process knows
  bool _peerFcUnread = false;
  // the same for the invite address's counter
  bool _fcUnread = false;

  @visibleForTesting
  Future<void> loadFirstContact() => _loadFirstContact();

  Future<void> _loadFirstContact() async {
    const st = secureStore;
    // a counter that does not read leaves the invite address unheard until
    // the next start, rather than moved
    try {
      _fcCounter = int.tryParse(await st.read(key: 'fc_counter') ?? '') ?? 0;
    } catch (e) {
      _fcUnread = true;
      dlog('first contact: counter unreadable (${e.runtimeType})');
      return;
    }
    try {
      final raw = await st.read(key: 'peer_fc');
      if (raw != null && raw.isNotEmpty) {
        (jsonDecode(raw) as Map<String, dynamic>).forEach((k, v) {
          _peerFc[k] = v as String;
        });
      }
    } catch (e) {
      _peerFcUnread = true;
      dlog('peer fc map unreadable, kept as it is: ${e.runtimeType}');
    }
    engine.subscribeFirstContactBg(_fcCounter);
    _fcLoaded = true;
    _maybeRepoint();
    notifyListeners();
  }

  // the dev chat's is his pinned one, never a remembered one: the gate says
  // whether it is reached
  String? peerFcFor(String haloId) {
    if (!isDevId(haloId)) return _peerFc[haloId];
    for (final k in devKeys) {
      if (k.chatId == haloId) return k.fc;
    }
    return null;
  }

  Future<void> rememberPeerFc(String haloId, String fcPk) async {
    // the dev chat's address is pinned, and no one else is given his
    if (devCardClaim(id: haloId, fc: fcPk)) return;
    _peerFc[haloId] = fcPk;
    if (_peerFcUnread) return;
    await secureStore.write(key: 'peer_fc', value: jsonEncode(_peerFc));
  }

  Future<void> forgetPeerFc(String haloId) async {
    if (_peerFc.remove(haloId) == null || _peerFcUnread) return;
    await secureStore.write(key: 'peer_fc', value: jsonEncode(_peerFc));
  }

  // true once the registry says the handle this phone believes in is held
  // under another key
  bool _handleForeign = false;
  bool get handleForeign => !sessionQuiet && _handleForeign;

  void _setHandleForeign(bool foreign) {
    if (foreign == _handleForeign) return;
    _handleForeign = foreign;
    notifyListeners();
  }

  // nothing is sent while the invite is the one the registry last took
  Future<void> _repointHandle() async {
    final h = _myHandle;
    if (h == null || myOnion.isEmpty) return;
    try {
      final r = await _handleRepoint.repoint(h);
      if (r != null) _setHandleForeign(r.contains('taken'));
    } catch (_) {
      // offline, or the registry is down. the handle stays claimed and
      // stale rather than lost, and the next claim fixes it.
    }
  }

  // asked by the handle screen when it opens on a claimed handle: a read of
  // whose it is, and a claim only when the registry holds something else
  Future<void> checkHandle() async {
    final h = _myHandle;
    if (h == null || myOnion.isEmpty) return;
    try {
      switch (await _handleRepoint.check(h)) {
        case HandleAtRegistry.foreign:
          _setHandleForeign(true);
        case HandleAtRegistry.mine:
          _setHandleForeign(false);
        default:
      }
    } catch (_) {
      // no answer: the card keeps what it showed
    }
  }

  Future<void> resetInviteAddress() async {
    // the everyday invite's key and address: never from a quiet session,
    // and never on the developer's own phone, whose card every install pins
    // a counter that did not read is never moved past
    if (sessionQuiet || _devIdentity || _fcUnread) return;
    // the key first: moving only the relay address leaves every old link
    // able to open a session and dial the onion directly
    await signalSession.rotateInvitePreKey();
    _fcCounter++;
    await secureStore.write(key: 'fc_counter', value: '$_fcCounter');
    engine.subscribeFirstContactBg(_fcCounter);
    await _repointHandle();
    notifyListeners();
  }

  // some screens are not optional. recovery shows the whole key, so it turns
  // the flag on whatever the user picked in settings, and hands it back on
  // the way out. a count, one per screen holding it: a room closing over
  // another room lets go of its own hold only
  int _secureHolds = 0;
  bool get secureForced => _secureHolds > 0;
  // an app lock keeps screenshots and the recents picture off, whatever the
  // switch says: the settings then never say one thing while the app does
  // another. a lock turned off in the decoy is off here too, as anywhere
  bool get screenSecureByLock => lockState.lockOn;

  Future<void> forceSecure(bool on) async {
    _secureHolds = on ? _secureHolds + 1 : max(0, _secureHolds - 1);
    await _applyScreenSecure();
  }

  // what android was last told. the call runs on android's main thread,
  // which dart shares, so an unchanged value is not sent: a room closing
  // in a session switch would otherwise hold the decoy's reveal alone
  bool? _secureSent;

  Future<void> _applyScreenSecure() async {
    final on = _blockScreenshotsApplied || secureForced || screenSecureByLock;
    if (on == _secureSent) return;
    _secureSent = on;
    try {
      await _platformChannel.invokeMethod('setSecure', {'on': on});
    } catch (e) {
      _secureSent = null;
      dlog('setSecure: $e');
    }
  }

  // the first fill of the search index for a history from before it: a
  // batch, a breath, the next, so the app never waits on it. each container
  // fills its own index, the vault's only while it is open
  ({int at, int to}) _liveFill = (at: 0, to: 0);
  ({int at, int to}) _vaultFill = (at: 0, to: 0);

  Future<void> _fillSearch([HaloDb? vault]) async {
    final d = vault ?? live;
    try {
      while (!haloWiping && (vault == null || identical(_openVault, vault))) {
        final p = await d.fillSearchIndex();
        if (vault == null) {
          _liveFill = p;
        } else if (identical(_openVault, vault)) {
          _vaultFill = p;
        }
        _showFill();
        if (p.at >= p.to) break;
        await Future.delayed(const Duration(milliseconds: 60));
      }
    } catch (e) {
      if (vault == null || identical(_openVault, vault)) {
        dlog('search fill stopped: $e');
      }
    }
  }

  // the search screen's line: the vault's part only while it is open
  void _showFill() {
    final v = _openVault == null ? (at: 0, to: 0) : _vaultFill;
    searchFill.value = (at: _liveFill.at + v.at, to: _liveFill.to + v.to);
  }

  String? _arrivingPoll(Object? raw) {
    final p = PollSpec.parse(raw);
    return p == null
        ? null
        : PollSpec(options: p.options, multi: p.multi).toRow();
  }

  // the packs an arriving sticker is read against. null if none loads: the
  // sticker is then read as one this version does not have
  Future<StickerLibrary?> _stickers() async {
    try {
      return await StickerLibrary.load();
    } catch (e) {
      dlog('stickers: $e');
      return null;
    }
  }

  // the open vault, when it is the everyday identity's: the decoy's own
  // never takes an arrival
  HaloDb? get _openVault {
    final s = _session;
    return identical(s.primary, live) ? s.vault : null;
  }

  // where a chat's rows are for receiving and sending: the open vault's own
  // chats there, every other one in the everyday container
  HaloDb _ownerOf(String chatId) {
    final v = _openVault;
    return v != null && _session.isHidden(chatId) ? v : live;
  }

  // where an arrival for this chat goes. while the vault is open, a chat it
  // holds goes there even before the list names it
  RouteTo _routeOf(String sender, String? groupId) {
    final open = _openVault != null;
    return _router.route(
      sender,
      groupId,
      open: open,
      held: open ? _session.isHidden : null,
    );
  }

  static bool _shown(RouteTo to) =>
      to == RouteTo.everyday || to == RouteTo.vault;

  // routing for group controls, reactions and data messages, shared by all
  // three receive paths (back-pair, tor drain, nostr poll). where it goes is
  // decided first: nothing on screen or on disk moves for an arrival that is
  // sealed. into is set when a sealed one is opened, with the time it came
  Future<RouteTo> _applyIncomingPayload(
    String senderHaloId,
    UnwrappedMessage env, {
    required String wire,
    bool fromBackPair = false,
    HaloDb? into,
    int? arrivedAt,
  }) async {
    // the dev chat takes a frame only while it runs, and only what his
    // chat may carry, said by his pinned key. the rest is dropped unseen
    if (isDevId(senderHaloId)) {
      final seat = await devLane.seat(senderHaloId);
      final kept = seat == null ? null : devInFrame(senderHaloId, wire);
      if (kept == null) {
        dlog('dev chat: a frame not taken');
        return RouteTo.dropped;
      }
      wire = kept;
      env = unwrapMessage(kept);
    }
    if (into != null) {
      return _fileArrival(
        senderHaloId,
        env,
        wire: wire,
        fromBackPair: fromBackPair,
        into: into,
        arrivedAt: arrivedAt,
      );
    }
    await _afterClose();
    // a chat being moved: what arrives for it waits for the list
    if (_moveDone != null) await _afterMove(senderHaloId, env.groupId);
    final keys = [senderHaloId, ?env.groupId];
    for (final k in keys) {
      _arriving[k] = (_arriving[k] ?? 0) + 1;
    }
    try {
      return await _fileArrival(
        senderHaloId,
        env,
        wire: wire,
        fromBackPair: fromBackPair,
      );
    } finally {
      for (final k in keys) {
        final n = (_arriving[k] ?? 1) - 1;
        n > 0 ? _arriving[k] = n : _arriving.remove(k);
      }
    }
  }

  // a file that travels as slices, one of them in this frame
  static bool _sliced(UnwrappedMessage env) =>
      env.mediaId != null && env.chunkTotal != null && env.chunkTotal! > 1;

  Future<RouteTo> _fileArrival(
    String senderHaloId,
    UnwrappedMessage env, {
    required String wire,
    bool fromBackPair = false,
    HaloDb? into,
    int? arrivedAt,
  }) async {
    final RouteTo to;
    final HaloDb db;
    if (into != null) {
      to = RouteTo.vault;
      db = into;
    } else {
      to = _routeOf(senderHaloId, env.groupId);
      if (to == RouteTo.dropped) return to;
      if (to == RouteTo.sealed) {
        await _sealArrival(senderHaloId, env, wire, fromBackPair);
        return to;
      }
      final v = _openVault;
      if (to == RouteTo.vault && v == null) return RouteTo.dropped;
      db = to == RouteTo.vault ? v! : live;
    }
    // opened from the seal: its tick already went, the lists are read again
    // once the batch is in, and what it writes carries the time it came.
    // the clocks that wait on it (a vote's hour, a slice's week) start now
    final unsealing = arrivedAt != null;
    _bumpChatRev(senderHaloId);
    if (env.groupId != null) _bumpChatRev('group:${env.groupId}');
    dlog(
      'INCOMING len=${env.message.length} hasPreview=${env.preview != null} uid=${env.msgUid}',
    );
    // delivery receipt, handled before the stranger gate and dedup so an ack
    // is never treated as a message or counted toward the cap. it leaves
    // back-paired alone: that flag lifts the sender-side cap, and a stranger
    // could then write past the two the other side will keep.
    if (env.deliveredUid != null) {
      await db.markDelivered(env.deliveredUid!, from: senderHaloId);
      _bumpChatRev(senderHaloId);
      notifyListeners();
      return to;
    }
    if (proofOfEngagement(env)) {
      final was = await db.isBackPaired(senderHaloId);
      await db.markBackPaired(senderHaloId);
      if (!was) {
        // the door just opened: rows parked for them go now, not when the
        // backoff runs out
        _outboxTries.clear();
        _outboxNextAt.clear();
        unawaited(drainOutbox());
      }
    }
    if (await db.isBlocked(senderHaloId)) return to;
    // the developer's own phone: a chat started from the Marios row goes to
    // support by its marker, and is never a way into his groups or contacts
    final support = await _supportOf(senderHaloId, env, db);
    if (support.on && supportRefuses(env)) {
      dlog('support: a group or an introduction, dropped');
      return to;
    }
    // 1) group control
    if (env.groupControl != null) {
      await _applyGroupControl(senderHaloId, env, db);
      return to;
    }
    // 1.5) introduction: a friend hands us someone's card
    if (env.intro != null) {
      await _applyIntro(senderHaloId, env.intro!, db, at: arrivedAt);
      return to;
    }
    // they are missing slices of something we sent them
    if (env.need != null) {
      await _answerNeed(senderHaloId, env.need!, db);
      return to;
    }
    // shared pin: every member mirrors it. only from someone in the chat
    // the row lives in: the frame names a uid and nothing else, and it rides
    // in above the stranger gate like an edit does.
    if (env.pin != null) {
      final where = await db.chatOf(env.pin!.targetUid);
      final ok = pinAllowed(
        rowPeer: where?.$1,
        rowGroup: where?.$2,
        sender: senderHaloId,
        frameGroup: env.groupId,
        members: where?.$2 == null
            ? const []
            : await db.getGroupMembers(where!.$2!),
      );
      if (!ok) {
        dlog('pin: dropped, sender is not in that chat');
        return to;
      }
      // the sender counts before it pins, but that is their word. held
      // here too, or a member could fill the list from afar.
      if (env.pin!.pinned) {
        final held = await db.pinnedIn(peerId: where!.$1, groupId: where.$2);
        if (held.length >= kMaxPins &&
            !held.any((r) => r['msg_uid'] == env.pin!.targetUid)) {
          dlog('pin: dropped, that chat is full');
          return to;
        }
      }
      await db.setPinned(env.pin!.targetUid, env.pin!.pinned, at: arrivedAt);
      notifyListeners();
      return to;
    }
    // polls: a vote, or the creator closing one
    if (env.vote != null) {
      await _applyVote(senderHaloId, env, db);
      return to;
    }
    if (env.pollClose != null) {
      await _applyPollClose(senderHaloId, env, db);
      return to;
    }
    // 2) reaction
    if (env.reaction != null) {
      final r = env.reaction!;
      // the frame names a uid and nothing else, so only someone in the chat
      // that row lives in gets to react to it
      final where = await db.chatOf(r.targetUid);
      final ok = pinAllowed(
        rowPeer: where?.$1,
        rowGroup: where?.$2,
        sender: senderHaloId,
        frameGroup: env.groupId,
        members: where?.$2 == null
            ? const []
            : await db.getGroupMembers(where!.$2!),
      );
      if (!ok || r.emoji.length > 32) {
        dlog('reaction: dropped');
        return to;
      }
      if (r.emoji.isEmpty) {
        await db.removeReaction(r.targetUid, senderHaloId);
      } else {
        await db.addReaction(r.targetUid, senderHaloId, r.emoji, at: arrivedAt);
      }
      return to;
    }
    // 2.5) edit: swap the text of an existing message
    if (env.edit != null) {
      // only the author. these frames ride in above the stranger gate, so
      // anyone who can reach us could rewrite any row by uid otherwise.
      if (await db.isTheirs(env.edit!.targetUid, senderHaloId)) {
        await db.editMessage(env.edit!.targetUid, env.edit!.newText);
        // home's row shows the last line, and only a refresh rereads it
        await refreshContacts();
        notifyListeners();
      }
      return to;
    }
    // 2.6) unsend: sender recalled a message; delete our copy
    if (env.unsend != null) {
      // a row that exists must be theirs. a half-file with no row yet has
      // nothing to protect, and its sender stopping it is the point.
      if (await db.messageExists(env.unsend!) &&
          !await db.isTheirs(env.unsend!, senderHaloId)) {
        return to;
      }
      _noteTakenBack(senderHaloId, env.unsend!);
      await db.deleteMessage(env.unsend!);
      // the delete took its unread mark; its notification goes too
      unawaited(_io.unnotifyMessage(env.unsend!));
      // a recall mid-transfer would otherwise leave a half-filled buffer and
      // a progress bar that never completes. drop both: the slices its
      // sender sent, never another sender's
      if (await db.dropMediaChunks(env.unsend!, from: senderHaloId) > 0) {
        incomingMediaDone(db.container.chatKey(env.groupId ?? senderHaloId));
      }
      // refresh so it vanishes live if the peer's looking at the chat now,
      // not only after they leave and come back. home shows the count too
      await refreshContacts();
      if (env.groupId != null) await refreshGroups();
      notifyListeners();
      return to;
    }
    // 3) data message: could be 1:1 or group
    final isGroup = env.groupId != null;
    if (isGroup && !await db.groupExists(env.groupId!)) {
      // unknown group: drop, so random senders cannot inject rows into
      // groups we never joined
      dlog('dropping group msg for unknown group ${env.groupId}');
      return to;
    }
    // a group's messages, polls and slices come from its members, here and
    // when a sealed one is opened
    if (isGroup &&
        !(await db.getGroupMembers(env.groupId!)).contains(senderHaloId)) {
      dlog('group msg: dropped, the sender is not a member');
      return to;
    }
    // badge rides real chat rows only. present = set, absent = clear so
    // turning it off propagates. control frames and preview patches never
    // get here with a fresh row, so they can't wipe it.
    if (env.preview == null && env.msgUid != null && !isDevId(senderHaloId)) {
      await db.setContactBadge(senderHaloId, env.supporterBadge);
    }
    // roster self-heal: if the admin rode their full member list on this
    // message and our copy drifted, reconcile. only trust it from the real
    // admin so a member can't rewrite membership by spoofing a roster.
    if (isGroup && env.roster != null && !support.on) {
      final adminId = await db.groupAdminId(env.groupId!);
      final isRoom = await _roomOf(env.groupId!, db) != null;
      final roster = _members(env.roster!, room: isRoom);
      // the admin is always on their own list: one without them is from a
      // phone that already left, and would empty the group here
      final fromAdmin =
          adminId != null &&
          senderHaloId == adminId &&
          roster.contains(adminId);
      // the admin's own list without this phone: taken out, as a remove
      // naming it says, and that remove may never come
      if (fromAdmin && !isRoom && !roster.contains(myId)) {
        final name = (await db.getGroup(env.groupId!))?['name'] as String?;
        await _dropGroup(env.groupId!, db);
        if (name != null) _removedFrom[env.groupId!] = name;
        _bumpChatRev('group:${env.groupId}');
        await refreshGroups();
        return to;
      }
      if (fromAdmin &&
          await _fitsCap(env.groupId!, roster.toSet().length, db)) {
        await db.syncGroupMembers(env.groupId!, roster);
        await _subscribeRoomMembers(env.groupId!);
        // contact stubs for self-healed members so we can encrypt to them:
        // ids alone are not enough, we need their keys
        if (env.rosterParticipants != null) {
          for (final p in env.rosterParticipants!) {
            final h = p['h'];
            final o = p['o'];
            final x = p['x'];
            if (h != null &&
                o != null &&
                x != null &&
                h != myId &&
                wireIdShaped(h, room: isRoom) &&
                !devCardClaim(id: h, xPub: x)) {
              await db.upsertContactStub(h, o, x);
            }
          }
          await refreshContacts();
        }
      }
    }
    // stranger lock + proof-of-work gate (1:1 only, unaccepted senders).
    // a sender a friend introduced is not a stranger: no pow, no cap. they
    // still land in requests and still need an accept to get a reply.
    if (!isGroup && !await db.isAccepted(senderHaloId)) {
      final vouched = await db.isVouched(senderHaloId);
      // pow: only the back-pair message (true first contact) must carry a
      // valid nonce, the one lane a cold stranger can arrive on. a whisper
      // through an existing session already paid once. dropped silently so
      // the spammer learns nothing.
      if (!vouched &&
          fromBackPair &&
          (env.powNonce == null ||
              !verifyPow(env.powText ?? env.message, env.powNonce!, powBits))) {
        dlog(
          'pow: dropping first-contact from $senderHaloId (nonce=${env.powNonce} bits=${env.powBitsUsed})',
        );
        throw const _NoProof();
      }
      // 2-message cap: a stranger gets 2 into requests, then the chat is locked
      // until we accept them. past the cap there is no receipt. a file still
      // in slices counts as one of the two, and its own slices come in
      final have = vouched
          ? 0
          : await db.countMessagesFrom(senderHaloId) +
                await db.filesInFlightFrom(
                  senderHaloId,
                  except: _sliced(env) ? env.mediaId : null,
                );
      if (strangerCapHolds(
        accepted: false,
        vouched: vouched,
        have: have,
        cap: support.on ? kSupportCap : 2,
      )) {
        dlog('stranger lock: holding from $senderHaloId (cap hit)');
        throw _HeldIn(db);
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
    // a timer runs from when the message came, sealed or not: one that ran
    // out while the vault was shut goes unread, as it would have on time.
    // never a stranger's, whose timers do not count
    Future<bool> burnedWhileSealed() async {
      final at = arrivedAt;
      final secs = chunkBurn;
      if (at == null || secs == null || secs <= 0) return false;
      if (at + secs * 1000 > DateTime.now().millisecondsSinceEpoch) {
        return false;
      }
      return isGroup || await db.isAccepted(senderHaloId);
    }

    // a save can fail, a full phone say. the message still lands, with a
    // line saying what is missing, rather than an empty bubble
    String? mediaPath;
    String? filePath;
    var unsaved = false;
    final fileName = env.fileName;
    // dedup comes before anything is written, so a uid this phone holds or
    // is filing right now never touches a file. the db check alone races
    // when two copies arrive at once, so an in-memory set of uids in flight
    // backs it: the first in claims the uid, a twin takes the known path
    final uid = env.msgUid;
    String? claimed;
    final taken = _sliced(env) ? env.mediaId : uid;
    if (taken != null && _wasTakenBack(senderHaloId, taken)) {
      dlog('recv: taken back before it came, dropped');
      return to;
    }
    if (_sliced(env)) {
      final mid = env.mediaId!;
      final total = env.chunkTotal!;
      final index = env.chunkIndex ?? 0;
      // the container's own: the same chat id can be another container's
      final progressKey = db.container.chatKey(
        isGroup ? env.groupId! : senderHaloId,
      );
      final slice = (env.imageB64 ?? env.fileB64) ?? '';
      // a sliced file is filed under its own id
      if (uid != null && uid != mid) {
        dlog('recv: slice of another message id, dropped');
        return to;
      }
      // a slice has a place in its file, and a file has a bounded number
      // of them
      if (total > kMaxSlices || index < 0 || index >= total) {
        dlog('recv: slice out of range, dropped');
        return to;
      }
      // a file's slices come from one sender
      final owner = await db.mediaChunkSender(mid);
      if (owner != null && owner != senderHaloId) {
        dlog('recv: slice of a file another sender is sending, dropped');
        return to;
      }
      if (_inflightUids.contains(mid)) return to;
      // a slice of a file already put together: the sender went round
      // again. buffering it would start a copy that never finishes. one
      // receipt per pass, on the first slice, so the sender can stop.
      if (await db.messageExists(mid)) {
        if (!isGroup &&
            !unsealing &&
            (env.chunkIndex ?? 0) == 0 &&
            senderHaloId != myId) {
          unawaited(_sendDeliveryReceipt(senderHaloId, mid));
        }
        unawaited(db.dropMediaWant(mid));
        return to;
      }
      // slices land on disk as they arrive and the count is over rows, so a
      // restart resumes instead of starting over
      final have = await db.putMediaChunk(
        mid,
        index,
        slice,
        total,
        (env.burnSeconds != null && env.burnSeconds! > 0)
            ? env.burnSeconds
            : null,
        from: senderHaloId,
      );
      chunkBurn = await db.mediaChunkBurn(mid) ?? chunkBurn;
      if (have < total && !isGroup && senderHaloId != myId) {
        await db.noteMediaWant(mid, senderHaloId, total, env.canResend);
      }
      if (have < total) {
        // what waits unfinished has a ceiling: past it the file whose last
        // slice came longest ago goes, this one too if it alone is past it
        final gone = await db.trimUnfinishedMedia(keep: _inflightUids);
        if (gone.contains(mid)) {
          incomingMediaDone(progressKey);
          return to;
        }
        // still waiting on more pieces: surface how far along we are. a
        // voice note is seconds of audio; the banner is for the long ones.
        if (!env.voice) incomingMediaUpdate(progressKey, have, total);
        return to;
      }
      if (await burnedWhileSealed()) {
        await db.dropMediaChunks(mid);
        unawaited(db.dropMediaWant(mid));
        incomingMediaDone(progressKey);
        return to;
      }
      // all pieces in. each goes from the database to the file on its own,
      // so the whole file is never in memory at once. a preview thumbnail
      // from an older client is never drawn, never kept.
      if (!_inflightUids.add(mid)) return to;
      claimed = mid;
      if (!env.pvImg) {
        try {
          final out = fileName != null
              ? await receivedFileFor(fileName, db.container)
              : await receivedImageFor(db.container);
          final path = await saveSlices(
            out,
            total,
            (i) => db.mediaChunkSlice(mid, i),
          );
          if (fileName != null) {
            filePath = path;
          } else {
            mediaPath = path;
          }
        } catch (e) {
          dlog('recv: chunked media not saved: $e');
          unsaved = true;
        }
      }
      await db.dropMediaChunks(mid);
      unawaited(db.dropMediaWant(mid));
      incomingMediaDone(progressKey);
      if (env.pvImg) {
        _inflightUids.remove(mid);
        return to;
      }
      // the slice in this envelope is on disk now; nothing below should
      // save it again
      imgB64 = null;
      fileB64v = null;
    } else if (await burnedWhileSealed()) {
      return to;
    } else if (uid != null) {
      final known = _inflightUids.contains(uid) || await db.messageExists(uid);
      // a preview-only frame from an older client carries nothing we draw:
      // a sender never gets to put a title or an image on this screen
      final previewOnly =
          env.preview != null &&
          env.message.isEmpty &&
          env.imageB64 == null &&
          env.fileB64 == null;
      if (previewOnly) return to;
      if (known) {
        // already have it, but a re-send means our receipt never landed. ack
        // again so the sender's tick flips and the outbox stops redelivering.
        if (!isGroup &&
            !unsealing &&
            env.deliveredUid == null &&
            env.reaction == null &&
            env.edit == null &&
            senderHaloId != myId) {
          unawaited(_sendDeliveryReceipt(senderHaloId, uid));
        }
        notifyListeners();
        return to;
      }
      _inflightUids.add(uid);
      claimed = uid;
    }
    if (imgB64 != null && imgB64.isNotEmpty) {
      try {
        mediaPath = await saveMediaBytes(base64Decode(imgB64), db.container);
      } catch (e) {
        dlog('recv: image not saved: $e');
        unsaved = true;
      }
    }
    if (fileB64v != null && fileB64v.isNotEmpty) {
      try {
        filePath = await saveFileBytes(
          base64Decode(fileB64v),
          fileName ?? 'file',
          db.container,
        );
      } catch (e) {
        dlog('recv: file not saved: $e');
        unsaved = true;
      }
    }
    final bodyText = unsaved
        ? [
            env.message,
            l10n.appAnAttachmentCouldNot,
          ].where((s) => s.trim().isNotEmpty).join('\n')
        : env.message;
    // a sticker is a message of its own: a frame with media, a file or a
    // poll on it is read without it
    final bare =
        env.imageB64 == null &&
        env.fileB64 == null &&
        env.fileName == null &&
        env.mediaId == null &&
        env.poll == null;
    final sticker = bare ? StickerWire.parse(env.sticker) : null;
    // a known sticker's text is our own emoji for it, never the sender's
    final text = sticker == null
        ? bodyText
        : stickerText(sticker, env.message, await _stickers());
    // what the sender said, as far as this phone shows it
    final said = sticker == null ? env.message : text;
    // a stranger doesn't get to set disappearing rules in the inbox: burned
    // rows refund the 2-message cap and can vanish before the request is even
    // seen. burn only counts once they're accepted.
    // a deleted (parked) peer writing again surfaces as a fresh request.
    if (!isGroup) await db.unparkIfArchived(senderHaloId);
    final senderAccepted = await db.isAccepted(senderHaloId);
    final burnOk = isGroup || senderAccepted;
    await db.saveMessage(
      senderHaloId,
      'in',
      text,
      burnAt: burnOk && chunkBurn != null && chunkBurn > 0
          ? (arrivedAt ?? DateTime.now().millisecondsSinceEpoch) +
                chunkBurn * 1000
          : null,
      msgUid: env.msgUid,
      replyTo: env.replyTo,
      groupId: env.groupId,
      voiceDisguised: env.voiceDisguised,
      mediaPath: mediaPath,
      filePath: filePath,
      fileName: fileName,
      // a preview the sender fetched over tor, title and url only. kept from
      // someone accepted or a member of a group you chose to be in; a
      // stranger's title is text they control and stays plain. a room's
      // frames never reach this path.
      preview: shippedPreview(env.preview, accepted: isGroup || senderAccepted),
      secure: env.secure,
      // a poll lives in a group or a room; in a 1:1 it is just its question.
      // never closed on arrival, whatever the frame says: only a close from
      // its creator does that
      poll: isGroup ? _arrivingPoll(env.poll) : null,
      sticker: sticker?.value,
      sentAt: arrivedAt,
    );
    // remember the face they picked. cheap, and it arrives with every
    // message so it stays current if they change it.
    if (env.senderAvatar != null) {
      await db.setContactAvatar(senderHaloId, env.senderAvatar);
    }
    // scam shield: a stranger's opener, once, on this phone only. in a
    // group that is any member you never added.
    if (!senderAccepted && senderHaloId != myId) {
      unawaited(
        _runShield(senderHaloId, said, env.senderAvatar, db, group: isGroup),
      );
    }
    // saved now, messageExists covers dedup from here
    if (claimed != null) _inflightUids.remove(claimed);
    // send a delivery receipt back for 1:1 messages we just stored, so the
    // sender's tick means "on your phone" not "a relay took it". groups skip
    // this (N acks per message is noise); receipts themselves carry no uid of
    // their own and are handled before any gate on the far side.
    if (!isGroup && !unsealing && uid != null && senderHaloId != myId) {
      unawaited(_sendDeliveryReceipt(senderHaloId, uid));
    }
    // notification context: for groups, title = group name and body
    // prefixes the sender. payload uses "group:<id>" so tap-to-open can
    // route to the right screen.
    // the chat is being read only where its rows are shown: the same id
    // open in another container is another chat
    final reading = readingIn(
      isGroup ? 'group:${env.groupId}' : senderHaloId,
      db.container,
    );
    if (!isGroup && !reading) {
      await db.bumpUnread(senderHaloId);
    } else if (!isGroup) {
      // already reading this chat: clear any stale badge
      await db.clearUnread(senderHaloId);
    } else if (env.groupId != null) {
      if (!reading) {
        await db.bumpGroupUnread(env.groupId!);
        if (mentionsMe(said, myId)) {
          await db.setGroupMentioned(env.groupId!);
        }
      } else {
        await db.clearGroupUnread(env.groupId!);
      }
    }
    // a batch opened from the seal is shown once it is all in, and what
    // came while the vault was shut does not ring now
    if (unsealing) return to;
    // a message landed: rebuild the contact list so the home shows the
    // new preview, time and unread dot without needing the chat opened.
    await refreshContacts();
    if (isGroup) await refreshGroups();
    final String notifTitle;
    final String notifBody;
    final String notifPayload;
    final bool suppress;
    // the name given to them here, as the chat list shows it
    final nickname =
        (await db.getContact(senderHaloId))?['nickname'] as String?;
    final named = nickname == null || nickname.isEmpty
        ? senderHaloId
        : nickname;
    if (isGroup) {
      final g = await db.getGroup(env.groupId!);
      notifTitle = (g?['name'] as String?) ?? l10n.appGroup2;
      final gBody = sticker != null
          ? l10n.stickerLabel
          : env.poll != null && PollSpec.parse(env.poll) != null
          ? l10n.pollPreview(env.message)
          : env.message.isNotEmpty
          ? env.message
          : notifMediaLine(fileName, mediaPath);
      final who = looksLikeRoomKey(senderHaloId)
          ? roomTag(senderHaloId)
          : named;
      notifBody = '$who: $gBody';
      notifPayload = 'group:${env.groupId}';
      suppress = reading;
    } else if (!senderAccepted) {
      // a stranger chose these words; they do not go on a lock screen
      // where anyone nearby reads them. that a request arrived is enough.
      notifTitle = l10n.appNewRequest;
      notifBody = l10n.appSomeoneYouHaveNot;
      notifPayload = senderHaloId;
      suppress = reading || await db.isMuted(senderHaloId);
    } else {
      // his chat rings under his name, never its id
      notifTitle = isDevChat(senderHaloId) ? l10n.devName : named;
      notifBody = sticker != null
          ? l10n.stickerLabel
          : env.message.isNotEmpty
          ? env.message
          : notifMediaLine(fileName, mediaPath);
      notifPayload = senderHaloId;
      suppress = reading || await db.isMuted(senderHaloId);
    }
    // support rings on its own channel: a waiting chat only as a count, an
    // answered one per message
    if (support.on && !isGroup) {
      if (!suppress) {
        await _ringSupport(
          senderHaloId,
          db,
          support.fresh,
          answered: senderAccepted,
          title: notifTitle,
          body: notifBody,
        );
      }
      return to;
    }
    if (!suppress) {
      // a hidden chat rings only while its vault is open, and what it shows
      // goes from the shade when the vault closes
      if (to == RouteTo.vault) {
        if (!identical(_openVault, db)) return to;
        _vaultShade.add(notifPayload);
      }
      await _io.notify(
        title: notifTitle,
        body: notifBody,
        payload: notifPayload,
        msgUid: env.msgUid,
      );
    }
    return to;
  }

  // his own phone, everyday container only: what the support marker files.
  // a failure leaves the chat where any stranger's goes, in requests
  Future<({bool on, bool fresh})> _supportOf(
    String sender,
    UnwrappedMessage env,
    HaloDb db,
  ) async {
    if (!_devIdentity || !identical(db, live)) return (on: false, fresh: false);
    try {
      return await fileSupport(
        db.support,
        sender,
        env,
        accepted: () => db.isAccepted(sender),
      );
    } catch (e) {
      dlog('support: not filed (${e.runtimeType})');
      return (on: false, fresh: false);
    }
  }

  Future<void> _ringSupport(
    String id,
    HaloDb db,
    bool fresh, {
    required bool answered,
    required String title,
    required String body,
  }) async {
    try {
      if (answered) {
        await _bell.chat(chatId: id, title: title, body: body);
      } else if (!readingIn(kSupportPayload, db.container)) {
        // the inbox on screen says it already. a chat is new with its
        // first message kept, whatever came before it and was not
        final first = fresh || await db.countMessagesFrom(id) == 1;
        await ringSupport(db.support, _bell, chat: id, fresh: first);
      }
    } catch (e) {
      dlog('support: not rung (${e.runtimeType})');
    }
  }

  // an arrival for a hidden chat while the vault is shut: sealed to the
  // vault as it came, and nothing else happens. a 1:1 message still gets
  // its tick, as a visible one would, so the far side sees what it always
  // sees. a copy of one already sealed is not kept twice
  Future<void> _sealArrival(
    String sender,
    UnwrappedMessage env,
    String wire,
    bool fromBackPair,
  ) async {
    _lastSealAt = DateTime.now().millisecondsSinceEpoch;
    final uid = env.msgUid;
    final total = env.chunkTotal;
    final sliced = env.mediaId != null && total != null && total > 1;
    final part = sliced ? env.chunkIndex ?? 0 : null;
    final previewOnly =
        env.preview != null &&
        env.message.isEmpty &&
        env.imageB64 == null &&
        env.fileB64 == null;
    final ticks =
        env.groupId == null &&
        uid != null &&
        sender != myId &&
        env.deliveredUid == null &&
        env.reaction == null &&
        env.edit == null &&
        !previewOnly &&
        !_router.blocks(sender);
    // a sliced file ticks once every slice is in, as it does when shown
    Future<bool> whole() async =>
        !sliced || await _router.sealedParts(uid!) >= total;
    if (uid != null && await _router.sealedHas(uid, part)) {
      if (ticks && (part ?? 0) == 0 && await whole()) {
        unawaited(_sendDeliveryReceipt(sender, uid));
      }
      return;
    }
    final kept = await _router.seal(
      Unsealed(
        sender,
        wire,
        fromBackPair,
        DateTime.now().millisecondsSinceEpoch,
      ),
      uid: uid,
      part: part,
    );
    if (!kept) {
      dlog('seal: not kept');
      return;
    }
    if (ticks && await whole()) unawaited(_sendDeliveryReceipt(sender, uid));
  }

  // what came for the hidden chats while the vault was shut, oldest first:
  // a batch, a breath, the next. each goes into the vault as if it had just
  // arrived, and its row after it. if the vault closes part way, the rest
  // wait for the next time
  bool _unsealing = false;
  Future<void> drainSealed(HaloDb vault, String priv) async {
    if (_unsealing) return;
    _unsealing = true;
    try {
      while (!haloWiping && identical(_openVault, vault) && _moveDone == null) {
        final batch = await _router.openOldest(priv);
        if (batch.isEmpty) break;
        for (final (id, u) in batch) {
          if (!identical(_openVault, vault) || _moveDone != null) return;
          if (u != null) {
            try {
              final env = unwrapMessage(u.wire);
              // a first contact files its sender, as it does in the everyday
              // container, so a changed key is flagged
              if (u.backPair) {
                await vault.upsertContact(
                  u.from,
                  env.senderOnion ?? '',
                  env.senderXPub ?? '',
                  accepted: 0,
                );
              }
              await _applyIncomingPayload(
                u.from,
                env,
                wire: u.wire,
                fromBackPair: u.backPair,
                into: vault,
                arrivedAt: u.at,
              );
            } on CapHeld {
              // past a stranger's two: not kept, as on the relay lane
            } on _NoProof {
              await _io.dropSession(u.from);
            } catch (e) {
              if (!identical(_openVault, vault)) return;
              dlog('unseal: one not applied ($e)');
            }
          }
          await _router.forgetSealed(id);
        }
        await refreshContacts();
        await refreshGroups();
        await Future.delayed(const Duration(milliseconds: 60));
      }
    } finally {
      _unsealing = false;
    }
  }

  // the open vault's age identity, read the first time it is needed and
  // dropped once that vault is no longer open
  String? _sealKey;
  HaloDb? _sealKeyOf;

  // the sealed arrivals of the open vault, when there may be any
  Future<void> _unseal() async {
    final v = _openVault;
    if (v == null) {
      _sealKey = null;
      _sealKeyOf = null;
      return;
    }
    // rows moving between the vault and the everyday side go first
    if (!_router.maybeSealed || _unsealing || _moveDone != null) return;
    try {
      if (!identical(_sealKeyOf, v)) {
        _sealKey = await VaultRouter.sealKeyIn(SqlRouterStore(v.open));
        _sealKeyOf = v;
      }
      final k = _sealKey;
      if (k != null) await drainSealed(v, k);
    } catch (e) {
      dlog('unseal: $e');
    }
  }

  // group screens reload their marks when this moves
  int _shieldRev = 0;
  int get shieldRev => _shieldRev;

  Future<void> _runShield(
    String senderHaloId,
    String text,
    int? face,
    HaloDb db, {
    bool group = false,
  }) async {
    try {
      if (!await loadScamShieldOn()) return;
      if (await db.countMessagesFrom(senderHaloId, inGroups: group) != 1) {
        return;
      }
      if (await db.shieldFor(senderHaloId) != null) return;
      final rows = await db.contacts();
      final contacts = [
        for (final c in rows)
          ShieldContact(
            c['halo_id'] as String,
            nickname: c['nickname'] as String?,
            avatar: (c['avatar'] as num?)?.toInt(),
          ),
      ];
      final r = group
          ? shieldCheckInGroup(
              strangerId: senderHaloId,
              strangerAvatar: face,
              firstMessage: text,
              contacts: contacts,
            )
          : shieldCheck(
              strangerId: senderHaloId,
              strangerAvatar: face,
              firstMessage: text,
              contacts: contacts,
            );
      // a clean check is recorded too, as an empty headline: the chat can
      // then say it looked, which is most of what a shield is for. not in
      // a group: you chose to be there, so a clean line is clutter.
      if (!r.flagged) {
        if (group) return;
        await db.setShield(senderHaloId, '', const []);
        notifyListeners();
        return;
      }
      await db.setShield(senderHaloId, jsonEncode(r.lead!.toJson()), [
        for (final h in r.hits) h.toJson(),
      ]);
      _shieldRev++;
      dlog('shield: flagged ${r.hits.map((h) => h.code).join(',')}');
      notifyListeners();
    } catch (e) {
      dlog('shield: $e');
    }
  }

  // a contact we accepted vouches for someone. the card becomes a request
  // row with a vouch on it, so their first message skips the stranger gate.
  // trust is ours alone: a card from anyone we have not accepted is dropped
  // unread, and so is one that names us or the sender.
  Future<void> _applyIntro(
    String senderHaloId,
    IntroFrame card,
    HaloDb db, {
    int? at,
  }) async {
    if (!await db.isAccepted(senderHaloId)) return;
    if (!await loadAcceptIntros()) {
      dlog('intro: dropped, introductions are off');
      return;
    }
    final h = card.haloId;
    if (h == myId || h == senderHaloId) return;
    if (!wireIdShaped(h, room: false)) {
      dlog('intro: not an id, dropped');
      return;
    }
    // the developer is his pinned card alone, never someone's say-so
    if (devCardClaim(id: h, xPub: card.xPub, fc: card.fc)) {
      dlog('intro: names the developer, dropped');
      return;
    }
    final everyday = identical(db, live);
    // a card for someone the router keeps is not the everyday side's to
    // file: no row, no vouch, nothing in requests
    if (everyday && _routeOf(h, null) != RouteTo.everyday) {
      dlog('intro: dropped');
      return;
    }
    final existing = await db.getContact(h);
    if (existing != null && (existing['accepted'] as int? ?? 0) == 1) return;
    // someone blocked stays blocked: no vouch, no listening, nothing sent.
    // a block on the everyday side holds for a hidden chat's card too, or
    // listening for them here would undo it
    if (await db.isBlocked(h) || (!everyday && await live.isBlocked(h))) {
      dlog('intro: names someone blocked, dropped');
      return;
    }
    await db.upsertContactStub(h, card.onion, card.xPub);
    // the note is the introducer's one line about them. it lives on the
    // vouch, so two introducers can each say their piece.
    await db.addVouch(h, senderHaloId, card.note, at: at);
    if (card.avatar != null) await db.setContactAvatar(h, card.avatar);
    // the first-contact addresses are kept for the phone, so only the
    // everyday side's go there
    if (everyday && card.fc != null && card.fc!.isNotEmpty) {
      await rememberPeerFc(h, card.fc!);
    }
    // a card is keys, not a session. listen for them and swap prekey bundles
    // now, so the first message either side types has a session to ride.
    if (everyday) {
      await subscribePeer(h);
    } else if (card.xPub.isNotEmpty) {
      _xPubToHaloId[card.xPub] = h;
      _io.listen(card.xPub);
    }
    _wantHeal(h);
    unawaited(_sendBundleCtl(h, want: true));
    dlog('intro: $senderHaloId introduced $h');
    await refreshContacts();
  }

  // a member list from the wire, less any id that would stand for the
  // developer. this phone's own stays: on his phone it is his words
  List<String> _noDev(List<String> ids) => [
    for (final h in ids)
      if (h == myId || !devIdClaim(h)) h,
  ];

  // a member list from the wire, only of ids with the shape of a member:
  // a person's in a group, a key in a room
  List<String> _members(List<String> ids, {required bool room}) => [
    for (final h in _noDev(ids))
      if (h == myId || wireIdShaped(h, room: room)) h,
  ];

  // whether a group or room of [n] people fits its cap
  Future<bool> _fitsCap(String groupId, int n, HaloDb db) async {
    if (n > kGroupMemberCap) return false;
    final cap = (await db.getGroup(groupId))?['member_cap'] as int?;
    return cap == null || n <= cap;
  }

  Future<void> _applyGroupControl(
    String senderHaloId,
    UnwrappedMessage env,
    HaloDb db,
  ) async {
    final gc = env.groupControl!;
    final groupId = env.groupId;
    if (groupId == null) return;
    // a group here already takes its controls from its admin alone; a
    // room's admin is its creator's key. leave speaks only for its sender
    final exists = await db.groupExists(groupId);
    final fromAdmin = exists && senderHaloId == await db.groupAdminId(groupId);
    switch (gc.type) {
      case 'join':
        // only ever valid off a room drop box, handled there
        return;
      case 'create':
        // someone added us to a new group. they are the admin; we are
        // a regular member. group.is_admin stays 0.
        if (gc.members == null || gc.name == null) return;
        if (exists && !fromAdmin) return;
        final isRoom = await _roomOf(groupId, db) != null;
        // a group from someone we never let in is a stranger's message
        // with a roster attached. rooms are ours: we opened the link.
        if (!isRoom &&
            !await db.isAccepted(senderHaloId) &&
            !await db.isVouched(senderHaloId)) {
          return;
        }
        var members = _members(gc.members!, room: isRoom);
        // a room key that left does not come back on a roster made before
        if (isRoom && exists) {
          final gone = await db.rosterGone(groupId);
          members = [
            for (final m in members)
              if (!gone.contains(m)) m,
          ];
        }
        if (!await _fitsCap(groupId, members.toSet().length, db)) return;
        // rosters can land out of order, a catch-up's most of all: one
        // older than the last taken changes nothing
        final stamp = gc.stamp;
        if (stamp != null && !await db.takeRosterStamp(groupId, stamp)) {
          dlog('group: an older roster, not taken');
          return;
        }
        if (!exists) {
          await db.createGroup(
            groupId,
            gc.name!,
            members,
            isAdmin: false,
            adminId: senderHaloId,
          );
        } else {
          // already in the group: reconcile the member list so a re-add or
          // membership change syncs instead of leaving a stale count.
          await db.syncGroupMembers(groupId, members);
          await db.renameGroup(groupId, gc.name!);
        }
        // auto-create contact stubs for unknown participants so we can
        // immediately send to them.
        if (gc.participants != null) {
          for (final p in gc.participants!) {
            final h = p['h'];
            final o = p['o'];
            final x = p['x'];
            if (h != null &&
                o != null &&
                x != null &&
                h != myId &&
                wireIdShaped(h, room: isRoom) &&
                !devCardClaim(id: h, xPub: x)) {
              await db.upsertContactStub(h, o, x);
            }
          }
        }
        await refreshContacts();
        await refreshGroups();
        break;
      case 'add':
        if (gc.members == null || !fromAdmin) return;
        final isRoom = await _roomOf(groupId, db) != null;
        final have = await db.getGroupMembers(groupId);
        final adds = {
          for (final h in _members(gc.members!, room: isRoom))
            if (!have.contains(h)) h,
        };
        if (!await _fitsCap(groupId, have.length + adds.length, db)) return;
        for (final h in adds) {
          await db.addGroupMember(groupId, h);
        }
        if (gc.participants != null) {
          for (final p in gc.participants!) {
            final h = p['h'];
            final o = p['o'];
            final x = p['x'];
            if (h != null &&
                o != null &&
                x != null &&
                h != myId &&
                wireIdShaped(h, room: isRoom) &&
                !devCardClaim(id: h, xPub: x)) {
              await db.upsertContactStub(h, o, x);
            }
          }
        }
        await refreshContacts();
        await refreshGroups();
        break;
      case 'remove':
        if (gc.members == null || !fromAdmin) return;
        // in a room this phone is its room key, never the kryfo id
        final room = await _roomOf(groupId, db);
        final me = room?.pub ?? myId;
        for (final h in gc.members!) {
          if (h != me) await db.removeGroupMember(groupId, h);
        }
        if (room != null) {
          await db.noteRosterGone(groupId, [
            for (final h in gc.members!)
              if (h != me) h,
          ]);
        }
        // taken out: the group goes from here with everything in it, as a
        // leave does, and an open screen says why it closed
        if (gc.members!.contains(me)) {
          final name = (await db.getGroup(groupId))?['name'] as String?;
          if (room != null) {
            await _destroyRoom(groupId, on: db);
          } else {
            await _dropGroup(groupId, db);
          }
          if (name != null) _removedFrom[groupId] = name;
          _bumpChatRev('group:$groupId');
        }
        await refreshGroups();
        break;
      case 'rename':
        if (gc.name == null || !fromAdmin) return;
        await db.renameGroup(groupId, gc.name!);
        await refreshGroups();
        break;
      case 'leave':
        await db.removeGroupMember(groupId, senderHaloId);
        // a room key never comes back once it left
        if (await _roomOf(groupId, db) != null) {
          await db.noteRosterGone(groupId, [senderHaloId]);
        }
        await refreshGroups();
        break;
    }
  }

  bool onboardingComplete = false;
  // this identity was moved to another device from here. set by the
  // export that moved it, never inferred. while set the engine never
  // starts, so nothing here can advance a ratchet the other device owns.
  bool _movedAway = false;
  bool get movedAway => !sessionQuiet && _movedAway;
  // the person chose to keep reading what was here. this session only.
  bool movedReadOnly = false;
  late AppLinks _appLinks;
  String myId = '';
  // who the screens show and write as: the everyday identity, or the
  // decoy's own while a decoy session is open. the decoy's never goes
  // online, so it is only ever shown
  QuietIdentity? _quiet;
  String get sessionId => sessionQuiet ? (_quiet?.id ?? '') : myId;
  String get sessionOnion => sessionQuiet ? (_quiet?.onion ?? '') : myOnion;
  String get sessionXPub =>
      sessionQuiet ? (_quiet?.xPub ?? '') : engine.myXPubkey();
  String get sessionEdPub =>
      sessionQuiet ? (_quiet?.edPub ?? '') : engine.myEdPubkey();
  // the link and QR code that say who you are
  Future<String> sessionInvite() async => sessionQuiet
      ? (_quiet?.invite ?? '')
      : buildHaloUriV3(myId, myOnion, fcCounter);

  // the decoy container: opened at start when the list names it, its
  // identity and invite built then, so a decoy unlock only changes what the
  // screens read
  HaloDb? _decoyDb;
  QuietIdentity? _decoyId;
  final Completer<void> _containersOpen = Completer<void>();
  Future<void> get containersReady => _containersOpen.future;
  @visibleForTesting
  void containersOpenedForTest() => _containersOpen.complete();
  // for the everyday session's own App lock screen
  bool get hasDecoy => !sessionQuiet && _decoyDb != null;
  // bumped when the screens change session: home starts over
  int sessionRev = 0;
  // what home shows of the session that is not open: read ahead, so an
  // unlock only swaps them in and every outcome shows at the same moment
  _Shown? _otherShown;

  Future<_Shown> _shownOf(Session s) async {
    final (list, pending, dev) = await _contactsOf(s);
    final a = await secureStore.read(key: s.container.key('my_avatar'));
    return _Shown(
      list,
      pending,
      await _groupsOf(s),
      int.tryParse(a ?? ''),
      dev,
    );
  }

  Future<void> _openContainers() async {
    try {
      final listed = await listedContainers();
      await sweepContainers(listed, pinTable: await pinTableKept());
      if (listed.contains(HaloContainer.decoy.id)) {
        final d = HaloDb(HaloContainer.decoy);
        final q = await _quietOf(d);
        if (q != null) {
          await _dropGroupLeftovers(d);
          _decoyDb = d;
          _decoyId = q;
          _otherShown = await _shownOf(Session(d));
        } else {
          await d.close();
        }
      }
    } catch (e) {
      dlog('containers: not opened ($e)');
    } finally {
      decoyReady = _decoyDb != null;
      if (!_containersOpen.isCompleted) _containersOpen.complete();
    }
  }

  // what the decoy's identity shows, from its own keys, with an invite on
  // its own signal store. nothing here touches the engine's identity
  Future<QuietIdentity?> _quietOf(HaloDb d) async {
    final raw = await d.open();
    final saved = await d.loadIdentity();
    // a restore made in the decoy leaves its onion key beside the database
    final left = File(
      p.join(
        (await getApplicationDocumentsDirectory()).path,
        'onion${d.container.suffix}.key',
      ),
    );
    if (await left.exists()) {
      final hex = (await left.readAsBytes())
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      await raw.insert('signal_meta', {
        'k': 'onion_key',
        'v': hex,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await shredFile(left.path);
    }
    final rows = await raw.query(
      'signal_meta',
      where: 'k = ?',
      whereArgs: ['onion_key'],
      limit: 1,
    );
    if (saved == null || rows.isEmpty) return null;
    final x = saved['x_priv']!;
    final q = engine.quietDescribe(
      saved['ed_priv']!,
      x,
      rows.first['v'] as String,
    );
    if (q == null) return null;
    final ss = SignalSession();
    final xb = _hexDecode(x);
    await ss.bootstrap(
      database: raw,
      xPubBytes: _hexDecode(q['x_pub'] as String),
      xPrivBytes: xb,
    );
    _zeroBytes(xb);
    final id = q['id'] as String;
    final onion = q['onion'] as String;
    final bundle = await makePreKeyBundleB64(ss);
    final fc = engine.quietFirstContactPk(x, 0);
    return QuietIdentity(
      id: id,
      edPub: q['ed_pub'] as String,
      xPub: q['x_pub'] as String,
      onion: onion,
      invite: fc.startsWith('error')
          ? 'kryfo://share?id=$id&onion=$onion&v=2&bundle=$bundle'
          : 'kryfo://share?id=$id&onion=$onion&v=3&bundle=$bundle&fc=$fc',
    );
  }

  // from the everyday session: a decoy that exists gets the new pin on its
  // own entry. otherwise a new container with an identity of its own,
  // registered nowhere, listed, and its pin entry written last. false when
  // the pin is in use: the screen says pick a different one
  Future<bool> setDecoyPin(String pin) async {
    if (sessionQuiet) return false;
    if (_decoyDb != null) return lockState.setupDecoyPin(pin);
    final d = HaloDb(HaloContainer.decoy);
    try {
      final q = engine.quietIdentity();
      if (q == null) throw StateError('no quiet identity');
      final raw = await d.open();
      await d.saveIdentity(
        q['id'] as String,
        q['ed_priv'] as String,
        q['x_priv'] as String,
      );
      await raw.insert('signal_meta', {
        'k': 'onion_key',
        'v': q['onion_key'] as String,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await listContainer(HaloContainer.decoy, true);
      final id = await _quietOf(d);
      if (id == null || !await lockState.setupDecoyPin(pin)) {
        await _dropDecoyFiles(d);
        return false;
      }
      _decoyDb = d;
      _decoyId = id;
      _otherShown = await _shownOf(Session(d));
      decoyReady = true;
      notifyListeners();
      return true;
    } catch (e) {
      // anything but a clash: nothing is left behind, and the flow says so
      dlog('decoy: not made ($e)');
      await _dropDecoyFiles(d);
      rethrow;
    }
  }

  // the pin entries first, then the list, then the files
  Future<void> removeDecoy() async {
    if (sessionQuiet) return;
    await lockState.clearDecoyPins();
    decoyReady = false;
    final d = _decoyDb ?? HaloDb(HaloContainer.decoy);
    _decoyDb = null;
    _decoyId = null;
    await _dropDecoyFiles(d);
    notifyListeners();
  }

  Future<void> _dropDecoyFiles(HaloDb d) async {
    await listContainer(HaloContainer.decoy, false);
    await d.close();
    await HaloContainer.decoy.wipeFiles();
    // its vault goes with it: its entry went with the decoy's pins
    await _host.wipeVault(HaloContainer.decoyVault);
  }

  // tests stand a fake in for the decoy container and its identity
  @visibleForTesting
  Future<void> useDecoyForTest(HaloDb d, QuietIdentity id) async {
    _decoyDb = d;
    _decoyId = id;
    _otherShown = await _shownOf(Session(d));
    decoyReady = true;
  }

  // ---- the vault: made, filled, emptied, gone ----

  // a vault just made, until its setup is done: its key, to move the picked
  // chats in. it is never a session
  HaloDb? _madeVault;
  // one change to the vault at a time
  Future<void> _vaultWork = Future<void>.value();
  // the chats being moved and the people they reach
  final Set<String> _moving = {};
  Completer<void>? _moveDone;
  // arrivals being filed, by sender and group, so a move starts after them
  final Map<String, int> _arriving = {};

  Future<T> _serial<T>(Future<T> Function() work) {
    final r = _vaultWork.then((_) => work());
    // the caller gets any error from r; the chain only keeps the order
    _vaultWork = r.then((_) {}, onError: (_) {});
    return r;
  }

  static List<ChatRef> _refs(
    Iterable<String> people,
    Iterable<String> groups,
  ) => [
    for (final id in {...people}) ChatRef(id),
    for (final id in {...groups}) ChatRef(id, group: true),
  ];

  // the everyday identity's vault: what arrives for its chats is routed by
  // the list. the decoy's takes nothing in, and nothing lists it
  static bool _everyday(HaloDb vault) => vault.container == HaloContainer.vault;

  // the database a vault extends
  HaloDb _primaryOf(HaloDb vault) {
    if (_everyday(vault)) return live;
    final d = _decoyDb;
    if (d == null) throw StateError('no decoy here');
    return d;
  }

  // the vault of the identity on screen: the decoy's in a decoy session
  HaloContainer get _ownVault =>
      sessionQuiet ? HaloContainer.decoyVault : HaloContainer.vault;

  // setup, once the pin is confirmed: the old vault goes first and the new
  // pin entry is written last. false when the pin is in use. the new vault
  // stays at hand for hideChats until vaultSetupDone. in a decoy session it
  // is the decoy's, and the everyday one is never touched. there a pin in
  // use is taken and kept nowhere, as every pin set in the decoy is: the
  // flow goes on as with any other, and what it hides no pin opens
  Future<bool> createVault(String pin) => _serial(() async {
    if (_session.vault != null) throw StateError('no vault setup from here');
    if (!_host.lockOn) throw StateError('no app lock');
    final c = _ownVault;
    await _destroy(c);
    final key = newVaultKey();
    try {
      final pub = await _host.makeVault(c, key);
      if (c == HaloContainer.vault) await _router.start(pub);
      if (await _host.putEntry(c, pin, key)) {
        _madeVault = HaloDb.withKey(c, key);
        return true;
      }
    } catch (e) {
      // the type only: an open error may quote the key
      dlog('vault: not made (${e.runtimeType})');
      await _unmake(c);
      rethrow;
    }
    await _unmake(c);
    return false;
  });

  // a vault no pin opens, with nothing listed: its key and files go
  Future<void> _unmake(HaloContainer c) async {
    try {
      if (c == HaloContainer.vault) await _router.retire();
      await _host.wipeVault(c);
    } catch (e) {
      dlog('vault: left for the next setup (${e.runtimeType})');
    }
  }

  // the setup flow is over, or the app locked during it: the new vault's
  // key goes
  Future<void> vaultSetupDone() => _serial(_dropMade);

  Future<void> _dropMade() async {
    final v = _madeVault;
    _madeVault = null;
    await v?.close();
  }

  // replace, or the lock turned off: the entry first, then the list (its
  // people stay as a drop list), the files last. never from inside a vault,
  // and only the identity on screen's
  Future<void> destroyVault() => _serial(() => _destroy(_ownVault));

  Future<void> _destroy(HaloContainer c) async {
    if (_session.vault != null) throw StateError('the vault is open');
    await _host.clearEntry(c);
    await _dropMade();
    if (c == HaloContainer.vault) {
      // what a move cut short left in the everyday folders goes with it
      await _repairMoves();
      await _router.forget();
      await _forgetPeers(_router.ids);
    }
    await _host.wipeVault(c);
  }

  // chats and groups into the vault, from the setup picker or from inside
  // the vault. requests, rooms and notes stay where they are. how many went
  Future<int> hideChats({
    Iterable<String> people = const [],
    Iterable<String> groups = const [],
  }) => _serial(() async {
    final v = _session.vault ?? _madeVault;
    if (v == null) throw StateError('no vault at hand');
    final chats = _refs(people, groups);
    if (chats.isEmpty) return 0;
    final went = await _move(v, chats, (m) => _hide(m, v, chats), out: false);
    // what could still name them outside the vault, and what they showed.
    // the decoy keeps no one outside and never shows anything
    if (_everyday(v)) {
      await _forgetPeers(_router.ids);
      if (went.isNotEmpty) {
        await _host.clearShade([
          for (final c in went) c.group ? 'group:${c.id}' : c.id,
        ]);
      }
    }
    await refreshContacts();
    await refreshGroups();
    return went.length;
  });

  // hidden chats back in the chat list, from inside the vault. how many
  // came back
  Future<int> unhideChats({
    Iterable<String> people = const [],
    Iterable<String> groups = const [],
  }) => _serial(() async {
    final v = _session.vault ?? _madeVault;
    if (v == null) throw StateError('no vault at hand');
    final chats = _refs(people, groups);
    if (chats.isEmpty) return 0;
    final n = await _move(v, chats, (m) => _unhide(m, v, chats), out: true);
    await refreshContacts();
    await refreshGroups();
    return n;
  });

  // remove hidden chats, from inside the vault: every chat it holds comes
  // back first, then the pin entry goes, then its key and files. a crash
  // part way leaves the rest hidden behind the same pin
  Future<void> removeVault() => _serial(() async {
    final v = _session.vault ?? _madeVault;
    if (v == null) throw StateError('no vault at hand');
    final everyday = _everyday(v);
    // every chat it holds, so each comes back alike: as the list names them
    // on the everyday side, as its own rows do on the decoy's
    final List<ChatRef> all;
    if (everyday) {
      await _attached(v, _recard);
      all = [for (final (id, g) in _router.hiddenChats) ChatRef(id, group: g)];
    } else {
      all = await _attached(
        v,
        (m) async => [
          for (final MapEntry(key: id, value: (kind, _))
              in (await m.vaultCards()).entries)
            ChatRef(id, group: kind == kHiddenGroup),
        ],
      );
    }
    await _move(v, all, (m) => _unhide(m, v, all), out: true);
    if (everyday) {
      // what is still listed the vault no longer holds: deleted inside it
      await _router.unlist([for (final (id, _) in _router.hiddenChats) id]);
    }
    await _host.clearEntry(v.container);
    if (everyday) await _router.retire();
    if (identical(_session.vault, v)) {
      _session = Session(_session.primary);
      lockState.inVault = false;
      _forgetVaultSide();
      _vaultShade.clear();
    }
    if (identical(_madeVault, v)) _madeVault = null;
    await v.close();
    await _host.wipeVault(v.container);
    await refreshContacts();
    await refreshGroups();
  });

  // for a vault just opened, before its session is built: its side of a
  // move a crash cut short is put right
  Future<void> settleVault(HaloDb vault) =>
      _serial(() => _attached(vault, (m) => _settle(m, vault)));

  // what receiving needs of the hidden chats, read again from the open
  // vault's rows
  Future<void> refreshHiddenCards() => _serial(() async {
    final v = _openVault;
    if (v != null) await _attached(v, _recard);
  });

  // at start-up, before anything can arrive
  Future<void> repairVaultMoves() => _serial(() => _repairMoves());

  Future<T> _attached<T>(
    HaloDb vault,
    Future<T> Function(ChatMover m) work,
  ) async {
    final m = _host.mover(_primaryOf(vault), vault);
    await m.attach();
    try {
      return await work(m);
    } finally {
      await m.detach();
    }
  }

  // what arrives for the moving chats waits, and a fault puts right what it
  // can before it is passed on. nothing arrives for the decoy's
  Future<T> _move<T>(
    HaloDb vault,
    List<ChatRef> chats,
    Future<T> Function(ChatMover m) work, {
    required bool out,
  }) async {
    final everyday = _everyday(vault);
    final primary = _primaryOf(vault);
    final m = _host.mover(primary, vault);
    await m.attach();
    final done = everyday ? Completer<void>() : null;
    if (done != null) _moveDone = done;
    try {
      if (everyday) {
        for (final c in chats) {
          _moving.add(c.id);
          if (c.group) _moving.addAll(await m.peopleIn(c, inVault: out));
        }
        // what is being filed for them lands first, and no unseal runs
        // while rows move
        while (_unsealing || _arriving.keys.any(_moving.contains)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }
      await _settle(m, vault);
      return await work(m);
    } catch (e) {
      dlog('vault: move cut short (${e.runtimeType})');
      try {
        if (everyday) {
          await _router.load();
          await _repairMoves(m);
        }
        await _settle(m, vault);
      } catch (_) {
        // the next start and the next open put it right
      }
      rethrow;
    } finally {
      try {
        await m.detach();
      } catch (e) {
        // attached to this connection until the next start opens a new one
        dlog('vault: not detached (${e.runtimeType})');
      }
      if (identical(_session.vault, vault)) {
        try {
          final rebuilt = await Session.withVault(primary, vault);
          // a lock that shut the vault meanwhile keeps it shut
          if (identical(_session.vault, vault)) _session = rebuilt;
        } catch (e) {
          dlog('vault: session not rebuilt (${e.runtimeType})');
        }
      }
      if (done != null) {
        _moving.clear();
        _moveDone = null;
        done.complete();
      }
    }
  }

  Future<void> _afterMove(String sender, String? groupId) async {
    while (true) {
      final done = _moveDone;
      if (done == null) return;
      final g = groupId != null && groupId.isNotEmpty ? groupId : null;
      if (!_moving.contains(sender) && (g == null || !_moving.contains(g))) {
        return;
      }
      await done.future;
    }
  }

  Future<List<ChatRef>> _hide(
    ChatMover m,
    HaloDb vault,
    List<ChatRef> chats,
  ) async {
    final everyday = _everyday(vault);
    final from = _primaryOf(vault).container;
    var marks = await m.marks();
    final went = <ChatRef>[];
    for (final c in chats) {
      // the developer chat is never hidden
      if (isDevChat(c.id) || !await m.hideable(c)) continue;
      marks = marks.hiding(c);
      await m.copyIn(c, marks);
      if (everyday) {
        // the commit point: from here what arrives for it goes to the vault
        final files = await m.commitIn(
          c,
          DateTime.now().millisecondsSinceEpoch,
        );
        await _router.load();
        await _placeFiles(files, from, vault.container);
        await _router.settle(c.id);
      } else {
        // no list: the commit point is the chat leaving the decoy's
        // database, and the vault's next open puts right what a crash
        // leaves after it
        final files = await m.vaultFiles(c);
        await m.dropLive(c);
        await _placeFiles(files, from, vault.container);
      }
      marks = marks.done(c);
      await m.putMarks(marks);
      _bumpChatRev(c.group ? 'group:${c.id}' : c.id);
      went.add(c);
    }
    if (everyday) await _recard(m);
    return went;
  }

  Future<int> _unhide(ChatMover m, HaloDb vault, List<ChatRef> chats) async {
    final everyday = _everyday(vault);
    final to = _primaryOf(vault).container;
    var marks = await m.marks();
    var n = 0;
    for (final c in chats) {
      if (everyday && !_router.hides(c.id)) continue;
      if (!await m.held(c)) continue;
      marks = marks.showing(c);
      await m.putMarks(marks);
      // the files go first, flagged on the list entry, so a start-up before
      // the commit puts them back. the decoy's next open does it there
      final files = await m.vaultFiles(c);
      if (everyday) await _router.markBack(c.id, files);
      await _placeFiles(files, vault.container, to);
      // the commit point: from here it shows without the vault again
      await m.commitOut(c);
      if (everyday) await _router.load();
      marks = marks.done(c);
      await m.dropVault(c, marks);
      _bumpChatRev(c.group ? 'group:${c.id}' : c.id);
      n++;
    }
    if (everyday) await _recard(m);
    return n;
  }

  // every chat the vault holds listed, with a card from its rows
  Future<void> _recard(ChatMover m) async =>
      _router.recard(await m.vaultCards());

  // the vault's side of a move cut short: a hide that never reached its
  // commit, or an unhide past it, left a copy in the vault, which goes. the
  // list says which on the everyday side; on the decoy's, whether its
  // database still holds the chat, and the files follow the rows
  Future<void> _settle(ChatMover m, HaloDb vault) async {
    final everyday = _everyday(vault);
    final primary = _primaryOf(vault);
    if (everyday) await _router.load();
    var left = await m.marks();
    if (left.isEmpty) return;
    for (final c in [...left.inbound, ...left.outbound]) {
      left = left.done(c);
      final hidden = everyday ? _router.hides(c.id) : !await _holds(primary, c);
      if (hidden) {
        if (!everyday) {
          await _placeFiles(
            await m.vaultFiles(c),
            primary.container,
            vault.container,
          );
        }
        await m.putMarks(left);
        continue;
      }
      await _placeFiles(
        await m.vaultFiles(c),
        vault.container,
        primary.container,
      );
      await m.dropVault(c, left);
    }
  }

  // the database holds the chat as one: an added person, or the group
  static Future<bool> _holds(HaloDb d, ChatRef c) async => c.group
      ? await d.groupExists(c.id)
      : (await d.getContact(c.id))?['accepted'] == 1;

  // a move cut short, as its list entry's flags say: the chat's everyday
  // rows go and its files into the vault's folders
  Future<void> _repairMoves([ChatMover? mover]) async {
    final pending = _router.pending;
    if (pending.isEmpty) return;
    final m = mover ?? _host.mover(live, null);
    if (mover == null) await m.attach();
    try {
      for (final p in pending) {
        final c = ChatRef(p.chatId, group: p.group);
        if (p.hid) await m.dropLive(c);
        await _placeFiles(p.files, live.container, HaloContainer.vault);
        await _router.settle(p.chatId);
      }
    } finally {
      if (mover == null) await m.detach();
    }
  }

  // each file into the folders its rows are in now. one already there wins
  // and the other is shredded
  Future<void> _placeFiles(
    List<String> names,
    HaloContainer from,
    HaloContainer to,
  ) async {
    for (final n in names) {
      final src = await chatFilePath(n, from);
      final dst = await chatFilePath(n, to);
      if (src == null || dst == null || !await File(src).exists()) continue;
      if (await File(dst).exists()) {
        await _host.shred(src);
      } else {
        await _host.moveFile(src, dst);
      }
    }
  }

  // the people the vault keeps, out of what the everyday side keeps on disk
  // about reaching someone: first-contact keys and the listen cache
  Future<void> _forgetPeers(Set<String> ids) async {
    if (ids.isEmpty) return;
    const st = secureStore;
    var fc = false;
    for (final id in ids) {
      if (_peerFc.remove(id) != null) fc = true;
    }
    if (fc && !_peerFcUnread) {
      await st.write(key: 'peer_fc', value: jsonEncode(_peerFc));
    }
    try {
      final raw = await st.read(key: 'xpub_cache');
      if (raw == null || raw.isEmpty) return;
      final cache = Map<String, Object?>.from(jsonDecode(raw) as Map);
      final before = cache.length;
      cache.removeWhere((_, v) => ids.contains(v));
      if (cache.length != before) {
        await st.write(key: 'xpub_cache', value: jsonEncode(cache));
      }
    } catch (e) {
      dlog('xpub cache: $e');
    }
  }

  // an unlock's outcome, under the lock screen before it lifts: the screens
  // get the session the pin opened, and every screen of the other one goes
  Future<void> sessionFor(PinResult r, {String? vaultKey}) async {
    // a vault left open by a lock that never reached the screen shuts first
    _shutVault();
    // and what home shows after one shut is read again before anything
    await _listsBack;
    if (vaultKey != null && r == PinResult.vault) {
      return _openVaultSession(HaloContainer.vault, vaultKey);
    }
    // the decoy's own vault comes with the decoy's outcome
    if (vaultKey != null && r == PinResult.decoy) {
      return _openVaultSession(HaloContainer.decoyVault, vaultKey);
    }
    final decoy = r == PinResult.decoy;
    final want = decoy ? _decoyDb : live;
    if (want == null) return;
    lockState.inDecoy = decoy;
    if (identical(_session.primary, want)) return;
    // no reads here: what home shows of the other session was read ahead,
    // and swapping it in costs the same whichever way it goes
    final leaving = _Shown(
      contacts,
      pendingCount,
      groups,
      _quietAvatar,
      devRow,
    );
    final coming = _otherShown;
    _otherShown = leaving;
    _session = Session(want);
    _quiet = decoy ? _decoyId : null;
    if (coming != null) {
      contacts = coming.contacts;
      pendingCount = coming.pending;
      devRow = coming.dev;
      groups = coming.groups;
      if (decoy) _quietAvatar = coming.avatar;
    }
    if (decoy) {
      _quietSince = DateTime.now().millisecondsSinceEpoch;
      _quietJobs = _jobRuns;
    }
    expiredRoomName = null;
    renewRootNavigator();
    sessionRev++;
    notifyListeners();
    // the new home is built now, still under the lock, so it comes up as
    // settled as the everyday one. when it shows is still verifyPin's wait,
    // the same for every outcome
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(milliseconds: 250),
      onTimeout: () {},
    );
    // once the lock is gone, off the clock: what was already in the shade
    // was already seen and goes, and the lists are read again for real. a
    // call into android here would hold the main thread, and dart with it,
    // and the decoy would show later than the everyday app does
    unawaited(
      Future.delayed(_afterReveal, () async {
        if (decoy) await cancelWithRetry(notifPlugin.cancelAll, 'decoy shade');
        await refreshContacts();
        await refreshGroups();
      }),
    );
  }

  // once the lock is gone and its fade is over
  Duration get _afterReveal =>
      revealGap ?? lockState.revealAfter + const Duration(milliseconds: 300);
  @visibleForTesting
  Duration? revealGap;

  // a vault's pin: its identity's app with its hidden chats, the everyday
  // one's or the decoy's. its key is wrapped, so nothing of it could be read
  // ahead: it opens here, under the lock, and its lists are read before the
  // same deadline as any other outcome. it throws when the vault will not
  // open, and the lock then opens the session the vault extends
  Future<void> _openVaultSession(HaloContainer c, String key) async {
    final decoy = c == HaloContainer.decoyVault;
    final primary = decoy ? _decoyDb : live;
    if (primary == null) throw StateError('no decoy here');
    final v = await _host.openVault(c, key);
    final Session s;
    final (List<ContactPreview>, int, DevRow?) home;
    final List<GroupPreview> gs;
    try {
      // a move a crash cut short is put right before ownership is read
      await settleVault(v);
      await _dropGroupLeftovers(v);
      s = await Session.withVault(primary, v);
      home = await _contactsOf(s);
      gs = await _groupsOf(s);
    } catch (e) {
      try {
        await v.close();
      } catch (_) {
        // its key went with the close; the open error is the one passed on
      }
      rethrow;
    }
    if (decoy) {
      // from the everyday side: its lists wait as if read ahead, and the
      // decoy's face is the one read ahead for it, as at a decoy unlock
      if (!sessionQuiet) {
        final ahead = _otherShown;
        _otherShown = _Shown(
          contacts,
          pendingCount,
          groups,
          _quietAvatar,
          devRow,
        );
        if (ahead != null) _quietAvatar = ahead.avatar;
        _quietSince = DateTime.now().millisecondsSinceEpoch;
        _quietJobs = _jobRuns;
      }
    } else if (sessionQuiet) {
      // from the decoy: its lists wait for its next unlock, as if read ahead
      _otherShown = _Shown(
        contacts,
        pendingCount,
        groups,
        _quietAvatar,
        devRow,
      );
    }
    lockState.inDecoy = decoy;
    _session = s;
    _quiet = decoy ? _decoyId : null;
    contacts = home.$1;
    pendingCount = home.$2;
    devRow = home.$3;
    groups = gs;
    _vaultFill = (at: 0, to: 0);
    lockState.inVault = true;
    expiredRoomName = null;
    renewRootNavigator();
    sessionRev++;
    notifyListeners();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(milliseconds: 250),
      onTimeout: () {},
    );
    unawaited(
      Future.delayed(
        _afterReveal,
        () => decoy ? _decoyVaultShown(v) : _vaultShown(v),
      ),
    );
  }

  // the decoy's, after the reveal and off the clock: the shade goes as at
  // any decoy unlock, and so do its timers that ran out while it was shut.
  // nothing is sealed to it and nothing in it sends
  Future<void> _decoyVaultShown(HaloDb v) async {
    if (!identical(_session.vault, v)) return;
    await cancelWithRetry(notifPlugin.cancelAll, 'decoy shade');
    try {
      await v.purgeExpired();
      await refreshContacts();
      await refreshGroups();
    } catch (e) {
      if (identical(_session.vault, v)) {
        dlog('vault: after open (${e.runtimeType})');
      }
    }
  }

  // after the reveal, off the clock
  Future<void> _vaultShown(HaloDb v) async {
    if (!identical(_openVault, v)) return;
    try {
      // its timers that ran out while it was shut go now
      await v.purgeExpired();
      await refreshContacts();
      await refreshGroups();
      // the list names every chat it holds, whatever the last close left
      await refreshHiddenCards();
      // what came sealed while it was shut
      await _unseal();
      unawaited(_fillSearch(v));
      // what was typed in it and never went, and files half arrived
      unawaited(drainOutbox());
      unawaited(askForMissingSlices());
    } catch (e) {
      if (identical(_openVault, v)) {
        dlog('vault: after open (${e.runtimeType})');
      }
    }
  }

  // payloads of what hidden chats showed in the shade while their vault was
  // open, taken down when it shuts
  final Set<String> _vaultShade = {};
  // set while a vault that just shut is given back: arrivals wait for the
  // list it leaves, so none lands on the everyday side
  Completer<void>? _closeDone;
  // home's lists read again once a vault shut, before any unlock shows them
  Future<void> _listsBack = Future<void>.value();

  // the lock is going up: a vault session shuts at once, and the key of a
  // vault made by a setup that did not finish goes
  void lockingUp() {
    unawaited(
      vaultSetupDone().catchError((Object e) {
        dlog('vault: setup key (${e.runtimeType})');
      }),
    );
    _shutVault();
  }

  // the session the vault extends is back before anything reads again. the
  // everyday vault's handle stays with its close until what it took in has
  // landed and the list names everyone in it. the decoy's takes nothing in
  void _shutVault() {
    final was = _session;
    final v = was.vault;
    if (v == null) return;
    final everyday = _everyday(v);
    final done = Completer<void>();
    if (everyday) _closeDone = done;
    _session = Session(was.primary);
    lockState.inVault = false;
    _forgetVaultSide();
    // its chats off home now; the rest is read again below
    contacts = [
      for (final c in contacts)
        if (!was.isHidden(c.haloId)) c,
    ];
    groups = [
      for (final g in groups)
        if (!was.isHidden(g.groupId)) g,
    ];
    expiredRoomName = null;
    renewRootNavigator();
    sessionRev++;
    notifyListeners();
    _listsBack = () async {
      try {
        await refreshContacts();
        await refreshGroups();
      } catch (e) {
        dlog('lists after the vault: $e');
      }
    }();
    unawaited(everyday ? _closeVault(v, done) : _closeDecoyVault(v));
  }

  // once a move under way is done, and its key goes with the handle
  Future<void> _closeDecoyVault(HaloDb v) async {
    try {
      await _serial(v.close);
    } catch (e) {
      dlog('vault: close (${e.runtimeType})');
    }
  }

  // what the session kept of the vault beside its handle
  void _forgetVaultSide() {
    _sealKey = null;
    _sealKeyOf = null;
    _vq = _Queue.none;
    _vaultFill = (at: 0, to: 0);
    _showFill();
  }

  Future<void> _closeVault(HaloDb v, Completer<void> done) async {
    try {
      await _serial(() async {
        // what is being filed into it, or opened from the seal, lands first
        final until = DateTime.now().add(const Duration(seconds: 10));
        while ((_unsealing || _arriving.isNotEmpty) &&
            DateTime.now().isBefore(until)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        try {
          await _attached(v, _recard);
        } catch (e) {
          dlog('vault: cards left as they were (${e.runtimeType})');
        }
        await v.close();
      });
    } catch (e) {
      dlog('vault: close (${e.runtimeType})');
    } finally {
      if (identical(_closeDone, done)) _closeDone = null;
      done.complete();
    }
    // what its chats showed in the shade goes with it
    final shown = [..._vaultShade];
    _vaultShade.clear();
    for (final p in shown) {
      await cancelWithRetry(() => _io.unnotify(p), 'vault shade');
    }
  }

  String myOnion = '';
  List<GroupPreview> groups = [];
  bool restored = false;
  bool ready = false;
  bool _booting = false;
  // bumped whenever something changes for a peer's thread. open chats
  // compare against this instead of reloading on every notify.
  final Map<String, int> _chatRev = {};
  int chatRevOf(String haloId) => _chatRev[haloId] ?? 0;
  void _bumpChatRev(String haloId) {
    _chatRev[haloId] = (_chatRev[haloId] ?? 0) + 1;
  }

  // a chat's rows changed from outside it: an upload that a screen since
  // closed started, finishing. whichever screen shows the chat now re-reads.
  void chatChanged(String haloId) {
    _bumpChatRev(haloId);
    notifyListeners();
  }

  bool _draining = false;
  bool _polling = false;
  TorStatus _torStatus = TorStatus.off;
  int _bootstrapPct = 0;
  TorStatus get torStatus => _torStatus;
  @visibleForTesting
  void setTorStatusForTest(TorStatus s) {
    _torStatus = s;
    notifyListeners();
  }

  @visibleForTesting
  void setRouteOKForTest(bool ok) {
    _routeOK = ok;
    notifyListeners();
  }

  @visibleForTesting
  void setRouteGenForTest(int gen) {
    _routeGen = gen;
    notifyListeners();
  }

  // whether the route carries traffic, from the engine's relay verdict, and
  // how many times it has been torn down on purpose. see engine/route.go.
  bool _routeOK = true;
  int _routeGen = 0;
  bool get routeOK => _routeOK;
  int get routeGen => _routeGen;

  // called from the status poll. the clock runs while tor is trying and
  // resets the moment it can carry traffic.
  void _noteTorProgress(DateTime now) {
    // the relay rows carry the only live signal: fails counts failures since
    // that relay's last success and is cleared the moment one lands.
    try {
      final tx = engine.transportState();
      _noteRelayHealth(tx['relays'] as List?, now: now);
    } catch (_) {
      // transport not readable yet: nothing to conclude
    }
    // only a climb past the best of this try is progress: a route torn down
    // that climbs back to where it stuck has not moved
    if (_bootstrapPct > _pctBest) {
      _pctBest = _bootstrapPct;
      _pctMovedAt = now;
    }
    if (torReady) {
      _torTryingSince = null;
      _pctBest = -1;
    } else {
      _torTryingSince ??= now;
    }
  }

  // what the home screen was last told about the two bridge cards
  (bool, bool) _bridgeHintsShown = (false, false);

  // a route the person changed starts a try of its own: bridges, the mode, a
  // reconnect, another network. the last try's best and clock say nothing
  // about it. the engine's own rescue is not one and keeps them
  bool _torTryNew = false;
  void _newTorTry() => _torTryNew = true;

  // tor torn down and started again on purpose
  void restartTor() {
    engine.restartTor();
    _newTorTry();
  }

  // tor's status as the poll reads it each second. the bridge cards turn on
  // by time alone, so a change in them is announced too
  @visibleForTesting
  TorStatus takeTorStatus(String raw, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final fresh = _torTryNew;
    _torTryNew = false;
    if (fresh) {
      _pctBest = -1;
      _pctMovedAt = at;
    }
    final st = parseTorStatus(raw);
    final pct = parseBootstrapPct(raw);
    final rok = parseRouteOK(raw);
    final rgen = parseRouteGen(raw);
    var changed = false;
    if (st != _torStatus ||
        pct != _bootstrapPct ||
        rok != _routeOK ||
        rgen != _routeGen) {
      _torStatus = st;
      _routeOK = rok;
      _routeGen = rgen;
      _bootstrapPct = pct;
      _noteTorProgress(at);
      changed = true;
    }
    if (fresh) _torTryingSince = torReady ? null : at;
    final hints = (suggestBridgesAt(at), suggestBridgesOffAt(at));
    if (hints != _bridgeHintsShown) {
      _bridgeHintsShown = hints;
      changed = true;
    }
    if (changed) notifyListeners();
    return st;
  }

  // the one test the outbox, the transport screen and the ui share; mirrors
  // torReadyNow() in the engine. outside onion nothing waits on a bootstrap.
  // it does not ask for a network: linkUp does
  bool get torReady => _sendMode != 'private' || torUsable;

  // tor can carry traffic. "reachable" is the end of publishing, not the
  // start of being usable. tor's word is not enough on its own: it can say
  // publishing while every relay connection through it fails, so this also
  // needs the engine's verdict that a relay has connected since the route
  // was last torn down, and that they are not all failing now.
  bool get torUsable =>
      _routeOK &&
      (_torStatus == TorStatus.bootstrapped ||
          _torStatus == TorStatus.publishing ||
          _torStatus == TorStatus.reachable);
  int get bootstrapPct => _bootstrapPct;

  // what every screen means by connected: a network, and the route the send
  // mode uses can carry traffic. connecting is that route not up yet while
  // something is still trying to bring it up
  bool get linkUp => _online && torReady;
  bool get linkComing => !torReady && _torStatus != TorStatus.off;

  // a reloaded 'sending' row has no send future left to resolve it, so past
  // a minute it is dead and becomes retryable. while tor warms up it is
  // queued, not dead: the reconnect retry fires it. torReady rather than
  // reachable, since an onion that will not publish never reaches
  // 'reachable'. a file still going out is never dead: its row is saved
  // before the first slice leaves, however long the rest takes. the one
  // rule for every chat screen
  bool sendLooksDead(DateTime sentAt, {String? msgUid, DateTime? now}) =>
      torReady &&
      (msgUid == null || !mediaInflight.contains(msgUid)) &&
      sentAt.isBefore(
        (now ?? DateTime.now()).subtract(const Duration(seconds: 60)),
      );

  // how long tor has been unable to carry traffic while kryfo is meant to be
  // connected. null when it is fine, when check-ins are holding tor off on
  // purpose, or when nothing has started trying yet. five minutes of this
  // and the home screen says so. it watches tor's own status; dropping wifi
  // does not make tor report off, and plain loss of network has its own
  // strip.
  Duration? get offlineFor => offlineDurationFor(
    mode: _deliveryMode,
    torHeld: _torHeld || haloWiping,
    torReady: torReady,
    tryingSince: _torTryingSince,
    now: DateTime.now(),
  );

  static const offlineAfter = Duration(minutes: 5);

  bool get looksOffline => (offlineFor ?? Duration.zero) >= offlineAfter;
  // when tor first started trying this session. a network that
  // blocks tor looks exactly like a slow one for the first
  // minute or two, so we wait before suggesting anything.
  DateTime? _torTryingSince;
  bool _bridgeHintOff = false;
  // when the bootstrap percentage last moved. a climbing bar is a slow
  // network; a stuck one under half way is a blocked one.
  int _pctBest = -1;
  DateTime? _pctMovedAt;

  bool _torLooksBlockedAt(DateTime now) {
    if (_sendMode != 'private') return false;
    if (torReady) return false;
    final t = _torTryingSince;
    if (t == null) return false;
    // still early: give it room before calling anything wrong
    if (now.difference(t).inSeconds < 120) return false;
    // it is climbing, just not quickly. that is a slow network, not a wall.
    final moved = _pctMovedAt;
    if (moved != null && now.difference(moved).inSeconds < 90) {
      return false;
    }
    // past halfway it is talking to the network fine and something else is
    // wrong. blocking bites at the start, not the end.
    return _bootstrapPct < 50;
  }

  bool get suggestBridges => suggestBridgesAt(DateTime.now());

  @visibleForTesting
  bool suggestBridgesAt(DateTime now) {
    if (_bridgeHintOff || _bridgesOn || !_online) return false;
    return _torLooksBlockedAt(now);
  }

  // our relay is not answering and it is the only one relay mode uses.
  DateTime? _relayDownSince;
  bool _relayHintOff = false;

  bool get suggestFastFallback => suggestFastFallbackAt(DateTime.now());

  @visibleForTesting
  bool suggestFastFallbackAt(DateTime now) {
    if (_relayHintOff || _sendMode != 'balanced' || !_online) return false;
    final t = _relayDownSince;
    if (t == null) return false;
    return now.difference(t).inSeconds > 90;
  }

  // what the home screen was last told about the relay hint
  bool _fastHintShown = false;

  // relay mode's read of its relay, on its own clock: tor sits still in that
  // mode, so a read taken only when tor changes misses an outage and keeps a
  // stale one. the hint turns on by time alone, so a change is announced
  @visibleForTesting
  void sampleRelayHealth({DateTime? now}) {
    final at = now ?? DateTime.now();
    try {
      _noteRelayHealth(engine.transportState()['relays'] as List?, now: at);
    } catch (_) {
      // transport not readable yet: nothing to conclude
    }
    final v = suggestFastFallbackAt(at);
    if (v != _fastHintShown) {
      _fastHintShown = v;
      notifyListeners();
    }
  }

  Future<void> dismissRelayHint() async {
    _relayHintOff = true;
    notifyListeners();
  }

  // fed by the transport poll. not sub_count: that counts peer subscriptions,
  // not relay connections. a relay row's fails counts failures since that
  // relay's last success and is deleted the moment one lands, so it says
  // what is true now. benched means it is in backoff. down is: nothing in
  // the list is usable.
  void _noteRelayHealth(List? relays, {DateTime? now}) {
    if (_sendMode != 'balanced') {
      _relayDownSince = null;
      return;
    }
    // no rows yet: the engine has not been configured, which is not the
    // same as a relay that will not answer
    if (relays == null || relays.isEmpty) {
      _relayDownSince = null;
      return;
    }
    final anyUsable = relays.any((r) {
      if (r is! Map) return true;
      final fails = (r['fails'] as num?)?.toInt() ?? 0;
      return fails == 0 && r['benched'] != true;
    });
    if (anyUsable) {
      _relayDownSince = null;
    } else {
      _relayDownSince ??= now ?? DateTime.now();
    }
  }

  bool get suggestBridgesOff => suggestBridgesOffAt(DateTime.now());

  @visibleForTesting
  bool suggestBridgesOffAt(DateTime now) {
    if (!_bridgesOn || !_online) return false;
    return _torLooksBlockedAt(now);
  }

  Future<void> dismissBridgeHint() async {
    _bridgeHintOff = true;
    await secureStore.write(key: 'bridge_hint_off', value: '1');
    notifyListeners();
  }

  bool _online = true;
  bool get online => _online;
  List<ContactPreview> contacts = [];
  int pendingCount = 0;
  // the developer chat, beside the contacts and never among them
  DevRow? devRow;

  // ---- the developer's own phone ----

  // the everyday identity's key, and whether it is a pinned one that still
  // works: read once, as the identity loads. only the private key makes it
  String _myXPub = '';
  bool _devIdentity = false;
  String get myXPub => _myXPub;
  set myXPub(String x) {
    _myXPub = x;
    _devIdentity = devModeOf(x);
  }

  // developer mode: his own phone, never in a decoy session
  bool get devMode => _devIdentity && !sessionQuiet;

  // support chats with no answer yet, for the home pin
  int supportWaiting = 0;

  // the support inbox and its notifications
  final SupportBell _bell;
  final Map<String, String> _xPubToHaloId = {};
  // peers waiting on a bundle swap, and when a bundle control last went to
  // each. both forget anything older than an hour so they cannot grow with
  // every peer ever seen
  final Map<String, int> _healPending = {};
  final Map<String, int> _bundleCtlSentAt = {};
  static const _healTtl = 60 * 60 * 1000;
  void _pruneHeal() {
    final cut = DateTime.now().millisecondsSinceEpoch - _healTtl;
    _healPending.removeWhere((_, t) => t < cut);
    _bundleCtlSentAt.removeWhere((_, t) => t < cut);
  }

  void _wantHeal(String peer) {
    _pruneHeal();
    _healPending[peer] = DateTime.now().millisecondsSinceEpoch;
  }

  final Map<String, int> _decryptFails = {};

  // relay backlog replays any cipher we can't land on every reconnect. give
  // it 3 lifetime chances (a session may still be forming), then mark it
  // seen so it stops bad-mac spamming every contact on every poll.
  void _strikeUndecryptable(String h, String lane) {
    final tries = (_decryptFails[h] ?? 0) + 1;
    _decryptFails[h] = tries;
    if (tries >= 3) {
      _decryptFails.remove(h);
      unawaited(live.markSeenLong(h));
      dlog('$lane: buried undecryptable after $tries tries');
    } else if (_decryptFails.length > 512) {
      _decryptFails.clear();
    }
  }

  // when an unknown sender's PreKey message arrives via
  // direct onion, decrypt under a placeholder peerId, then verify the
  // sender's claimed identity (via envelope) and move the libsignal
  // session to the real HaloID. someone the router keeps is filed by the
  // router, never as an everyday request. the id and where it went
  Future<(String, RouteTo)?> backPairFromCipher(String cipher) async {
    try {
      final opened = await _io.openFirstContact(cipher);
      if (opened == null) return null;
      var h = opened.haloId;
      final env = opened.env;
      // the developer never starts a chat this way, and no one else may
      // claim to be him
      if (devCardClaim(id: h, xPub: env.senderXPub)) return null;
      await _afterClose();
      if (_moveDone != null) await _afterMove(h, null);
      // a hidden chat's name stays with its key as well
      if (h == env.senderHaloId && await _hiddenKeyDiffers(h, env)) {
        final at = await _refileFirstContact(h);
        if (at == null) return null;
        h = at;
      }
      final to = _routeOf(h, null);
      // persist contact + nostr sub. a stranger who back-paired to us lands
      // unaccepted: their message waits in requests until we accept. while
      // the vault is shut its people are filed when it opens
      HaloDb? filed;
      var fresh = false;
      if (to == RouteTo.everyday || to == RouteTo.vault) {
        final db = to == RouteTo.vault ? _openVault! : live;
        filed = db;
        fresh = await db.getContact(h) == null;
        await db.upsertContact(
          h,
          env.senderOnion ?? '',
          env.senderXPub ?? '',
          accepted: 0,
        );
        // filed on its own: the request says the name it gave
        final said = env.senderHaloId;
        if (said != null && said != h) await _noteOtherKey(db, h, said);
      }
      final x = env.senderXPub;
      final heardAs = x == null ? null : _xPubToHaloId[x];
      if (to != RouteTo.dropped && x != null && x.isNotEmpty) {
        _xPubToHaloId[x] = h;
        _io.listen(x);
      }
      var went = to;
      try {
        went = await _applyIncomingPayload(
          h,
          env,
          wire: opened.plain,
          fromBackPair: true,
        );
      } on CapHeld {
        // the row exists now; the relay replays this after accept
      } on _NoProof {
        // the session it opened goes, so nothing later from it opens
        // without the proof, and a row it made goes with it
        await _io.dropSession(h);
        if (fresh) {
          await filed?.forgetRequest(h);
          // the address it was heard on goes too, unless someone here has it
          if (x != null && x.isNotEmpty && _xPubToHaloId[x] == h) {
            if (heardAs == null) {
              _xPubToHaloId.remove(x);
              _io.unlisten(x);
            } else {
              _xPubToHaloId[x] = heardAs;
            }
          }
        }
        return (h, RouteTo.dropped);
      }
      if (_shown(went)) {
        await refreshContacts();
        notifyListeners();
        await forgetPeerFc(h);
      }
      dlog('back-pair: done for $h');
      return (h, went);
    } catch (e) {
      dlog('back-pair error: $e');
      return null;
    }
  }

  // whether a hidden chat holds [id] with a key other than the one this
  // first contact gives
  Future<bool> _hiddenKeyDiffers(String id, UnwrappedMessage env) async {
    final card = _router.cardOf(id);
    final held = card != null
        ? _rowIdentity({'xpub': card.xpub})
        : _rowIdentity(await _openVault?.getContact(id));
    if (held == null) return false;
    final given = _rowIdentity({'xpub': env.senderXPub ?? ''});
    return given == null || !_eqBytes(held, given);
  }

  // a request filed on its own id says which name it gave, once
  Future<void> _noteOtherKey(HaloDb db, String id, String said) async {
    final hit = ShieldHit('other_key', said).toJson();
    await db.setShield(id, jsonEncode(hit), [hit]);
    _shieldRev++;
  }

  // a vault that just shut: nothing is opened or filed until the list it
  // leaves names everyone it took in while it was open
  Future<void> _afterClose() async {
    final closing = _closeDone;
    if (closing != null) await closing.future;
  }

  // the ids the router keeps and the people the open vault holds: tried
  // like contacts, never filed as everyday requests
  Set<String> _keptIds() => {
    ..._router.ids,
    ..._moving,
    if (_openVault != null) ..._session.hiddenPeople,
  };

  // a message tried under everyone who may have sent it: everyday contacts,
  // then everyday requests, then the kept ids. never the screen's list,
  // which belongs to whichever session is open
  Future<({String id, String plain})?> _openKnown(
    String cipher, {
    String? skip,
  }) async {
    await _afterClose();
    final tried = <String>{?skip};
    Future<({String id, String plain})?> under(Iterable<String> ids) async {
      for (final id in ids) {
        // never the dev chat: only its own lanes carry the developer
        if (isDevId(id) || !tried.add(id)) continue;
        final p = await _io.decrypt(id, cipher);
        if (p != null) return (id: id, plain: p);
      }
      return null;
    }

    return await under([
          for (final r in await live.contacts()) r['halo_id'] as String,
        ]) ??
        await under([
          for (final r in await live.pendingRequests()) r['halo_id'] as String,
        ]) ??
        await under(_keptIds());
  }

  // a peer we deleted keeps its session but loses its contact row, so the
  // tries above skip it. their next message is a plain whisper back-pair
  // can't rebuild: try any sessioned address that is not an everyday
  // contact or kept by the router, to re-file it as a fresh request
  Future<({String id, String plain})?> _openParked(String cipher) async {
    await _afterClose();
    final skip = {
      for (final r in await live.contacts()) r['halo_id'] as String,
      ..._keptIds(),
      '_pending_back_pair_',
    };
    for (final addr in await _io.sessionAddresses()) {
      // a deleted dev chat stays deleted, whatever session is left
      if (skip.contains(addr) || isDevId(addr)) continue;
      final p = await _io.decrypt(addr, cipher);
      if (p == null) continue;
      // and a peer let go does not come back as the developer
      if (devCardClaim(id: addr, xPub: unwrapMessage(p).senderXPub)) {
        return null;
      }
      return (id: addr, plain: p);
    }
    return null;
  }

  // listen for everyone who can write: accepted contacts, people a friend
  // introduced and strangers in requests, and the people of the hidden
  // chats. those never go into the cache on disk
  @visibleForTesting
  Future<void> subscribeKnown() async {
    await _listenKnown(cache: true);
  }

  // the keys it listened on
  Future<Set<String>> _listenKnown({bool cache = false}) async {
    // subscribe off the xpub stored on the contact row, the same key the
    // send path uses. the signal store has none until a session exists, so
    // the scanned side could never receive the first message.
    // people we have not accepted yet listen too: someone a friend
    // introduced, and any stranger already sitting in requests. their
    // second message rides the pair address, or it waits on the relay
    // until we accept them.
    final rows = bootSubscribeRows(
      accepted: await live.contacts(),
      vouchedPending: await live.vouchedPending(),
      pendingRequests: [
        ...await live.pendingRequests(),
        ...await live.parkedRequests(),
      ],
    );
    final fresh = <String, String>{};
    for (final r in rows) {
      final haloId = r['halo_id'] as String?;
      if (haloId == null) continue;
      var xPub = r['xpub'] as String?;
      // v2 bundle pairing stores an empty xpub on the row: the key only
      // lands in the signal store, which processPeerBundle fills at pair
      // time. v1 stores it on the row and has no session yet. take
      // whichever exists, then backfill the row so the next boot is cheap.
      if (xPub == null || xPub.isEmpty) {
        xPub = await signalSession.peerXPubHex(haloId);
        if (xPub != null && xPub.isNotEmpty) {
          await live.setContactXPub(haloId, xPub);
        }
      }
      if (xPub == null || xPub.isEmpty) continue;
      _xPubToHaloId[xPub] = haloId;
      _io.listen(xPub);
      fresh[xPub] = haloId;
    }
    final hidden = _router.listenFor;
    for (final e in hidden.entries) {
      _xPubToHaloId[e.key] = e.value;
      _io.listen(e.key);
    }
    if (cache) await _saveXPubCache(fresh);
    return {...fresh.keys, ...hidden.keys};
  }

  // what the onion inbox held. an arrival for a hidden chat while its vault
  // is shut changes nothing here: no refresh, and the transport screen does
  // not count it
  @visibleForTesting
  Future<void> receiveOnion(List<String> ciphers) async {
    var noted = false;
    void arrived() {
      if (noted) return;
      noted = true;
      // the onion lane counts as an arrival too, or the night's record
      // would call a phone that only heard direct messages deaf
      _noteDrain();
    }

    for (final cipher in ciphers) {
      // dedup: same msg can arrive twice (tor late + nostr, or a retry).
      // the first copy consumes the one-time prekey; a duplicate would
      // crash on it, so skip anything we've already handled.
      final h = sha256.convert(utf8.encode(cipher)).toString();
      if (await live.alreadySeen(h)) {
        arrived();
        continue;
      }
      if (cipher.startsWith('{')) {
        // ctl frames only ride the authenticated relay lane. raw json
        // in the onion inbox is junk: bury it without trial decrypts.
        arrived();
        _strikeUndecryptable(h, 'drain');
        continue;
      }
      var handled = false;
      var shown = true;
      final known = await _openKnown(cipher);
      if (known != null) {
        final env = unwrapMessage(known.plain);
        try {
          shown = _shown(
            await _applyIncomingPayload(known.id, env, wire: known.plain),
          );
        } on CapHeld catch (e) {
          // no relay to replay from: kept here, opened on accept
          await (e is _HeldIn ? e.into : live).holdCipher(known.id, cipher);
        }
        if (shown) notifyListeners();
        handled = true;
      }
      if (!handled) {
        final parked = await _openParked(cipher);
        if (parked != null) {
          final addr = parked.id;
          final env = unwrapMessage(parked.plain);
          await live.upsertContact(
            addr,
            env.senderOnion ?? '',
            env.senderXPub ?? '',
            accepted: 0,
          );
          if (env.senderXPub != null && env.senderXPub!.isNotEmpty) {
            _xPubToHaloId[env.senderXPub!] = addr;
          }
          try {
            // an opener from someone we let go: the same proof a cold
            // stranger owes. their client grinds for any fresh
            // session, so an honest re-add still lands.
            await _applyIncomingPayload(
              addr,
              env,
              wire: parked.plain,
              fromBackPair: true,
            );
          } on CapHeld {
            await live.holdCipher(addr, cipher);
          } on _NoProof {
            // dropped, as a cold stranger's opener is
          }
          await refreshContacts();
          notifyListeners();
          handled = true;
          dlog('drain: recovered deleted peer $addr into requests');
        }
      }
      if (!handled && _isPreKeyWire(cipher)) {
        final paired = await backPairFromCipher(cipher);
        handled = paired != null;
        if (paired != null) shown = _shown(paired.$2);
        dlog('drain: back-pair ${paired != null ? "ok" : "failed"}');
      }
      // only now is it safe to burn the dedup hash: the prekey is spent
      // and the message is filed. an unhandled cipher stays un-seen so a
      // later pass (or the relay replay) can still land it.
      if (handled) {
        await live.markSeen(h);
      } else {
        _strikeUndecryptable(h, 'drain');
      }
      if (shown) arrived();
    }
  }

  // what the relays held, as the onion inbox above
  @visibleForTesting
  Future<void> receiveRelay(List<({String peer, String cipher})> msgs) async {
    var noted = false;
    void arrived() {
      if (noted) return;
      noted = true;
      _noteDrain();
    }

    // one sender's messages in the order they were sent, strangers' openers
    // included. room frames stay put
    final ordered = inSendOrder(
      msgs,
      peer: (m) => m.peer,
      cipher: (m) => m.cipher,
      lane: keepsArrivalOrder,
    );
    for (final m in ordered) {
      // dedup: skip a message we've already handled (see direct-onion note).
      final h = sha256.convert(utf8.encode(m.cipher)).toString();
      if (await live.alreadySeen(h)) {
        arrived();
        continue;
      }
      // his lanes are the dev chat's alone, and only while it runs on them
      if (devKeyOfTag(m.peer) != null) {
        if (await _receiveDev(m.peer, m.cipher, h)) notifyListeners();
        arrived();
        continue;
      }
      // a room frame: opened by the room key already, never signal
      if (m.peer.startsWith('room:') || m.peer.startsWith('roomfc:')) {
        try {
          await _handleRoomFrame(m.peer, m.cipher);
        } catch (e) {
          dlog('room frame: $e');
        }
        await live.markSeen(h);
        notifyListeners();
        arrived();
        continue;
      }
      if (m.cipher.startsWith('{')) {
        // control frame riding the transport outside signal (bundle
        // exchange). signal wire is base64, never starts with '{'.
        await _handleBundleCtl(m.peer, m.cipher, h);
        arrived();
        continue;
      }
      // 'firstcontact' is a lane, not a peer. every stranger's opening
      // message arrives under that one tag, so it can neither name who
      // sent this nor be remembered as anyone.
      final fcLane = m.peer == 'firstcontact';
      var haloId = fcLane ? null : _xPubToHaloId[m.peer];
      // flagKeyChange means "this cipher really is from this peer", which
      // skips the identity check and spends the one-time prekey. only a
      // real xpub mapping earns that.
      String? wrapped = haloId == null
          ? null
          : await _io.decrypt(haloId, m.cipher, flagKeyChange: true);
      // fallback: xpub not mapped yet (or it decrypted wrong). trial
      // against everyone known like the direct path, then remember it.
      if (wrapped == null) {
        final known = await _openKnown(m.cipher, skip: haloId);
        if (known != null) {
          wrapped = known.plain;
          haloId = known.id;
          if (!fcLane) _xPubToHaloId[m.peer] = known.id;
        }
      }
      if (wrapped == null) {
        // a peer we deleted keeps its session but loses its contact row.
        // their next message is a plain whisper, so back-pair can't help:
        // re-file them as a fresh request.
        final parked = await _openParked(m.cipher);
        if (parked != null) {
          final addr = parked.id;
          wrapped = parked.plain;
          haloId = addr;
          if (!fcLane) _xPubToHaloId[m.peer] = addr;
          final env0 = unwrapMessage(parked.plain);
          await live.upsertContact(
            addr,
            env0.senderOnion ?? '',
            env0.senderXPub ?? '',
            accepted: 0,
          );
          await refreshContacts();
          dlog('relay: recovered deleted peer $addr into requests');
        }
      }
      if (wrapped == null) {
        // only a prekey can bootstrap a new session. a whisper nothing
        // could decrypt is undeliverable: drop it without the noise.
        var landed = false;
        var shown = true;
        if (_isPreKeyWire(m.cipher)) {
          final paired = await backPairFromCipher(m.cipher);
          dlog('nostr: back-pair ${paired != null ? "ok" : "failed"}');
          if (paired != null) {
            if (!fcLane) _xPubToHaloId[m.peer] = paired.$1;
            await live.markSeen(h);
            landed = true;
            shown = _shown(paired.$2);
          }
        }
        if (!landed) _strikeUndecryptable(h, 'nostr');
        if (shown) arrived();
        continue;
      }
      final env = unwrapMessage(wrapped);
      final RouteTo went;
      try {
        went = await _applyIncomingPayload(haloId!, env, wire: wrapped);
      } on CapHeld {
        // not seen: it stays on the relay and lands once we accept them
        arrived();
        continue;
      }
      await live.markSeen(h);
      if (_shown(went)) {
        notifyListeners();
        arrived();
      }
    }
  }

  Future<void> _saveXPubCache(Map<String, String> cache) async {
    try {
      await secureStore.write(key: 'xpub_cache', value: jsonEncode(cache));
    } catch (e) {
      dlog('xpub cache write: $e');
    }
  }

  // a boot that throws leaves ready false behind the splash, so the error is
  // held for the gate to show
  String? bootError;

  AppLifecycleListener? _seen;

  // a window is not the same as a person: samsung relaunches a recently used
  // app's activity, unseen, right after its data is cleared, and booting then
  // would make a fresh identity out of a panic wipe. a phone that has been
  // set up boots at once; one with nothing yet waits until the app is in
  // front of someone.
  Future<void> bootWhenWanted() async {
    final state = WidgetsBinding.instance.lifecycleState;
    dlog('LAUNCH lifecycle at boot request: $state');
    if (state == AppLifecycleState.resumed || await _hasLocalData()) {
      await boot();
      return;
    }
    if (_seen != null) return;
    dlog('LAUNCH nothing here and not in front - boot waits');
    _seen = AppLifecycleListener(
      onResume: () {
        _seen?.dispose();
        _seen = null;
        dlog('LAUNCH in front now - booting');
        unawaited(boot());
      },
    );
  }

  Future<void> boot() async {
    try {
      await _boot();
    } catch (e, st) {
      dlog('BOOT failed: $e\n$st');
      bootError = e.toString();
      _booting = false;
      // both deep link handlers wait on this
      if (!_signalReady.isCompleted) _signalReady.complete();
      notifyListeners();
    }
  }

  // clears the error and runs the whole thing again. the failure may well be
  // permanent, but retrying costs nothing and beats a force-stop.
  Future<void> retryBoot() async {
    bootError = null;
    notifyListeners();
    await boot();
  }

  // the rows go now, their files in the background as above
  Future<void> _dropGroupLeftovers(HaloDb d) async {
    try {
      final files = await d.dropGroupLeftovers();
      if (files.isEmpty) return;
      dlog('groups: ${files.length} files of groups no longer here');
      unawaited(() async {
        for (final f in files) {
          await shredFile(f);
        }
      }());
    } catch (e) {
      dlog('groups: leftovers not swept (${e.runtimeType})');
    }
  }

  // which files go is settled here; the zeros are written after, in the
  // background: nothing names these files, so nothing can reach them
  Future<void> _sweepUnnamedMedia(DateTime before) async {
    try {
      final gone = await live.unnamedMedia(before: before);
      if (gone.isEmpty) return;
      dlog('media: ${gone.length} files no message names');
      unawaited(() async {
        for (final f in gone) {
          await shredFile(f.path);
        }
      }());
    } catch (e) {
      dlog('media: not swept (${e.runtimeType})');
    }
  }

  // what the splash says while boot runs. the keys and the database come
  // first and take the longest on a new phone; tor starts once the home
  // is ready to paint
  String bootPhase = l10n.appSettingUpYourKeys;

  Future<void> _boot() async {
    dlog('LAUNCH boot');
    final bsw = Stopwatch()..start();
    final bootAt = DateTime.now();
    // both _OnboardingGate and _RootShell call boot() on cold start, before
    // ready flips, and must not race through generateIdentity and db open
    if (ready || _booting) return;
    _booting = true;
    // let the splash paint one frame before any heavy native call. sqlcipher
    // key derivation + the first go ffi hop block the ui thread long enough
    // to trip the anr watchdog on weak phones.
    await Future.delayed(const Duration(milliseconds: 16));
    dlog('LAUNCH boot after yield');
    unawaited(_openContainers());
    final docsDir = await getApplicationDocumentsDirectory();
    final saved = await live.loadIdentity();
    dlog('LAUNCH identity loaded');
    // the hidden chats' list, before anything can arrive: without it an
    // arrival for one would land in the everyday container
    await _router.load();
    // and a move a crash cut short put right, as its list entry says
    var settled = true;
    try {
      await repairVaultMoves();
    } catch (e) {
      settled = false;
      dlog('vault: repair left for the next start (${e.runtimeType})');
    }
    // files no message names any more go, before anything here can move
    // or write one. with a move still open the rows may be on the other
    // side. a file from the last minutes may be one another start of the
    // app is still filing
    if (settled) {
      await _dropGroupLeftovers(live);
      await _sweepUnnamedMedia(bootAt.subtract(const Duration(minutes: 10)));
    }
    if (saved != null) {
      myId = engine.restoreIdentity(saved['ed_priv']!, saved['x_priv']!);
      restored = true;
    } else {
      myId = engine.generateIdentity();
      await live.saveIdentity(myId, engine.myEdPrivkey(), engine.myXPrivkey());
    }
    myXPub = engine.myXPubkey();
    dlog('BOOT identity +${bsw.elapsedMilliseconds}ms');
    bootPhase = l10n.appOpeningYourChats;
    notifyListeners();
    _appLinks = AppLinks();
    // a link carries a prekey bundle, and taking one needs the signal
    // store, which boots after the home paints. both handlers wait for it.
    _appLinks.uriLinkStream.listen((uri) async {
      if (uri.scheme != 'kryfo') return;
      await lockGuard.afterUnlock(key: 'link:$uri', () async {
        await _signalReady.future;
        final result = await handleHaloUri(uri.toString());
        dlog('deep link: $result');
        _sayLinkResult(result);
        await refreshContacts();
        notifyListeners();
      });
    });
    // the stream only fires while we're already running. a link tapped with
    // kryfo closed cold-starts the app and would otherwise be dropped.
    unawaited(
      _appLinks
          .getInitialLink()
          .then((uri) async {
            if (uri == null || uri.scheme != 'kryfo') return;
            await lockGuard.afterUnlock(key: 'link:$uri', () async {
              await _signalReady.future;
              final result = await handleHaloUri(uri.toString());
              dlog('deep link (cold start): $result');
              _sayLinkResult(result);
              await refreshContacts();
              notifyListeners();
            });
          })
          .catchError((Object e) {
            dlog('deep link (cold start) failed: $e');
          }),
    );

    await refreshContacts();
    dlog('BOOT contacts +${bsw.elapsedMilliseconds}ms');
    await refreshGroups();
    dlog('BOOT groups +${bsw.elapsedMilliseconds}ms');
    // paint the home as soon as contacts/groups are ready; notifications,
    // nostr subscriptions keep warming up in the background.
    onboardingComplete =
        (await secureStore.read(key: 'onboarding_done')) == 'true';
    _movedAway =
        (await SharedPreferences.getInstance()).getInt('moved.at') != null;
    // let the onion linger a beat before the home appears
    if (onboardingComplete) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
    ready = true;
    bootPhase = l10n.appStartingTor;
    dlog('BOOT ready +${bsw.elapsedMilliseconds}ms');
    notifyListeners();
    // moved away: home can show what was here, and that is all. no tor,
    // no relays, no outbox. see movedAway.
    if (_movedAway) {
      bootPhase = '';
      if (!_signalReady.isCompleted) _signalReady.complete();
      _booting = false;
      notifyListeners();
      return;
    }
    // signal prekey gen is cpu-heavy (~5s on a fresh identity) and nothing
    // above needs it, so it waits until the home paints. tor + nostr also
    // start after this, and both take longer to warm than the prekeys, so
    // the session is ready well before any message can arrive.
    _signalBoot = _bootSignal().whenComplete(() {
      dlog('BOOT signal (deferred) done');
      if (!_signalReady.isCompleted) _signalReady.complete();
    });
    // outbox drainer: anything the wire never confirmed gets re-sent for the
    // life of the app, whatever screen you're on and across restarts.
    startOutboxDrain();
    await _loadBridges();
    // drop week-old partial transfers nobody ever completed.
    unawaited(live.sweepMediaChunks());
    _deliveryMode = await loadDeliveryMode();
    // in front means resumed, not that a view exists: android hands every
    // engine an implicit view, window or not
    _inFront =
        _inFront ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    await _judgeLastRun();
    // a knock wakes a check-in, whatever mode is set: a helper app still
    // registered from before should not be answered with silence
    HelperPush.instance.onKnock = () => unawaited(checkIn(why: 'push'));
    HelperPush.instance.listen();
    await _loadDeliveryTimes();
    // start tor last: nothing above needs it, and earlier it stalls the main
    // thread while tor bootstraps. a process the fifteen-minute job started,
    // with no window, in a mode that sleeps between checks leaves tor down;
    // the job's own check-in brings it up for its minute.
    if (_deliveryMode != DeliveryMode.always && !_inFront) {
      _torHeld = true;
      await engine.torStop();
      _docsPath = docsDir.path;
    } else {
      _docsPath = docsDir.path;
      _startListenerOnIsolate(docsDir.path).then((addr) {
        if (addr.isNotEmpty && !addr.startsWith('error')) {
          myOnion = addr;
          _maybeRepoint();
          notifyListeners();
        }
      });
    }
    // poll bootstrap so the kryfo can breathe while the listener warms up.
    // it runs for the life of the app and doubles as the watchdog.
    var torKickedAt = DateTime.now();
    var ticks = 0;
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (haloWiping) return;
      if (_sendMode == 'balanced' && ++ticks % 5 == 0) sampleRelayHealth();
      final st = takeTorStatus(engine.getStatus());
      flushOnRouteUp();
      // tor died or never came up in this process. nothing else
      // restarts it, so we do. throttled: a start takes a while.
      if (st == TorStatus.off &&
          !_torHeld &&
          DateTime.now().difference(torKickedAt).inSeconds > 45) {
        torKickedAt = DateTime.now();
        dlog('TOR_WATCHDOG: tor off, restarting listener');
        _startListenerOnIsolate(docsDir.path).then((addr) {
          if (addr.isNotEmpty && !addr.startsWith('error')) {
            myOnion = addr;
            notifyListeners();
          }
        });
      }
    });
    _initConnectivity();
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
    dlog('transport: booting in $_sendMode');
    // only takes a lock in the engine, so it is set right here, before the
    // first-contact runner: that snapshots the list on start and gives up
    // if it is empty.
    engine.nostrInit(relaysFor(_sendMode));
    _loadFirstContact();
    await loadScreenshotPref();
    await loadHeartbeat();
    startMemoryLog();
    await initNotifications(onTap: openChatForHalo);
    // the first call into android's notification service after a start is
    // slow, a tenth of a second or more. every start pays it here, so
    // nothing later pays it where it could be timed
    // a warm-up only: an id that was never shown, and no answer wanted
    unawaited(notifPlugin.cancel(id: 0x7ffffffe).catchError((_) {}));

    unawaited(_fillSearch());
    if (kDebugMode) unawaited(maybeRunSearchBench());
    // periodic sweep: delete messages whose burn_at has passed. a sweep
    // that keeps failing means burned messages are staying, which the
    // user was promised would not happen, so after a minute of it say so
    var sweepFails = 0;
    var sweeps = 0;
    Timer.periodic(const Duration(seconds: 5), (_) async {
      if (haloWiping) return;
      try {
        void unring(String uid) => unawaited(_io.unnotifyMessage(uid));
        var gone = await live.purgeExpired(gone: unring);
        final stray = ++sweeps % 12 == 0;
        if (stray) await live.purgeStrayVotes();
        // the open vault's too. shut, its timers wait for the next open
        final v = _openVault;
        if (v != null) {
          try {
            gone += await v.purgeExpired(gone: unring);
            if (stray) await v.purgeStrayVotes();
          } catch (e) {
            if (identical(_openVault, v)) rethrow;
          }
        }
        sweepFails = 0;
        // a row whose newest message just burned needs a new preview
        if (gone > 0) {
          unawaited(refreshContacts());
          unawaited(refreshGroups());
        }
      } catch (e) {
        sweepFails++;
        dlog('burn sweep failed ($sweepFails): $e');
        if (sweepFails == 12) {
          final ctx = rootNavKey.currentContext;
          if (ctx != null && ctx.mounted) {
            showHaloToast(ctx, l10n.appTimedMessagesAreNot);
          }
        }
      }
    });
    // warm up signal sessions + nostr subs after the first frame. a cached
    // xpub→haloId map (encrypted) lets returning users skip the per-contact
    // crypto entirely; only uncached contacts hit the heavy lookup.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      // rooms first, on their own: a hang anywhere in the contact loop
      // below must not leave a live room deaf after a restart.
      try {
        await _subscribeRooms();
      } catch (e) {
        dlog('rooms: boot subscribe failed: $e');
      }
      // the dev chat's lane, only once it has started
      try {
        await subscribeDevLane();
      } catch (e) {
        dlog('dev lane: boot subscribe failed: $e');
      }
      unawaited(sweepCaptures());
      await subscribeKnown();
    });
    // what the removed ntfy mode left behind in the prefs
    unawaited(forgetNtfy());

    // continuous drain of direct-onion inbox. handles back-
    // pair from strangers + falls back to trial-decrypt against known
    // contacts for in-session direct-onion messages.
    Timer.periodic(const Duration(seconds: 1), (_) async {
      if (haloWiping) return;
      // while the vault is open, what came sealed goes in, a tick at a time
      unawaited(_unseal());
      // reentrancy guard: the ffi drain + decrypt can outrun the 1s tick,
      // and stacked calls pin the main thread hard enough to anr on weak
      // phones. no tor gate here: the bytes are already in the go inbox and
      // opening them needs nothing from the network.
      if (_draining) return;
      _draining = true;
      try {
        final ciphers = engine.drainInbox();
        if (ciphers.isEmpty) return;
        await receiveOnion(ciphers);
      } finally {
        _draining = false;
      }
    });

    Timer.periodic(const Duration(seconds: 1), (_) async {
      if (haloWiping) return;
      // same as the onion drain above: the relay queue is already on this
      // phone, so it is read whatever tor is doing
      if (_polling) return;
      _polling = true;
      _beat();
      try {
        final msgs = engine.nostrPoll();
        if (msgs.isEmpty) return;
        await receiveRelay(msgs);
      } finally {
        _polling = false;
      }
    });
    final stored = await secureStore.read(key: 'onboarding_done');
    onboardingComplete = stored == 'true';
    ready = true;
    notifyListeners();
  }

  Future<void> _initConnectivity() async {
    // what the network was when we started, so the first event the listener
    // delivers is not taken for a change and bounced
    var lastKinds = '';
    try {
      final init = await Connectivity().checkConnectivity();
      _online = init.any((r) => r != ConnectivityResult.none);
      lastKinds = (init.map((r) => r.name).toList()..sort()).join(',');
      notifyListeners();
    } catch (e) {
      dlog('connectivity init: $e');
    }
    Connectivity().onConnectivityChanged.listen((results) {
      final on = results.any((r) => r != ConnectivityResult.none);
      final kinds = (results.map((r) => r.name).toList()..sort()).join(',');
      // back online, or a different kind of network while online (wifi to
      // mobile data): tor's open connections belong to the network that went.
      // the engine waits for the network to settle before it bounces, so a
      // flapping one is not bounced on every flap.
      if (on && (!_online || kinds != lastKinds)) networkMoved();
      lastKinds = kinds;
      noteOnline(on);
    });
  }

  // tor's connections belong to the network that went
  @visibleForTesting
  void networkMoved() {
    _needRouteUp();
    engine.networkChanged();
    _newTorTry();
  }

  // the route just became usable: flush anything the outbox is holding
  // instead of waiting out the next 20s tick. torReady asks the mode first,
  // so outside onion this never waits on a bootstrap
  @visibleForTesting
  void flushOnRouteUp() {
    if (linkUp && !_outboxWasReady) unawaited(drainOutbox());
  }

  // when the network last went. a drop shorter than this is the phone
  // handing over between networks, not a spell offline
  DateTime? _offlineAt;
  static const _offlineSpell = Duration(seconds: 60);

  @visibleForTesting
  void noteOnline(bool on, {DateTime? now}) {
    if (on == _online) return;
    final at = now ?? DateTime.now();
    _online = on;
    // the relay's clock starts again from here: dials that failed while
    // the network was gone were not the relay's fault
    _relayDownSince = null;
    if (!on) {
      _offlineAt = at;
    } else {
      // back from a spell offline, waiting rows go with their tries whole. a
      // network that flaps keeps its count, or a failing row never stops
      final gone = _offlineAt;
      _offlineAt = null;
      if (gone == null || at.difference(gone) >= _offlineSpell) {
        _outboxTries.clear();
        _outboxNextAt.clear();
      }
      // the status poll sees the route come up and drains
      _outboxWasReady = false;
    }
    notifyListeners();
  }

  // done once the signal store can take a bundle. a failed boot completes
  // it too, so a waiting link fails loudly rather than hangs
  final _signalReady = Completer<void>();
  Future<void>? _signalBoot;

  Future<void> _bootSignal() async {
    try {
      final database = await live.open();
      final xpb = _hexDecode(engine.myXPrivkey());
      await signalSession.bootstrap(
        database: database,
        xPubBytes: _hexDecode(engine.myXPubkey()),
        xPrivBytes: xpb,
      );
      _zeroBytes(xpb); // priv bytes consumed by bootstrap, wipe from ram
    } catch (e, st) {
      dlog('signal bootstrap failed: $e\n$st');
    }
  }

  Uint8List _hexDecode(String s) {
    final bytes = Uint8List(s.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  Future<void> deleteConversation(String haloId) async {
    // messages + contact row only. the signal session stays: the peer still
    // holds a live session and their next message is a plain whisper, which
    // back-pair (prekey-only) can't rebuild. keeping the session lets it
    // decrypt, find no contact, and land in requests like a new stranger.
    await session.deleteConversation(haloId);
    // keep _xPubToHaloId: the row and subscription both survive so they can
    // still reach us, in requests instead of a live chat.
    await refreshContacts();
    notifyListeners();
  }

  Future<void> archive(String haloId) async {
    await session.setArchived(haloId, true);
    await refreshContacts();
  }

  Future<void> unarchive(String haloId) async {
    await session.setArchived(haloId, false);
    await refreshContacts();
  }

  Future<void> mute(String haloId) async {
    await session.setMuted(haloId, true);
    await refreshContacts();
  }

  Future<void> unmute(String haloId) async {
    await session.setMuted(haloId, false);
    await refreshContacts();
  }

  // a block stops listening on their relay address, and that address's
  // files go with it
  Future<void> block(String haloId) async {
    await session.setBlocked(haloId, true);
    await session.dropHeld(haloId);
    if (!sessionQuiet) await _unlistenPeer(haloId);
    await refreshContacts();
  }

  Future<void> _unlistenPeer(String haloId) async {
    final keys = {
      for (final e in _xPubToHaloId.entries)
        if (e.value == haloId) e.key,
    };
    final x = await _ownerOf(haloId).contactXPub(haloId);
    if (x != null && x.isNotEmpty) keys.add(x);
    for (final k in keys) {
      // a key someone else here is heard on stays
      final heard = _xPubToHaloId[k];
      if (heard != null && heard != haloId) continue;
      _xPubToHaloId.remove(k);
      _io.unlisten(k);
    }
  }

  // a support chat is taken on by its first reply, and stays in support.
  // true when this reply accepted it
  Future<bool> answerSupport(String haloId) async {
    if (!devMode ||
        await session.isAccepted(haloId) ||
        !await session.support.has(haloId)) {
      return false;
    }
    await session.acceptRequest(haloId);
    await afterAccept(haloId);
    return true;
  }

  // the support inbox is on screen: its summary has nothing left to say
  Future<void> supportSeen() => _bell.clear();

  // what every accept does, from the chat or the requests list: listen for
  // them, tell them they are in, and open what the onion lane held back
  Future<void> afterAccept(String haloId) async {
    // a quiet session has no one waiting and answers no one
    if (sessionQuiet) {
      await refreshContacts();
      return;
    }
    unawaited(subscribePeer(haloId));
    unawaited(sendAcceptAck(haloId));
    for (final cipher in await session.takeHeld(haloId)) {
      try {
        final plain = await _io.decrypt(haloId, cipher);
        if (plain == null) continue;
        await _applyIncomingPayload(haloId, unwrapMessage(plain), wire: plain);
      } catch (e) {
        dlog('held: could not open one for $haloId ($e)');
      }
    }
    _bumpChatRev(haloId);
    await refreshContacts();
    notifyListeners();
  }

  // an unblock listens for them again
  Future<void> unblock(String haloId) async {
    await session.setBlocked(haloId, false);
    if (!sessionQuiet) await subscribePeer(haloId);
    await refreshContacts();
  }

  // everyone blocked, contacts or not: a request, a group member or a
  // support chat blocked before it was ever accepted is here too, or the
  // block could never be undone
  Future<List<({String haloId, String? nickname})>> blockedContacts() async {
    final s = session;
    final ids = await s.blockedIds();
    final out = <({String haloId, String? nickname})>[];
    for (final r in await s.contacts()) {
      final id = r['halo_id'] as String;
      if (ids.remove(id)) {
        out.add((haloId: id, nickname: r['nickname'] as String?));
      }
    }
    for (final id in ids.toList()..sort()) {
      final r = await s.getContact(id);
      out.add((haloId: id, nickname: r?['nickname'] as String?));
    }
    return out;
  }

  Future<void> refreshContacts() async {
    final s = session;
    final (list, pending, dev) = await _contactsOf(s);
    final waiting = _devModeIn(s) ? await s.support.waiting() : null;
    // a session swapped while this read keeps what it was given
    if (!identical(s, _session)) return;
    contacts = list;
    pendingCount = pending;
    devRow = dev;
    if (waiting != null) supportWaiting = waiting;
    notifyListeners();
  }

  // developer mode as a session has it: his own phone, never its decoy
  bool _devModeIn(Session s) => _devIdentity && !s.container.quiet;

  // how a row says its last message, and when it was sent
  (String?, DateTime?) _lastLine(Map<String, Object?>? last) {
    if (last == null) return (null, null);
    final dir = last['direction'] as String?;
    final text = (last['plaintext'] as String?) ?? '';
    final media = last['media_path'] as String?;
    final fileName = last['file_name'] as String?;
    String body;
    // a sticker's text is its emoji; the row says what it is
    if (last['sticker'] != null) {
      body = l10n.stickerLabel;
    } else if (text.isNotEmpty) {
      body = text;
    } else if (fileName == 'voice.wav') {
      body = l10n.appVoiceMessage2;
    } else if (fileName != null) {
      body = fileName;
    } else if (media != null) {
      body = l10n.appPhoto;
    } else {
      body = '';
    }
    final sentAt = last['sent_at'] as int?;
    return (
      body.isEmpty ? null : (dir == 'out' ? l10n.appYou(body) : body),
      sentAt == null ? null : DateTime.fromMillisecondsSinceEpoch(sentAt),
    );
  }

  Future<(List<ContactPreview>, int, DevRow?)> _contactsOf(Session s) async {
    final rows = await s.contacts();
    final lasts = await s.lastMessages();
    // an answered support chat stays in support: out of this list, the
    // pickers and the introductions
    final apart = _devModeIn(s) ? await s.support.ids() : const <String>{};
    final list = <ContactPreview>[];
    final devRows = <String, Map<String, Object?>>{};
    for (final r in rows) {
      final haloId = r['halo_id'] as String;
      if (apart.contains(haloId)) continue;
      // the developer chat has a row of its own: kept out of this list, it
      // stays out of every picker, count and loop that reads it
      if (isDevChat(haloId)) {
        devRows[haloId] = r;
        continue;
      }
      final (preview, sent) = _lastLine(lasts[haloId]);
      // default to the contact's last_seen; a real message overrides it.
      final when =
          sent ?? DateTime.fromMillisecondsSinceEpoch(r['last_seen'] as int);
      list.add(
        ContactPreview(
          haloId: haloId,
          nickname: r['nickname'] as String?,
          avatarSeed: haloId,
          avatar: (r['avatar'] as num?)?.toInt(),
          preview: preview,
          when: when,
          blocked: (r['blocked'] as int? ?? 0) == 1,
          archived: (r['archived'] as int? ?? 0) == 1,
          muted: (r['muted'] as int? ?? 0) == 1,
          verified: (r['verified'] as int? ?? 0) == 1,
          unread: (r['unread'] as int? ?? 0),
          pinned: (r['pinned'] as int? ?? 0) == 1,
          supporterBadge: r['supporter_badge'] as String?,
          hidden: s.isHidden(haloId),
        ),
      );
    }
    // most-recent conversation floats to the top
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return (b.when ?? DateTime(0)).compareTo(a.when ?? DateTime(0));
    });
    return (
      list,
      await s.pendingRequestCount(),
      await _devRowOf(s, devRows, lasts),
    );
  }

  // the session's own row, never a vault's. a row that will not read is no
  // row: home still shows everything else
  Future<DevRow?> _devRowOf(
    Session s,
    Map<String, Map<String, Object?>> rows,
    Map<String, Map<String, Object?>> lasts,
  ) async {
    try {
      final r = await s.devChat.load();
      final id = r?.chatId;
      final (preview, sent) = _lastLine(id == null ? null : lasts[id]);
      return devRowOf(
        r,
        contact: id == null ? null : rows[id],
        preview: preview,
        when: sent,
        // the developer's own phone has none. its decoy does
        devMode: _devModeIn(s),
      );
    } catch (e) {
      dlog('dev row: $e');
      return null;
    }
  }

  // ---- the dev chat's first send ----

  // one start at a time: a second screen of the same chat waits for the
  // first and finds it started
  Future<void> _devStarting = Future.value();

  // asked by every way a message leaves the dev chat, before anything of it
  // is saved: fresh becomes everyday, or anon under a name made for this
  // chat alone. his card is checked and his session built first, then the
  // chat's rows, then its lane is listened to; the message goes out the
  // usual way after it. a key that does not check out throws
  // DevKeyCheckFailed, any other failure throws too, and neither leaves
  // anything of the start behind. a chat already started stays as it is
  Future<DevStart> devBegin({required bool anon}) {
    final out = _devStarting.then((_) => _devBegin(anon: anon));
    // the caller gets any error from out; the chain only keeps the order
    _devStarting = out.then((_) {}, onError: (_) {});
    return out;
  }

  Future<DevStart> _devBegin({required bool anon}) async {
    final s = session;
    final quiet = s.container.quiet;
    // the developer does not write to himself
    if (!quiet && devModeOf(myXPub)) return DevStart.none;
    final r = await s.devChat.load();
    if (r == null || r.state == DevState.gone) return DevStart.none;
    if (r.started) return DevStart.ok;
    final key = currentDevKey;
    if (key == null) return DevStart.none;
    // his card as pinned, checked the same way in every container
    if (!devCardChecks(key)) throw const DevKeyCheckFailed();
    final made = anon ? _devMadeName() : null;
    if (quiet) {
      // a decoy keeps its chat on this phone: no store, no lane, nothing
      // listened to, and what is written there stays parked
      if (!await s.devChat.begin(key, anon: made?.$1)) {
        throw StateError('dev chat: the row did not start');
      }
    } else if (made == null) {
      await _devBeginEveryday(s, key);
    } else {
      await _devBeginAnon(s, key, made.$1, made.$2);
    }
    await refreshContacts();
    if (!quiet) await subscribeDevLane();
    return DevStart.ok;
  }

  // three words: his session in the everyday store, then the chat's rows
  Future<void> _devBeginEveryday(Session s, DevKey key) async {
    final ss = signalSession;
    if (!ss.ready) throw StateError('dev chat: the store is not ready');
    await _devSession(ss, key);
    try {
      if (!await s.devChat.begin(key)) {
        throw StateError('dev chat: the row did not start');
      }
    } catch (_) {
      await _dropDevSession(ss, key.chatId);
      rethrow;
    }
  }

  // anonymous: a store of its own under the made name, in the everyday
  // database beside the chat's row. emptied before, and again if the start
  // fails, so no half made name stays
  Future<void> _devBeginAnon(
    Session s,
    DevKey key,
    DevAnon name,
    DevSelf self,
  ) async {
    final db = await live.open();
    await clearDevStore(db);
    try {
      final ss = SignalSession();
      final priv = _hexDecode(name.xPriv);
      try {
        await ss.bootstrapInitiator(
          database: db,
          xPubBytes: _hexDecode(self.xPub),
          xPrivBytes: priv,
          prefix: kDevSignalPrefix,
        );
      } finally {
        // the store keeps a copy of its own
        _zeroBytes(priv);
      }
      await _devSession(ss, key);
      if (!await s.devChat.begin(key, anon: name)) {
        throw StateError('dev chat: the row did not start');
      }
    } catch (_) {
      await clearDevStore(db);
      rethrow;
    }
  }

  // his card into [ss], then the key it holds for him read back: the
  // pinned one, byte for byte. a card libsignal refuses, or any other key,
  // is a key that did not check out, and no session of it stays
  Future<void> _devSession(SignalSession ss, DevKey key) async {
    final addr = SignalProtocolAddress(key.chatId, 1);
    var ok = false;
    try {
      await processPeerBundle(key.chatId, key.bundle, into: ss);
      final held = await ss.identityStore.getIdentity(addr);
      ok =
          held != null &&
          _eqBytes(held.serialize(), pinnedIdentity(key)) &&
          await ss.sessionStore.containsSession(addr);
    } on UntrustedIdentityException {
      ok = false;
    } on InvalidKeyException {
      ok = false;
    } catch (_) {
      await _dropDevSession(ss, key.chatId);
      rethrow;
    }
    if (!ok) {
      await _dropDevSession(ss, key.chatId);
      throw const DevKeyCheckFailed();
    }
  }

  Future<void> _dropDevSession(SignalSession ss, String id) async {
    final addr = SignalProtocolAddress(id, 1);
    try {
      await ss.sessionStore.deleteSession(addr);
      await ss.identityStore.removePeerIdentity(addr);
    } catch (e) {
      dlog('dev chat: the session did not clear ($e)');
    }
  }

  // the name an anonymous chat writes under: made by the engine for this
  // chat alone, read back from its own keys, and sharing nothing with the
  // everyday identity or the session's
  (DevAnon, DevSelf) _devMadeName() {
    // pure: touches no engine state and logs nothing
    final q = engine.quietIdentity();
    final id = q?['id'], ed = q?['ed_priv'], x = q?['x_priv'];
    final edPub = q?['ed_pub'], xPub = q?['x_pub'];
    if (id is! String ||
        ed is! String ||
        x is! String ||
        edPub is! String ||
        xPub is! String) {
      throw StateError('dev chat: no name was made');
    }
    final self = DevSelf.ofKeys(id, ed, x);
    if (self == null ||
        self.edPub != edPub.toLowerCase() ||
        self.xPub != xPub.toLowerCase()) {
      throw StateError('dev chat: the made name does not read');
    }
    final mine = {
      myId,
      sessionId,
      for (final k in [_io.edPub(), _io.xPub(), sessionEdPub, sessionXPub])
        k.toLowerCase(),
    }..remove('');
    if (mine.contains(self.id) ||
        mine.contains(self.edPub) ||
        mine.contains(self.xPub)) {
      throw StateError('dev chat: the made name is not new');
    }
    return (DevAnon(id: id, edPriv: ed, xPriv: x), self);
  }

  // ---- the dev chat on the wire ----

  // its own lane, once it has started and while it can hear: his key's
  // pair lane with three words, the made name's room lane when anonymous
  // (the gate turns the listen into the room export). the everyday
  // container's chat only, never before its first send or after a delete
  @visibleForTesting
  Future<void> subscribeDevLane() async {
    final DevChatRow? r;
    try {
      r = await live.devChat.load();
    } catch (e) {
      dlog('dev lane: the chat did not read ($e)');
      return;
    }
    final k = r?.key;
    if (r == null ||
        !r.started ||
        r.nameless ||
        k == null ||
        k.status == DevKeyStatus.retired) {
      return;
    }
    _io.listen(k.xPub);
  }

  // a line on one of his lanes. taken only by the everyday chat running on
  // that lane, opened in its own store; anything else, and anything outside
  // signal, is dropped and marked seen. true when it shows
  Future<bool> _receiveDev(String tag, String cipher, String h) async {
    final DevChatRow? r;
    try {
      r = await live.devChat.load();
    } catch (e) {
      // left on the relay: it comes again
      dlog('dev lane: the chat did not read ($e)');
      return false;
    }
    final id = r?.chatId;
    if (id == null || !devLaneTakes(r, tag) || cipher.startsWith('{')) {
      dlog('dev lane: a line not taken');
      await live.markSeen(h);
      return false;
    }
    final plain = await _io.decrypt(id, cipher, flagKeyChange: true);
    if (plain == null) {
      _strikeUndecryptable(h, 'dev lane');
      return false;
    }
    final RouteTo went;
    try {
      went = await _applyIncomingPayload(id, unwrapMessage(plain), wire: plain);
    } on CapHeld {
      return false;
    }
    await live.markSeen(h);
    return _shown(went);
  }

  // deleted means gone: every row of it in the session's container. for
  // the everyday chat the wire lets go too: the seal forgets its store and
  // ciphers, the made name's room lane is dropped and his key maps to no
  // chat. his pair lane stays open until the app restarts, and what comes
  // on it is dropped. a decoy's delete leaves the everyday chat running
  Future<void> devDelete() async {
    final s = session;
    if (s.container.quiet) {
      await s.devChat.delete();
      return;
    }
    DevChatRow? was;
    try {
      was = await live.devChat.load();
    } catch (e) {
      dlog('dev delete: the chat did not read ($e)');
    }
    await s.devChat.delete();
    devLane.forget();
    _xPubToHaloId.removeWhere((_, id) => isDevId(id));
    final self = DevSelf.ofKeys(was?.anonId, was?.anonEdPriv, was?.anonXPriv);
    if (self != null) engine.roomUnsubscribeBg(self.xPub);
  }

  // ---- groups ----

  Future<void> refreshGroups() async {
    final s = session;
    final list = await _groupsOf(s);
    if (!identical(s, _session)) return;
    groups = list;
    notifyListeners();
  }

  Future<List<GroupPreview>> _groupsOf(Session s) async {
    final rows = await s.loadGroups();
    final list = <GroupPreview>[];
    for (final r in rows) {
      final gid = r['group_id'] as String;
      final members = await s.getGroupMembers(gid);
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
          mentioned: (r['mentioned'] as int? ?? 0) == 1,
          expiresAt: r['expires_at'] as int?,
          hidden: s.isHidden(gid),
        ),
      );
    }
    return list;
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
    // a relay replaying its backlog hands us the same message many times
    // over. re-acking still matters (the first receipt may have died), so
    // this throttles rather than blocks.
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
      dlog('receipt for $uid failed: $e');
    }
  }

  SenderInfo _mySender() => SenderInfo(
    haloId: myId,
    edPub: _io.edPub(),
    onion: myOnion,
    xPub: _io.xPub(),
    avatar: _myAvatar,
  );

  // wipe a corrupt outbound session and rebuild it from the peer's stored
  // prekey bundle. false if we never kept a bundle: the caller then surfaces
  // the original failure.
  Future<bool> _healSession(String memberId) async {
    // the dev chat heals from the pinned card alone, in its own store
    final bundle = isDevId(memberId)
        ? (await devLane.seat(memberId))?.key.bundle
        : (await _reach(memberId))?.bundle;
    if (bundle == null || bundle.isEmpty) return false;
    final ss = await signalFor(memberId);
    if (ss == null) return false;
    try {
      final addr = SignalProtocolAddress(memberId, 1);
      await ss.sessionStore.deleteSession(addr);
      await processPeerBundle(memberId, bundle, into: ss);
      dlog('healed session for $memberId');
      return true;
    } catch (e) {
      dlog('heal session failed for $memberId: $e');
      return false;
    }
  }

  // ship our prekey bundle to a peer over the gift-wrap transport: no
  // signal session needed, which is the point, since ours to them is broken.
  // want=true asks them to reset their session with us and send theirs back.
  Future<void> _sendBundleCtl(String memberId, {required bool want}) async {
    // the dev chat's bundle is pinned: nothing goes to him in the clear
    if (isDevId(memberId)) return;
    final key = '$memberId:$want';
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_bundleCtlSentAt[key] ?? 0) < 60000) {
      return; // 1/min, not 1/chunk
    }
    _pruneHeal();
    _bundleCtlSentAt[key] = now;
    try {
      final to = await _reach(memberId);
      // nothing goes to someone blocked, not even keys
      if (await to?.on?.isBlocked(memberId) ?? false) return;
      final xpub = to?.xpub ?? '';
      if (xpub.isEmpty) return;
      final payload = jsonEncode({
        'halo_ctl': 'bundle',
        'from': myId,
        'bundle': await makePreKeyBundleB64(),
        'want': want,
      });
      final r = await Future(() => _io.relaySend(xpub, payload));
      dlog('bundle ctl (want=$want) to $memberId: $r');
    } catch (e) {
      dlog('bundle ctl to $memberId failed: $e');
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
      // the pinned bundle is the dev chat's only one, and no one else may
      // speak for the developer
      if (devIdClaim(from)) {
        dlog('bundle ctl: claims the developer, dropped');
        return;
      }
      final to = await _reach(from);
      if (to == null) return;
      if (to.xpub != peerXPub) {
        dlog('bundle ctl: xpub mismatch for $from, dropped');
        return;
      }
      final bj =
          jsonDecode(utf8.decode(base64Decode(bundle))) as Map<String, dynamic>;
      final claimed = base64Decode(bj['identityKey'] as String);
      final addr = SignalProtocolAddress(from, 1);
      final known = await signalSession.identityStore.getIdentity(addr);
      if (known != null && !_eqBytes(known.serialize(), claimed)) {
        dlog('bundle ctl: identity mismatch for $from, dropped');
        return;
      }
      // kept on the row, where there is one: a hidden chat's card holds no
      // bundle while the vault is shut
      await to.on?.setPeerBundle(from, bundle);
      if (want || _healPending.remove(from) != null) {
        await signalSession.sessionStore.deleteSession(addr);
        await processPeerBundle(from, bundle);
        dlog('healed session for $from (bundle exchange)');
        unawaited(_owedDueFor(from));
      }
      if (want) unawaited(_sendBundleCtl(from, want: false));
    } catch (e) {
      dlog('bundle ctl handle failed: $e');
    } finally {
      await live.markSeen(h);
    }
  }

  // how to reach someone: their everyday row, the open vault's, else the
  // card the router keeps for a hidden chat while the vault is shut
  Future<
    ({String onion, String xpub, String? bundle, bool backPaired, HaloDb? on})?
  >
  _reach(String id) async {
    for (final d in [live, ?_openVault]) {
      final c = await d.getContact(id);
      if (c == null) continue;
      return (
        onion: (c['onion'] as String?) ?? '',
        xpub: (c['xpub'] as String?) ?? '',
        bundle: c['peer_bundle'] as String?,
        backPaired: await d.isBackPaired(id),
        on: d,
      );
    }
    final card = _router.cardOf(id);
    if (card == null) return null;
    return (
      onion: card.onion,
      xpub: card.xpub,
      bundle: null,
      backPaired: card.backPaired,
      on: null,
    );
  }

  Future<bool> _sendOneEnvelope(String memberId, String wrapped) async {
    // one attempt. the engine calls carry their own timeouts (onion 15s,
    // relay 60s), so retrying here only stacks them. a failed send is marked
    // failed and the user gets tap-to-retry.
    try {
      final to = await _reach(memberId);
      if (to == null) {
        dlog('send: no contact for $memberId');
        return false;
      }
      String cipher;
      // a member with no session AND no stored bundle can't be reached
      // (e.g. a dead identity still in the roster). don't burn a relay
      // timeout on it every send: skip fast so live members deliver now.
      if (!await _io.hasSession(memberId) && to.bundle == null) {
        // an introduced peer whose bundle swap never landed: ask again, the
        // user's tap-to-retry goes through once it does.
        if (await to.on?.isVouched(memberId) ?? false) {
          _wantHeal(memberId);
          unawaited(_sendBundleCtl(memberId, want: true));
        }
        dlog('send: $memberId unreachable (no session/bundle), skipping');
        return false;
      }
      try {
        cipher = await _io.encrypt(memberId, wrapped);
      } catch (e) {
        // a corrupt session (InvalidKeyException or bad state) can't encrypt.
        // if we kept the peer's bundle at pairing, wipe the broken session and
        // rebuild it, then try once more.
        final healed = await _healSession(memberId);
        if (!healed) {
          // no stored bundle (paired before v30 kept them). ask the peer
          // for a fresh one over the gift-wrap transport: the reply heals
          // the session and the user's tap-to-retry then goes through.
          _wantHeal(memberId);
          unawaited(_sendBundleCtl(memberId, want: true));
          rethrow;
        }
        cipher = await _io.encrypt(memberId, wrapped);
      }
      final backPaired = to.backPaired;
      final xpub = to.xpub;
      final onion = to.onion;

      // back-paired: onion-only, already fast and leaks the least.
      if (backPaired || onion.isEmpty) {
        // no onion and not added back yet: their first-contact address is
        // the one relay route that reaches them, as the chat's own send has
        final fc = backPaired ? null : peerFcFor(memberId);
        if (fc != null && fc.isNotEmpty) {
          final f = await Future(() => _io.firstContactSend(xpub, fc, cipher));
          if (f == 'ok') return true;
          dlog('send: first-contact failed ($f)');
        }
        final n = await Future(() => _io.relaySend(xpub, cipher));
        // the pair address is a drop box they read only once they add us
        // back. stored there is parked, not delivered.
        if (n == 'ok') return backPaired;
        dlog('send: nostr failed ($n)');
        return false;
      }

      // not back-paired: race onion and relay, so a slow or dead onion does
      // not cost the full 15s
      final done = Completer<bool>();
      var pending = 2;
      void settle(String tag, String r) {
        // a relay taking it for the pair address is not delivery here:
        // they read that address only after adding us back
        if (r == 'ok' && tag != 'nostr') {
          if (!done.isCompleted) done.complete(true);
        } else {
          if (r != 'ok') dlog('send: $tag failed ($r)');
          if (--pending == 0 && !done.isCompleted) done.complete(false);
        }
      }

      unawaited(
        Future(() => _io.onionSend(onion, cipher))
            .then((r) => settle('onion', r))
            .catchError((_) => settle('onion', 'err')),
      );
      unawaited(
        Future(() => _io.relaySend(xpub, cipher))
            .then((r) => settle('nostr', r))
            .catchError((_) => settle('nostr', 'err')),
      );
      final fc = _peerFc[memberId];
      dlog(
        fc == null || fc.isEmpty
            ? 'send: no first-contact addr for $memberId (v2 invite?)'
            : 'send: racing onion + relay + first-contact for $memberId',
      );
      if (fc != null && fc.isNotEmpty) {
        pending++;
        unawaited(
          _io
              .firstContactSend(xpub, fc, cipher)
              .then((r) => settle('firstcontact', r))
              .catchError((_) => settle('Firstcontact', 'err')),
        );
      }
      return done.future;
    } catch (e) {
      dlog('send to $memberId failed: $e');
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
      dlog('accept ack failed: $e');
    }
  }

  // one contact's card, ready to hand to another. the row is the source:
  // v2 pairings keep the xpub in the signal store, so fall back to that.
  Future<IntroFrame?> _introCardFor(String haloId, String note) async {
    // the dev chat is never handed on
    if (isDevId(haloId)) return null;
    // a hidden chat's row is in the open vault
    final c = await _ownerOf(haloId).getContact(haloId);
    if (c == null || (c['accepted'] as int? ?? 0) != 1) return null;
    var x = (c['xpub'] as String?) ?? '';
    if (x.isEmpty) x = await signalSession.peerXPubHex(haloId) ?? '';
    if (x.isEmpty) return null;
    return IntroFrame(
      haloId: haloId,
      onion: (c['onion'] as String?) ?? '',
      xPub: x,
      avatar: (c['avatar'] as num?)?.toInt(),
      fc: peerFcFor(haloId),
      note: note.isEmpty ? null : note,
    );
  }

  // introduce two accepted contacts to each other. each gets the other's
  // card over the session we already hold with them. returns whether each
  // side took it; the caller owns the budget and the wording.
  Future<({bool toFirst, bool toSecond})> introduce(
    String first,
    String second, {
    String note = '',
  }) async {
    // a quiet session sends nothing, and knows no one to introduce
    if (sessionQuiet) return (toFirst: false, toSecond: false);
    final n = note.trim();
    final cardOfFirst = await _introCardFor(first, n);
    final cardOfSecond = await _introCardFor(second, n);
    if (cardOfFirst == null || cardOfSecond == null) {
      return (toFirst: false, toSecond: false);
    }
    Future<bool> send(String to, IntroFrame card) async {
      try {
        final wrapped = await wrapMessage('', intro: card, sender: _mySender());
        return await _sendOneEnvelope(to, wrapped);
      } catch (e) {
        dlog('intro to $to failed: $e');
        return false;
      }
    }

    final r = await Future.wait([
      send(first, cardOfSecond),
      send(second, cardOfFirst),
    ]);
    dlog('intro: $first<->$second first=${r[0]} second=${r[1]}');
    return (toFirst: r[0], toSecond: r[1]);
  }

  // what a group row says about being a room, or null for a plain group
  Future<({String priv, String pub, int expiresAt})?> _roomOf(
    String groupId, [
    HaloDb? on,
  ]) async {
    final g = await (on ?? live).getGroup(groupId);
    final priv = g?['room_priv'] as String?;
    final pub = g?['room_pub'] as String?;
    if (priv == null || pub == null) return null;
    return (priv: priv, pub: pub, expiresAt: (g!['expires_at'] as int?) ?? 0);
  }

  // the one door every group frame leaves through. a plain group goes to
  // the member's signal session. a room frame is rewritten so the only
  // identity on it is the room key (no kryfo id, onion, push endpoint or
  // badge) and sealed with the room key to the member's room key.
  Future<bool> _sendGroupEnvelope(
    String groupId,
    String memberId,
    String wrapped,
  ) async {
    final room = await _roomOf(groupId);
    if (room == null) return _sendOneEnvelope(memberId, wrapped);
    if (memberId == room.pub) return false;
    if (room.expiresAt <= DateTime.now().millisecondsSinceEpoch) return false;
    final stripped = roomFrame(wrapped, room.pub);
    if (stripped == null) return false;
    final r = await engine.roomSend(room.priv, memberId, stripped);
    if (r != 'ok') dlog('room send: $r');
    return r == 'ok';
  }

  // ---- burner rooms ----

  // rooms we listen to, room pub -> member pubs, so a roster update only
  // opens the subscriptions it did not have.
  final Map<String, Set<String>> _roomSubs = {};
  Timer? _roomTimer;
  // the last room that expired, shown for a few seconds in the chat list
  String? expiredRoomName;

  Future<String> createRoom(
    String name, {
    required Duration expiry,
    int? cap,
  }) async {
    final k = engine.roomKeygen();
    if (k == null) throw StateError('could not make a room key');
    final fc = engine.roomFcPk(k.priv);
    if (fc.startsWith('error')) throw StateError(fc);
    final groupId = newMsgUid();
    await session.createRoom(
      groupId: groupId,
      name: name.trim().isEmpty ? l10n.homeRoom : name.trim(),
      priv: k.priv,
      pub: k.pub,
      expiresAt: DateTime.now().add(expiry).millisecondsSinceEpoch,
      creatorPub: k.pub,
      fcPk: fc,
      cap: cap,
      members: [k.pub],
    );
    // a quiet session keeps the room on this phone: nobody is listened for
    if (!sessionQuiet) {
      engine.roomSubscribeFcBg(k.priv);
      _roomSubs[k.pub] = {};
    }
    _armRoomTimer();
    await refreshGroups();
    return groupId;
  }

  Future<RoomLink?> roomLinkFor(String groupId) async {
    final g = await session.getGroup(groupId);
    if (g == null || g['room_pub'] == null) return null;
    return RoomLink(
      roomId: groupId,
      name: g['name'] as String,
      expiresAt: g['expires_at'] as int,
      creatorPub: g['creator_pub'] as String,
      fcPk: g['fc_pk'] as String,
      cap: g['member_cap'] as int?,
    );
  }

  // join off a link: make a key for this room only, tell the creator's drop
  // box about it, and listen for the creator. the roster comes back from
  // them and opens the rest.
  Future<String> joinRoom(RoomLink link) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (link.expiresAt <= now) return l10n.appThisRoomHasAlready;
    if (await session.groupExists(link.roomId)) {
      return l10n.appYouAreAlreadyIn;
    }
    final k = engine.roomKeygen();
    if (k == null) return l10n.appCouldNotMakeA;
    await session.createRoom(
      groupId: link.roomId,
      name: link.name,
      priv: k.priv,
      pub: k.pub,
      expiresAt: link.expiresAt,
      creatorPub: link.creatorPub,
      fcPk: link.fcPk,
      cap: link.cap,
      members: [link.creatorPub, k.pub],
    );
    // a quiet session keeps the room on this phone: the hello never leaves
    if (sessionQuiet) {
      _armRoomTimer();
      await refreshGroups();
      return l10n.appJoinedButTheCreator(link.name);
    }
    _roomSubs[k.pub] = {};
    await _subscribeRoomMembers(link.roomId);
    _armRoomTimer();
    await refreshGroups();
    final wrapped = roomFrame(
      await wrapMessage(
        '',
        groupId: link.roomId,
        groupControl: const GroupControl(type: 'join'),
        sender: _mySender(),
      ),
      k.pub,
    );
    if (wrapped == null) {
      return l10n.appJoinedButYourHello(link.name);
    }
    final r = await engine.roomSendFirstContact(
      k.priv,
      link.creatorPub,
      link.fcPk,
      wrapped,
    );
    dlog('room join: $r');
    return r == 'ok'
        ? l10n.appJoined(link.name)
        : l10n.appJoinedButTheCreator(link.name);
  }

  // open a subscription for every member key we do not listen to yet
  Future<void> _subscribeRoomMembers(String groupId) async {
    final room = await _roomOf(groupId);
    if (room == null) return;
    final have = _roomSubs.putIfAbsent(room.pub, () => {});
    for (final m in await live.getGroupMembers(groupId)) {
      if (m == room.pub || have.contains(m)) continue;
      have.add(m);
      engine.roomSubscribeBg(room.priv, m);
    }
  }

  // someone came in off the link. only the creator takes these, only for a
  // live room, only under the cap. then everyone gets the new roster and
  // subscribes to the newcomer off it.
  Future<void> _roomJoin(String roomPub, UnwrappedMessage env) async {
    final g = await live.roomByPub(roomPub);
    if (g == null || env.groupId != g['group_id']) return;
    if ((g['is_admin'] as int? ?? 0) != 1) return;
    if ((g['expires_at'] as int) <= DateTime.now().millisecondsSinceEpoch) {
      return;
    }
    final who = env.senderHaloId;
    if (who == null || !looksLikeRoomKey(who) || who == roomPub) return;
    // a room key that is a pinned key is no one's to join with
    if (devIdClaim(who)) return;
    final groupId = g['group_id'] as String;
    // a key that left or was taken out stays out: its join can come in
    // after its leave, off a lane of its own
    if ((await live.rosterGone(groupId)).contains(who)) return;
    final members = await live.getGroupMembers(groupId);
    // no room is bigger than a group: a longer roster is one no member
    // would take
    final cap = min(
      (g['member_cap'] as int?) ?? kGroupMemberCap,
      kGroupMemberCap,
    );
    if (!members.contains(who)) {
      if (members.length >= cap) {
        dlog('room: full, ignoring join');
        return;
      }
      await live.addGroupMember(groupId, who);
    }
    await _subscribeRoomMembers(groupId);
    final all = await live.getGroupMembers(groupId);
    await _queueControl(
      groupId,
      GroupControl(
        type: 'create',
        name: g['name'] as String,
        members: all,
        stamp: await live.nextRosterStamp(
          groupId,
          DateTime.now().millisecondsSinceEpoch,
        ),
      ),
      on: live,
    );
    _bumpChatRev('group:$groupId');
    await refreshGroups();
  }

  // a frame off a room subscription. the tag says which room key took it
  // and which member key sent it; the content is the plain envelope, the
  // relay layer already opened the seal.
  Future<void> _handleRoomFrame(String tag, String content) async {
    final parts = tag.split(':');
    if (parts.length < 2) return;
    final roomPub = parts[1];
    final g = await live.roomByPub(roomPub);
    if (g == null) return;
    final groupId = g['group_id'] as String;
    if ((g['expires_at'] as int) <= DateTime.now().millisecondsSinceEpoch) {
      await _destroyRoom(groupId, expired: true);
      return;
    }
    final env = unwrapMessage(content);
    if (env.groupId != groupId) return;
    if (parts[0] == 'roomfc') {
      if (env.groupControl?.type == 'join') await _roomJoin(roomPub, env);
      return;
    }
    if (parts.length < 3) return;
    final from = parts[2];
    if (env.senderHaloId != from) return;
    if (!(await live.getGroupMembers(groupId)).contains(from)) {
      dlog('room: frame from a key not in the roster, dropped');
      return;
    }
    try {
      await _applyIncomingPayload(from, env, wire: content);
    } on CapHeld {
      // rooms are never strangers; here for completeness
    }
    if (env.groupControl != null) await _subscribeRoomMembers(groupId);
  }

  // the room is over: every message, every file, the row, the key, the
  // subscriptions. the wipe goes through the same shred the burn timer
  // uses. a gone room is not a notification, just a line in the list for
  // a moment if someone is looking.
  Future<void> _destroyRoom(
    String groupId, {
    bool expired = false,
    HaloDb? on,
  }) async {
    final d = on ?? live;
    final g = await d.getGroup(groupId);
    if (g == null) return;
    final pub = g['room_pub'] as String?;
    final priv = g['room_priv'] as String?;
    if (pub != null && !d.container.quiet) {
      engine.roomUnsubscribeBg(pub);
      _roomSubs.remove(pub);
      if (priv != null) {
        engine.roomForgetBg(priv, await d.getGroupMembers(groupId));
      }
    }
    for (final path in await d.groupFilePaths(groupId)) {
      await shredFile(path);
    }
    await d.deleteGroupMessages(groupId);
    await d.deleteGroup(groupId);
    // what it put in the shade goes with it
    await _io.unnotify('group:$groupId');
    // the line in the list is only for a room of the session on screen: an
    // everyday room ending while the decoy is open says nothing there
    if (expired && identical(d, session.primary)) {
      expiredRoomName = g['name'] as String?;
      Timer(const Duration(seconds: 6), () {
        expiredRoomName = null;
        notifyListeners();
      });
    }
    _bumpChatRev('group:$groupId');
    await refreshGroups();
  }

  Future<void> leaveRoom(String groupId) async {
    if (sessionQuiet) return _destroyRoom(groupId, on: session.primary);
    // one try, now: the room's keys go with it, and nothing could send later
    try {
      final wrapped = await wrapMessage(
        '',
        groupId: groupId,
        groupControl: const GroupControl(type: 'leave'),
        sender: _mySender(),
      );
      await Future.wait([
        for (final m in await _othersIn(live, groupId))
          _sendGroupEnvelope(groupId, m, wrapped),
      ]);
    } catch (e) {
      dlog('leave control not sent: $e');
    }
    await _destroyRoom(groupId);
  }

  // every container a room can be made in: the everyday one, and the
  // decoy's, whose rooms end on time too
  List<HaloDb> get _roomHomes {
    final out = <HaloDb>[live];
    for (final d in [_decoyDb, session.primary]) {
      if (d != null && !out.any((o) => identical(o, d))) out.add(d);
    }
    return out;
  }

  @visibleForTesting
  Future<void> sweepRooms() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final d in _roomHomes) {
      for (final g in await d.expiredRooms(now)) {
        await _destroyRoom(g['group_id'] as String, expired: true, on: d);
      }
    }
  }

  // one sweep every half minute is plenty: the header counts down on its
  // own, this only has to notice the end.
  void _armRoomTimer() {
    _roomTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (!haloWiping) unawaited(sweepRooms());
    });
  }

  // on boot: drop what ended while we were away, then listen to what lives
  Future<void> _subscribeRooms() async {
    await sweepRooms();
    final rooms = await _listenToRooms();
    if (rooms > 0) _armRoomTimer();
    dlog('rooms: listening to $rooms');
    unawaited(_armForOtherRooms());
  }

  // the decoy opens on its own at boot, maybe only after the line above:
  // its rooms are counted once it has, so they end on time too
  Future<void> _armForOtherRooms() async {
    await containersReady;
    try {
      for (final d in _roomHomes.skip(1)) {
        if ((await d.rooms()).isNotEmpty) {
          _armRoomTimer();
          return;
        }
      }
    } catch (e) {
      dlog('rooms: other containers not counted ($e)');
    }
  }

  @visibleForTesting
  Future<void> subscribeRoomsAtBoot() => _subscribeRooms();

  @visibleForTesting
  bool get roomTimerArmed => _roomTimer != null;

  // every everyday room's lanes, each runner started again, so all of
  // them dial the relays of the mode now in use
  Future<int> _listenToRooms() async {
    final rooms = await live.rooms();
    for (final g in rooms) {
      final gid = g['group_id'] as String;
      final priv = g['room_priv'] as String;
      final pub = g['room_pub'] as String;
      _roomSubs[pub] = {};
      if ((g['is_admin'] as int? ?? 0) == 1) engine.roomSubscribeFcBg(priv);
      await _subscribeRoomMembers(gid);
    }
    return rooms.length;
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
    Map<String, String>? preview,
    PollSpec? poll,
    String? sticker,
  }) async {
    // a retry of a poll passes only its uid: the options come off the row
    if (poll == null && msgUid != null) {
      poll = (await session.pollRow(msgUid))?.spec;
    }
    // and so does a retry of a sticker, or it goes out as its emoji
    if (sticker == null && msgUid != null) {
      sticker = await session.stickerOf(msgUid);
    }
    msgUid ??= newMsgUid();
    final burnAt = (burnSeconds != null && burnSeconds > 0)
        ? DateTime.now().millisecondsSinceEpoch + burnSeconds * 1000
        : null;
    // save the local row up front so the chat list shows it at once.
    // peer_id = self so we render it as outgoing. a retry passes the same
    // uid, and a second row breaks every uid-keyed widget key.
    if (!await session.messageExists(msgUid)) {
      await session.saveMessage(
        sessionId,
        'out',
        plain,
        groupId: groupId,
        msgUid: msgUid,
        replyTo: replyTo,
        burnAt: burnAt,
        // a retry after a reload reads the timer back from the row
        burnSecs: burnAt == null ? null : burnSeconds,
        // born unsent, or a dead send reloads as a ticked message nobody
        // ever received
        sent: 0,
        preview: preview == null ? null : jsonEncode(preview),
        poll: poll?.toRow(),
        sticker: sticker,
      );
    }
    // a quiet session keeps the row here, unsent: nothing leaves
    if (sessionQuiet) {
      notifyListeners();
      return false;
    }
    final members = await session.getGroupMembers(groupId);
    // if we are the group admin, ride the full roster on the message so any
    // member whose list drifted self-heals the moment they receive it.
    final adminId = await session.groupAdminId(groupId);
    final amAdmin = adminId == myId;
    // ride the member keys too, not just ids: a self-healed member the
    // receiver has no contact for would otherwise throw InvalidKeyException
    // on encrypt. participants let the receiver upsert a stub.
    final rosterParts = amAdmin ? await _buildParticipants(members) : null;
    final wrapped = await wrapMessage(
      plain,
      msgUid: msgUid,
      replyTo: replyTo,
      burnSeconds: burnSeconds,
      preview: preview,
      groupId: groupId,
      roster: amAdmin ? members : null,
      rosterParticipants: rosterParts,
      supporterBadge: await sharedBadge(),
      sender: _mySender(),
      poll: poll?.toWire(),
      sticker: sticker,
    );
    dlog('GRPSEND group=$groupId members=$members me=$myId admin=$amAdmin');
    final d = _ownerOf(groupId);
    final to = await _othersIn(d, groupId, members);
    final missed = await _fanOut(d, groupId, to, wrapped);
    final anyOk = missed.length < to.length;
    // the tick is earned, not assumed: only a delivery to at least one
    // member flips the row to sent. the members it missed are owed it
    if (anyOk) {
      await session.markSent(msgUid);
      await _oweText(d, msgUid, groupId, to: to, missed: missed, first: true);
    }
    notifyListeners();
    return anyOk;
  }

  // chunked media multicast for groups: every 16k slice to each member, see
  // group_media_send. the local row is saved by the caller; this only puts
  // bytes on the wire. returns 'ok', 'busy', 'cancelled' or an error string.
  Future<String> sendMediaToGroup(
    String groupId,
    String path, {
    required String msgUid,
    String caption = '',
    String? fileName,
    bool voice = false,
    bool voiceDisguised = false,
    int? burnSeconds,
    // only these members, owed it by a send that went, with what each has
    Map<String, Set<int>>? owed,
  }) async {
    // one send per media at a time, the same set the 1:1 path holds. the
    // drainer picks up any row older than 45 s, and a video to a group is
    // still leaving long after that: both would send the whole file.
    if (mediaInflight.contains(msgUid)) return 'busy';
    // a quiet session keeps the row here, unsent: nothing leaves
    if (sessionQuiet) return 'error: quiet';
    final d = _ownerOf(groupId);
    final members = await d.getGroupMembers(groupId);
    final adminId = await d.groupAdminId(groupId);
    final amAdmin = adminId == myId;
    // the roster is read again for each slice: a long file still going out
    // after a remove or a leave must not carry the old list back to the
    // other phones. once this phone has left or is no longer the admin, the
    // slices carry none. ids and cards are one pair, so wraps running side
    // by side never mix two lists
    var held = (
      ids: members,
      parts: amAdmin ? await _buildParticipants(members) : null,
    );
    Future<(List<String>?, List<Map<String, String>>?)> roster() async {
      if (!amAdmin) return (null, null);
      final now = await d.getGroupMembers(groupId);
      if (!now.contains(myId) || await d.groupAdminId(groupId) != myId) {
        return (null, null);
      }
      var pair = held;
      if (!listEquals(now, pair.ids)) {
        pair = (ids: now, parts: await _buildParticipants(now));
        held = pair;
      }
      return (pair.ids, pair.parts);
    }

    // in a room this phone is its room key, which never takes a frame
    final room = await _roomOf(groupId, d);
    final to = [
      for (final m in members)
        if (m != myId && m != room?.pub && (owed?.containsKey(m) ?? true)) m,
    ];
    // the owed have all left the group
    if (owed != null && to.isEmpty) return 'gone';
    // a member still to get a control of the group gets that first. one
    // that cannot yet is owed the whole file
    final waiting = await d.groupCtlWaiting(groupId);
    final behind = <String>{};
    await Future.wait([
      for (final m in to)
        if (waiting.contains(m))
          _ctlLane(d, groupId, m, force: true).then((ok) {
            if (!ok) behind.add(m);
          }),
    ]);
    final go = [
      for (final m in to)
        if (!behind.contains(m)) m,
    ];
    if (go.isEmpty) return owed == null ? 'error: held' : 'later';

    // 16k slices. bigger sizes trip nip-44's 65535 plaintext ceiling once
    // base64'd + double-wrapped (envelope + signal + gift wrap ~= x2.4), and
    // public relays reject the event. 16k lands ~38-51k, safe on every relay.
    // receivers reassemble by index/total, so slice size is free to change.
    return sendGroupSlices(
      path: path,
      msgUid: msgUid,
      members: go,
      // a send to the owed is behind a row that already reads sent
      progressKey: owed == null ? d.container.chatKey(groupId) : null,
      owed: owed,
      // a member left short is sent the rest later, from the outbox
      onShort: (short, total) async {
        // the send went either way: a row not written costs that member
        // the file, not the others their sent tick
        try {
          await d.settleGroupOwed(
            msgUid,
            groupId,
            total: total,
            tried: go,
            short: {
              ...short,
              if (owed == null)
                for (final m in behind) m: <int>{},
            },
            sentTo: to.length,
            first: owed == null,
            now: DateTime.now().millisecondsSinceEpoch,
          );
        } catch (e) {
          dlog('GRP MEDIA $msgUid: owed not kept (${e.runtimeType})');
        }
        groupOwedTick.value++;
      },
      photo: fileName == null && !voice,
      wrap: (slice, i, total) async {
        final (ids, parts) = await roster();
        return wrapMessage(
          caption,
          msgUid: msgUid,
          imageB64: fileName == null && !voice ? slice : null,
          fileB64: fileName != null || voice ? slice : null,
          fileName: fileName,
          voice: voice,
          voiceDisguised: voiceDisguised,
          mediaId: total > 1 ? msgUid : null,
          chunkIndex: total > 1 ? i : null,
          chunkTotal: total > 1 ? total : null,
          burnSeconds: burnSeconds,
          groupId: groupId,
          roster: ids,
          rosterParticipants: parts,
          supporterBadge: await sharedBadge(),
          sender: _mySender(),
        );
      },
      deliver: (m, wrapped) => _sendGroupEnvelope(groupId, m, wrapped),
    );
  }

  // shared pin: everyone in the group sees the same pins
  Future<void> pinInGroup(
    String groupId,
    String targetMsgUid,
    bool pinned,
  ) async {
    await session.setPinned(targetMsgUid, pinned);
    notifyListeners();
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) {
      notifyListeners();
      return;
    }
    final wrapped = await wrapMessage(
      '',
      groupId: groupId,
      pin: PinFrame(targetUid: targetMsgUid, pinned: pinned),
      sender: _mySender(),
    );
    final members = await session.getGroupMembers(groupId);
    await Future.wait([
      for (final memberId in members)
        if (memberId != myId) _sendGroupEnvelope(groupId, memberId, wrapped),
    ]);
  }

  // pairwise reaction multicast for group messages.
  Future<void> reactInGroup(
    String groupId,
    String targetMsgUid,
    String emoji,
  ) async {
    if (emoji.isEmpty) {
      await session.removeReaction(targetMsgUid, '');
    } else {
      await session.addReaction(targetMsgUid, '', emoji);
    }
    // show it now, not after the tor multicast
    notifyListeners();
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) {
      notifyListeners();
      return;
    }
    final wrapped = await wrapMessage(
      '',
      groupId: groupId,
      reaction: ReactionFrame(targetUid: targetMsgUid, emoji: emoji),
      sender: _mySender(),
    );
    final members = await session.getGroupMembers(groupId);
    // fan out in the background; the reaction is already on screen.
    unawaited(
      Future.wait([
        for (final memberId in members)
          if (memberId != myId) _sendGroupEnvelope(groupId, memberId, wrapped),
      ]),
    );
  }

  // ---- polls ----

  // who this phone is in a chat. in a room it is the room key, never the
  // kryfo id: a vote, or the final count a close carries, would otherwise
  // put the real id in front of the room.
  Future<String> meIn(String groupId) async =>
      (await _roomOf(groupId, session.primary))?.pub ?? sessionId;

  // a vote goes out like a reaction: shown here at once, then to every
  // member. choosing nothing takes the vote back.
  Future<void> votePoll(
    String groupId,
    String pollUid,
    List<int> choices,
  ) async {
    final row = await session.pollRow(pollUid);
    if (row == null || row.spec.closed || row.groupId != groupId) return;
    final me = await meIn(groupId);
    final picks = cleanChoices(choices, row.spec);
    final seq = nextVoteSeq(
      await session.pollVoteSeq(pollUid, me),
      DateTime.now().millisecondsSinceEpoch,
    );
    await session.putPollVote(pollUid, me, groupId, picks, seq);
    _bumpChatRev('group:$groupId');
    notifyListeners();
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) {
      notifyListeners();
      return;
    }
    final wrapped = await wrapMessage(
      '',
      groupId: groupId,
      vote: VoteFrame(pollUid: pollUid, choices: picks, seq: seq),
      sender: _mySender(),
    );
    final members = await session.getGroupMembers(groupId);
    unawaited(
      Future.wait([
        for (final m in members)
          if (m != myId && m != me) _sendGroupEnvelope(groupId, m, wrapped),
      ]),
    );
  }

  // only the poll's creator closes it. the close carries the votes as this
  // phone holds them, and every member takes those as the final result.
  Future<void> closePoll(String groupId, String pollUid) async {
    final row = await session.pollRow(pollUid);
    if (row == null || !row.mine || row.spec.closed || row.groupId != groupId) {
      return;
    }
    final held = (await session.pollVotesFor([pollUid]))[pollUid] ?? const {};
    final finals = <String, List<int>>{};
    for (final e in held.entries) {
      final picks = cleanChoices(e.value.choices, row.spec);
      if (picks.isNotEmpty) finals[e.key] = picks;
    }
    await session.closePollRow(pollUid, row.spec, finals, groupId);
    _bumpChatRev('group:$groupId');
    notifyListeners();
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) {
      notifyListeners();
      return;
    }
    final wrapped = await wrapMessage(
      '',
      groupId: groupId,
      pollClose: PollCloseFrame(pollUid: pollUid, finalVotes: finals),
      sender: _mySender(),
    );
    final me = await meIn(groupId);
    final members = await session.getGroupMembers(groupId);
    await Future.wait([
      for (final m in members)
        if (m != myId && m != me) _sendGroupEnvelope(groupId, m, wrapped),
    ]);
  }

  // a vote from a member. members write to us separately, so a vote can
  // overtake the poll it names; it waits then, an hour at most, and counts
  // once the poll is here. a vote for a poll that already went is dropped.
  Future<void> _applyVote(
    String sender,
    UnwrappedMessage env,
    HaloDb db,
  ) async {
    final v = env.vote!;
    final gid = env.groupId;
    if (gid == null || !await db.groupExists(gid)) return;
    final row = await db.pollRow(v.pollUid);
    final fate = voteFate(
      member: (await db.getGroupMembers(gid)).contains(sender),
      pollHere: row != null,
      pollGone: row == null && await db.pollGone(v.pollUid),
      sameChat: row?.groupId == gid,
      closed: row?.spec.closed ?? false,
    );
    switch (fate) {
      case VoteFate.drop:
        dlog('vote: dropped');
      case VoteFate.hold:
        final raw = <int>{
          for (final c in v.choices)
            if (c is int && c >= 0 && c < kPollMaxOptions) c,
        }.toList()..sort();
        await db.putPollVote(v.pollUid, sender, gid, raw, v.seq);
      case VoteFate.count:
        final picks = cleanChoices(v.choices, row!.spec);
        if (await db.putPollVote(v.pollUid, sender, gid, picks, v.seq)) {
          notifyListeners();
        }
    }
  }

  Future<void> _applyPollClose(
    String sender,
    UnwrappedMessage env,
    HaloDb db,
  ) async {
    final c = env.pollClose!;
    final row = await db.pollRow(c.pollUid);
    if (!closeAccepted(
      pollHere: row != null,
      fromCreator: row != null && await db.isTheirs(c.pollUid, sender),
      sameChat: row?.groupId == env.groupId,
      closed: row?.spec.closed ?? false,
    )) {
      dlog('poll close: dropped');
      return;
    }
    await db.closePollRow(
      c.pollUid,
      row!.spec,
      cleanFinal(c.finalVotes, row.spec),
      row.groupId,
    );
    notifyListeners();
  }

  // recall a group message everywhere: delete locally, tell every member.
  // receiver handles 'un' group-agnostically (deletes by uid).
  Future<void> unsendInGroup(String groupId, String targetMsgUid) async {
    // a file still going, to everyone or to the members it missed, stops
    // before its row and its file go, and what they were owed goes too
    final going = mediaInflight.contains(targetMsgUid);
    if (going) cancelMediaSend(targetMsgUid);
    await session.deleteMessage(targetMsgUid);
    groupOwedTick.value++;
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) {
      notifyListeners();
      return;
    }
    await _sayUnsent(groupId, targetMsgUid);
    notifyListeners();
    // a slice already on its way can land after that: said again once the
    // send has let go, so nobody is left holding part of the file
    if (going) {
      unawaited(
        whenMediaFree(
          targetMsgUid,
        ).then((_) => _sayUnsent(groupId, targetMsgUid)),
      );
    }
  }

  Future<void> _sayUnsent(String groupId, String targetMsgUid) async {
    final wrapped = await wrapMessage(
      '',
      groupId: groupId,
      unsend: targetMsgUid,
      sender: _mySender(),
    );
    final members = await session.getGroupMembers(groupId);
    await Future.wait([
      for (final memberId in members)
        if (memberId != myId) _sendGroupEnvelope(groupId, memberId, wrapped),
    ]);
  }

  // edit a group message everywhere: swap text locally, tell every member.
  Future<void> editInGroup(
    String groupId,
    String targetMsgUid,
    String newText,
  ) async {
    await session.editMessage(targetMsgUid, newText);
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) {
      notifyListeners();
      return;
    }
    final wrapped = await wrapMessage(
      '',
      groupId: groupId,
      edit: EditFrame(targetUid: targetMsgUid, newText: newText),
      sender: _mySender(),
    );
    final members = await session.getGroupMembers(groupId);
    await Future.wait([
      for (final memberId in members)
        if (memberId != myId) _sendGroupEnvelope(groupId, memberId, wrapped),
    ]);
    notifyListeners();
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
        final c = await session.getContact(h);
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

  // small groups on purpose: multicast stays cheap and big rooms bring
  // moderation trouble
  static const int kGroupMemberCap = 50;

  Future<String> createGroupAndAnnounce(
    String name,
    List<String> memberHaloIds,
  ) async {
    final groupId = newMsgUid();
    final full = [sessionId, ...memberHaloIds];
    if (full.length > kGroupMemberCap) throw const GroupFull();
    await session.createGroup(
      groupId,
      name,
      full,
      isAdmin: true,
      adminId: sessionId,
    );
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) {
      await refreshGroups();
      return groupId;
    }
    final d = _ownerOf(groupId);
    final participants = await _buildParticipants(full);
    final gc = GroupControl(
      type: 'create',
      name: name,
      members: full,
      participants: participants,
      stamp: await d.nextRosterStamp(
        groupId,
        DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _queueControl(groupId, gc, on: d);
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
    final group = await session.getGroup(groupId);
    if (group == null) return;
    if ((group['is_admin'] as int? ?? 0) != 1) return;
    final existingMembers = await session.getGroupMembers(groupId);
    if (existingMembers.length + newHaloIds.length > kGroupMemberCap) {
      throw const GroupFull();
    }
    for (final h in newHaloIds) {
      await session.addGroupMember(groupId, h);
    }
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) {
      await refreshGroups();
      return;
    }
    final d = _ownerOf(groupId);
    final newParticipants = await _buildParticipants(newHaloIds);
    final addGc = GroupControl(
      type: 'add',
      members: newHaloIds,
      participants: newParticipants,
    );
    await _queueControl(groupId, addGc, to: existingMembers, on: d);
    final allMembers = await session.getGroupMembers(groupId);
    final allParticipants = await _buildParticipants(allMembers);
    final createGc = GroupControl(
      type: 'create',
      name: group['name'] as String,
      members: allMembers,
      participants: allParticipants,
      stamp: await d.nextRosterStamp(
        groupId,
        DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _queueControl(groupId, createGc, to: newHaloIds, on: d);
    await refreshGroups();
  }

  // admin-only. removes locally and tells everyone (including removed) so
  // both sides converge on the new member list.
  Future<void> removeMembersFromGroup(
    String groupId,
    List<String> removedHaloIds,
  ) async {
    final group = await session.getGroup(groupId);
    if (group == null) return;
    if ((group['is_admin'] as int? ?? 0) != 1) return;
    final allMembers = await session.getGroupMembers(groupId);
    for (final h in removedHaloIds) {
      await session.removeGroupMember(groupId, h);
    }
    // a room key taken out does not join again
    final d = _ownerOf(groupId);
    if (await _roomOf(groupId, d) != null) {
      await d.noteRosterGone(groupId, removedHaloIds);
    }
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) {
      await refreshGroups();
      return;
    }
    // the ones taken out hear it too, so they drop the group
    final gc = GroupControl(type: 'remove', members: removedHaloIds);
    await _queueControl(groupId, gc, to: allMembers);
    await refreshGroups();
  }

  Future<void> renameGroupAndAnnounce(String groupId, String newName) async {
    final group = await session.getGroup(groupId);
    if (group == null) return;
    if ((group['is_admin'] as int? ?? 0) != 1) return;
    await session.renameGroup(groupId, newName);
    final gc = GroupControl(type: 'rename', name: newName);
    // a quiet session keeps it on this phone: nothing leaves
    if (!sessionQuiet) await _queueControl(groupId, gc);
    await refreshGroups();
  }

  // anyone can leave. the group goes from here with all it held, then the
  // rest are told, so they drop us from their copies. the leave is queued:
  // it goes once the route is there, and leaving waits for nobody
  Future<void> leaveGroupAndAnnounce(String groupId) async {
    if (await _roomOf(groupId, session.primary) != null) {
      return leaveRoom(groupId);
    }
    final d = _ownerOf(groupId);
    final members = sessionQuiet
        ? const <String>[]
        : await d.getGroupMembers(groupId);
    await session.clearGroupConversation(groupId);
    await session.deleteGroup(groupId);
    // a quiet session keeps it on this phone: nothing leaves
    if (!sessionQuiet) {
      await _queueControl(
        groupId,
        const GroupControl(type: 'leave'),
        to: members,
        on: d,
      );
    }
    await _io.unnotify('group:$groupId');
    _bumpChatRev('group:$groupId');
    await refreshGroups();
  }

  // a group this phone was taken out of: its messages, files and row, and
  // what it left in the shade
  Future<void> _dropGroup(String groupId, HaloDb db) async {
    await db.clearGroupConversation(groupId);
    await db.deleteGroup(groupId);
    await _io.unnotify('group:$groupId');
  }

  // groups this phone was taken out of, by name, until the open screen of
  // one says so
  final Map<String, String> _removedFrom = {};

  String? takeRemovedFrom(String groupId) => _removedFrom.remove(groupId);

  // the engine's own identity, which only the everyday container holds
  // one new identity at a time: a second ask while one is being made gets
  // that one, so signal never ends on a key the engine no longer holds
  Future<void>? _regenerating;
  Future<void> regenerateIdentity() => _regenerating ??= _regenerateIdentity()
      .whenComplete(() => _regenerating = null);

  Future<void> _regenerateIdentity() async {
    if (sessionQuiet) return;
    // a first signal boot still running ends on the old key, then all that
    // is made from the key is made again from the new one
    await _signalBoot;
    myId = engine.generateIdentity();
    await live.saveIdentity(myId, engine.myEdPrivkey(), engine.myXPrivkey());
    myXPub = engine.myXPubkey();
    restored = false;
    if (signalSession.ready) await _rekeySignal();
    // the invite address is derived from the key too
    if (_fcLoaded) engine.subscribeFirstContactBg(_fcCounter);
    notifyListeners();
  }

  Future<void> _rekeySignal() async {
    try {
      final database = await live.open();
      final xpb = _hexDecode(engine.myXPrivkey());
      await signalSession.rekey(
        database: database,
        xPubBytes: _hexDecode(engine.myXPubkey()),
        xPrivBytes: xpb,
      );
      _zeroBytes(xpb);
    } catch (e) {
      // the next start bootstraps on the saved key
      dlog('signal rekey failed (${e.runtimeType})');
    }
  }

  Future<void> subscribePeer(String haloId) async {
    // the dev chat listens on its own lane, and only once it runs
    if (isDevId(haloId)) return subscribeDevLane();
    // the row xpub is set by v1 pairing and is there before any session
    // exists; v2 bundle pairing leaves it empty and puts the key in the
    // signal store instead. try both, backfill the row when we learn it.
    // a hidden chat's row is in the open vault. no one blocked is heard
    final d = _ownerOf(haloId);
    if (await d.isBlocked(haloId)) return;
    var xPub = await d.contactXPub(haloId);
    if (xPub == null || xPub.isEmpty) {
      xPub = await signalSession.peerXPubHex(haloId);
      if (xPub != null && xPub.isNotEmpty) {
        await d.setContactXPub(haloId, xPub);
      }
    }
    if (xPub == null || xPub.isEmpty) return;
    _xPubToHaloId[xPub] = haloId;
    _io.listen(xPub);
  }

  // a backup reads the databases while no hide, show or close runs, so its
  // copies agree and a vault shut on the way shuts after it, never half
  // way through. the vault is the session's open one, or with made the one
  // a setup just made; null when there is none at hand
  Future<T> backupStill<T>(
    Future<T> Function(HaloDb? vault) work, {
    bool made = false,
  }) => _serial(() => work(made ? _madeVault : _session.vault));

  // the export that moved this identity writes the mark; the moved screen
  // clears it when the person says they are not moving after all
  Future<void> markMoved() async {
    // a decoy is never moved
    if (sessionQuiet) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('moved.at', DateTime.now().millisecondsSinceEpoch);
    _movedAway = true;
    notifyListeners();
  }

  // the person chose to keep this phone to read. this session only: the
  // mark stays and the next launch asks again
  void keepMovedToRead() {
    movedReadOnly = true;
    notifyListeners();
  }

  Future<void> unmarkMoved() async {
    // a decoy is never moved
    if (sessionQuiet) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('moved.at');
    _movedAway = false;
    movedReadOnly = false;
    notifyListeners();
  }

  Future<void> markOnboardingComplete() async {
    onboardingComplete = true;
    await secureStore.write(key: 'onboarding_done', value: 'true');
    notifyListeners();
  }
}

final appState = AppState();

void main() async {
  dlog('LAUNCH main');
  WidgetsFlutterBinding.ensureInitialized();
  // a toast shown while the lock is up waits for it to lift
  haloWhenOpen = (act) => lockGuard.afterUnlock(act);
  // toasts live in the root overlay, over every route and sheet
  haloToastOverlay = () => rootNavKey.currentState?.overlay;
  // an unlock opens its session under the lock screen, before it lifts
  lockState.onOutcome = appState.sessionFor;
  lockState.sessionsReady = appState.containersReady;
  unawaited(_sweepPlaintextLeftovers());
  // what a backup or a restore cut short left, before either can run again
  unawaited(sweepBackupLeftovers());
  // not awaited: this is a platform call, and with no activity attached it
  // never answers
  unawaited(
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  );
  // the periodic job knocks here every fifteen minutes. registered before
  // anything that could fail, and whether or not a screen is attached:
  // after a kill the system restarts the process for the service or the
  // job, and this handler is what is there to answer.
  const MethodChannel('halo/job').setMethodCallHandler((call) async {
    if (call.method != 'drain') return null;
    dlog('job: drain asked');
    appState.noteJobRun();
    final args = call.arguments;
    return appState.drainNow(serviceUp: args is Map && args['up'] == true);
  });
  // the language, before anything says a word: the first frame, or a
  // notification from a process the job started
  await loadAppLocale();
  // the theme pref sits in secure storage, and the first read on a new phone
  // creates the keystore key, which takes seconds. the splash paints dark
  // first. started before the window check so a headless start loads it too.
  unawaited(
    appState.loadThemePref().then((_) {
      if (HaloColors.isLight) themeRevision.value++;
    }),
  );
  if (PlatformDispatcher.instance.implicitView == null) {
    dlog('LAUNCH headless');
    // no window: the service or the job brought the process back, and
    // runApp would throw without a view. only an engine with something to
    // serve boots here: samsung relaunches a recently used app's process
    // right after its data is cleared, and booting then would make a fresh
    // identity out of a panic wipe. the rest waits for a window.
    unawaited(() async {
      if (await _hasLocalData()) {
        await appState.boot();
      } else {
        dlog('LAUNCH headless with nothing here - waiting for a window');
      }
    }());
    Timer.periodic(const Duration(milliseconds: 400), (t) {
      if (PlatformDispatcher.instance.implicitView == null) return;
      t.cancel();
      dlog('LAUNCH window arrived');
      WidgetsBinding.instance.addObserver(lockBack);
      runApp(const HaloApp());
      WidgetsBinding.instance.addPostFrameCallback((_) => _openFromNotif());
    });
    return;
  }
  WidgetsBinding.instance.addPostFrameCallback((_) => dlog('LAUNCH frame'));
  // before runApp, so it is asked about back before the app's navigator
  WidgetsBinding.instance.addObserver(lockBack);
  runApp(const HaloApp());
  dlog('LAUNCH runApp returned');
  // cold-start: if launched from a notification tap, open the chat
  // after the first frame so rootNavKey has a navigator.
  WidgetsBinding.instance.addPostFrameCallback((_) => _openFromNotif());
}

Future<void> _openFromNotif() async {
  try {
    final details = await notifPlugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      final payload = details?.notificationResponse?.payload;
      Future.delayed(
        const Duration(milliseconds: 500),
        () => openChatForHalo(payload),
      );
    }
  } catch (e) {
    dlog('notif launch: $e');
  }
}

final themeRevision = ValueNotifier<int>(0);

class HaloApp extends StatelessWidget {
  const HaloApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        themeRevision,
        localeRevision,
        navRevision,
      ]),
      builder: (context, _) => haloAppShell(
        navigatorKey: rootNavKey,
        locale: l10nLocale,
        lock: (navigator) => _LockGate(child: navigator),
        home: _LocaleScope(child: _OnboardingGate(child: RootShell())),
      ),
    );
  }
}

// true when the phone asks for less movement. widgets check this before
// running anything decorative.
bool reduceMotion(BuildContext c) => MediaQuery.of(c).disableAnimations;

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
    // whole go runtime + embedded tor and blocks briefly, and before the first
    // paint that can trip the anr watchdog on weak phones.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => appState.bootWhenWanted(),
    );
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
                ? l10n.appBooting
                : l10n.appSettingUpYourIdentity,
            style: HaloType.mono(size: 11, color: HaloColors.text2),
          ),
        ),
      );
    }
    return HomeScreen(
      key: ValueKey(appState.sessionRev),
      haloId: appState.sessionId,
      contacts: appState.contacts,
      devRow: appState.devRow,
      pendingCount: appState.pendingCount,
      support: appState.devMode ? appState.supportWaiting : null,
      groups: appState.groups
          .map(
            (g) => GroupSummary(
              groupId: g.groupId,
              name: g.name,
              memberCount: g.memberCount,
              unread: g.unread,
              mentioned: g.mentioned,
              expiresAt: g.expiresAt,
              hidden: g.hidden,
            ),
          )
          .toList(),
      onAddContact: () => showAddContact(context),
      onNewGroup: () => _open(const NewGroupScreen()),
      onNewRoom: () async {
        final id = await showRoomCreateSheet(context);
        if (id == null || !mounted) return;
        _open(GroupChatScreen(groupId: id));
      },
      expiredRoomName: appState.expiredRoomName,
      onOpenDev: () => _open(const DevScreen()),
      onOpenSettingsDirect: () => _open(SettingsScreen()),
      onOpenChat: (id) async {
        final rows = await session.contacts();
        final matches = rows.where((r) => r['halo_id'] == id).toList();
        if (matches.isEmpty || !context.mounted) return;
        final row = matches.first;
        Navigator.push(
          context,
          haloRoute(
            ChatScreen(
              peerHaloId: id,
              peerOnion: row['onion'] as String,
              peerXPub: row['xpub'] as String,
              avatarSeed: id,
              avatarChoice: (row['avatar'] as num?)?.toInt(),
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
  final action = await showHaloSheet<String>(
    context,
    scroll: true,
    builder: (sheetCtx) => _AddSheet(ctrl: ctrl, done: sheetCtx),
  );
  if (action == null || !context.mounted) return;
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

// the add someone sheet. the field lights up while it is typed in, and
// "add them" fills once there is something to add
class _AddSheet extends StatefulWidget {
  final TextEditingController ctrl;
  // the sheet's own context, which the choice pops
  final BuildContext done;
  const _AddSheet({required this.ctrl, required this.done});
  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_repaint);
    widget.ctrl.addListener(_repaint);
  }

  void _repaint() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_repaint);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sheetCtx = widget.done;
    final still = MediaQuery.disableAnimationsOf(context);
    final d = still ? Duration.zero : const Duration(milliseconds: 200);
    final typed = widget.ctrl.text.trim().isNotEmpty;
    final lit = _focus.hasFocus;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        0,
        22,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          const SizedBox(height: 18),
          Text(
            l10n.appAddSomeone,
            style: HaloType.serif(
              size: 22,
              italic: true,
              color: HaloColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.appScanTheirCodeOr,
            style: HaloType.sans(size: 12.5, color: HaloColors.text2),
          ),
          const SizedBox(height: 16),
          _Pressable(
            onTap: () => Navigator.pop(sheetCtx, 'scan'),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: HaloColors.amber,
                borderRadius: BorderRadius.circular(14),
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
                    l10n.appScanTheirCode,
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
          const SizedBox(height: 14),
          AnimatedContainer(
            duration: d,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: HaloColors.surface3,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: lit
                    ? HaloColors.amber.withValues(alpha: 0.7)
                    : HaloColors.line,
                width: lit ? 1 : 0.5,
              ),
            ),
            child: TextField(
              textDirection: TextDirection.ltr,
              controller: widget.ctrl,
              focusNode: _focus,
              minLines: 1,
              maxLines: 3,
              style: HaloType.mono(size: 12, color: HaloColors.text),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: l10n.appAKryfoLinkA,
                hintStyle: HaloType.mono(size: 12, color: HaloColors.text3),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _Pressable(
            onTap: () => Navigator.pop(sheetCtx, 'paste'),
            child: AnimatedContainer(
              duration: d,
              curve: Curves.easeOutCubic,
              height: 46,
              decoration: BoxDecoration(
                color: typed ? HaloColors.amber : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: HaloColors.amber, width: 1),
              ),
              child: Center(
                child: AnimatedDefaultTextStyle(
                  duration: d,
                  style: HaloType.sans(
                    size: 13.5,
                    weight: FontWeight.w600,
                    color: typed ? HaloColors.onAmber : HaloColors.amber,
                  ),
                  child: Text(l10n.appAddThem),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          // the page with every way in: your own code, a link to send,
          // handles, introductions
          _Pressable(
            onTap: () => Navigator.pop(sheetCtx, 'mine'),
            // the door most people need, so it gets the amber edge and glow
            // the jump button uses
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              decoration: BoxDecoration(
                color: HaloColors.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: HaloColors.amber.withValues(alpha: 0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: HaloColors.amber.withValues(alpha: 0.16),
                    blurRadius: 16,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: HaloColors.amberSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.qr_code_2,
                      size: 20,
                      color: HaloColors.amber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.appEveryWayToAdd,
                          style: HaloType.sans(
                            size: 14.5,
                            weight: FontWeight.w600,
                            color: HaloColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.appShowYourCodeSend,
                          style: HaloType.sans(
                            size: 11.5,
                            color: HaloColors.text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: HaloColors.amber),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
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
    // with less movement the press is felt, not seen
    final still = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(0.96),
      onTapUp: (_) => _set(1),
      onTapCancel: () => _set(1),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: still ? 1 : _scale,
        duration: Duration(milliseconds: _scale < 1 ? 90 : 240),
        curve: _scale < 1 ? Curves.easeOut : Curves.easeOutBack,
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
  final _msgCtrl = TextEditingController(text: l10n.appHelloFromTheOther);
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
    _status = appState.restored
        ? l10n.appIdentityRestored
        : l10n.appIdentityCreated;
    _loadLastPeer();
  }

  Future<void> _loadLastPeer() async {
    final rows = await session.contacts();
    if (rows.isEmpty) return;
    setState(() {
      _peerId = rows.first['halo_id'] as String;
      _peerOnion = rows.first['onion'] as String;
      _peerXPub = rows.first['xpub'] as String;
    });
  }

  Future<void> _startListener() async {
    setState(() => _status = l10n.appStartingTor30s);
    final docsDir = await getApplicationDocumentsDirectory();
    // off the ui thread: starting tor blocks on socket i/o long enough to
    // trip an anr
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
          session.saveMessage(_peerId, 'in', plain);
        }
        setState(() {});
      }
    });
  }

  Future<void> _send() async {
    if (_peerOnion.isEmpty || _peerXPub.isEmpty) {
      setState(() => _status = l10n.appScanOrImportA);
      return;
    }
    setState(() => _status = l10n.appEncryptingSending30s);
    final plain = _msgCtrl.text;
    final cipher = engine.encryptFor(_peerXPub, plain);
    if (cipher.startsWith('error')) {
      setState(() => _status = cipher);
      return;
    }
    final result = await Future(() => engine.sendTo(_peerOnion, cipher));
    if (result == 'ok') {
      await session.saveMessage(_peerId, 'out', plain);
    }
    setState(() => _status = result);
  }

  Future<void> _showMyQr() async {
    if (_myAddr.isEmpty) {
      setState(() => _status = l10n.appTapStartListeningFirst);
      return;
    }
    final uri = await buildHaloUriV3(
      appState.myId,
      _myAddr,
      appState.fcCounter,
    );
    if (!mounted) return;
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
                l10n.appYourKryfo,
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
                  showHaloToast(context, l10n.appUriCopied);
                },
                child: Text(
                  l10n.appCopyUri,
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
          l10n.appAddAKryfo,
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
                label: Text(l10n.appScanQr),
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
                label: Text(l10n.appPairingCode),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HaloColors.text2,
                  side: BorderSide(color: HaloColors.line),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.appOrPaste,
              style: HaloType.sans(size: 11, color: HaloColors.text3),
            ),
            const SizedBox(height: 10),
            TextField(
              textDirection: TextDirection.ltr,
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
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'paste'),
            child: Text(
              l10n.appImport,
              style: HaloType.sans(color: HaloColors.amber),
            ),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;

    if (action == 'code') {
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
          l10n.appDev,
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
                'Kryfo',
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
                l10n.appYourKryfo2,
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
                    l10n.appRestoredFromDisk,
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
                child: Text(
                  _myAddr.isEmpty ? l10n.appStartListening : l10n.appListening,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.qr_code, color: HaloColors.amber),
                      label: Text(l10n.appShowMyQr),
                      onPressed: _showMyQr,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.content_paste, color: HaloColors.violet),
                      label: Text(l10n.appImportPeer),
                      onPressed: _importPeer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_peerId.isNotEmpty) ...[
                Text(
                  l10n.appPeer,
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
                  labelText: l10n.appMessageWillBeEncrypted,
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
                child: Text(l10n.appEncryptSend),
              ),
              const SizedBox(height: 16),
              TorWarmupGraph(status: _torStatus, bootstrapPct: _bootstrapPct),
              const SizedBox(height: 12),
              if (_status.isNotEmpty)
                Text(
                  l10n.appStatus(_status),
                  style: HaloType.sans(size: 12, color: HaloColors.text2),
                ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () =>
                    Navigator.of(context).push(haloRoute(const ModesScreen())),
                child: Text(
                  l10n.appSpeedPrivacy,
                  style: HaloType.mono(size: 11, color: HaloColors.amber),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => Navigator.of(
                  context,
                ).push(haloRoute(const GettingMessagesScreen())),
                child: Text(
                  l10n.appGettingMessages,
                  style: HaloType.mono(size: 11, color: HaloColors.amber),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  if (lockState.lockOn) {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: HaloColors.surface3,
                        title: Text(
                          l10n.appDisableAppLock,
                          style: HaloType.serif(
                            size: 18,
                            color: HaloColors.text,
                          ),
                        ),
                        content: Text(
                          l10n.appThePinWillBe,
                          style: HaloType.sans(
                            size: 13,
                            color: HaloColors.text2,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text(
                              l10n.commonCancel,
                              style: HaloType.sans(
                                size: 13,
                                color: HaloColors.text2,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: Text(
                              l10n.appDisable,
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
                  builder: (_, _) => Text(
                    lockState.lockOn ? l10n.appAppLockOn : l10n.appAppLockOff,
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

// when the cold start's splash lets go, set once for the process: a gate
// built again for a switched session holds it to the same moment
DateTime? _splashUntil;

class _OnboardingGateState extends State<_OnboardingGate> {
  // boot is quick enough that the onion is gone before it registers. hold
  // the splash a beat on cold start so it gets seen. warm reopens skip it.
  bool _hold = false;

  @override
  void initState() {
    super.initState();
    if (!appState.ready) {
      appState.bootWhenWanted();
      _splashUntil ??= DateTime.now().add(const Duration(milliseconds: 2500));
    }
    final left = _splashUntil?.difference(DateTime.now());
    if (left != null && left > Duration.zero) {
      _hold = true;
      Future.delayed(left, () {
        if (mounted) setState(() => _hold = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        if (appState.bootError != null) {
          return BootFailedScreen(
            error: appState.bootError!,
            onRetry: () {
              setState(() => _hold = false);
              appState.retryBoot();
            },
          );
        }
        if (!appState.ready || _hold) {
          return const TorBootSplash();
        }
        if (appState.movedAway && !appState.movedReadOnly) {
          return const MovedScreen();
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

// a language switch redraws everything below here from scratch, on the
// first screen: whatever was open above it is closed. the lock and the
// navigator stay, so a switch never asks for the pin again.
class _LocaleScope extends StatefulWidget {
  final Widget child;
  const _LocaleScope({required this.child});
  @override
  State<_LocaleScope> createState() => _LocaleScopeState();
}

class _LocaleScopeState extends State<_LocaleScope>
    with SingleTickerProviderStateMixin {
  // the new language comes up out of the background instead of every word
  // changing in one frame
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );
  late final _shown = CurvedAnimation(
    parent: _fade,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    localeRevision.addListener(_switched);
  }

  @override
  void dispose() {
    localeRevision.removeListener(_switched);
    _shown.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _switched() {
    if (lockGuard.isLocked()) {
      // under the lock nothing animates, so nothing may be left mid-pop:
      // a new navigator, home only
      renewRootNavigator();
    } else {
      rootNavKey.currentState?.popUntil((r) => r.isFirst);
    }
    setState(() {});
    if (!reduceMotion(context)) _fade.forward(from: 0);
    unawaited(appState.languageChanged());
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: HaloColors.surface,
    child: FadeTransition(
      opacity: _shown,
      child: KeyedSubtree(
        key: ValueKey(localeRevision.value),
        child: widget.child,
      ),
    ),
  );
}

class _LockGate extends StatefulWidget {
  final Widget child;
  const _LockGate({required this.child});
  @override
  State<_LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<_LockGate> {
  @override
  Widget build(BuildContext context) => LockGate(
    app: widget.child,
    lock: lockState,
    loaded: () => lockState.loaded,
    locked: () => lockState.locked,
    load: lockState.load,
    leaving: lockState.leaving,
    returned: lockState.returned,
    guard: lockGuard,
    quiet: () => sessionQuiet,
    pad: (_) => const LockScreen(),
    lockingUp: appState.lockingUp,
    inFront: appState.appInFront,
    localesChanged: systemLocalesChanged,
    revealed: () {
      appRevealed = true;
      homeRevealed();
    },
  );
}

class TorHalo extends StatefulWidget {
  final bool label;
  const TorHalo({super.key, this.label = false});
  @override
  State<TorHalo> createState() => TorHaloState();
}

class TorHaloState extends State<TorHalo> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  // pulses only while tor is still coming up. once it is usable the chip
  // says so and rests, even when the onion is never confirmed reachable
  bool get _isConnecting => appState.torStatus == TorStatus.starting;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    appState.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  // a few pulses each time tor starts, then still: where tor is blocked it
  // can sit in starting for minutes, and nothing here may run that long
  bool _pulsed = false;

  void _sync() {
    if (!_isConnecting) {
      _pulsed = false;
      if (_c.isAnimating) _c.stop();
      return;
    }
    if (_pulsed || _c.isAnimating) return;
    _pulsed = true;
    if (mounted && motionStill(context)) return;
    _c.repeat(count: 8);
  }

  @override
  void dispose() {
    appState.removeListener(_sync);
    _c.dispose();
    super.dispose();
  }

  void _explain() {
    showHaloSheet(
      context,
      scroll: true,
      builder: (_) => AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final s = appState.torStatus;
          final pct = appState.bootstrapPct;
          // bootstrapped and publishing both mean tor's client side is live:
          // messages send and arrive over relays, full 3 hops. the remaining
          // wait only publishes our own address so peers can dial us direct.
          // none of it counts while no relay gets through
          final line = s == TorStatus.off
              ? l10n.appTorIsOff
              : !appState.torUsable && s != TorStatus.starting
              ? l10n.appConnecting2
              : s == TorStatus.reachable
              ? l10n.appConnectedRoutedThrough3
              : s == TorStatus.publishing
              ? l10n.appReadyToSendPublishing
              : s == TorStatus.bootstrapped
              ? l10n.appReadyToSendFinishing
              : l10n.appConnecting(percent(pct / 100));
          return Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                const SizedBox(height: 8),
                Text(
                  l10n.appTor,
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
                if (s != TorStatus.reachable || !appState.torUsable) ...[
                  const SizedBox(height: 16),
                  Text(
                    s == TorStatus.off
                        ? l10n.appTorIsOffTurn
                        : l10n.appTheFirstConnectionTakes,
                    style: HaloType.sans(
                      size: 12.5,
                      color: HaloColors.text,
                    ).copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.appRelayAndFastModes,
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
      // nothing to explain outside onion: no bootstrap, no circuit, no
      // descriptor
      onTap: appState.sendMode == 'private' ? _explain : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([appState, _c]),
        builder: (context, _) {
          final s = appState.torStatus;
          final off = s == TorStatus.off;
          // ready is the test the outbox and the offline card use, so the
          // pill never says ready over a route nothing gets through
          final ready = appState.torUsable;
          final secured = ready && s == TorStatus.reachable;
          final connecting = _isConnecting;
          const torGreen = Color(0xFF34D399);
          final accent = off
              ? HaloColors.text3
              // one route, one colour. onion stays violet whether tor is
              // merely usable or fully published.
              : appState.sendMode == 'balanced'
              ? const Color(0xFF4BB8C9)
              : appState.sendMode == 'fast'
              ? torGreen
              : ready
              ? const Color(0xFFB79CFF)
              : HaloColors.amber;
          final t = _c.value;
          Widget dot(Color accent) => SizedBox(
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
          // the state changes are the most watched thing on the screen: the
          // colour slides to the new one and the words cross-fade, rather
          // than both snapping
          Widget tinted(Widget Function(Color) build) =>
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: accent),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                builder: (_, c, _) => build(c ?? accent),
              );
          if (!widget.label) {
            return tinted(
              (c) =>
                  SizedBox(width: 20, height: 20, child: Center(child: dot(c))),
            );
          }
          final mode = appState.sendMode;
          final txt = mode == 'balanced'
              ? (appState.linkUp ? l10n.appViaRelay : l10n.appOffline)
              : mode == 'fast'
              ? (appState.linkUp ? l10n.appFast : l10n.appOffline)
              : off
              ? l10n.appTorOff
              : ready
              ? l10n.appTorReady
              : l10n.appConnecting2;
          return tinted(
            (c) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                dot(c),
                const SizedBox(width: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.35),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    txt,
                    key: ValueKey(txt),
                    style: HaloType.mono(size: 11, color: c),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// raw voice recordings a crash, or an older build, left in the cache: the
// voice as spoken, before any disguise. the decrypted open-with copies are
// cleared on the native side, on every resume.
Future<void> _sweepPlaintextLeftovers() async {
  try {
    await sweepVoiceLeftovers(await getTemporaryDirectory());
  } catch (e) {
    dlog('sweep: voice leftovers (${e.runtimeType})');
  }
}

// every raw recording in [dir]: one that will not go is logged and the
// rest still go. [drop] stands in for the delete in tests
@visibleForTesting
Future<void> sweepVoiceLeftovers(
  Directory dir, {
  Future<void> Function(File f)? drop,
}) async {
  await for (final e in dir.list()) {
    final name = e.uri.pathSegments.isEmpty ? '' : e.uri.pathSegments.last;
    if (e is! File || !name.startsWith('vn_') || !name.endsWith('.wav')) {
      continue;
    }
    try {
      await (drop ?? (f) => f.delete())(e);
    } catch (err) {
      dlog('sweep: a voice leftover stayed (${err.runtimeType})');
    }
  }
}

// the database exists: this phone has been set up at some point. a plain file
// check on purpose: reading secure storage on a wiped app would create its
// keystore key and write a prefs file, which is a trace of its own. the
// native side asks the same question (KryfoState.hasData).
Future<bool> _hasLocalData() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/halo.db').exists();
  } catch (_) {
    // cannot tell: assume it has been set up
    return true;
  }
}
