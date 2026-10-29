// SPDX-License-Identifier: GPL-3.0-or-later
// the engine bindings: ffi calls into libhalo, some run on an isolate

part of '../main.dart';

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
// the calls that seal, open, listen or derive an address: the identity
// they run on comes first (identities.dart)
typedef IdentFn = Pointer<Utf8> Function(Int32);
typedef IdentFnDart = Pointer<Utf8> Function(int);
typedef IdentOneFn = Pointer<Utf8> Function(Int32, Pointer<Utf8>);
typedef IdentOneFnDart = Pointer<Utf8> Function(int, Pointer<Utf8>);
typedef IdentTwoFn =
    Pointer<Utf8> Function(Int32, Pointer<Utf8>, Pointer<Utf8>);
typedef IdentTwoFnDart =
    Pointer<Utf8> Function(int, Pointer<Utf8>, Pointer<Utf8>);
typedef IdentThreeFn =
    Pointer<Utf8> Function(Int32, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef IdentThreeFnDart =
    Pointer<Utf8> Function(int, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef IdentCounterFn = Pointer<Utf8> Function(Int32, Int32);
typedef IdentCounterFnDart = Pointer<Utf8> Function(int, int);
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
  late final IdentTwoFnDart _encryptFor;
  late final IdentTwoFnDart _decryptFrom;
  late final Pointer<Utf8> Function(Pointer<Utf8>) _start;
  late final CStrFnDart _drainInbox;
  late final IntArgFnDart _setDebug;
  late final CStrFnDart _getStatus;
  late final CStrFnDart _nostrKick;
  late final CStrFnDart _memStats;
  late final OneArgFnDart _nostrInit;
  late final IdentOneFnDart _nostrSubscribe;
  late final CStrFnDart _nostrPoll;
  late final IdentCounterFnDart _fcPk;
  late final CStrFnDart _txState;
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
    _encryptFor = _lib.lookupFunction<IdentTwoFn, IdentTwoFnDart>(
      'HaloEncryptFor',
    );
    _decryptFrom = _lib.lookupFunction<IdentTwoFn, IdentTwoFnDart>(
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
    _nostrSubscribe = _lib.lookupFunction<IdentOneFn, IdentOneFnDart>(
      'HaloNostrSubscribe',
    );
    _nostrPoll = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloNostrPoll');
    _fcPk = _lib.lookupFunction<IdentCounterFn, IdentCounterFnDart>(
      'HaloFirstContactPk',
    );
    _txState = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloTransportState');
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

  // the open chat's peer key, '' for none: its address asks first after a
  // start or wake, with no turn. looked up on first use so older engines load
  late final OneArgFnDart _nostrFirst = _lib
      .lookupFunction<OneArgFn, OneArgFnDart>('HaloNostrFirst');
  void nostrFirst(String peerXPubHex) {
    final p = peerXPubHex.toNativeUtf8();
    try {
      engineTake(_nostrFirst(p));
    } catch (_) {
      // an older engine without the call
    } finally {
      malloc.free(p);
    }
  }

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
  Future<String> nostrSend(int ident, String peerXPubHex, String b64Cipher) =>
      devGate.nostrSend(
        peerXPubHex,
        b64Cipher,
        // a frame no signal seal covers is filled out here, inside the
        // relay's encryption
        out: () => _onPair(
          ident,
          peerXPubHex,
          (pair) =>
              _sendOnIsolate((
                nostr: true,
                ident: ident,
                a: pair,
                b: padRumor(b64Cipher),
              )).timeout(
                const Duration(seconds: 60),
                onTimeout: () => 'error: relay timeout',
              ),
        ),
        room: (priv) => roomSend(priv, peerXPubHex, b64Cipher),
      );

  // [fresh]: someone just added or accepted, heard without a turn
  void nostrSubscribeBg(int ident, String peerXPubHex, {bool fresh = false}) {
    _background(
      devGate.listen(
        peerXPubHex,
        out: () => _onPair(
          ident,
          peerXPubHex,
          (pair) => _subscribeOnIsolate(ident, pair, fresh: fresh),
        ),
        room: (priv) async {
          roomSubscribeBg(priv, peerXPubHex);
          return 'ok';
        },
      ),
      'relay listen',
    );
  }

  // how tor connects: auto, direct, snowflake, webtunnel, moat or own,
  // with its options as json. "ok" or "error: <code>". the engine applies
  // it itself. looked up on first use so an older engine still loads
  late final TwoArgFnDart _setBridgeMode = _lib
      .lookupFunction<TwoArgFn, TwoArgFnDart>('HaloSetBridgeMode');
  String setBridgeMode(String mode, String opts) {
    try {
      final a = mode.toNativeUtf8();
      final b = opts.toNativeUtf8();
      try {
        return engineTake(_setBridgeMode(a, b));
      } finally {
        malloc.free(a);
        malloc.free(b);
      }
    } on ArgumentError {
      return 'error: no engine';
    }
  }

  // the kept mode, handed over once at start before tor runs. taken with a
  // decoy open too, where a pick is refused
  late final TwoArgFnDart _restoreBridgeMode = _lib
      .lookupFunction<TwoArgFn, TwoArgFnDart>('HaloRestoreBridgeMode');
  String restoreBridgeMode(String mode, String opts) {
    try {
      final a = mode.toNativeUtf8();
      final b = opts.toNativeUtf8();
      try {
        return engineTake(_restoreBridgeMode(a, b));
      } finally {
        malloc.free(a);
        malloc.free(b);
      }
    } on ArgumentError {
      return 'error: no engine';
    }
  }

  // the status line's facts as json, never a line or an address
  late final CStrFnDart _bridgeStatus = _lib.lookupFunction<CStrFn, CStrFnDart>(
    'HaloBridgeStatus',
  );
  String bridgeStatus() {
    try {
      return engineTake(_bridgeStatus());
    } on ArgumentError {
      return '{}';
    }
  }

  // the route the engine is on now
  late final CStrFnDart _transportMode = _lib
      .lookupFunction<CStrFn, CStrFnDart>('HaloTransportMode');
  String transportMode() {
    try {
      return engineTake(_transportMode());
    } on ArgumentError {
      return '';
    }
  }

  // automatic tries again now, after it gave up
  late final CStrFnDart _bridgeRetry = _lib.lookupFunction<CStrFn, CStrFnDart>(
    'HaloBridgeRetry',
  );
  void bridgeRetry() {
    try {
      _take(_bridgeRetry());
    } on ArgumentError {
      // an older engine: tor keeps its own schedule
    }
  }

  // a check per line of the last lines handed over, as json
  late final CStrFnDart _lineChecks = _lib.lookupFunction<CStrFn, CStrFnDart>(
    'HaloBridgeLineChecks',
  );
  String bridgeLineChecks() {
    try {
      return engineTake(_lineChecks());
    } on ArgumentError {
      return '[]';
    }
  }

  // what automatic remembers, and the built-in and tor project lines the
  // engine refreshed: json for the store, an error while a decoy is open
  String autoMemory() => _keep('HaloAutoMemory');
  String bridgeCache() => _keep('HaloBridgeCache');
  String setAutoMemory(String json) => _give('HaloSetAutoMemory', json);
  String setBridgeCache(String json) => _give('HaloSetBridgeCache', json);

  String _keep(String symbol) {
    try {
      return engineTake(_lib.lookupFunction<CStrFn, CStrFnDart>(symbol)());
    } on ArgumentError {
      return '{"error":"no engine"}';
    }
  }

  String _give(String symbol, String json) {
    try {
      final a = json.toNativeUtf8();
      try {
        return _take(_lib.lookupFunction<OneArgFn, OneArgFnDart>(symbol)(a));
      } finally {
        malloc.free(a);
      }
    } on ArgumentError {
      return 'error: no engine';
    }
  }

  // google push: the fcm token sealed once to the gateway's key, a new seal
  // each call (engine/push_seal.go). "error: ..." for a key or a token that
  // is not one, or an engine without the call
  String pushSeal(String publicKey, String token) {
    final k = publicKey.toNativeUtf8();
    final t = token.toNativeUtf8();
    try {
      return engineTake(
        _lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloPushSeal')(k, t),
      );
    } catch (_) {
      return 'error: no engine';
    } finally {
      malloc.free(k);
      malloc.free(t);
    }
  }

  // the bridges that come with kryfo for one transport
  List<String> builtinBridges(String transport) {
    try {
      final a = transport.toNativeUtf8();
      try {
        final r =
            jsonDecode(
                  engineTake(
                    _lib.lookupFunction<OneArgFn, OneArgFnDart>(
                      'HaloBuiltinBridges',
                    )(a),
                  ),
                )
                as Map<String, dynamic>;
        return [for (final l in (r['lines'] as List? ?? const [])) '$l'];
      } finally {
        malloc.free(a);
      }
    } catch (_) {
      return const [];
    }
  }

  void restartTor() => _take(_restartTor());

  // tor reconnected now, past the floor and any reconnect still running.
  // 'ok' or why not. off the ui thread: it waits on tor's control port
  Future<String> reconnectNow() => _torCtlOnIsolate('HaloReconnectNow');

  // android reports a new default network: tor is bounced once it has been
  // quiet a few seconds. looked up on first use so older engines still load.
  late final CounterFnDart _networkState = _lib
      .lookupFunction<CounterFn, CounterFnDart>('HaloNetworkState');
  // [online]: whether there is a network after the change. with none the
  // engine resets its floors and waits for one before it bounces
  void networkChanged({bool online = true}) {
    try {
      _take(_networkState(online ? 1 : 0));
    } catch (_) {
      // an older engine without the call: tor keeps its own schedule
    }
  }

  // what connectivity sees, on every event: with the watch's word the
  // engine tells a dispute from an outage. looked up on first use
  late final CounterFnDart _connectivitySeen = _lib
      .lookupFunction<CounterFn, CounterFnDart>('HaloConnectivitySeen');
  void connectivitySeen(bool on) {
    try {
      _take(_connectivitySeen(on ? 1 : 0));
    } catch (_) {
      // an older engine without the call
    }
  }

  // android's word on the default network as json (validated, captive
  // portal, vpn, type), for automatic bridges. looked up on first use
  late final OneArgFnDart _networkDetail = _lib
      .lookupFunction<OneArgFn, OneArgFnDart>('HaloNetworkDetail');
  void networkDetail(String json) {
    try {
      final a = json.toNativeUtf8();
      try {
        _take(_networkDetail(a));
      } finally {
        malloc.free(a);
      }
    } catch (_) {
      // an older engine without the call
    }
  }

  // a check-in begins or ends: automatic starts no pass inside one
  late final CounterFnDart _checkInWindow = _lib
      .lookupFunction<CounterFn, CounterFnDart>('HaloCheckIn');
  // [ago]: seconds since the job began, so the engine times the check-in's
  // turns from the job
  void checkInWindow(bool on, {int ago = 0}) {
    try {
      _take(_checkInWindow(on ? 1 + ago : 0));
    } catch (_) {
      // an older engine without the call
    }
  }

  static String _take(Pointer<Utf8> p) => engineTake(p);

  // the registry is a request over tor, so it runs off the ui thread
  Future<String> handleCheck(String h) =>
      _ffiOnIsolate('HaloHandleCheck', [h], wait: registryWait);

  Future<String> handleClaim(String h, String invite, String bio) =>
      _ffiOnIsolate('HaloHandleClaim', [h, invite, bio], wait: registryWait);

  Future<String> handleRelease(String h) =>
      _ffiOnIsolate('HaloHandleRelease', [h], wait: registryWait);

  Future<String> handleListing(String h, bool listed, String name) =>
      _ffiOnIsolate('HaloHandleListing', [
        h,
        listed ? '1' : '0',
        name,
      ], wait: registryWait);

  // the helper app mode (engine/knock.go). an engine without the calls
  // answers with an error and the mode stays hidden
  Future<String> _knock(String symbol, List<String> args, Duration wait) =>
      _ffiOnIsolate(
        symbol,
        args,
        wait: wait,
        what: 'knock',
      ).catchError((Object e) => 'error: ${e.runtimeType}');

  Future<String> knockAddresses(String excludeJson) =>
      _knock('HaloKnockAddresses', [excludeJson], const Duration(seconds: 10));

  Future<String> knockRegister(String itemsJson) =>
      _knock('HaloKnockRegister', [itemsJson], const Duration(seconds: 100));

  Future<String> knockCheck() =>
      _knock('HaloKnockCheck', const [], const Duration(seconds: 100));

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

  // what the tor project advises for a country, and the country it
  // guesses from the address it sees. outside tor, through meek, and only
  // with the person's yes. off the ui isolate: a network round trip
  Future<String> moatSettings(String country) => _ffiOnIsolate(
    'HaloMoatSettings',
    [
      jsonEncode({
        'consent': true,
        'via': 'meek',
        if (country.isNotEmpty) 'country': country,
      }),
    ],
    wait: const Duration(seconds: 60),
    what: 'moat',
  );

  // everything the transport knows, in one read. no inference on this side.
  Map<String, dynamic> transportState() {
    try {
      return jsonDecode(engineTake(_txState())) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }

  // the main identity's v3 first-contact address at [counter]: no other
  // identity has one (fcKeyPk)
  String firstContactPk(int ident, int counter) =>
      engineTake(_fcPk(ident, counter));

  // the public half of an invite's random first-contact key, an error
  // string for 32 bytes that are not a secp256k1 key
  late final OneArgFnDart _fcKeyPk = _lib
      .lookupFunction<OneArgFn, OneArgFnDart>('HaloFcKeyPk');
  String fcKeyPk(String skHex) {
    final p = skHex.toNativeUtf8();
    try {
      return engineTake(_fcKeyPk(p));
    } finally {
      freeSecret(p);
    }
  }

  // listen on, or let go of, invite [inviteId]'s first-contact key of
  // [ident]
  Future<String> subscribeFcKey(int ident, String inviteId, String skHex) =>
      _identFfiOnIsolate('HaloNostrSubscribeFcKey', ident, [inviteId, skHex]);
  Future<String> unsubscribeFcKey(int ident, String inviteId) =>
      _identFfiOnIsolate('HaloNostrUnsubscribeFcKey', ident, [inviteId]);

  // identity v4 invites (invite_v4.go): the face signature over a face
  // text by the legacy ed key, an onion key's address, the seal key a v4
  // first contact to my [ident] from [senderXHex] must carry
  late final OneArgFnDart _faceSign = _lib
      .lookupFunction<OneArgFn, OneArgFnDart>('HaloFaceSign');
  String faceSign(String msgHex) {
    final p = msgHex.toNativeUtf8();
    try {
      return engineTake(_faceSign(p));
    } finally {
      malloc.free(p);
    }
  }

  late final OneArgFnDart _onionOfKey = _lib
      .lookupFunction<OneArgFn, OneArgFnDart>('HaloOnionOfKey');
  String onionOfKey(String keyHex) {
    final p = keyHex.toNativeUtf8();
    try {
      return engineTake(_onionOfKey(p));
    } finally {
      malloc.free(p);
    }
  }

  late final IdentOneFnDart _helloSealPk = _lib
      .lookupFunction<IdentOneFn, IdentOneFnDart>('HaloHelloSealPk');
  String helloSealPk(int ident, String senderXHex) {
    final p = senderXHex.toNativeUtf8();
    try {
      return engineTake(_helloSealPk(ident, p));
    } finally {
      malloc.free(p);
    }
  }

  // a hello or a v4 opener from my [ident] to [fcPk], the first-contact key
  // of an invite answered by [ownerXHex], under the two's hello seal key
  Future<String> sendHello(
    int ident,
    String ownerXHex,
    String fcPk,
    String msg,
  ) =>
      _identFfiOnIsolate('HaloNostrSendHello', ident, [
        ownerXHex,
        fcPk,
        padRumor(msg),
      ]).timeout(
        const Duration(seconds: 60),
        onTimeout: () => 'error: relay timeout',
      );

  // an identity other than the main one, by its x25519 key, and let go
  late final IdentOneFnDart _identityPut = _lib
      .lookupFunction<IdentOneFn, IdentOneFnDart>('HaloIdentityPut');
  late final IdentFnDart _identityDrop = _lib
      .lookupFunction<IdentFn, IdentFnDart>('HaloIdentityDrop');
  String identityPut(int ident, String xPrivHex) {
    final p = xPrivHex.toNativeUtf8();
    try {
      return engineTake(_identityPut(ident, p));
    } finally {
      freeSecret(p);
    }
  }

  String identityDrop(int ident) => engineTake(_identityDrop(ident));

  // a pair a v4 first contact made: its address seed
  Future<String> pairSeed(int ident, String peerXPubHex, String seedHex) =>
      _identFfiOnIsolate('HaloPairSeed', ident, [peerXPubHex, seedHex]);

  // put an invite where a six digit code points, and look for one there. a
  // look that never came back heard from no relay, so it says nothing about
  // the code. a share waits past the engine's publishWait, so a slow onion
  // dial that lands is not reported as unreached
  Future<String> pairCodePublish(String code, String payload) =>
      _pairCodeOnIsolate(
        code,
        payload,
      ).timeout(const Duration(seconds: 60), onTimeout: () => pairUnreached);

  Future<String> pairCodeFetch(String code) => _pairCodeOnIsolate(
    code,
    null,
  ).timeout(const Duration(seconds: 40), onTimeout: () => pairUnreached);

  // unlike every other subscription this needs no contacts
  void subscribeFirstContactBg(int ident, int counter) {
    _background(_fcSubscribeOnIsolate(ident, counter), 'first contact listen');
  }

  // the same, waited on: 'ok', or why the address is not listened on
  Future<String> subscribeFirstContact(int ident, int counter) =>
      _fcSubscribeOnIsolate(ident, counter);

  late final int Function() _fcRelays = _lib
      .lookupFunction<Int32 Function(), int Function()>(
        'HaloFirstContactRelays',
      );

  // how many relays the first-contact listener is on, -1 with none
  int firstContactRelays() => _fcRelays();

  // introduce ourselves to someone who has never heard of us.
  Future<String> sendFirstContact(
    int ident,
    String peerXPubHex,
    String fcPk,
    String b64Cipher,
  ) => devGate.sendFirstContact(
    peerXPubHex,
    fcPk,
    b64Cipher,
    out: () => _onPair(
      ident,
      peerXPubHex,
      (pair) =>
          _fcSendOnIsolate(ident, pair, fcPk, padRumor(b64Cipher)).timeout(
            const Duration(seconds: 60),
            onTimeout: () => 'error: relay timeout',
          ),
    ),
    room: (priv) => roomSendFirstContact(priv, peerXPubHex, fcPk, b64Cipher),
  );

  // it cannot wait on the dev chat, so it never names a pinned key
  String nostrSubscribe(int ident, String peerXPubHex) {
    if (devGate.names(xPub: peerXPubHex)) return kDevRefused;
    final ptr = peerXPubHex.toNativeUtf8();
    try {
      return engineTake(_nostrSubscribe(ident, ptr));
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

  // the gif relay, on a lane of its own: search, trending, and a picture
  // into [path] whole or not at all ("ok <n>"). the route people search
  // takes. a wait that runs out says gif, not tor: off the onion route
  // there is no tor to blame
  Future<String> gifPost(String url, String body) => _ffiOnIsolate(
    'HaloGifPost',
    [url, body],
    wait: const Duration(seconds: 60),
    what: 'gif',
  );

  Future<String> gifGet(String url) => _ffiOnIsolate(
    'HaloGifGet',
    [url],
    wait: const Duration(seconds: 60),
    what: 'gif',
  );

  Future<String> gifGetFile(String url, String path) => _ffiOnIsolate(
    'HaloGifGetFile',
    [url, path],
    wait: const Duration(seconds: 80),
    what: 'gif',
  );

  // the files service (file_drop.dart): a send or a fetch runs on an
  // isolate for as long as the file takes; its progress and its stop are
  // asked for here, by "s:<message id>" or "f:<file id>"
  Future<String> fileSend(String job) => _ffiOnIsolate(
    'HaloFileSend',
    [job],
    wait: const Duration(hours: 2),
    what: 'files',
  );

  Future<String> fileFetch(String job) => _ffiOnIsolate(
    'HaloFileFetch',
    [job],
    wait: const Duration(hours: 2),
    what: 'files',
  );

  Future<String> fileGot(String host, String id, String token) => _ffiOnIsolate(
    'HaloFileGot',
    [host, id, token],
    wait: const Duration(minutes: 3),
    what: 'files',
  );

  Future<String> fileValues(String job) => _ffiOnIsolate(
    'HaloFileValues',
    [job],
    wait: const Duration(minutes: 1),
    what: 'files',
  );

  Future<String> fileTakeBack(String job) => _ffiOnIsolate(
    'HaloFileDrop',
    [job],
    wait: const Duration(minutes: 3),
    what: 'files',
  );

  late final OneArgFnDart _fileProgress = _lib
      .lookupFunction<OneArgFn, OneArgFnDart>('HaloFileProgress');
  late final OneArgFnDart _fileCancel = _lib
      .lookupFunction<OneArgFn, OneArgFnDart>('HaloFileCancel');

  /// (done, total) bytes of a transfer under way, or null
  (int, int)? fileProgress(String key) {
    final p = fileProgressOf(key);
    return p == null ? null : (p.done, p.total);
  }

  /// the same, and whether a send is still doing its work, before any
  /// byte goes
  ({int done, int total, bool preparing})? fileProgressOf(String key) {
    final k = key.toNativeUtf8();
    try {
      return parseFileProgress(engineTake(_fileProgress(k)));
    } finally {
      malloc.free(k);
    }
  }

  void fileCancel(String key) {
    final k = key.toNativeUtf8();
    try {
      engineTake(_fileCancel(k));
    } finally {
      malloc.free(k);
    }
  }

  // what the relays delivered, one entry per event (relay_poll.dart). room
  // frames in it are plaintext, so it is zeroed on the way back
  RelayBatch nostrPoll() => parseRelayPoll(engineTakeSecret(_nostrPoll()));

  late final TwoArgFnDart _nostrAck = _lib
      .lookupFunction<TwoArgFn, TwoArgFnDart>('HaloNostrAck');

  // a batch from nostrPoll kept, but for the places in it at [failed]: the
  // engine remembers the rest as seen and offers those again. those at
  // [held] stay on the relay until a full shelf has room
  String nostrAck(
    String token,
    List<int> failed, {
    List<int> held = const [],
    List<String> groups = const [],
  }) {
    final a = token.toNativeUtf8();
    final b = jsonEncode(
      held.isEmpty ? failed : {'f': failed, 'h': held, 'g': groups},
    ).toNativeUtf8();
    try {
      return engineTake(_nostrAck(a, b));
    } finally {
      malloc.free(a);
      malloc.free(b);
    }
  }

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

  String encryptFor(int ident, String peerPub, String plain) {
    final cPub = peerPub.toNativeUtf8();
    final cPlain = plain.toNativeUtf8();
    try {
      return engineTake(_encryptFor(ident, cPub, cPlain));
    } finally {
      calloc.free(cPub);
      calloc.free(cPlain);
    }
  }

  String decryptFrom(int ident, String peerPub, String b64) {
    final cPub = peerPub.toNativeUtf8();
    final cB64 = b64.toNativeUtf8();
    try {
      return engineTakeSecret(_decryptFrom(ident, cPub, cB64));
    } finally {
      calloc.free(cPub);
      calloc.free(cB64);
    }
  }

  // offloaded to a background isolate so a slow tor dial never freezes the ui.
  Future<String> sendTo(String addr, String msg) => devGate.sendTo(
    addr,
    out: () =>
        _sendOnIsolate((
          nostr: false,
          ident: kMainIdent,
          a: addr,
          b: msg,
        )).timeout(
          const Duration(seconds: 15),
          onTimeout: () => 'error: onion timeout',
        ),
  );

  // a typing frame to a peer's door (HaloSendTyping): the private route
  // only, one try, nothing kept. an engine without the call sends nothing
  Future<String> sendTyping(String onion, String line) => _ffiOnIsolate(
    'HaloSendTyping',
    [onion, line],
    wait: const Duration(seconds: 10),
    what: 'typing',
  ).catchError((Object e) => 'error: typing (${e.runtimeType})');

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
            _roomFfiOnIsolate('HaloRoomSend', [
              priv,
              peerPub,
              padRumor(msg),
            ]).timeout(
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
          padRumor(msg),
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
  // the same, waited on: what listens again comes after it
  Future<String> roomUnsubscribe(String pub) =>
      _roomFfiOnIsolate('HaloRoomUnsubscribe', [pub]);

  // what a room's addresses kept on disk, gone with the room: its key and
  // its members' keys name every address it had
  void roomForgetBg(String priv, List<String> members) =>
      _background(roomForget(priv, members), 'room forget');
  // the same, waited on: 'ok' once the files are gone
  Future<String> roomForget(String priv, List<String> members) =>
      _roomFfiOnIsolate('HaloRoomForget', [priv, jsonEncode(members)]);

  // one member who left or was taken out: their lane stops, and what their
  // address kept on disk goes
  void roomUnlistenBg(String priv, String peerPub) => _background(
    _roomFfiOnIsolate('HaloRoomUnsubscribeMember', [priv, peerPub]),
    'room unlisten member',
  );

  // what a full shelf left on the peer's address: "mark" lets it go for the
  // runner's next connection or probe, "free" fetches it by id now, "drop"
  // takes it as kept
  Future<String> nostrLetHeld(int ident, String peerXPubHex, String how) =>
      _onPair(
        ident,
        peerXPubHex,
        (pair) => _identFfiOnIsolate('HaloNostrLetHeld', ident, [pair, how]),
      );

  // "mark" for each of the peers, in one call: each with its identity
  Future<String> nostrMarkHeld(List<(int, String)> peers) async =>
      _roomFfiOnIsolate('HaloNostrMarkHeld', [await _identPeers(peers)]);

  // the pinned chats' keys (HaloNostrPinned)
  Future<String> nostrPinned(List<(int, String)> peers) async =>
      _roomFfiOnIsolate('HaloNostrPinned', [await _identPeers(peers)]);

  // each with its pair's seed when it has one; a peer whose pair is
  // refused is left out
  static Future<String> _identPeers(List<(int, String)> peers) async {
    final out = <Map<String, Object>>[];
    for (final (i, x) in peers) {
      try {
        final pair = await pairArgOf(i, x);
        final (key, seed) = switch (pair.split('.')) {
          [final k, final s] => (k, s),
          _ => (pair, ''),
        };
        out.add({'i': i, 'x': key, if (seed.isNotEmpty) 's': seed});
      } on PairRefused catch (e) {
        dlog('pairs: a peer left out ($e)');
      }
    }
    return jsonEncode(out);
  }

  // no more listening for a peer, and its address's files gone
  void nostrUnsubscribeBg(int ident, String peerXPubHex) => _background(
    _onPair(
      ident,
      peerXPubHex,
      (pair) => _identFfiOnIsolate('HaloNostrUnsubscribe', ident, [pair]),
    ),
    'unlisten',
  );

  // [run] on the pair the containers name for [ident] and [x] now; a pair
  // refused goes nowhere
  static Future<String> _onPair(
    int ident,
    String x,
    Future<String> Function(String pair) run,
  ) async {
    final String pair;
    try {
      pair = await pairArgOf(ident, x);
    } on PairRefused catch (e) {
      dlog('pairs: refused ($e)');
      return 'error: pair refused';
    }
    return run(pair);
  }
}

// a knock left to wait its room's turn: offered again, not an error
class _KnockWaits implements Exception {
  const _KnockWaits();
}

// a stranger's opener that did not file and may later: not acked
class _FirstWaits implements Exception {
  const _FirstWaits();
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

// a call that names the identity it runs on, then one to three strings
Future<String> _identFfiOnIsolate(String name, int ident, List<String> args) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final ptrs = [for (final a in args) a.toNativeUtf8()];
    try {
      switch (ptrs.length) {
        case 1:
          return engineTake(
            lib.lookupFunction<IdentOneFn, IdentOneFnDart>(name)(
              ident,
              ptrs[0],
            ),
          );
        case 2:
          return engineTake(
            lib.lookupFunction<IdentTwoFn, IdentTwoFnDart>(name)(
              ident,
              ptrs[0],
              ptrs[1],
            ),
          );
        default:
          return engineTake(
            lib.lookupFunction<IdentThreeFn, IdentThreeFnDart>(name)(
              ident,
              ptrs[0],
              ptrs[1],
              ptrs[2],
            ),
          );
      }
    } finally {
      for (final p in ptrs) {
        freeSecret(p);
      }
    }
  });
}

Future<String> _fcSendOnIsolate(
  int ident,
  String peerXPub,
  String fcPk,
  String msg,
) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final fn = lib.lookupFunction<IdentThreeFn, IdentThreeFnDart>(
      'HaloNostrSendFirstContact',
    );
    final a = peerXPub.toNativeUtf8();
    final b = fcPk.toNativeUtf8();
    final c = msg.toNativeUtf8();
    try {
      return engineTake(fn(ident, a, b, c));
    } finally {
      malloc.free(a);
      malloc.free(b);
      malloc.free(c);
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

Future<String> _fcSubscribeOnIsolate(int ident, int counter) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final fn = lib.lookupFunction<IdentCounterFn, IdentCounterFnDart>(
      'HaloNostrSubscribeFirstContact',
    );
    return engineTake(fn(ident, counter));
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
/// past the engine's own bound on a registry call (engine/handle.go,
/// handleWait): the engine's answer comes back, never a give-up here while
/// a claim may still land
const registryWait = Duration(seconds: 75);

// a check-in's budget, in seconds from its job's start: tor carries by this,
// the boot's listeners are up by this, the relays are kicked by this or not
// at all, and their answers are waited for until this. the tail, about ten
// seconds, and tor's sleep, six at most, follow. the job stops at 170
const kCheckReadyBy = 90;
const kCheckListenedBy = 95;
const kCheckKickBy = 105;
const kCheckLoopBy = 120;
// less than this left before kCheckReadyBy, and tor is not woken at all
const kCheckWakeLeast = Duration(seconds: 5);
// a job older than this is someone else's clock
const kCheckJobOldest = Duration(minutes: 10);

// the helper app mode's engine calls, through whichever engine is in use
class _EngineKnocks implements KnockEngine {
  @override
  Future<String> knockAddresses(String excludeJson) =>
      engine.knockAddresses(excludeJson);
  @override
  Future<String> knockRegister(String itemsJson) =>
      engine.knockRegister(itemsJson);
  @override
  Future<String> knockCheck() => engine.knockCheck();
}

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
        case 0:
          return engineTake(lib.lookupFunction<CStrFn, CStrFnDart>(symbol)());
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

// [ident]: the identity a relay send seals on; an onion send has none
Future<String> _sendOnIsolate(
  ({bool nostr, int ident, String a, String b}) args,
) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final p1 = args.a.toNativeUtf8();
    final p2 = args.b.toNativeUtf8();
    try {
      if (args.nostr) {
        return engineTake(
          lib.lookupFunction<IdentTwoFn, IdentTwoFnDart>('HaloNostrSend')(
            args.ident,
            p1,
            p2,
          ),
        );
      }
      final fn = lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloSendTo');
      return engineTake(fn(p1, p2));
    } finally {
      malloc.free(p1);
      malloc.free(p2);
    }
  });
}

Future<String> _subscribeOnIsolate(
  int ident,
  String xPub, {
  bool fresh = false,
}) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final fn = lib.lookupFunction<IdentOneFn, IdentOneFnDart>(
      fresh ? 'HaloNostrSubscribeNew' : 'HaloNostrSubscribe',
    );
    final p = xPub.toNativeUtf8();
    try {
      return engineTake(fn(ident, p));
    } finally {
      malloc.free(p);
    }
  });
}

// the update check's GET: kryfo.app only, on a tor circuit of its own
Future<String> updateGetOnIsolate(String url) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final fn = lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloUpdateGet');
    final p = url.toNativeUtf8();
    try {
      return engineTake(fn(p));
    } finally {
      malloc.free(p);
    }
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

HaloEngine _engine = HaloEngine();

// a kill, as the tests stand one in: called before each bridge key write
@visibleForTesting
void Function(String key)? bridgeWriteTap;
HaloEngine get engine => _engine;

// tests stand a spy in for the engine, which needs the native library
@visibleForTesting
void useEngineForTest(HaloEngine e) => _engine = e;
