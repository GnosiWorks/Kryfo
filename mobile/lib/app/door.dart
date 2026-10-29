// SPDX-License-Identifier: GPL-3.0-or-later
// the one door (identity v4 4.2): every frame to a contact is sealed here,
// on the identity that contact knows. the sender fields and my own entry in
// a roster are filled from that identity's row; a frame that still names
// another identity of mine (its key in any form, its words, onion, handle
// or first-contact key) is refused and nothing goes. the main identity's
// frames leave as they always did

part of '../main.dart';

/// a frame for one identity of mine that names another: refused at the door
class OtherIdentity implements Exception {
  const OtherIdentity(this.what);
  final String what;
  @override
  String toString() => 'OtherIdentity: $what';
}

/// what one identity of mine shows of itself on the wire. the main one
/// has words, a face key, an onion, a handle and its v3 first-contact key;
/// any other has its x key alone, and an id of its own made from it
class IdentityFace {
  const IdentityFace({
    required this.ident,
    required this.xPub,
    this.words,
    this.edPub,
    this.onion,
    this.handle,
    this.fc = const [],
    this.avatar,
  });

  final int ident;
  final String xPub;
  final String? words;
  final String? edPub;
  final String? onion;
  final String? handle;
  final List<String> fc;
  final int? avatar;

  bool get main => ident == kMainIdent;

  /// what names this identity among members: its words, or for one with
  /// none the id of its own its key gives (unboundIdOf)
  String get memberId => words ?? unboundIdOf(_hexList('05$xPub'));

  /// every form of this identity a frame could carry: text as it is, keys
  /// in hex and base64, the 32-byte x key and libsignal's 33-byte form
  List<String> get marks => [
    ?words,
    ?handle,
    if (onion case final o? when o.isNotEmpty) ...[
      o,
      o.replaceAll('.onion', ''),
    ],
    ..._keyForms(xPub),
    ..._keyForms('05$xPub'),
    if (edPub case final e? when e.isNotEmpty) ..._keyForms(e),
    for (final f in fc) ..._keyForms(f),
  ];

  static List<String> _keyForms(String hex) {
    if (hex.isEmpty) return const [];
    final b = _hexList(hex);
    return [
      hex.toLowerCase(),
      // the characters of the key's base64 alone, wherever it starts in a
      // longer run
      for (var lead = 0; lead < 3; lead++)
        for (final enc in [base64Encode, base64UrlEncode])
          _inner(enc([...List.filled(lead, 0), ...b]), lead, b.length),
    ];
  }

  static String _inner(String s, int lead, int n) {
    final from = (lead * 8 + 5) ~/ 6 + 1;
    final to = ((lead + n) * 8) ~/ 6 - 1;
    return s.substring(from, to);
  }

  static List<int> _hexList(String h) => [
    for (var i = 0; i + 1 < h.length; i += 2)
      int.parse(h.substring(i, i + 2), radix: 16),
  ];
}

// the keys of a frame that hold what the person wrote or sent, never what
// the app put there: the door reads every other one
const _doorUserKeys = {'m', 'i', 'f', 'fn', 'pv', 'pl', 'st'};

/// [wrapped] (an envelope, or a frame outside the session such as the
/// json heal) for identity [face]: its sender fields and my entries in a
/// roster are [face]'s, and nothing names an identity of [others]. throws
/// OtherIdentity, and nothing goes, for one that does
String doorFrame(
  String wrapped,
  IdentityFace face,
  List<IdentityFace> others, {
  required Set<String> myXs,
  required Set<String> myIds,
}) {
  const prefix = 'halo/1:';
  final enveloped = wrapped.startsWith(prefix);
  var out = wrapped;
  if (enveloped && !face.main) {
    final j =
        jsonDecode(wrapped.substring(prefix.length)) as Map<String, dynamic>;
    if (j.containsKey('h') || j.containsKey('x') || j.containsKey('e')) {
      // in place, so the frame keeps its order
      j.remove('h');
      j.remove('e');
      j.remove('o');
      j.remove('av');
      // the supporter badge is the main account's
      j.remove('bg');
      j['x'] = face.xPub;
      if (face.avatar case final a?) j['av'] = a;
    }
    // me among the members, anywhere the app put me (a roster, a group
    // control's members and keys, who turned a setting): as this identity
    Object? swap(Object? v) => switch (v) {
      String h when myIds.contains(h) => face.memberId,
      Map e when myXs.contains('${e['x']}'.toLowerCase()) => {
        for (final k in e.keys)
          '$k': switch ('$k') {
            'h' => face.memberId,
            'x' => face.xPub,
            'o' || 'e' || 'fc' => '',
            _ => swap(e[k]),
          },
      },
      Map e => {for (final k in e.keys) '$k': swap(e[k])},
      List l => [for (final x in l) swap(x)],
      _ => v,
    };
    for (final k in j.keys.toList()) {
      if (const {'h', 'e', 'o', 'x', 'av'}.contains(k)) continue;
      if (_doorUserKeys.contains(k)) continue;
      j[k] = swap(j[k]);
    }
    out = '$prefix${jsonEncode(j)}';
  }
  // what the app put in it, read as text
  String read;
  try {
    final j = jsonDecode(enveloped ? out.substring(prefix.length) : out);
    if (j is Map) {
      final m = Map<String, dynamic>.from(j)
        ..removeWhere((k, _) => _doorUserKeys.contains(k));
      if (m['ed'] case final Map e) m['ed'] = {...e}..remove('m');
      read = jsonEncode(m).toLowerCase();
    } else {
      read = out.toLowerCase();
    }
  } catch (_) {
    read = out.toLowerCase();
  }
  for (final o in others) {
    for (final mark in o.marks) {
      if (mark.length >= 8 && read.contains(mark.toLowerCase())) {
        throw OtherIdentity('identity ${o.ident}');
      }
    }
  }
  return out;
}

// contacts on an identity other than the main one, and the signal stores
// of those identities: kept beside the app state, so a store is found
// without one
final Map<String, int> _idents = {};
final Map<int, SignalSession> _identStores = {};

/// my identity for [haloId]: the main one unless their row names another
int identOfPeer(String haloId) => _idents[haloId] ?? kMainIdent;

/// the signal store of identity [ident], opened from its row the first
/// time, its key handed to the engine with it
Future<SignalSession> signalOfIdent(int ident) async {
  if (ident == kMainIdent) return signalSession;
  final had = _identStores[ident];
  if (had != null) return had;
  final db = await live.open();
  final ss = SignalSession(null, ident);
  await ss.bootstrapIdentity(db);
  final row = await identityRow(db, ident);
  if (row != null) {
    try {
      engine.identityPut(
        ident,
        row.xPriv.map((x) => x.toRadixString(16).padLeft(2, '0')).join(),
      );
    } catch (e) {
      dlog('door: identity $ident not in the engine (${e.runtimeType})');
    }
  }
  return _identStores[ident] ??= ss;
}

extension AppStateDoor on AppState {
  /// my identity for [haloId]: the main one unless their row names another
  int identOf(String haloId) => identOfPeer(haloId);

  /// the same, by their x key
  int identOfX(String xPub) {
    final h = _xPubToHaloId[xPub] ?? _xPubToHaloId[xPub.toLowerCase()];
    return h == null ? kMainIdent : identOf(h);
  }

  /// the contacts on an identity other than the main one, from the
  /// containers open now
  Future<void> loadIdents() async {
    final next = <String, int>{};
    for (final d in [live, ?_openVault]) {
      try {
        final db = await d.open();
        for (final r in await db.query(
          'contacts',
          columns: ['halo_id', 'ident'],
          where: 'ident != ?',
          whereArgs: [kMainIdent],
        )) {
          next[r['halo_id'] as String] = r['ident'] as int;
        }
      } catch (e) {
        dlog('door: identities not read (${e.runtimeType})');
      }
    }
    _idents
      ..clear()
      ..addAll(next);
    for (final i in next.values.toSet()) {
      try {
        await signalOfIdent(i);
      } catch (e) {
        dlog('door: identity $i not opened (${e.runtimeType})');
      }
    }
  }

  @visibleForTesting
  Future<void> loadIdentsForTest() => loadIdents();

  /// what identity [ident] shows of itself
  Future<IdentityFace> faceOf(int ident) async {
    if (ident == kMainIdent) {
      return IdentityFace(
        ident: kMainIdent,
        words: myId.isEmpty ? null : myId,
        edPub: _io.edPub(),
        onion: myOnion,
        xPub: _io.xPub(),
        handle: _myHandle,
        fc: [await _mainFcNow()],
        avatar: _myAvatar,
      );
    }
    final ss = await signalOfIdent(ident);
    final row = await identityRow(await live.open(), ident);
    return IdentityFace(
      ident: ident,
      xPub: ss.identity.public
          .sublist(1)
          .map((x) => x.toRadixString(16).padLeft(2, '0'))
          .join(),
      avatar: row?.photo,
    );
  }

  // the main v3 first-contact key, read from the engine at each check: the
  // counter from its store when the listener has not loaded it yet. one
  // that cannot be read refuses the frame
  Future<String> _mainFcNow() async {
    final c = _fcLoaded
        ? _fcCounter
        : int.tryParse(await readFcCounter() ?? '') ?? 0;
    final s = engine.firstContactPk(kMainIdent, c);
    if (s.isEmpty || s.startsWith('error')) {
      throw const OtherIdentity('first-contact key unread');
    }
    return s;
  }

  /// my identity for [peer], read from the containers open now: the main
  /// one with no row. rows that disagree, or that cannot be read, refuse
  Future<int> identForSeal(String peer) async {
    final found = <int>{};
    for (final d in [live, ?_openVault]) {
      final r = await d.getContact(peer);
      if (r != null) found.add((r['ident'] as num?)?.toInt() ?? kMainIdent);
    }
    if (found.length > 1) throw const OtherIdentity('two identities');
    final ident = found.isEmpty ? kMainIdent : found.single;
    // the cache the sync paths read follows what the rows say
    if (ident == kMainIdent) {
      _idents.remove(peer);
    } else {
      _idents[peer] = ident;
    }
    return ident;
  }

  /// the one door: [frame] for [peer] filled and checked for the identity
  /// they know, and the identity it goes on. [outside]: a frame no session
  /// seals (the json heal), which the relay's wrap alone covers
  Future<(int, String)> doorFor(
    String peer,
    String frame, {
    bool outside = false,
  }) async {
    final ident = await identForSeal(peer);
    // no contact on any other identity and none opened: the main identity
    // alone, nothing to keep apart, and its frames go as they always did
    if (ident == kMainIdent && _idents.isEmpty && _identStores.isEmpty) {
      return (ident, frame);
    }
    final rows = await identityRows(await live.open());
    final face = await faceOf(ident);
    final others = [
      for (final r in rows)
        if (r.id != ident) await faceOf(r.id),
      if (ident != kMainIdent && !rows.any((r) => r.id == kMainIdent))
        await faceOf(kMainIdent),
    ];
    final all = [face, ...others];
    final out = doorFrame(
      frame,
      face,
      others,
      myXs: {for (final f in all) f.xPub.toLowerCase()},
      myIds: {for (final f in all) f.memberId},
    );
    return (ident, out);
  }

  /// the door's seal of [frame] for [peer], for the tests: what would go,
  /// on the identity it would go on
  @visibleForTesting
  Future<(int, String)> sealForTest(
    String peer,
    String frame, {
    bool outside = false,
  }) async {
    final (ident, out) = await doorFor(peer, frame, outside: outside);
    if (outside) return (ident, out);
    return (ident, await signalEncrypt(peer, out));
  }
}
