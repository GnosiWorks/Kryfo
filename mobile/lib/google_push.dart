// SPDX-License-Identifier: GPL-3.0-or-later
// google push, the play build only (android: GooglePush.kt). fcm gives this
// install one token, and that one token registered for all sixteen slots
// would let the relay tie them together. so each slot gets the token sealed
// to our push gateway's pinned key, a fresh seal each (engine/push_seal.go),
// and the relay sees sixteen strings with nothing in common:
// https://relay.kryfo.app/push/<sealed>. the gateway (server/push) opens one
// in memory and wakes the phone with an empty message.
//
// it stands where the helper app stands in HelperDelivery: the same slots,
// the same registrations with the relay, the same knock and check-in. no
// token is asked for before google push is picked, and leaving it deletes
// the token.
import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dlog.dart';
import 'helper_push.dart';

const kPushGateway = 'https://relay.kryfo.app/push/';
// the gateway's public key, pinned like the version key. the private half
// is made on the server with `kryfo-push keygen` and never leaves it
const kPushGatewayPub = kPushGatewayDevPub;
// the development key: test/push_gateway_key_test.dart refuses it for a
// release
const kPushGatewayDevPub = 'QRglUlzqI_cAwOAFO7vVY52Kpw7xO9xePWnMIldDhW0';
// how the slot book names google push where it names a helper app
const kGooglePackage = 'google';
// instance -> its sealed endpoint
const kGoogleEndpointsKey = 'gpush_endpoints';
// a hash of the token the endpoints were sealed from, never the token
const kGoogleSealedForKey = 'gpush_sealed_for';
const kGoogleOnKey = 'gpush_on';
// the card offering google push to a phone set up before it: 'due' or 'said'
const kGoogleOfferKey = 'gpush_offer';
// what the relay takes (relay-live/knock.go)
const _kEndpointMax = 512;
const _kAsk = Duration(seconds: 20);

typedef PushSealer = String Function(String publicKey, String token);

class GooglePush extends HelperPush {
  GooglePush(super.ch, {this.seal, this.gatewayKey = kPushGatewayPub})
    : _g = ch;
  static final GooglePush instance = GooglePush(
    const MethodChannel('halo/gpush'),
  );
  final MethodChannel _g;
  // the engine's seal (AppState sets it), or a stand-in in tests
  PushSealer? seal;
  final String gatewayKey;
  bool? _available;

  @override
  void listen() {
    _g.setMethodCallHandler((call) async {
      // a new token: the next round seals it again for every slot
      if (call.method == 'token') onChange?.call();
      return null;
    });
  }

  Future<T?> _ask<T>(String method) async {
    try {
      return await _g.invokeMethod<T>(method).timeout(_kAsk);
    } catch (e) {
      dlog('google: $method (${e.runtimeType})');
      return null;
    }
  }

  /// play services on the phone, so fcm can reach it. a build without
  /// google push answers no
  Future<bool> available() async =>
      _available ??= (await _ask<bool>('available')) ?? false;

  /// asked again next time: play services can be turned off meanwhile
  void forgetAvailable() => _available = null;

  /// pushes come, and how many android delivered below high priority
  Future<Map<String, int>> stats() async {
    final raw = await _ask<Map<Object?, Object?>>('stats');
    return {
      for (final e in (raw ?? const {}).entries)
        if (e.key is String && e.value is int) e.key as String: e.value as int,
    };
  }

  static bool tokenOK(String? t) =>
      t != null &&
      t.length >= 20 &&
      t.length <= 300 &&
      RegExp(r'^[A-Za-z0-9_:\-]+$').hasMatch(t);

  static String _hash(String token) =>
      sha256.convert(utf8.encode('kryfo gpush:$token')).toString();

  Future<Map<String, String>> _kept(SharedPreferences prefs) async {
    try {
      final j = jsonDecode(prefs.getString(kGoogleEndpointsKey) ?? '{}');
      if (j is! Map) return {};
      return {
        for (final e in j.entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      };
    } catch (_) {
      return {};
    }
  }

  // a fresh seal: never the same string twice, and never one the relay
  // would refuse
  String? _endpoint(String token) {
    final s = seal;
    if (s == null) return null;
    final sealed = s(gatewayKey, token);
    if (sealed.isEmpty || sealed.startsWith('error')) return null;
    final e = '$kPushGateway$sealed';
    return e.length <= _kEndpointMax ? e : null;
  }

  // every kept slot sealed again from [token] once it differs from the one
  // they were sealed from: a new token makes every endpoint new
  Future<Map<String, String>> _sealedFor(
    SharedPreferences prefs,
    String token,
    Iterable<String> add,
  ) async {
    final kept = await _kept(prefs);
    final fresh = prefs.getString(kGoogleSealedForKey) == _hash(token);
    final out = <String, String>{};
    for (final i in {...kept.keys, ...add}) {
      final had = kept[i];
      final e = fresh && had != null ? had : _endpoint(token);
      if (e != null) out[i] = e;
    }
    await prefs.setString(kGoogleEndpointsKey, jsonEncode(out));
    await prefs.setString(kGoogleSealedForKey, _hash(token));
    return out;
  }

  @override
  Future<List<HelperApp>> apps() async => await available()
      ? const [HelperApp(kGooglePackage, 'Google')]
      : const [];

  @override
  Future<String?> chosen() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getBool(kGoogleOnKey) ?? false) ? kGooglePackage : null;
  }

  /// the token asked for (the first time, firebase starts) and sealed for
  /// each instance that has no endpoint yet
  @override
  Future<int> register(String package, Iterable<String> instances) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kGoogleOnKey, true);
    final token = await _ask<String>('on');
    if (!tokenOK(token)) {
      dlog('google: no token');
      return 0;
    }
    final want = instances.toSet();
    final got = await _sealedFor(prefs, token!, want);
    return got.keys.where(want.contains).length;
  }

  @override
  Future<Map<String, String>> endpoints() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(kGoogleOnKey) ?? false)) return {};
    final token = await _ask<String>('token');
    // no answer from firebase: the endpoints made before still hold
    if (!tokenOK(token)) return _kept(prefs);
    return _sealedFor(prefs, token!, const []);
  }

  // a push carries no slot, so android cannot say which endpoint knocked
  @override
  Future<Set<String>?> knocked() async => null;

  @override
  Future<void> unregisterOne(String instance) async {
    final prefs = await SharedPreferences.getInstance();
    final kept = await _kept(prefs)
      ..remove(instance);
    await prefs.setString(kGoogleEndpointsKey, jsonEncode(kept));
  }

  /// leaving google push: the token is deleted, so the gateway's next push
  /// to any endpoint finds no phone and the relay lets it go
  @override
  Future<void> unregister() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kGoogleOnKey);
    await prefs.remove(kGoogleEndpointsKey);
    await prefs.remove(kGoogleSealedForKey);
    await _ask<bool>('off');
  }

  @override
  Future<void> knockAgain() => HelperPush.instance.knockAgain();
}
