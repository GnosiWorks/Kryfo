// SPDX-License-Identifier: GPL-3.0-or-later
// how tor gets out: what the person picked, what the engine says about it,
// and the one line every screen shows for it.
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'l10n/l10n.dart';
import 'l10n/numbers.dart';

/// what the person picked. the cards hold the first three, "more" the rest.
/// [id] is what the store keeps
enum BridgeChoice {
  auto('auto'),
  direct('direct'),
  friend('own'),
  torProject('moat'),
  builtin('builtin'),
  snowflake('snowflake');

  const BridgeChoice(this.id);
  final String id;

  static BridgeChoice? parse(String? v) {
    for (final c in values) {
      if (c.id == v) return c;
    }
    return null;
  }
}

/// the settings behind the choice, as kept in the store
@immutable
class BridgeSetup {
  final BridgeChoice choice;
  // lines from a friend, as pasted or scanned
  final String friendLines;
  // lines the tor project handed out before 0.5.1
  final String torProjectLines;
  // may automatic ask the tor project: yes, no, or ask the first time tor
  // is found blocked
  final String consent;
  // tor is risky here: automatic never tries it without a bridge
  final bool skipDirect;
  // two letters for the tor project, empty lets it guess
  final String country;
  // an upgrade from before automatic: offer it once
  final bool offerAuto;

  const BridgeSetup({
    this.choice = BridgeChoice.auto,
    this.friendLines = '',
    this.torProjectLines = '',
    this.consent = 'ask',
    this.skipDirect = false,
    this.country = '',
    this.offerAuto = false,
  });

  BridgeSetup copyWith({
    BridgeChoice? choice,
    String? friendLines,
    String? torProjectLines,
    String? consent,
    bool? skipDirect,
    String? country,
    bool? offerAuto,
  }) => BridgeSetup(
    choice: choice ?? this.choice,
    friendLines: friendLines ?? this.friendLines,
    torProjectLines: torProjectLines ?? this.torProjectLines,
    consent: consent ?? this.consent,
    skipDirect: skipDirect ?? this.skipDirect,
    country: country ?? this.country,
    offerAuto: offerAuto ?? this.offerAuto,
  );

  /// the engine's mode and its options. null while there is nothing to use
  /// yet: a friend's card with no line, or no built-in line
  (String, String)? engineMode({List<String> builtin = const []}) {
    switch (choice) {
      case BridgeChoice.auto:
        final wt = [
          for (final l in [
            ...splitBridgeLines(torProjectLines),
            ...splitBridgeLines(friendLines),
          ])
            if (l.toLowerCase().startsWith('webtunnel ')) l,
        ];
        return (
          'auto',
          jsonEncode({
            'consent': consent,
            if (skipDirect) 'skip_direct': true,
            if (country.isNotEmpty) 'country': country,
            if (wt.isNotEmpty) 'webtunnel': wt,
          }),
        );
      case BridgeChoice.direct:
        return ('direct', '{}');
      case BridgeChoice.snowflake:
        return ('snowflake', '{}');
      case BridgeChoice.friend:
        final ls = splitBridgeLines(friendLines);
        if (ls.isEmpty) return null;
        return ('own', jsonEncode({'lines': ls}));
      case BridgeChoice.torProject:
        final ls = splitBridgeLines(torProjectLines);
        if (ls.isEmpty) return null;
        return ('moat', jsonEncode({'lines': ls}));
      case BridgeChoice.builtin:
        if (builtin.isEmpty) return null;
        return ('moat', jsonEncode({'lines': builtin}));
    }
  }
}

/// the lines of pasted or kept text, one per line, empty ones dropped
List<String> splitBridgeLines(String text) => [
  for (final l in text.split('\n'))
    if (l.trim().isNotEmpty) l.trim(),
];

final _quoted = RegExp(r'''['"]([^'"]+)['"]''');
final _bridgeWord = RegExp(r'^bridge\s+', caseSensitive: false);

/// bridge lines out of what was pasted or scanned. the tor project's qr
/// codes hold a list, ['obfs4 …', 'obfs4 …'], and a line copied out of a
/// torrc starts with "Bridge". the engine judges the rest
List<String> bridgeLinesFrom(String raw) {
  var t = raw.trim();
  if (t.startsWith('[') && t.endsWith(']')) {
    final inner = [for (final m in _quoted.allMatches(t)) m.group(1)!];
    t = inner.isEmpty ? t.substring(1, t.length - 1) : inner.join('\n');
  }
  return [
    for (final l in t.split(RegExp(r'[\r\n]+')))
      if (l.trim().isNotEmpty) l.trim().replaceFirst(_bridgeWord, ''),
  ];
}

const _transports = ['obfs4', 'webtunnel', 'snowflake'];

/// the transport a line names, or null for anything else
String? bridgeTransport(String line) {
  final w = line.trim().split(RegExp(r'\s+')).first.toLowerCase();
  return _transports.contains(w) ? w : null;
}

/// whether a scanned code could hold bridge lines at all
bool looksLikeBridges(String raw) =>
    bridgeLinesFrom(raw).any((l) => bridgeTransport(l) != null);

/// what 0.5.0 kept, read once into the new settings. an upgrade keeps what
/// it used and never asks the tor project without a yes; with bridges off
/// it stays on tor alone and is offered automatic once. a new install
/// starts on automatic and is asked the first time tor is found blocked
BridgeSetup migrateBridges({
  required bool upgrade,
  String? on,
  String? lines,
  String? source,
}) {
  if (!upgrade) return const BridgeSetup();
  final text = (lines ?? '').trim();
  final moat = source == 'moat';
  final kept = BridgeSetup(
    choice: BridgeChoice.direct,
    consent: 'no',
    friendLines: moat ? '' : text,
    torProjectLines: moat ? text : '',
  );
  if (on == '1' && text.isNotEmpty) {
    return kept.copyWith(
      choice: moat ? BridgeChoice.torProject : BridgeChoice.friend,
    );
  }
  return kept.copyWith(offerAuto: true);
}

/// one check of a line, from the engine
@immutable
class BridgeLineCheck {
  final int i;
  final String state;
  final String why;
  const BridgeLineCheck(this.i, this.state, this.why);

  bool get broken => state == 'broken';
  bool get tooLong => why.contains('too long');

  static List<BridgeLineCheck> parse(String raw) {
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          if (e is Map)
            BridgeLineCheck(
              (e['i'] as num?)?.toInt() ?? -1,
              '${e['state'] ?? ''}',
              '${e['why'] ?? ''}',
            ),
      ];
    } catch (_) {
      return const [];
    }
  }
}

/// the engine's word on how tor connects, without any line or address
@immutable
class BridgeStatus {
  final String mode;
  final String phase;
  final String method;
  final String source;
  final int progress;
  final int attempt;
  final int attempts;
  final int sinceMs;
  final bool canSend;
  final bool blocked;
  final bool limited;
  final String snowflake;
  final String errorCode;
  final bool askConsent;

  const BridgeStatus({
    this.mode = '',
    this.phase = '',
    this.method = '',
    this.source = '',
    this.progress = 0,
    this.attempt = 0,
    this.attempts = 0,
    this.sinceMs = 0,
    this.canSend = false,
    this.blocked = false,
    this.limited = false,
    this.snowflake = '',
    this.errorCode = '',
    this.askConsent = false,
  });

  /// before the engine has said anything
  static const none = BridgeStatus();

  static BridgeStatus parse(String raw) {
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return none;
      String s(String k) => m[k] is String ? m[k] as String : '';
      int n(String k) => m[k] is num ? (m[k] as num).toInt() : 0;
      bool b(String k) => m[k] == true;
      return BridgeStatus(
        mode: s('mode'),
        phase: s('phase'),
        method: s('method'),
        source: s('source'),
        progress: n('progress'),
        attempt: n('attempt'),
        attempts: n('attempts'),
        sinceMs: n('since_ms'),
        canSend: b('can_send'),
        blocked: b('blocked'),
        limited: b('limited'),
        snowflake: s('snowflake'),
        errorCode: s('error_code'),
        askConsent: b('ask_consent'),
      );
    } catch (_) {
      return none;
    }
  }

  bool get exhausted => phase == 'exhausted';

  /// the same, at a later count of how long the attempt has run
  BridgeStatus withSince(int ms) => BridgeStatus(
    mode: mode,
    phase: phase,
    method: method,
    source: source,
    progress: progress,
    attempt: attempt,
    attempts: attempts,
    sinceMs: ms,
    canSend: canSend,
    blocked: blocked,
    limited: limited,
    snowflake: snowflake,
    errorCode: errorCode,
    askConsent: askConsent,
  );

  /// automatic is past the usual way: tor looked blocked or a disguise is
  /// being tried
  bool get tryingAnother =>
      mode == 'auto' &&
      (phase == 'trying' || phase == 'asking') &&
      (blocked || limited || attempt > 1);

  /// a bridge carries tor now
  bool get throughBridge =>
      phase == 'connected' && method.isNotEmpty && method != 'direct';

  @override
  bool operator ==(Object other) =>
      other is BridgeStatus &&
      other.mode == mode &&
      other.phase == phase &&
      other.method == method &&
      other.source == source &&
      other.progress == progress &&
      other.attempt == attempt &&
      other.attempts == attempts &&
      other.canSend == canSend &&
      other.blocked == blocked &&
      other.limited == limited &&
      other.snowflake == snowflake &&
      other.errorCode == errorCode &&
      other.askConsent == askConsent;

  @override
  int get hashCode => Object.hash(
    mode,
    phase,
    method,
    progress,
    attempt,
    attempts,
    canSend,
    blocked,
    limited,
    snowflake,
    errorCode,
    askConsent,
  );
}

enum BridgeTone { green, amber, rose, quiet }

/// the one thing to do when stuck
enum BridgeAction { tryAgain, getBridge, openWifi }

/// the status line: words, colour, whether it is at work, how far along,
/// and the way out when stuck
@immutable
class BridgeLine {
  final String head;
  final String? detail;
  // what the detail says, without its numbers: a new kind rises in, a
  // count changes in place
  final String detailKind;
  final BridgeTone tone;
  final bool moving;
  // 0 to 1, where tor says how far it is
  final double? progress;
  final BridgeAction? action;
  // how long this way has been tried, in ms, when tor gives no percent:
  // the view counts on from it, so nothing else rebuilds each second
  final int? clockMs;

  const BridgeLine({
    required this.head,
    this.detail,
    this.detailKind = '',
    required this.tone,
    this.moving = false,
    this.progress,
    this.action,
    this.clockMs,
  });
}

/// m:ss in the person's digits
String bridgeClock(int ms) {
  final s = ms ~/ 1000;
  return '${whole(s ~/ 60)}:${twoDigits(s % 60)}';
}

/// what goes between the parts of the status line. next to arabic and
/// persian digits a middle dot reads as a zero, so those use their comma
String get bridgeSep =>
    const {'ar', 'fa'}.contains(l10nLocale.languageCode) ? '، ' : ' · ';

/// the status line for [s]. a decoy hears only connected, connecting or
/// offline: no counts, no asking, no codes. [consent] is whether automatic
/// may ask the tor project, which decides the way out when nothing got
/// through
BridgeLine bridgeStatusLine(
  BridgeStatus s, {
  bool decoy = false,
  String consent = 'no',
}) {
  if (decoy) {
    // the engine says connected, trying or offline in a decoy
    if (const {
      'offline',
      'no_internet',
      'paused',
      'captive',
    }.contains(s.phase)) {
      return BridgeLine(head: l10n.bridgesOffline, tone: BridgeTone.rose);
    }
    if (s.canSend || s.phase == 'not_tor_mode') {
      return BridgeLine(head: l10n.bridgesConnected, tone: BridgeTone.green);
    }
    return BridgeLine(
      head: l10n.bridgesConnectingDots,
      tone: BridgeTone.amber,
      moving: true,
    );
  }
  switch (s.phase) {
    case 'not_tor_mode':
      return BridgeLine(
        head: l10n.bridgesNotNeededRightNow,
        detail: l10n.bridgesYouReOnAMode,
        detailKind: 'not-tor',
        tone: BridgeTone.quiet,
      );
    case 'no_internet':
      return BridgeLine(
        head: l10n.bridgesNoInternet,
        detail: l10n.bridgesKryfoConnectsAsSoon,
        detailKind: 'no-internet',
        tone: BridgeTone.rose,
      );
    case 'paused':
      return BridgeLine(
        head: l10n.bridgesAsleepBetweenCheckIns,
        tone: BridgeTone.quiet,
      );
    case 'checkin':
      return BridgeLine(
        head: l10n.bridgesCheckingForMessages,
        tone: BridgeTone.amber,
        moving: true,
      );
    case 'captive':
      return BridgeLine(
        head: l10n.bridgesSignInToThisWifi,
        detail: l10n.bridgesThisNetworkWantsA,
        detailKind: 'captive',
        tone: BridgeTone.amber,
        action: BridgeAction.openWifi,
      );
    case 'exhausted':
      // the words go with the button under them
      final ask = consent != 'yes';
      return BridgeLine(
        head: l10n.bridgesNothingGotThrough,
        detail: ask
            ? l10n.bridgesTheTorProjectCanSuggest
            : l10n.bridgesKryfoTriesAgainOnItsOwn,
        detailKind: ask ? 'exhausted-ask' : 'exhausted',
        tone: BridgeTone.rose,
        action: ask ? BridgeAction.getBridge : BridgeAction.tryAgain,
      );
  }
  // a picked bridge tor cannot use, its listeners down or its lines
  // refused: tor waits offline. automatic moves on by itself
  if (s.mode != 'auto' &&
      (s.errorCode == 'pt_failed' || s.errorCode == 'not_applied')) {
    return BridgeLine(
      head: l10n.bridgesYourBridgeCouldNot,
      detail: l10n.bridgesKryfoStaysOfflineRather,
      detailKind: 'pt',
      tone: BridgeTone.rose,
      action: BridgeAction.tryAgain,
    );
  }
  if (s.phase == 'connected' && s.canSend) {
    final bridge = s.method.isNotEmpty && s.method != 'direct';
    return BridgeLine(
      head: l10n.bridgesConnected,
      detail: bridge ? l10n.bridgesThroughABridge : l10n.bridgesStraightToTor,
      detailKind: bridge ? 'bridge' : 'direct',
      tone: BridgeTone.green,
    );
  }

  // on the way. the numbers keep it from ever looking stuck
  final pct = s.progress > 0 && s.progress < 100 ? s.progress : null;
  final parts = <String>[];
  var kind = '';
  final auto = s.mode == 'auto';
  final String head;
  // automatic with no way in yet, as after a wake: a pass is on its way
  if (auto &&
      s.errorCode == 'auto_wait' &&
      s.phase != 'asking' &&
      !s.tryingAnother) {
    head = l10n.bridgesConnectingDots;
    parts.add(l10n.bridgesFindingAWayIn);
    kind = 'wait';
  } else if (s.phase == 'connected') {
    head = l10n.bridgesConnectingDots;
    parts.add(l10n.bridgesAlmostThere);
    kind = 'almost';
  } else if (auto) {
    head = s.limited
        ? l10n.bridgesYourNetworkMayBe
        : s.blocked
        ? l10n.bridgesTorSeemsBlocked
        : l10n.bridgesConnectingDots;
    if (s.phase == 'asking') {
      parts.add(l10n.bridgesAskingTheTorProject);
      kind = 'asking';
    } else if (s.tryingAnother) {
      parts.add(
        s.attempts >= s.attempt && s.attempt > 0
            ? l10n.bridgesTryingAnotherWayOf(
                whole(s.attempt),
                whole(s.attempts),
              )
            : l10n.bridgesTryingAnotherWay,
      );
      kind = 'another';
    }
  } else {
    head = s.method.isEmpty || s.method == 'direct' || s.mode == 'direct'
        ? l10n.bridgesConnectingDots
        : l10n.bridgesConnectingThroughYourBridge;
  }
  if (s.phase == 'trying' && s.snowflake.isNotEmpty) {
    // the broker matched a volunteer, or the volunteer answered
    final found = s.snowflake == 'broker' || s.snowflake == 'connected';
    parts.add(
      found ? l10n.bridgesFoundAVolunteer : l10n.bridgesLookingForAVolunteer,
    );
    kind += found ? '+found' : '+looking';
  }
  if (s.errorCode == 'moat_unreachable' && s.phase == 'trying') {
    parts.add(l10n.bridgesCouldNotReachTheTor);
    kind += '+moat';
  }
  if (pct != null) parts.add(percent(pct / 100));
  return BridgeLine(
    head: head,
    detail: parts.isEmpty ? null : parts.join(bridgeSep),
    detailKind: kind,
    tone: BridgeTone.amber,
    moving: true,
    progress: pct == null ? null : pct / 100,
    clockMs: pct == null && s.sinceMs > 0 ? s.sinceMs : null,
  );
}

/// what a choice is called
String bridgeChoiceName(BridgeChoice c) => switch (c) {
  BridgeChoice.auto => l10n.bridgesAutomatic,
  BridgeChoice.direct => l10n.bridgesDirect,
  BridgeChoice.friend => l10n.bridgesBridgeFromAFriend,
  BridgeChoice.torProject => l10n.bridgesFromTheTorProject,
  BridgeChoice.builtin => l10n.bridgesBuiltInBridges,
  BridgeChoice.snowflake => 'Snowflake',
};

/// the method in use, in the words "more" uses. transport names are kept
/// left to right in a right-to-left language
String bridgeMethodWords(BridgeStatus s, {BridgeChoice? choice}) {
  if (s.method.isEmpty) return l10n.bridgesNothingYet;
  if (s.method == 'direct') return l10n.bridgesTorNoBridge;
  // built-in bridges go to the engine as a picked set: named by the pick
  final source = choice == BridgeChoice.builtin ? 'builtin' : s.source;
  final from = switch (source) {
    'builtin' => l10n.bridgesBuiltIn,
    'moat' => l10n.bridgesFromTheTorProjectLower,
    'own' => l10n.bridgesFromAFriendLower,
    _ => '',
  };
  final name = ltr(s.method);
  return from.isEmpty ? name : l10n.bridgesMethodFrom(name, from);
}

/// what the engine made of lines from a friend
@immutable
class FriendLines {
  final bool used;
  final int total;
  final List<BridgeLineCheck> checks;
  const FriendLines(this.used, this.total, this.checks);
  const FriendLines.none(this.total) : used = false, checks = const [];

  int get broken => used ? checks.where((c) => c.broken).length : total;
  bool get tooLong => checks.any((c) => c.broken && c.tooLong);
}

/// the countries the tor project has its own advice for
const kBridgeCountries = ['by', 'cn', 'eg', 'hk', 'ir', 'mm', 'ru', 'tm'];

String bridgeCountryName(String cc) => switch (cc) {
  'by' => l10n.bridgesBelarus,
  'cn' => l10n.bridgesChina,
  'eg' => l10n.bridgesEgypt,
  'hk' => l10n.bridgesHongKong,
  'ir' => l10n.bridgesIran,
  'mm' => l10n.bridgesMyanmar,
  'ru' => l10n.bridgesRussia,
  'tm' => l10n.bridgesTurkmenistan,
  _ => cc.toUpperCase(),
};
