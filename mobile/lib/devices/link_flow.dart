// SPDX-License-Identifier: GPL-3.0-or-later
// one link as the screens see it: the phone's side (scan, compare the six
// numbers, link) and the new device's side (show the code, compare, take
// its place). the engine runs the link; a flow reads its state and does
// what only the app can. the decoy's flow looks the same and reaches
// nothing
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'link_calls.dart';

enum LinkStep {
  /// the new device shows its code
  showing,

  /// the phone's answer is out, nothing back yet
  reaching,

  /// six numbers to compare
  digits,

  /// confirmed: the rest is under way
  linking,
  done,
  failed,
}

/// why a link ended without one
enum LinkEnd {
  /// the other side never answered, or the code ran out
  unreached,

  /// a no, or a message that did not fit: nothing was linked
  stopped,

  /// the phone has every device it may have
  full,
}

/// how long the phone waits for the new device's first answer before it
/// says it could not reach it. the decoy's link ends after as long
const kLinkReachWait = Duration(seconds: 90);

@immutable
class LinkStage {
  const LinkStage(
    this.step, {
    this.offer,
    this.digits,
    this.end,
    this.keyNumber,
  });
  final LinkStep step;

  /// the new device's qr text
  final String? offer;
  final String? digits;
  final LinkEnd? end;

  /// the account's key number, on the new device once linked
  final String? keyNumber;
}

abstract class LinkFlow extends ValueNotifier<LinkStage> {
  LinkFlow(super.value);

  Future<void> start();

  /// the person says the numbers match
  Future<void> match();

  /// the person says they do not: nothing is linked
  void noMatch();

  /// the page closed: whatever runs stops
  void cancel();

  @override
  void dispose() {
    cancel();
    super.dispose();
  }
}

LinkEnd linkEndOf(String? why) => switch (why) {
  'full' || 'too_many' => LinkEnd.full,
  'refused' ||
  'ended' ||
  'malformed' ||
  'signature' ||
  'duplicate' => LinkEnd.stopped,
  _ => LinkEnd.unreached,
};

// the engine's state, read every [poll]
abstract class _EngineFlow extends LinkFlow {
  _EngineFlow(this.calls, super.first, {Duration? poll})
    : poll = poll ?? const Duration(milliseconds: 400);
  final LinkCalls calls;
  final Duration poll;
  String? _link;
  Timer? _timer;
  bool _busy = false;
  bool _over = false;

  bool get over => _over;

  void _watch() {
    _timer?.cancel();
    _timer = Timer.periodic(poll, (_) => _tick());
  }

  Future<void> _tick() async {
    final id = _link;
    if (_busy || _over || id == null) return;
    _busy = true;
    try {
      await onState(calls.call('state', {'link': id}));
    } catch (_) {
      fail(LinkEnd.stopped);
    } finally {
      _busy = false;
    }
  }

  Future<void> onState(Map<String, dynamic> s);

  void _end() {
    _over = true;
    _timer?.cancel();
    final id = _link;
    _link = null;
    if (id != null) calls.call('end', {'link': id});
  }

  void fail(LinkEnd why) {
    if (_over) return;
    _end();
    value = LinkStage(LinkStep.failed, end: why);
  }

  void finish(LinkStage v) {
    _over = true;
    _timer?.cancel();
    _link = null;
    value = v;
  }

  @override
  void noMatch() => fail(LinkEnd.stopped);

  @override
  void cancel() {
    if (!_over) _end();
  }
}

/// what the phone hands the app once the new device's bundles came
@immutable
class LinkTaken {
  const LinkTaken({
    required this.device,
    required this.key,
    required this.reg,
    required this.list,
    required this.first,
    required this.last,
    required this.once,
    required this.made,
    required this.stream,
  });
  final int device;
  final String key;
  final int reg;
  final Uint8List list;
  final Uint8List first;
  final Uint8List last;
  final List<Uint8List> once;
  final int made;
  final Uint8List stream;

  static LinkTaken of(Map<String, dynamic> j) {
    final d = j['device'] as Map<String, dynamic>;
    Uint8List b(Object? v) => base64Decode(v as String);
    return LinkTaken(
      device: d['id'] as int,
      key: d['key'] as String,
      reg: d['reg'] as int,
      list: b(j['list']),
      first: b(j['first']),
      last: b(j['last']),
      once: [for (final x in (j['once'] as List?) ?? const []) b(x)],
      made: j['made'] as int,
      stream: b(j['stream']),
    );
  }
}

/// what only the phone's app can do in a link
abstract class PhoneLinkHooks {
  /// the identity the device joins, hex
  Future<String> identity();

  /// the phone's registration id, for a first list of its own
  Future<int> phoneReg();

  /// ks_sign by the identity over the next list's body
  Future<Uint8List> sign(Uint8List body);

  /// everything the link left, written before the link is called done
  Future<void> keep(LinkTaken t);
}

class PhoneLinkFlow extends _EngineFlow {
  PhoneLinkFlow(
    LinkCalls calls, {
    required this.code,
    required this.hooks,
    Duration? poll,
    this.reachWait = kLinkReachWait,
  }) : super(calls, const LinkStage(LinkStep.reaching), poll: poll);

  final String code;
  final PhoneLinkHooks hooks;
  final Duration reachWait;
  Timer? _reach;
  bool _keeping = false;

  @override
  Future<void> start() async {
    final String id;
    try {
      id = await hooks.identity();
    } catch (_) {
      return fail(LinkEnd.stopped);
    }
    if (over) return;
    final r = calls.call('link_start', {'offer': code, 'key': id});
    final err = r['err'] as String?;
    if (err != null) return fail(linkEndOf(err));
    _link = r['link'] as String;
    _reach = Timer(reachWait, () {
      if (value.step == LinkStep.reaching) fail(LinkEnd.unreached);
    });
    _watch();
  }

  @override
  Future<void> onState(Map<String, dynamic> s) async {
    switch (s['st']) {
      case 'digits':
        _reach?.cancel();
        if (value.step == LinkStep.reaching) {
          value = LinkStage(LinkStep.digits, digits: s['sas'] as String?);
        }
      case 'bundles':
        if (_keeping) return;
        _keeping = true;
        final t = calls.call('take', {'link': _link});
        if (t['err'] != null) return fail(LinkEnd.stopped);
        try {
          await hooks.keep(LinkTaken.of(t));
        } catch (_) {
          return fail(LinkEnd.stopped);
        }
        finish(const LinkStage(LinkStep.done));
      case 'failed':
        fail(linkEndOf(s['why'] as String?));
    }
  }

  @override
  Future<void> match() async {
    final id = _link;
    if (value.step != LinkStep.digits || id == null) return;
    value = const LinkStage(LinkStep.linking);
    final l = calls.call('list', {
      'link': id,
      'ident': 0,
      'reg': await hooks.phoneReg(),
    });
    if (l['err'] != null) return fail(linkEndOf(l['err'] as String));
    final Uint8List sig;
    try {
      sig = await hooks.sign(base64Decode(l['body'] as String));
    } catch (_) {
      return fail(LinkEnd.stopped);
    }
    if (over) return;
    final s = calls.call('sign', {'link': id, 'sig': base64Encode(sig)});
    if (s['err'] != null) return fail(LinkEnd.stopped);
    final c = calls.call('confirm', {'link': id});
    if (c['err'] != null) return fail(linkEndOf(c['err'] as String));
  }

  @override
  void cancel() {
    _reach?.cancel();
    super.cancel();
  }
}

/// the new device's place, once the phone told it
@immutable
class JoinPlace {
  const JoinPlace({
    required this.identity,
    required this.device,
    required this.keyNumber,
  });
  final String identity;
  final int device;
  final String keyNumber;
}

/// a new device's first bundles for its phone
typedef JoinBundles = ({
  Uint8List first,
  Uint8List last,
  List<Uint8List> once,
  int made,
});

/// what only the new device's app can do in a link
abstract class JoinLinkHooks {
  /// this device's key (hex, its signal identity) and registration id
  Future<({String key, int reg})> myKey();

  /// the container takes its place: the identity, its device id
  Future<void> placed(JoinPlace p);

  /// the rows the engine gave for the own list the link brought
  Future<void> writeRows(Map<String, dynamic> answer);

  /// its first own bundles, as device [device]: [want] one-time ones,
  /// as many as the phone asked for
  Future<JoinBundles> bundles(int device, int want);

  /// linked: the history stream's key, kept for the history copy
  Future<void> joined(JoinPlace p, Uint8List stream);
}

class JoinLinkFlow extends _EngineFlow {
  JoinLinkFlow(LinkCalls calls, {required this.hooks, Duration? poll})
    : super(calls, const LinkStage(LinkStep.showing), poll: poll);

  final JoinLinkHooks hooks;
  JoinPlace? _place;
  bool _placing = false;
  bool _taking = false;

  @override
  Future<void> start() async {
    final ({String key, int reg}) me;
    try {
      me = await hooks.myKey();
    } catch (_) {
      return fail(LinkEnd.stopped);
    }
    final r = calls.call('join_start', {'key': me.key, 'reg': me.reg});
    if (r['err'] != null) return fail(linkEndOf(r['err'] as String));
    _link = r['link'] as String;
    value = LinkStage(LinkStep.showing, offer: r['offer'] as String);
    _watch();
  }

  @override
  Future<void> onState(Map<String, dynamic> s) async {
    switch (s['st']) {
      case 'digits':
        if (value.step == LinkStep.showing) {
          value = LinkStage(LinkStep.digits, digits: s['sas'] as String?);
        }
      case 'placed':
        if (_placing) return;
        _placing = true;
        final d = s['device'] as Map<String, dynamic>;
        final p = JoinPlace(
          identity: s['identity'] as String,
          device: d['id'] as int,
          keyNumber: s['key_number'] as String,
        );
        _place = p;
        try {
          await hooks.placed(p);
          final own = calls.call('own', {'link': _link, 'ident': 0});
          await hooks.writeRows(own);
          if (own['err'] != null) return fail(LinkEnd.stopped);
          final b = await hooks.bundles(
            p.device,
            (s['want'] as num?)?.toInt() ?? 0,
          );
          final r = calls.call('bundles', {
            'link': _link,
            'first': base64Encode(b.first),
            'last': base64Encode(b.last),
            'once': [for (final x in b.once) base64Encode(x)],
            'made': b.made,
          });
          if (r['err'] != null) return fail(LinkEnd.stopped);
        } catch (_) {
          return fail(LinkEnd.stopped);
        }
      case 'done':
        final p = _place;
        if (_taking || p == null) return;
        _taking = true;
        final t = calls.call('take', {'link': _link});
        if (t['err'] != null) return fail(LinkEnd.stopped);
        try {
          await hooks.joined(p, base64Decode(t['stream'] as String));
        } catch (_) {
          return fail(LinkEnd.stopped);
        }
        finish(LinkStage(LinkStep.done, keyNumber: p.keyNumber));
      case 'failed':
        fail(linkEndOf(s['why'] as String?));
    }
  }

  @override
  Future<void> match() async {
    final id = _link;
    if (value.step != LinkStep.digits || id == null) return;
    value = const LinkStage(LinkStep.linking);
    final c = calls.call('confirm', {'link': id});
    if (c['err'] != null) fail(linkEndOf(c['err'] as String));
  }
}

/// the decoy's link: the same pages, a wait as long as a real one that
/// reaches nobody, then "couldn't reach the device". nothing is sent and
/// nothing of the real account is read
class DecoyLinkFlow extends LinkFlow {
  DecoyLinkFlow({Duration? wait, Random? random})
    : _wait =
          wait ??
          kLinkReachWait +
              Duration(seconds: (random ?? Random.secure()).nextInt(8)),
      super(const LinkStage(LinkStep.reaching));

  final Duration _wait;
  Timer? _t;

  @override
  Future<void> start() async {
    _t = Timer(_wait, () {
      value = const LinkStage(LinkStep.failed, end: LinkEnd.unreached);
    });
  }

  @override
  Future<void> match() async {}

  @override
  void noMatch() {}

  @override
  void cancel() => _t?.cancel();
}
