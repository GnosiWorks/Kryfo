// SPDX-License-Identifier: GPL-3.0-or-later
// scam shield. runs on the phone, over a stranger's first message and their
// id, against the contacts we already hold. nothing here does io, so every
// rule is a plain function and a test can hit it directly. the rules ship in
// the apk; there is no list to fetch and nothing to report back to.

class ShieldContact {
  final String id;
  final String? nickname;
  final int? avatar;
  const ShieldContact(this.id, {this.nickname, this.avatar});
}

class ShieldHit {
  final String code;
  final String line; // the plain sentence shown to the person
  const ShieldHit(this.code, this.line);
  @override
  bool operator ==(Object other) =>
      other is ShieldHit && other.code == code && other.line == line;
  @override
  int get hashCode => Object.hash(code, line);
}

class ShieldResult {
  final List<ShieldHit> hits;
  // impersonation flags on its own; content needs two rules to agree
  final bool impersonation;
  const ShieldResult(this.hits, {this.impersonation = false});
  bool get flagged => impersonation ? hits.isNotEmpty : hits.length >= 2;
  // the banner line. the name one is the sharper of the two on purpose.
  String? get headline {
    if (!flagged) return null;
    for (final h in hits) {
      if (h.code == 'name_match') {
        return h.line.replaceFirst(
          'name matches your contact',
          'this name matches',
        );
      }
    }
    return 'looks like a scam';
  }
}

const _wellKnown = [
  'google.com',
  'apple.com',
  'microsoft.com',
  'amazon.com',
  'paypal.com',
  'facebook.com',
  'instagram.com',
  'whatsapp.com',
  'telegram.org',
  'signal.org',
  'binance.com',
  'coinbase.com',
  'kraken.com',
  'metamask.io',
  'ledger.com',
  'trezor.io',
  'blockchain.com',
  'github.com',
  'kryfo.app',
  'proton.me',
];

// cyrillic and friends that draw the same as latin, plus the two digits that
// pass for letters. lowercase in, lowercase out.
const _fold = <String, String>{
  'а': 'a',
  'е': 'e',
  'о': 'o',
  'р': 'p',
  'с': 'c',
  'х': 'x',
  'у': 'y',
  'і': 'i',
  'ј': 'j',
  'һ': 'h',
  'ԁ': 'd',
  'ԛ': 'q',
  'ѕ': 's',
  'ɡ': 'g',
  'ο': 'o',
  'α': 'a',
  'ε': 'e',
  'ι': 'i',
  'κ': 'k',
  'ν': 'v',
  'ρ': 'p',
  'τ': 't',
  'υ': 'u',
  'χ': 'x',
  '0': 'o',
  '1': 'l',
};

const _accents = <String, String>{
  'àáâãäåāă': 'a',
  'çćč': 'c',
  'ďđ': 'd',
  'èéêëēėęě': 'e',
  'ğ': 'g',
  'ìíîïīı': 'i',
  'ľł': 'l',
  'ñńň': 'n',
  'òóôõöøō': 'o',
  'ŕř': 'r',
  'śšş': 's',
  'ťţ': 't',
  'ùúûüūů': 'u',
  'ýÿ': 'y',
  'źżž': 'z',
  'ß': 'ss',
};

String normaliseName(String s) {
  final sb = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    var out = _fold[ch];
    if (out == null) {
      for (final e in _accents.entries) {
        if (e.key.contains(ch)) {
          out = e.value;
          break;
        }
      }
    }
    sb.write(out ?? ch);
  }
  return sb.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

int editDistance(String a, String b) {
  if (a == b) return 0;
  if ((a.length - b.length).abs() > 2) return 3; // caller only cares up to 1
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = [
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}

// does this stranger look like someone we already know. ids are what a
// request shows, so the check is on ids and on our nicknames for people, and
// a matching picked face only ever confirms a near match.
ShieldResult checkImpersonation(
  String strangerId,
  int? strangerAvatar,
  Iterable<ShieldContact> contacts,
) {
  final me = normaliseName(strangerId);
  if (me.isEmpty) return const ShieldResult([]);
  for (final c in contacts) {
    if (c.id == strangerId) continue;
    final cid = normaliseName(c.id);
    final nick = c.nickname == null ? null : normaliseName(c.nickname!);
    final close =
        me == cid ||
        (nick != null && nick.isNotEmpty && me == nick) ||
        editDistance(me, cid) == 1;
    if (!close) continue;
    final shown = c.nickname ?? c.id;
    final hits = [ShieldHit('name_match', 'name matches your contact $shown')];
    if (strangerAvatar != null && strangerAvatar == c.avatar) {
      hits.add(ShieldHit('face_match', 'same face as your contact $shown'));
    }
    return ShieldResult(hits, impersonation: true);
  }
  return const ShieldResult([]);
}

final _btcLegacy = RegExp(r'\b[13][a-km-zA-HJ-NP-Z1-9]{25,34}\b');
final _btcBech32 = RegExp(r'\bbc1[qp][a-z0-9]{38,86}\b', caseSensitive: false);
final _eth = RegExp(r'\b0x[a-fA-F0-9]{40}\b');
final _xmr = RegExp(r'\b4[0-9AB][1-9A-HJ-NP-Za-km-z]{93}\b');

final _money = RegExp(
  r'(\bpay(ment|ing)?\b|\bmoney\b|\bcash\b|\bbitcoin\b|\bbtc\b|\beth\b|\busdt\b|\bcrypto\b|\binvest(ment|ing)?\b|\bprofits?\b|\bwallet\b|\btransfer\b|\bdeposit\b|\bfees?\b|\bgift ?cards?\b|\bwire\b|\brefund\b|\bloan\b|[$€£]\s?\d|\d\s?[$€£])',
  caseSensitive: false,
);
final _urgency = RegExp(
  r'(\bnow\b|\burgent(ly)?\b|\bimmediately\b|\btoday\b|\bright away\b|\basap\b|\bquick(ly)?\b|\bhurry\b|\blast chance\b|\bexpires?\b|\blimited\b|\bwithin \d+ ?(h|hours?|min)|\bbefore it\b|\bdon.?t wait\b)',
  caseSensitive: false,
);
final _appAsk = RegExp(
  r'(\b(add|message|msg|text|dm|reach|contact|find|write|talk|chat|continue|switch|move|ping|hit me up)\b[^.!?\n]{0,30}\b(whatsapp|telegram|signal|wechat|viber|discord|snapchat|instagram|kakao|skype|zoom|messenger|imessage|line)\b|\b(whatsapp|telegram|signal|wechat|viber|discord|snapchat|instagram|kakao|skype|zoom|messenger|imessage)\b[^.!?\n]{0,12}\bme\b)',
  caseSensitive: false,
);
final _secretAsk = RegExp(
  r'((verification|security|login|2fa|otp|one.?time|confirmation|auth) code|\bseed phrase|\brecovery (phrase|file|key|words)|\bbackup file|\bpassphrase\b|\bprivate key|\bsecret key|\b(12|24) words|\bmnemonic)',
  caseSensitive: false,
);
final _host = RegExp(
  r'(?:https?://|www\.)?([\p{L}\p{N}][\p{L}\p{N}-]*(?:\.[\p{L}\p{N}-]+)+)',
  unicode: true,
);

bool _mixedScript(String host) {
  var latin = false, other = false;
  for (final r in host.runes) {
    if ((r >= 0x61 && r <= 0x7a) || (r >= 0x41 && r <= 0x5a)) {
      latin = true;
    } else if (r > 0x7f &&
        String.fromCharCode(r).toLowerCase() !=
            String.fromCharCode(r).toUpperCase()) {
      other = true;
    }
  }
  return latin && other;
}

bool lookalikeHost(String host) {
  final h = host.toLowerCase();
  if (_mixedScript(h)) return true;
  final labels = h.split('.');
  if (labels.length < 2) return false;
  final reg = labels.sublist(labels.length - 2).join('.');
  final folded = normaliseName(reg);
  for (final w in _wellKnown) {
    if (reg == w) return false;
    if (folded == w) return true; // xn-- style, drawn the same
    if (editDistance(reg, w) == 1) return true;
  }
  return false;
}

// the six content rules over a stranger's opener. each is a point, the
// caller flags at two.
ShieldResult scanFirstMessage(String text) {
  final hits = <ShieldHit>[];
  final t = text.trim();
  if (t.isEmpty) return const ShieldResult([]);

  if (_btcLegacy.hasMatch(t) ||
      _btcBech32.hasMatch(t) ||
      _eth.hasMatch(t) ||
      _xmr.hasMatch(t)) {
    hits.add(const ShieldHit('crypto_address', 'contains a crypto address'));
  }

  var rush = false;
  for (final m in _money.allMatches(t)) {
    for (final u in _urgency.allMatches(t)) {
      final gap = (m.start - u.start).abs();
      if (gap <= 60) {
        rush = true;
        break;
      }
    }
    if (rush) break;
  }
  if (rush) {
    hits.add(
      const ShieldHit('money_rush', 'mentions money and urgency together'),
    );
  }

  if (_appAsk.hasMatch(t)) {
    hits.add(const ShieldHit('move_app', 'asks you to move to another app'));
  }

  for (final m in _host.allMatches(t)) {
    final host = m.group(1)!;
    if (!host.contains('.')) continue;
    if (lookalikeHost(host)) {
      hits.add(
        const ShieldHit(
          'lookalike_url',
          'links to a lookalike of a well-known site',
        ),
      );
      break;
    }
  }

  if (t.length > 400) {
    hits.add(
      const ShieldHit(
        'long_opener',
        'a long opener from someone with no history',
      ),
    );
  }

  if (_secretAsk.hasMatch(t)) {
    hits.add(
      const ShieldHit(
        'secret_ask',
        'asks for a code, seed phrase or recovery file',
      ),
    );
  }
  return ShieldResult(hits);
}

// both checks, joined the way the banner wants them: impersonation lines
// first, then content, flagged if either side says so.
ShieldResult shieldCheck({
  required String strangerId,
  required int? strangerAvatar,
  required String firstMessage,
  required Iterable<ShieldContact> contacts,
}) {
  final who = checkImpersonation(strangerId, strangerAvatar, contacts);
  final what = scanFirstMessage(firstMessage);
  if (who.impersonation) {
    return ShieldResult([...who.hits, ...what.hits], impersonation: true);
  }
  return what;
}
