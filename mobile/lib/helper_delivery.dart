// SPDX-License-Identifier: GPL-3.0-or-later
// the helper app mode, put together: whether our relay can knock, the
// sixteen registrations with the helper app, and the registrations with the
// relay (helper_slots.dart says which address goes where). what each side
// learns is in PRIVACY.md.
//
// the relay would see registrations sent together as one phone's. so one
// group goes per round, new groups first, each item signed at its own time
// and renewed on a day of its own; a round runs with each check-in, and a
// few minutes apart while the app is open. forgets, when the mode is left,
// go the same way, one per round, over tor on any route.
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'dlog.dart';
import 'helper_push.dart';
import 'helper_slots.dart';

// the slot book, see helper_slots.dart
const kHelperSlotsKey = 'helper_slots';
// what the relay took last: name -> [endpoint, sent ms, due ms]. names are
// the engine's ids, never an address
const kHelperSyncedKey = 'helper_synced';
// forgets still to send after the mode was left: [{"i":id} or {"k","s"}],
// each with "w", when its registration was sent
const kHelperForgetKey = 'helper_forget';
// slot -> when the helper app was last asked for it again
const kHelperAskedKey = 'helper_asked';
// "yes" or "no" and when our relay last said so, as "yes@ms"
const kHelperRelayKey = 'helper_relay_knocks';
// the helper app was there and is gone, or the relay stopped knocking:
// said once, on the home screen
const kHelperGoneKey = 'helper_gone';

// the relay keeps a registration a month; each is sent again on a day of
// its own between four and six days on
const kRefreshMinMs = 4 * 24 * 60 * 60 * 1000;
const kRefreshSpanMs = 2 * 24 * 60 * 60 * 1000;
// how long our relay's answer to "can you knock" is kept
const kRelayAskEveryMs = 24 * 60 * 60 * 1000;
// how far back a registration's time may be set (engine/knock.go takes up
// to an hour)
const kSignedJitterS = 20 * 60;
// a registration the relay found not newer is tried again this much later
const kDupRetryMs = 20 * 60 * 1000;
// a slot the helper app dropped is asked again at most this often
const kAskAgainMs = 60 * 60 * 1000;
// a forget for an address the engine cannot sign for is tried this often
const kForgetTries = 3;

/// the engine calls the mode needs. the app's engine, or a stand-in in tests
abstract class KnockEngine {
  /// [{"i":id,"g":group}], leaving out the peers in [excludeJson]
  Future<String> knockAddresses(String excludeJson);

  /// {"done":[names],"dup":[names]}, or an error
  Future<String> knockRegister(String itemsJson);

  /// "yes", "no", or an error
  Future<String> knockCheck();
}

class _Synced {
  final String endpoint;
  final int sent, due;
  const _Synced(this.endpoint, this.sent, this.due);
  static const dup = '!dup';
}

class HelperDelivery {
  HelperDelivery({
    required this.engine,
    required this.push,
    List<String> Function()? hidden,
    Random? rnd,
    int Function()? nowMs,
  }) : _hidden = hidden ?? (() => const []),
       _rnd = rnd ?? Random.secure(),
       _now = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final KnockEngine engine;
  final HelperPush push;
  // the hidden chats' peers: their addresses are never registered
  final List<String> Function() _hidden;
  final Random _rnd;
  final int Function() _now;
  Future<int>? _syncing;
  // name -> forgets the engine could not sign, the address not listened on
  final Map<String, int> _forgetTried = {};

  /// whether the last round left something still to send
  bool get more => _more;
  bool _more = false;

  /// whether the last round sent anything: one group a round, all told
  bool get sent => _sent;
  bool _sent = false;

  /// whether our relay said it can knock. [ask] asks it again when the
  /// answer is a day old: over tor, so only when tor is up
  Future<bool> relayKnocks({bool ask = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final kept = prefs.getString(kHelperRelayKey) ?? '';
    final at = int.tryParse(kept.split('@').last) ?? 0;
    final fresh = at > 0 && _now() - at < kRelayAskEveryMs && at <= _now();
    if (!ask || fresh) return kept.startsWith('yes@');
    final r = await engine.knockCheck();
    // a relay that could not be asked keeps its last answer
    if (r != 'yes' && r != 'no') {
      dlog('helper: relay not asked: $r');
      return kept.startsWith('yes@');
    }
    await prefs.setString(kHelperRelayKey, '$r@${_now()}');
    return r == 'yes';
  }

  Future<SlotBook> _book() async {
    final prefs = await SharedPreferences.getInstance();
    return SlotBook.read(prefs.getString(kHelperSlotsKey));
  }

  Future<void> _saveBook(SlotBook b) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kHelperSlotsKey, b.write());
  }

  Future<Map<String, _Synced>> _synced() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final j = jsonDecode(prefs.getString(kHelperSyncedKey) ?? '{}');
      if (j is! Map) return {};
      return {
        for (final e in j.entries)
          if (e.value is List &&
              (e.value as List).length == 3 &&
              (e.value as List)[0] is String &&
              (e.value as List)[1] is int &&
              (e.value as List)[2] is int)
            '${e.key}': _Synced(
              (e.value as List)[0] as String,
              (e.value as List)[1] as int,
              (e.value as List)[2] as int,
            ),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveSynced(Map<String, _Synced> m) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kHelperSyncedKey,
      jsonEncode({
        for (final e in m.entries)
          e.key: [e.value.endpoint, e.value.sent, e.value.due],
      }),
    );
  }

  /// registers the sixteen slots with [package] and waits for their
  /// endpoints. true once at least one came back
  Future<bool> setUp(
    String package, {
    Duration wait = const Duration(seconds: 12),
  }) async {
    final book = await _book();
    await push.register(package, [
      for (var s = 0; s < kHelperSlots; s++) book.instance(s),
    ]);
    final until = DateTime.now().add(wait);
    var got = 0;
    while (true) {
      got = slotEndpoints(book, await push.endpoints()).length;
      if (got >= kHelperSlots || !DateTime.now().isBefore(until)) break;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    dlog('helper: $got endpoints from the helper app');
    return got > 0;
  }

  /// one round: the book brought up to date, and one group's registrations
  /// sent, new groups first. returns how many the relay took; [more] says
  /// whether anything is left for another round
  Future<int> sync({String? package}) {
    final running = _syncing;
    if (running != null) return running;
    final f = _sync(package).whenComplete(() => _syncing = null);
    _syncing = f;
    return f;
  }

  Future<int> _sync(String? package) async {
    _sent = false;
    final now = _now();
    final live = [
      for (final a in knockAddressesOf(
        await engine.knockAddresses(jsonEncode(_hidden())),
      ))
        if (!(lastingGroup(a.group) && restsNow(a.address, now))) a,
    ];
    final before = await _book();
    final plan = planSlots(before, live, _rnd);
    var book = plan.book;
    // a slot let go gets a new registration, so a new endpoint, before it
    // serves anyone else. the old one goes first, then the book is kept
    final pkg = package ?? await push.chosen();
    for (final s in plan.renew) {
      await push.unregisterOne(slotInstance(s, (book.gen[s] ?? 1) - 1));
    }
    await _saveBook(book);
    if (pkg != null && plan.renew.isNotEmpty) {
      await push.register(pkg, [for (final s in plan.renew) book.instance(s)]);
    }
    var endpoints = slotEndpoints(book, await push.endpoints());
    // a registration the helper app dropped or never answered is asked
    // again, at most once an hour per slot: same group, same slot
    final prefs = await SharedPreferences.getInstance();
    final asked = _asked(prefs);
    final missing = [
      for (var s = 0; s < kHelperSlots; s++)
        if (!endpoints.containsKey(s) &&
            !plan.renew.contains(s) &&
            now - (asked[s] ?? 0) >= kAskAgainMs)
          s,
    ];
    if (pkg != null && missing.isNotEmpty) {
      for (final s in missing) {
        asked[s] = now;
      }
      await prefs.setString(
        kHelperAskedKey,
        jsonEncode({for (final e in asked.entries) '${e.key}': e.value}),
      );
      await push.register(pkg, [for (final s in missing) book.instance(s)]);
      endpoints = slotEndpoints(book, await push.endpoints());
    }

    final synced = await _synced();
    final wanted = wantedItems(book, endpoints);
    final names = {for (final it in wanted) it.name};
    // an address gone, hidden, replaced or resting is never forgotten: a
    // forget then would tell the relay what happened. its registration
    // lapses within the month
    synced.removeWhere((k, _) => !names.contains(k));
    // forgets still queued from leaving the mode must not undo what is
    // about to be registered again
    final queued = _forgets(prefs);
    final keep = [
      for (final f in queued)
        if (f['i'] == null || !names.contains(f['i'])) f,
    ];
    if (keep.length != queued.length) {
      await prefs.setString(kHelperForgetKey, jsonEncode(keep));
    }

    String groupOf(KnockItem it) =>
        it.address != null ? 'g:${book.owner[it.slot]}' : 's${it.slot}';
    final due = [
      for (final it in wanted)
        if (_due(synced[it.name], it.endpoint, now)) it,
    ];
    if (due.isEmpty) {
      _more = false;
      await _saveSynced(synced);
      return 0;
    }
    final groups = <String, List<KnockItem>>{};
    for (final it in due) {
      (groups[groupOf(it)] ??= []).add(it);
    }
    // groups the relay has never seen first, then the rest, at random
    final fresh = [
      for (final e in groups.entries)
        if (e.value.any((it) => synced[it.name] == null)) e.key,
    ];
    final pool = fresh.isNotEmpty ? fresh : groups.keys.toList();
    final pick = pool[_rnd.nextInt(pool.length)];
    final batch = groups[pick]!;
    _more = groups.length > 1;

    _sent = true;
    final r = await engine.knockRegister(
      jsonEncode([
        for (final it in batch)
          {...it.toJson(), 't': _signedAt(synced[it.name]?.sent, now)},
      ]),
    );
    final done = _namesOf(r, 'done');
    final dup = _namesOf(r, 'dup') ?? const {};
    if (done == null) {
      dlog('helper: registrations not sent: $r');
      await _saveSynced(synced);
      return 0;
    }
    final refused = _namesOf(r, 'refused') ?? const {};
    final standIn = Map<int, String>.from(book.standIn);
    for (final it in batch) {
      if (it.endpoint.isEmpty && !done.contains(it.name)) {
        // a stand-in's forget: the relay holding something newer is as
        // good as done; one it refuses is given up after a few
        var drop = dup.contains(it.name);
        if (refused.contains(it.name)) {
          final tries = (_forgetTried[it.name] ?? 0) + 1;
          _forgetTried[it.name] = tries;
          drop = drop || tries >= kForgetTries;
        }
        if (drop) {
          _forgetTried.remove(it.name);
          synced.remove(it.name);
          standIn.remove(it.slot);
        }
        continue;
      }
      if (dup.contains(it.name)) {
        // the relay keeps one at least as new: again a little later, newer
        synced[it.name] = _Synced(_Synced.dup, now, now + kDupRetryMs);
        continue;
      }
      if (!done.contains(it.name)) continue;
      if (it.endpoint.isEmpty) {
        // a stand-in forgotten: its slot carries an address now
        synced.remove(it.name);
        standIn.remove(it.slot);
      } else {
        synced[it.name] = _Synced(
          it.endpoint,
          now,
          now + kRefreshMinMs + _rnd.nextInt(kRefreshSpanMs),
        );
      }
    }
    if (standIn.length != book.standIn.length) {
      await _saveBook(book.copyWith(standIn: standIn));
    }
    await _saveSynced(synced);
    dlog('helper: relay took ${done.length} of ${batch.length}');
    return done.length;
  }

  // the time a registration or a forget is signed with, in seconds: its
  // own, up to twenty minutes back, and always after the one before it for
  // the same name
  int _signedAt(int? sentMs, int nowMs) {
    final now = nowMs ~/ 1000;
    final back = now - _rnd.nextInt(kSignedJitterS + 1);
    final after = sentMs == null ? 0 : sentMs ~/ 1000 + 1;
    return min(now, max(back, after));
  }

  Map<int, int> _asked(SharedPreferences prefs) {
    try {
      final j = jsonDecode(prefs.getString(kHelperAskedKey) ?? '{}') as Map;
      return {
        for (final e in j.entries)
          if (int.tryParse('${e.key}') != null && e.value is int)
            int.parse('${e.key}'): e.value as int,
      };
    } catch (_) {
      return {};
    }
  }

  bool _due(_Synced? had, String endpoint, int now) {
    if (had == null) return true;
    if (had.endpoint == _Synced.dup) return now >= had.due;
    if (had.endpoint != endpoint) return true;
    return now >= had.due || had.sent > now;
  }

  Set<String>? _namesOf(String r, String key) {
    try {
      final j = jsonDecode(r);
      if (j is! Map || j[key] is! List) return null;
      return {for (final d in j[key] as List) '$d'};
    } catch (_) {
      return null;
    }
  }

  /// leaving the mode: the helper app lets every registration go now, so
  /// the relay's next knock to each finds it gone. what the relay holds is
  /// queued to be forgotten, a round at a time (forgetRound)
  Future<void> stop() async {
    final book = await _book();
    final synced = await _synced();
    final prefs = await SharedPreferences.getInstance();
    final queued = _forgets(prefs);
    // each with when its registration went, so its forget is signed after
    for (final e in synced.entries) {
      final n = e.key;
      final w = e.value.sent;
      if (n.startsWith('s')) {
        final s = int.tryParse(n.substring(1));
        final k = s == null ? null : book.standIn[s];
        if (k != null) queued.add({'k': k, 's': s!, 'w': w});
      } else {
        queued.add({'i': n, 'w': w});
      }
    }
    await prefs.setString(kHelperForgetKey, jsonEncode(queued));
    await push.unregister();
    await prefs.remove(kHelperSyncedKey);
    // the next set-up starts on new endpoints: every slot one generation on
    await _saveBook(
      SlotBook(
        gen: {for (var s = 0; s < kHelperSlots; s++) s: (book.gen[s] ?? 0) + 1},
      ),
    );
  }

  List<Map<String, Object>> _forgets(SharedPreferences prefs) {
    try {
      final j = jsonDecode(prefs.getString(kHelperForgetKey) ?? '[]');
      return [
        for (final e in j as List)
          if (e is Map)
            {for (final f in e.entries) '${f.key}': f.value as Object},
      ];
    } catch (_) {
      return [];
    }
  }

  /// whether forgets are still queued
  Future<bool> forgetsLeft() async =>
      _forgets(await SharedPreferences.getInstance()).isNotEmpty;

  /// one queued forget, signed at its own time, after its registration.
  /// one registered again since is dropped, never sent
  Future<int> forgetRound() async {
    final prefs = await SharedPreferences.getInstance();
    var queued = _forgets(prefs);
    if (queued.isEmpty) return 0;
    final synced = await _synced();
    queued = [
      for (final f in queued)
        if (f['i'] == null || !synced.containsKey(f['i'])) f,
    ];
    await prefs.setString(kHelperForgetKey, jsonEncode(queued));
    if (queued.isEmpty) return 0;
    // the engine signs only for what it lists now
    await engine.knockAddresses(jsonEncode(_hidden()));
    final f = queued[_rnd.nextInt(queued.length)];
    final now = _now();
    final item = {
      for (final e in f.entries)
        if (e.key != 'w') e.key: e.value,
      'e': '',
      't': _signedAt(f['w'] as int?, now),
    };
    _sent = true;
    final r = await engine.knockRegister(jsonEncode([item]));
    final done = _namesOf(r, 'done');
    final unknown = _namesOf(r, 'unknown') ?? const {};
    final dup = _namesOf(r, 'dup') ?? const {};
    final refused = _namesOf(r, 'refused') ?? const {};
    // nothing went: tor down, or the relay unreached. tried again later,
    // and not counted
    if (done == null) return 0;
    final name = f['i'] as String? ?? 's${f['s']}';
    // the relay holding something newer is as good as done
    var drop = done.contains(name) || dup.contains(name);
    if (unknown.contains(name) || refused.contains(name)) {
      // an address no longer listened on is never signed for, and a forget
      // the relay refuses is not sent for ever
      final tries = (_forgetTried[name] ?? 0) + 1;
      _forgetTried[name] = tries;
      drop = drop || tries >= kForgetTries;
    }
    if (drop) {
      queued.remove(f);
      _forgetTried.remove(name);
      await prefs.setString(kHelperForgetKey, jsonEncode(queued));
    }
    return done.length;
  }

  /// a phone moving away: the helper app has let go, so the relay's next
  /// knock finds each endpoint gone. nothing more is sent from here
  Future<void> dropForgets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kHelperForgetKey);
  }

  /// whether the helper app registered with is still on the phone. null
  /// when none was ever chosen
  Future<bool?> helperThere() async {
    final pkg = await push.chosen();
    if (pkg == null) return null;
    final apps = await push.apps();
    return apps.any((a) => a.package == pkg);
  }
}
