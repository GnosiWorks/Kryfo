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
  Future<String> nostrSend(String peerXPubHex, String b64Cipher) =>
      devGate.nostrSend(
        peerXPubHex,
        b64Cipher,
        // a frame no signal seal covers is filled out here, inside the
        // relay's encryption
        out: () =>
            _sendOnIsolate((
              nostr: true,
              a: peerXPubHex,
              b: padRumor(b64Cipher),
            )).timeout(
              const Duration(seconds: 60),
              onTimeout: () => 'error: relay timeout',
            ),
        room: (priv) => roomSend(priv, peerXPubHex, b64Cipher),
      );

  // [fresh]: someone just added or accepted, heard without a turn
  void nostrSubscribeBg(String peerXPubHex, {bool fresh = false}) {
    _background(
      devGate.listen(
        peerXPubHex,
        out: () => _subscribeOnIsolate(peerXPubHex, fresh: fresh),
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

  String firstContactPk(int counter) => engineTake(_fcPk(counter));

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
  void subscribeFirstContactBg(int counter) {
    _background(_fcSubscribeOnIsolate(counter), 'first contact listen');
  }

  // the same, waited on: 'ok', or why the address is not listened on
  Future<String> subscribeFirstContact(int counter) =>
      _fcSubscribeOnIsolate(counter);

  late final int Function() _fcRelays = _lib
      .lookupFunction<Int32 Function(), int Function()>(
        'HaloFirstContactRelays',
      );

  // how many relays the first-contact listener is on, -1 with none
  int firstContactRelays() => _fcRelays();

  // introduce ourselves to someone who has never heard of us.
  Future<String> sendFirstContact(
    String peerXPubHex,
    String fcPk,
    String b64Cipher,
  ) => devGate.sendFirstContact(
    peerXPubHex,
    fcPk,
    b64Cipher,
    out: () => _fcSendOnIsolate(peerXPubHex, fcPk, padRumor(b64Cipher)).timeout(
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
  Future<String> nostrLetHeld(String peerXPubHex, String how) =>
      _roomFfiOnIsolate('HaloNostrLetHeld', [peerXPubHex, how]);

  // "mark" for each of the peers, in one call
  Future<String> nostrMarkHeld(List<String> peerXPubHexes) =>
      _roomFfiOnIsolate('HaloNostrMarkHeld', [jsonEncode(peerXPubHexes)]);

  // no more listening for a peer, and its address's files gone
  void nostrUnsubscribeBg(String peerXPubHex) => _background(
    _roomFfiOnIsolate('HaloNostrUnsubscribe', [peerXPubHex]),
    'unlisten',
  );
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

Future<String> _subscribeOnIsolate(String xPub, {bool fresh = false}) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    OneArgFnDart fn;
    try {
      fn = lib.lookupFunction<OneArgFn, OneArgFnDart>(
        fresh ? 'HaloNostrSubscribeNew' : 'HaloNostrSubscribe',
      );
    } on ArgumentError {
      // an engine without it hears them all the same, after a turn
      fn = lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloNostrSubscribe');
    }
    final p = xPub.toNativeUtf8();
    try {
      return engineTake(fn(p));
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
