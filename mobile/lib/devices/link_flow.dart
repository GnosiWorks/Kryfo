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

  /// the person here said the numbers differ
  stopped,

  /// anything else that cut it short: the other side stopped, a message
  /// that did not fit, a step that failed
  interrupted,

  /// the phone has every device it may have
  full,
}

/// how long the phone waits for the new device's first answer before it
/// says it could not reach it
const kLinkReachWait = Duration(seconds: 90);

/// the wait with its spread: the real phone's and the decoy's are drawn
/// alike, so a stopwatch cannot tell them apart
Duration linkReachWait([Random? r]) =>
    kLinkReachWait +
    Duration(milliseconds: (r ?? Random.secure()).nextInt(2000));

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

  bool _gone = false;

  /// a new stage, unless the page that showed this flow is gone
  @protected
  void show(LinkStage v) {
    if (!_gone) value = v;
  }

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
    _gone = true;
    super.dispose();
  }
}

/// the engine's reason as the person's
LinkEnd linkEndOf(String? why) => switch (why) {
  'full' || 'too_many' => LinkEnd.full,
  'expired' || 'unreached' => LinkEnd.unreached,
  _ => LinkEnd.interrupted,
};

const _kLinkPrefix = 'kryfo-link:';

/// what the engine would say of a scanned code before anything is sent:
/// null for one that runs, else 'malformed' or 'expired', as ParseOfferText
/// and AcceptOffer decide them (engine/devices/link.go). the decoy checks
/// this way, so a bad code ends there as fast as on a real phone
String? linkCodeProblem(String code, DateTime now) {
  final t = code.trim();
  if (!t.startsWith(_kLinkPrefix)) return 'malformed';
  final b64 = t.substring(_kLinkPrefix.length);
  if (b64.length > 2 * 76 ||
      b64.contains('=') ||
      b64.contains(RegExp(r'[+/]'))) {
    return 'malformed';
  }
  final Uint8List b;
  try {
    b = base64Url.decode(base64Url.normalize(b64));
  } catch (_) {
    return 'malformed';
  }
  if (b.length != 76 ||
      ascii.decode(b.sublist(0, 4), allowInvalid: true) != 'KLO2') {
    return 'malformed';
  }
  final exp = ByteData.sublistView(b, 68).getUint64(0);
  final secs = now.millisecondsSinceEpoch ~/ 1000;
  if (exp > secs + 3600) return 'malformed';
  if (exp <= secs) return 'expired';
  return null;
}

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
      fail(LinkEnd.interrupted);
    } finally {
      _busy = false;
    }
  }

  Future<void> onState(Map<String, dynamic> s);

  // the engine ends the run and tells the other side at once
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
    show(LinkStage(LinkStep.failed, end: why));
    unawaited(failed());
  }

  /// after a failure, what the app undoes
  Future<void> failed() async {}

  void finish(LinkStage v) {
    _over = true;
    _timer?.cancel();
    _link = null;
    show(v);
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
    this.bind,
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

  /// the link's transcript, which the history copy is bound to
  final Uint8List? bind;

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
      bind: j['bind'] is String ? b(j['bind']) : null,
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

  /// everything the link left, written in one go. [kept] tells the engine,
  /// which acks the new device's last line; it throws when the engine gave
  /// up first, and then nothing is kept
  Future<void> keep(LinkTaken t, Future<void> Function() kept);
}

class PhoneLinkFlow extends _EngineFlow {
  PhoneLinkFlow(
    LinkCalls calls, {
    required this.code,
    required this.hooks,
    Duration? poll,
    Duration? reachWait,
  }) : reachWait = reachWait ?? linkReachWait(),
       super(calls, const LinkStage(LinkStep.reaching), poll: poll);

  final String code;
  final PhoneLinkHooks hooks;
  final Duration reachWait;
  Timer? _reach;
  bool _keeping = false;

  @override
  Future<void> start() async {
    // the wait runs from the scan, as the decoy's does
    _reach = Timer(reachWait, () {
      if (value.step == LinkStep.reaching) fail(LinkEnd.unreached);
    });
    final String id;
    try {
      id = await hooks.identity();
    } catch (_) {
      return fail(LinkEnd.interrupted);
    }
    if (over) return;
    final r = calls.call('link_start', {'offer': code, 'key': id});
    final err = r['err'] as String?;
    if (err != null) return fail(linkEndOf(err));
    _link = r['link'] as String;
    _watch();
  }

  @override
  Future<void> onState(Map<String, dynamic> s) async {
    switch (s['st']) {
      case 'digits':
        _reach?.cancel();
        if (value.step == LinkStep.reaching) {
          show(LinkStage(LinkStep.digits, digits: s['sas'] as String?));
        }
      case 'bundles':
        if (_keeping) return;
        _keeping = true;
        final id = _link;
        final t = calls.call('take', {'link': id});
        if (t['err'] != null) return fail(LinkEnd.interrupted);
        final taken = LinkTaken.of(t);
        try {
          await hooks.keep(taken, () async {
            final k = calls.call('kept', {'link': id});
            if (k['err'] != null) throw StateError('the link gave up');
          });
        } catch (_) {
          _keeping = false;
          return fail(LinkEnd.interrupted);
        } finally {
          taken.stream.fillRange(0, taken.stream.length, 0);
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
    show(const LinkStage(LinkStep.linking));
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
      return fail(LinkEnd.interrupted);
    }
    if (over) return;
    final s = calls.call('sign', {'link': id, 'sig': base64Encode(sig)});
    if (s['err'] != null) return fail(LinkEnd.interrupted);
    final c = calls.call('confirm', {'link': id});
    if (c['err'] != null) return fail(linkEndOf(c['err'] as String));
  }

  @override
  void cancel() {
    _reach?.cancel();
    // a keep under way finishes: it tells the engine itself, so the page
    // closing never leaves the device kept here and unlinked there
    if (_keeping) {
      _timer?.cancel();
      return;
    }
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

/// what a new device keeps of its link for the history copy: the stream
/// key, the link's transcript and its phone's onion
typedef LinkStream = ({Uint8List key, Uint8List? bind, String? onion});

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

  /// the place, held in memory only: the device state as it would be,
  /// nothing written until the link is done
  Future<void> placed(JoinPlace p);

  /// its first own bundles, as device [device]: [want] one-time ones,
  /// as many as the phone asked for
  Future<JoinBundles> bundles(int device, int want);

  /// linked, the phone kept it: everything written at once (the place, the
  /// own list's rows, the history stream's key) and onboarding done
  Future<void> joined(
    JoinPlace p,
    LinkStream stream,
    Map<String, dynamic> ownRows,
  );

  /// a link that failed after its place: the state as before it
  Future<void> failed();
}

class JoinLinkFlow extends _EngineFlow {
  JoinLinkFlow(LinkCalls calls, {required this.hooks, Duration? poll})
    : super(calls, const LinkStage(LinkStep.showing), poll: poll);

  final JoinLinkHooks hooks;
  JoinPlace? _place;
  Map<String, dynamic>? _own;
  bool _placing = false;
  bool _taking = false;

  @override
  Future<void> start() async {
    final ({String key, int reg}) me;
    try {
      me = await hooks.myKey();
    } catch (_) {
      return fail(LinkEnd.interrupted);
    }
    final r = calls.call('join_start', {'key': me.key, 'reg': me.reg});
    if (r['err'] != null) return fail(linkEndOf(r['err'] as String));
    _link = r['link'] as String;
    show(LinkStage(LinkStep.showing, offer: r['offer'] as String));
    _watch();
  }

  @override
  Future<void> failed() async {
    if (_place != null) await hooks.failed();
  }

  // the page closing after the place lets it go as a failure does; once
  // linked (taking) there is nothing to undo
  @override
  void cancel() {
    final undo = !over && _place != null && !_taking;
    super.cancel();
    if (undo) unawaited(hooks.failed());
  }

  @override
  Future<void> onState(Map<String, dynamic> s) async {
    switch (s['st']) {
      case 'digits':
        if (value.step == LinkStep.showing) {
          show(LinkStage(LinkStep.digits, digits: s['sas'] as String?));
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
          // the page closed meanwhile: what placed loaded goes again
          if (over) return hooks.failed();
          final own = calls.call('own', {'link': _link, 'ident': 0});
          if (own['err'] != null) return fail(LinkEnd.interrupted);
          _own = own;
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
          if (r['err'] != null) return fail(LinkEnd.interrupted);
        } catch (_) {
          return fail(LinkEnd.interrupted);
        }
      case 'done':
        final p = _place;
        final own = _own;
        if (_taking || p == null || own == null) return;
        _taking = true;
        final t = calls.call('take', {'link': _link});
        if (t['err'] != null) return fail(LinkEnd.interrupted);
        final stream = base64Decode(t['stream'] as String);
        final bind = t['bind'];
        try {
          await hooks.joined(p, (
            key: stream,
            bind: bind is String ? base64Decode(bind) : null,
            onion: t['onion'] as String?,
          ), own);
        } catch (_) {
          return fail(LinkEnd.interrupted);
        } finally {
          stream.fillRange(0, stream.length, 0);
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
    show(const LinkStage(LinkStep.linking));
    final c = calls.call('confirm', {'link': id});
    if (c['err'] != null) fail(linkEndOf(c['err'] as String));
  }
}

/// the decoy's link: the same pages, a code checked as the engine checks
/// it, then a wait drawn as the real phone's is, and "couldn't reach the
/// device". nothing is sent and nothing of the real account is read
class DecoyLinkFlow extends LinkFlow {
  DecoyLinkFlow({
    required this.code,
    Duration? wait,
    Random? random,
    DateTime Function()? now,
  }) : _wait = wait ?? linkReachWait(random),
       _now = now ?? DateTime.now,
       super(const LinkStage(LinkStep.reaching));

  final String code;
  final Duration _wait;
  final DateTime Function() _now;
  Timer? _t;

  @override
  Future<void> start() async {
    final bad = linkCodeProblem(code, _now());
    if (bad != null) {
      show(LinkStage(LinkStep.failed, end: linkEndOf(bad)));
      return;
    }
    _t = Timer(_wait, () {
      show(const LinkStage(LinkStep.failed, end: LinkEnd.unreached));
    });
  }

  @override
  Future<void> match() async {}

  @override
  void noMatch() {}

  @override
  void cancel() => _t?.cancel();
}
