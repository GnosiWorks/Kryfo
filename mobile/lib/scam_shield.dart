// SPDX-License-Identifier: GPL-3.0-or-later
// scam shield: a stranger's message request, checked on the phone against
// our contacts. no io, and the rules ship in the apk: no list to fetch,
// nothing reported back. it stays silent unless a rule is sure: a false
// alarm on a friend is the fastest way to get it switched off.

import 'dart:convert';

import 'l10n/l10n.dart';

class ShieldContact {
  final String id;
  final String? nickname;
  final int? avatar;
  const ShieldContact(this.id, {this.nickname, this.avatar});
}

class ShieldHit {
  final String code;
  // the contact a name match points at, or the name a request gave
  final String? who;
  const ShieldHit(this.code, [this.who]);

  // what was noticed, in plain words. null for a code this build no longer
  // shows: a flag an older build stored on a weaker rule stays quiet
  String? get noticed => switch (code) {
    'name_match' => l10n.scamShieldNameMatchesYourContact(who ?? ''),
    'other_key' => l10n.scamShieldGivesUsedName(who ?? ''),
    'fake_support' => l10n.scamShieldClaimsSupport,
    'asks_secret' => l10n.scamShieldAsksForSecret,
    'lookalike_link' => l10n.scamShieldLinksToALookalike,
    'pay_rush' => l10n.scamShieldAsksForMoneyFast,
    'profit_promise' => l10n.scamShieldPromisesProfit,
    _ => null,
  };

  // how a flag is stored: the code and the contact, never the words
  Map<String, String> toJson() => {'code': code, 'who': ?who};
  static ShieldHit fromJson(Map m) =>
      ShieldHit('${m['code']}', m['who'] as String?);

  @override
  bool operator ==(Object other) =>
      other is ShieldHit && other.code == code && other.who == who;
  @override
  int get hashCode => Object.hash(code, who);
}

// which line leads when more than one rule fires
const _order = [
  'name_match',
  'other_key',
  'fake_support',
  'asks_secret',
  'lookalike_link',
  'pay_rush',
  'profit_promise',
];

class ShieldResult {
  final List<ShieldHit> hits;
  const ShieldResult(this.hits);
  // every rule left is one that is sure on its own
  bool get flagged => hits.isNotEmpty;
  ShieldHit? get lead {
    for (final c in _order) {
      for (final h in hits) {
        if (h.code == c) return h;
      }
    }
    return null;
  }
}

// a stored flag, as the row in the shield table reads back: the one line a
// request shows. null for no row, a dismissed one, a clean check an older
// build stored, or a rule this build dropped
class ShieldFlag {
  final ShieldHit lead;
  const ShieldFlag(this.lead);

  String get line => l10n.scamShieldWarning(lead.noticed ?? '');

  static ShieldFlag? fromRow(Map<String, Object?>? r) {
    if (r == null || (r['dismissed'] as int? ?? 0) == 1) return null;
    try {
      final head = r['headline'] as String? ?? '';
      if (head.startsWith('{')) {
        final h = ShieldHit.fromJson(jsonDecode(head) as Map);
        if (h.noticed != null) return ShieldFlag(h);
      }
      for (final e in jsonDecode(r['lines'] as String? ?? '[]') as List) {
        if (e is! Map) continue;
        final h = ShieldHit.fromJson(e);
        if (h.noticed != null) return ShieldFlag(h);
      }
    } catch (_) {}
    return null;
  }

  @override
  bool operator ==(Object other) => other is ShieldFlag && other.lead == lead;
  @override
  int get hashCode => lead.hashCode;
}

/// a row the check may still write over: a clean check an older build
/// stored. a flag stays, and a dismissed one stays dismissed
bool shieldRowOpen(Map<String, Object?> r) =>
    (r['headline'] as String? ?? '').isEmpty &&
    (r['dismissed'] as int? ?? 0) == 0;

// the id a sender is filed on when the name it gave is bound here to
// another key (unboundIdOf in app/signal.dart): 16 hex, never three words
final _ownId = RegExp(r'^[0-9a-f]{16}$');

/// what a request is called: its three words, or for a sender filed on an
/// id of its own a short name. the shield line under it says which name it
/// gave
String requestTitle(String id) =>
    _ownId.hasMatch(id) ? l10n.requestsSomeoneNew : id;

const _wellKnown = [
  'google.com',
  'apple.com',
  'icloud.com',
  'microsoft.com',
  'outlook.com',
  'amazon.com',
  'paypal.com',
  'netflix.com',
  'facebook.com',
  'instagram.com',
  'whatsapp.com',
  'telegram.org',
  'signal.org',
  'binance.com',
  'coinbase.com',
  'kraken.com',
  'kucoin.com',
  'bybit.com',
  'metamask.io',
  'trustwallet.com',
  'ledger.com',
  'trezor.io',
  'blockchain.com',
  'revolut.com',
  'steamcommunity.com',
  'github.com',
  'kryfo.app',
  'proton.me',
];

// real sites one edit from a name above, or wearing one in their name
const _alsoReal = {
  'apple.co',
  'paypal.me',
  'binance.us',
  'github.io',
  'google-analytics.com',
  'paypal-community.com',
  'paypal-status.com',
};

// names no ordinary site wears with a dash: "apple-pie.com" is a recipe,
// "paypal-login.com" is not
const _dashBrands = {
  'paypal',
  'binance',
  'coinbase',
  'metamask',
  'kucoin',
  'bybit',
  'trustwallet',
  'revolut',
  'icloud',
  'appleid',
  'whatsapp',
  'instagram',
  'facebook',
  'netflix',
  'microsoft',
  'steamcommunity',
  'kryfo',
};

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
// request shows, so the check is on ids and on our nicknames for people.
ShieldResult checkImpersonation(
  String strangerId,
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
    if (close) {
      return ShieldResult([ShieldHit('name_match', c.nickname ?? c.id)]);
    }
  }
  return const ShieldResult([]);
}

// latin with its accents, and the scripts whose letters pass for it
bool _latin(int r) =>
    (r >= 0x41 && r <= 0x5a) ||
    (r >= 0x61 && r <= 0x7a) ||
    (r >= 0xc0 && r <= 0x24f && r != 0xd7 && r != 0xf7) ||
    (r >= 0x1e00 && r <= 0x1eff);
bool _lookalikeScript(int r) =>
    (r >= 0x370 && r <= 0x3ff) || (r >= 0x400 && r <= 0x52f);

// one label drawn in two scripts: "аpple" with a cyrillic a
bool _mixedScript(String host) {
  for (final label in host.split('.')) {
    var latin = false, other = false;
    for (final r in label.runes) {
      if (_latin(r)) latin = true;
      if (_lookalikeScript(r)) other = true;
    }
    if (latin && other) return true;
  }
  return false;
}

final _country = RegExp(r'^[a-z]{2}$');

bool lookalikeHost(String host) {
  final h = host.toLowerCase();
  if (_mixedScript(h)) return true;
  final labels = h.split('.');
  if (labels.length < 2) return false;
  final reg = labels.sublist(labels.length - 2).join('.');
  if (_alsoReal.contains(reg)) return false;
  final folded = normaliseName(reg);
  for (final w in _wellKnown) {
    if (reg == w) return false;
  }
  // "paypa1-login.com", "metamask-io.com": the name with a dash in a site
  // of its own
  final parts = folded.split('.').first.split('-');
  if (parts.length > 1 && parts.any(_dashBrands.contains)) return true;
  for (final w in _wellKnown) {
    if (folded == w) return true; // drawn the same
    if (editDistance(reg, w) == 1) return true;
    // the real name worn in front of another: paypal.com.login-help.ru.
    // amazon.com.au is the real one's country site
    final i = h.indexOf(w);
    if (i < 0 || (i > 0 && h[i - 1] != '.')) continue;
    final end = i + w.length;
    if (end >= h.length) continue;
    if (h[end] == '-') return true;
    if (h[end] == '.' && !_country.hasMatch(h.substring(end + 1))) return true;
  }
  return false;
}

final _host = RegExp(
  r'(?:https?://|www\.)?([\p{L}\p{N}][\p{L}\p{N}-]*(?:\.[\p{L}\p{N}-]+)+)',
  unicode: true,
);

final _btcLegacy = RegExp(r'\b[13][a-km-zA-HJ-NP-Z1-9]{25,34}\b');
final _btcBech32 = RegExp(r'\bbc1[qp][a-z0-9]{38,86}\b', caseSensitive: false);
final _eth = RegExp(r'\b0x[a-fA-F0-9]{40}\b');
final _xmr = RegExp(r'\b4[0-9AB][1-9A-HJ-NP-Za-km-z]{93}\b');
final _trx = RegExp(r'\bT[1-9A-HJ-NP-Za-km-z]{33}\b');

// a list as one group of whole words. han has no spaces to stand on, so
// its words go as they are
final _han = RegExp(r'\p{Script=Han}', unicode: true);
String _any(List<String> ws) {
  final words = ws.where((w) => !_han.hasMatch(w)).join('|');
  final han = ws.where(_han.hasMatch).join('|');
  final parts = [
    if (words.isNotEmpty) '(?<![\\p{L}\\p{N}])(?:$words)(?![\\p{L}\\p{N}])',
    if (han.isNotEmpty) '(?:$han)',
  ];
  return '(?:${parts.join('|')})';
}

// the text is lowercased once and every pattern is written lowercase:
// case folding over lists this long is what makes a regex slow
RegExp _re(String p) => RegExp(p, unicode: true);

final _stop = RegExp(r'[.!?。！？؟\n]');

// an [a] then a [b] in the same sentence, at most [gap] apart: the span
// from the start of one to the end of the other
List<(int, int)> _pairs(String t, RegExp a, RegExp b, int gap) {
  final out = <(int, int)>[];
  final bs = b.allMatches(t).toList();
  if (bs.isEmpty) return out;
  for (final m in a.allMatches(t)) {
    for (final n in bs) {
      if (n.start < m.end) continue;
      if (n.start - m.end > gap) break;
      if (_stop.hasMatch(t.substring(m.end, n.start))) break;
      out.add((m.start, n.end));
      break;
    }
  }
  return out;
}

// a sentence saying not to do the thing ("never share your code") is
// advice, not an ask
final _notBefore = _re(
  _any([
        'never',
        "don't",
        'dont',
        'do not',
        'not',
        'nobody',
        'no one',
        'nunca',
        'no',
        'jamais',
        'ne',
        "n'",
        'nie',
        'niemals',
        'nicht',
        'kein',
        'keinem',
        'non',
        'mai',
        'никогда',
        'не',
        'ніколи',
        'asla',
        'jangan',
        'tidak',
        'đừng',
        'không',
        'لا',
        'أبدا',
        'أبدًا',
        'هرگز',
        'نه',
      ]) +
      r"[\s\p{P}]*(?:(?:ever|should|must|can|will|pernah|bao giờ|[\p{L}\p{N}']{1,3})[\s\p{P}]*)?$",
);
final _notAfter = _re(
  r"^[\s\p{P}]*(?:[\p{L}\p{N}']+[\s\p{P}]*)?" +
      _any([
        'never',
        'jamais',
        'nunca',
        'niemals',
        'mai',
        'to anyone',
        'with anyone',
      ]),
);
const _hanNot = ['不要', '别', '別', '绝不', '絕不', '千万不要', '千萬不要', '切勿', '不能'];

bool _negated(String t, int start, int end) {
  final before = t.substring(start < 24 ? 0 : start - 24, start);
  if (_notBefore.hasMatch(before)) return true;
  for (final n in _hanNot) {
    if (before.contains(n)) return true;
  }
  final after = t.substring(end, end + 24 > t.length ? t.length : end + 24);
  return _notAfter.hasMatch(after);
}

// "gib niemals dein passwort weiter": the no sits inside the ask
final _notWithin = _re(
  _any([
    'never',
    'niemals',
    'nie',
    'jamais',
    'nunca',
    'mai',
    'никогда',
    'ніколи',
    'asla',
    'jangan',
    'đừng',
    'không bao giờ',
    'هرگز',
    'أبدا',
  ]),
);

bool _hitAsk(List<(int, int)> spans, String t) {
  for (final (a, b) in spans) {
    final said = t.substring(a, b);
    if (_negated(t, a, b) || _notWithin.hasMatch(said)) continue;
    if (_hanNot.any(said.contains)) continue;
    return true;
  }
  return false;
}

// asks for a code, a pin, a password or recovery words

const _secretVerbs = [
  // en
  'send me', 'send us', 'send it', 'send them', 'send over', 'send back',
  'send your', 'send ur', 'give me', 'give us', 'tell me', 'tell us',
  'share', 'forward', 'read me', 'read out', 'read it', 'text me', 'dm me',
  'screenshot', 'provide', "what's", 'whats', 'what is', 'i need', 'we need',
  'i want', 'can i have', 'can i get', 'reply with', 'can you send',
  'could you send', 'can you give', 'could you give', 'can you tell',
  'could you tell', 'can you read', 'could you read',
  // es
  'envía', 'envíame', 'envíanos', 'envíe', 'envíeme', 'envia', 'enviame',
  'mándame', 'mandame', 'mándanos', 'manda', 'dame', 'danos', 'dime',
  'dígame', 'pásame', 'pasame', 'comparte', 'reenvía', 'reenvíame',
  'cuál es', 'cual es', 'necesito', 'necesitamos',
  // pt
  'envie', 'me envia', 'me manda', 'me passa', 'passa', 'me diz', 'diga',
  'me fala', 'qual é', 'qual o', 'preciso', 'precisamos', 'compartilhe',
  'repassa', 'encaminha',
  // fr
  'envoie', 'envoie-moi', 'envoyez', 'envoyez-moi', 'donne', 'donne-moi',
  'donnez', 'donnez-moi', 'dis-moi', 'dites-moi', 'transfère', 'transférez',
  'communique', 'communiquez', 'partage', 'partagez', 'quel est',
  "j'ai besoin", 'nous avons besoin', 'lis-moi', 'lisez-moi',
  // de
  'schick', 'schicke', 'schicken sie', 'sende', 'senden sie', 'sag',
  'sag mir', 'sagen sie', 'gib', 'gib mir', 'geben sie', 'nenn', 'nenne',
  'nennen sie', 'teil', 'teile', 'teilen sie', 'leite', 'leiten sie',
  'wie lautet', 'ich brauche', 'wir brauchen', 'lies', 'lesen sie',
  // it
  'invia', 'inviami', 'inviaci', 'mandami', 'mandaci', 'dammi', 'dacci',
  'dimmi', 'dicci', 'passami', 'condividi', 'inoltra', 'inoltrami',
  'qual è', 'mi serve', 'ci serve', 'ho bisogno', 'abbiamo bisogno',
  'leggimi',
  // ru
  'отправь', 'отправьте', 'пришли', 'пришлите', 'скинь', 'скиньте',
  'скажи', 'скажите', 'назови', 'назовите', 'продиктуй', 'продиктуйте',
  'перешли', 'перешлите', 'сообщи', 'сообщите', 'напиши', 'напишите',
  'какой', 'нужен', 'дай', 'дайте',
  // uk
  'надішли', 'надішліть', 'скажіть', 'назви', 'назвіть', 'перешліть',
  'повідом', 'повідомте', 'напишіть', 'який', 'потрібен',
  // tr
  'gönder', 'gönderin', 'gönderir misin', 'gönderir misiniz', 'yolla',
  'söyle', 'söyler misin', 'söyler misiniz', 'söyleyin', 'ver', 'verin',
  'verir misin', 'verir misiniz', 'paylaş', 'paylaşın', 'ilet', 'iletin',
  'lazım', 'gerekiyor',
  // id
  'kirim', 'kirimkan', 'kirimin', 'berikan', 'kasih', 'kasih tau',
  'kasih tahu', 'sebutkan', 'beritahu', 'beri tahu', 'bagikan', 'minta',
  'teruskan', 'bacakan',
  // vi
  'gửi', 'gởi', 'cho mình', 'cho tôi', 'cho em', 'cho anh', 'cho chị',
  'đọc', 'nói', 'chia sẻ', 'báo', 'cung cấp',
  // zh
  '发给我', '發給我', '发我', '發我', '给我', '給我', '告诉我', '告訴我',
  '提供', '转发', '轉發', '报一下', '報一下', '念一下', '发一下', '發一下',
  '发过来', '發過來',
  // ar
  'أرسل', 'ارسل', 'أرسلي', 'ابعث', 'ابعتلي', 'أعطني', 'اعطني', 'قل لي',
  'شارك', 'زودني', 'ما هو',
  // fa
  'بفرست', 'بفرستید', 'بگو', 'بگویید', 'بده', 'بدهید', 'ارسال کن',
  'ارسال کنید',
];

const _secrets = [
  // en
  r'(?:verification|security|login|log-in|sign-in|signin|2fa|two-factor|otp|one-time|one time|authentication|auth|sms|recovery|reset|whatsapp|telegram|[456]-digit|[456] digit|four-digit|five-digit|six-digit|six digit) codes?',
  'otp',
  r'codes? (?:that )?(?:you|u) (?:just )?(?:got|received|were sent|get|receive)',
  r'codes? (?:we|i|they) (?:just )?sent',
  r'codes? (?:that )?(?:just )?(?:came|arrived|went) to your (?:phone|number)',
  r'pin (?:code|number)',
  r'(?:bank|card|kryfo|unlock|app|lock|sim|atm) pin',
  r'(?:your|ur) (?:account |kryfo |bank |card |email |apple id |icloud |google |login )?(?:password|passcode|passphrase)',
  r'seed (?:phrase|words)',
  r'recovery (?:phrase|words|seed|key)',
  r'secret (?:phrase|recovery phrase)',
  'mnemonic',
  r'(?:your|ur) (?:12|24|twelve|twenty-four|twenty four)[- ]words?',
  r'private keys?',
  // es
  r'código (?:de verificación|de seguridad|de acceso|sms|que te (?:llegó|ha llegado|enviaron|mandaron)|que recibiste)',
  r'código de \d dígitos',
  r'tu (?:contraseña|pin)',
  r'tu frase (?:semilla|de recuperación|secreta)',
  'frase semilla',
  r'tus (?:12|24) palabras',
  'clave privada',
  // pt
  r'código (?:de verificação|de segurança|de acesso|sms|que (?:você )?recebeu|que (?:te )?chegou|que (?:te )?enviamos|que mandamos)',
  r'código de \d dígitos',
  r'(?:sua|tua) senha',
  r'(?:seu|teu) pin',
  r'(?:sua|tua) frase (?:semente|de recuperação|secreta)',
  'frase semente',
  r'(?:suas|tuas) (?:12|24) palavras',
  'chave privada',
  // fr
  r"code (?:de vérification|de sécurité|d'accès|sms|reçu|que (?:tu as|vous avez) reçu|qu'on (?:t'a|vous a) envoyé|à \d chiffres)",
  r'(?:ton|votre) mot de passe',
  r'(?:ton|votre) (?:code )?pin',
  r'(?:ta|votre) phrase (?:secrète|de récupération)',
  'phrase de récupération',
  r'(?:tes|vos) (?:12|24) mots',
  'clé privée',
  // de
  r'(?:bestätigungs|verifizierungs|sicherheits|login|anmelde|zugangs|sms|tan)-?code',
  r'code,? (?:den|die) (?:du|sie) (?:bekommen|erhalten)',
  r'(?:dein|ihr) (?:passwort|kennwort)',
  r'(?:deine|ihre) pin',
  r'(?:deine|ihre) (?:seed|wiederherstellungs)-?phrase',
  r'seed-?phrase',
  'wiederherstellungsphrase',
  r'(?:deine|ihre) (?:12|24) wörter',
  r'(?:deinen|ihren) privaten schlüssel',
  // it
  r"codice (?:di verifica|di sicurezza|di accesso|sms|otp|che (?:hai ricevuto|ti è arrivato))",
  r'codice di \d cifre',
  r'(?:la )?tua password',
  r'(?:il )?tuo pin',
  r'(?:la )?tua (?:frase (?:seed|di recupero)|seed phrase)',
  'frase di recupero',
  r'(?:le )?tue (?:12|24) parole',
  'chiave privata',
  // ru
  r'код (?:из смс|из sms|подтверждения|верификации|безопасности|доступа|который (?:тебе |вам )?приш[её]л)',
  r'(?:смс|sms)[- ]код',
  r'(?:твой|ваш|свой) пароль',
  r'(?:твой|ваш|свой) пин[- ]?код',
  r'сид[- ]?фраз\p{L}*',
  r'фраз\p{L}* (?:для )?восстановлени\p{L}*',
  r'секретн\p{L}* фраз\p{L}*',
  r'(?:твои|ваши|свои) (?:12|24) слов\p{L}*',
  r'приватн\p{L}* ключ\p{L}*',
  // uk
  r'код (?:з смс|із смс|підтвердження|верифікації|доступу|який (?:тобі |вам )?прийшов)',
  r'(?:твій|ваш|свій) пароль',
  r'(?:твій|ваш|свій) пін[- ]?код',
  r'сід[- ]?фраз\p{L}*',
  r'фраз\p{L}* відновлення',
  r'(?:твої|ваші|свої) (?:12|24) слів',
  // tr
  r'doğrulama kod\p{L}*',
  r'onay kod\p{L}*',
  r'sms (?:kod|şifre)\p{L}*',
  r'güvenlik kod\p{L}*',
  r'giriş kod\p{L}*',
  r'gelen (?:kod|şifre)\p{L}*',
  r'tek kullanımlık (?:kod|şifre)\p{L}*',
  r'şifreni(?:zi)?',
  r'parolanı(?:zı)?',
  r'pin kodunu(?:zu)?',
  r'kurtarma (?:ifadeni(?:zi)?|kelimelerini(?:zi)?)',
  r'(?:gizli|özel) anahtarını(?:zı)?',
  // id
  r'kode (?:verifikasi|otp|sms|keamanan|akses)',
  r'kode yang (?:masuk|kami kirim|dikirim)',
  r'(?:kata sandi|password)(?:mu| kamu| anda)',
  r'pin(?:mu| kamu| anda)',
  r'frasa (?:pemulihan|seed|rahasia)',
  r'(?:12|24) kata (?:pemulihan|rahasia)',
  'kunci pribadi',
  // vi
  r'mã (?:xác nhận|xác minh|xác thực|otp|bảo mật|đăng nhập)',
  r'mật khẩu (?:của bạn|của em|của anh|của chị)',
  r'mã pin',
  r'cụm từ (?:khôi phục|bí mật|hạt giống)',
  r'(?:12|24) từ khôi phục',
  r'khóa riêng(?: tư)?',
  // zh
  '验证码', '驗證碼', '短信码', '短信碼', '簡訊碼', '校验码', '校驗碼', '动态码',
  '動態碼', '你的密码', '你的密碼', '登录密码', '登入密碼', '支付密码', '支付密碼',
  '助记词', '助記詞', '私钥', '私鑰', '恢复短语', '恢復短語',
  // ar
  'رمز التحقق', 'كود التحقق', 'رمز التفعيل', 'كود التفعيل', 'رمز التأكيد',
  r'(?:الرمز|الكود) (?:اللي|الذي) (?:وصلك|وصل|جاك)',
  r'كلمة (?:المرور|السر)', 'الرقم السري', 'عبارة الاسترداد', 'العبارة السرية',
  'المفتاح الخاص',
  // fa
  r'کد (?:تایید|تأیید|فعال‌سازی|یکبار مصرف)', 'رمز یکبار مصرف', 'رمز دوم',
  r'رمز عبور(?:ت| شما)?', 'عبارت بازیابی', 'کلمات بازیابی', 'کلید خصوصی',
];

final _secretVerbRe = _re(_any(_secretVerbs));
final _secretRe = _re(_any(_secrets));

// a wallet drainer: put your words into their page
final _enterRe = _re(
  _any([
    'enter',
    'type',
    'paste',
    'input',
    'import',
    'submit',
    'validate',
    'verify',
    'sync',
    'connect',
  ]),
);
final _walletWordsRe = _re(
  _any([
    r'(?:your|ur|the) (?:seed|recovery|secret|wallet) (?:phrase|words)',
    r'(?:your|ur) (?:12|24) words?',
    'private key',
    'mnemonic',
  ]),
);

// a code for the wifi, a door or a router is no secret of yours
final _benignSecret = _re(
  _any([
    'wi-?fi',
    'wlan',
    'router',
    'роутер',
    'вайфай',
    'вай-фай',
    'واي فاي',
    'وای فای',
    'door',
    'gate',
    'lockbox',
    'key ?box',
    'locker',
    'garage',
    'alarm',
    'parking',
  ]),
);

bool _asksSecret(String t) {
  if (_benignSecret.hasMatch(t)) return false;
  return _hitAsk(_pairs(t, _secretVerbRe, _secretRe, 40), t) ||
      _hitAsk(_pairs(t, _secretRe, _secretVerbRe, 40), t) ||
      _hitAsk(_pairs(t, _enterRe, _walletWordsRe, 30), t);
}

// money, asked for in a hurry

const _payVerbs = [
  // en
  'send me', 'send us', 'send it', 'send the money', 'send money',
  'send cash', 'transfer', 'wire', 'pay me', 'pay us', 'pay the', 'pay a',
  'pay this', 'deposit', 'lend me', 'loan me', 'top up', 'buy me', 'buy some',
  'buy a', 'buy the', 'i need', 'i really need', 'i urgently need',
  'i badly need', 'can you send', 'could you send', 'please send',
  // es
  'envíame', 'enviame', 'mándame', 'mandame', 'transfiéreme', 'transfiere',
  'transfiera', 'págame', 'pagame', 'paga', 'préstame', 'prestame',
  'deposita', 'necesito', 'hazme un bizum', 'envía', 'envia',
  // pt
  'me manda', 'me envia', 'me transfere', 'me empresta', 'me paga', 'manda',
  'envie', 'transfira', 'preciso de', 'eu preciso de', 'faz um pix',
  'faça um pix',
  'deposite',
  // fr
  'envoie-moi', 'envoyez-moi', 'vire-moi', 'virez-moi', 'prête-moi',
  'prêtez-moi', 'envoie', 'envoyez', "j'ai besoin d'", "j'ai besoin de",
  'payez', 'paie', 'versez',
  // de
  'schick mir', 'schicken sie', 'überweis mir', 'überweise',
  'überweisen sie', 'leih mir', 'sende mir', 'ich brauche', 'zahl',
  'zahlen sie',
  // it
  'mandami', 'inviami', 'prestami', 'fammi un bonifico', 'bonifica',
  'ricarica', 'ho bisogno di', 'io ho bisogno di', 'versa', 'mi serve',
  'mi servono', 'mi fai un bonifico', 'fammi',
  // ru
  'переведи', 'переведите', 'скинь', 'скиньте', 'отправь', 'отправьте',
  'займи', 'одолжи', 'одолжите', r'мне (?:\p{L}+ )?нужн\p{L}*', 'пришли',
  'пришлите',
  // uk
  'переведіть', 'надішли', 'надішліть', 'позич', 'позичте',
  r'мені (?:\p{L}+ )?потрібн\p{L}*',
  // id
  'kirim', 'kirimin', 'transfer', 'tf', 'pinjam', 'pinjamkan', 'butuh',
  'perlu', 'saya butuh', 'aku butuh', 'saya perlu', 'aku perlu',
  // vi
  'chuyển', 'gửi', 'cho mình vay', 'cho em vay', 'cho tôi vay',
  'cho mình mượn', 'cho em mượn', 'cần', 'mình cần', 'tôi cần', 'em cần',
  'anh cần',
  // zh
  '转账', '轉帳', '轉賬', '汇款', '匯款', '打钱', '打錢', '借我', '借錢', '借钱',
  '转给我', '轉給我', '我需要', '急需',
  // ar
  'حول لي', 'حوّل لي', 'ارسل لي', 'أرسل لي', 'اقرضني', 'أقرضني', 'أحتاج',
  'احتاج',
  // fa
  'واریز کن', 'واریز کنید', 'کارت به کارت کن', 'بفرست', 'قرض بده', 'لازم دارم',
];

const _money = [
  // signs and digits, every language
  r'\$ ?\d[\d,.]*', r'€ ?\d[\d,.]*', r'£ ?\d[\d,.]*', r'₽ ?\d[\d,.]*',
  r'r\$ ?\d[\d,.]*', r'rp ?\d[\d,.]*',
  r'\d[\d,. ]*(?:\$|€|£|₽|₺|₴|usd|eur|gbp|usdt|usdc|btc|eth|k)',
  // en
  'money', 'cash', 'funds', r'dollars?', 'bucks', r'euros?', r'pounds?',
  r'bitcoins?', 'btc', 'usdt', 'usdc', 'ethereum', 'crypto', r'gift ?cards?',
  'itunes', r'google play cards?', r'steam cards?', 'western union',
  'moneygram', 'zelle', r'cash ?app', 'venmo', 'paypal', 'bank transfer',
  // es
  'dinero', 'plata', r'tarjetas? de regalo', 'bizum', 'dólares', 'pesos',
  // pt
  'dinheiro', 'grana', 'reais', r'cartões? presente', 'pix',
  // fr
  'argent', 'fric', r'cartes? cadeaux?', 'virement', 'transcash', 'neosurf',
  // de
  'geld', 'kohle', r'gutscheine?', r'geschenkkarten?', 'paysafecard',
  // it
  'soldi', 'denaro', 'buoni regalo', 'carte regalo', 'postepay', 'bonifico',
  // ru
  r'деньг\p{L}*', r'руб\p{L}*', r'биткоин\p{L}*', 'на карту',
  r'подарочн\p{L}* карт\p{L}*', r'долл\p{L}*',
  // uk
  r'грош\p{L}*', 'грн', r'гривень', r'біткоїн\p{L}*',
  // id
  'uang', 'duit', r'\d+ ?(?:rb|ribu|jt|juta)', 'pulsa',
  // vi
  'tiền', r'\d+ ?(?:k|đ|vnd|triệu|nghìn)',
  // zh
  '钱', '錢', r'\d+ ?元', '块钱', '塊錢', '比特币', '比特幣', '礼品卡', '禮品卡',
  '泰达币',
  // ar
  'فلوس', 'المال', 'مبلغ', 'بيتكوين', 'بطاقة هدايا', 'دولار', 'دولارات',
  // fa
  'پول', 'تومان', 'ریال', 'بیت‌کوین',
];

// turkish puts the verb last: "parayı hemen gönder"
final _trMoneyRe = _re(
  _any([r'para(?:yı)?', r'\d+ ?(?:tl|lira)', r'hediye kart\p{L}*']),
);
final _trVerbRe = _re(
  _any([
    r'gönder(?:in|ir misin|ir misiniz|ebilir misin|ebilir misiniz)?',
    r'yolla(?:r mısın|yabilir misin)?',
    r'havale (?:et|eder misin|yapar mısın)',
    'lazım',
    'gerek',
    'gerekiyor',
    r'borç ver(?:ir misin)?',
  ]),
);

// the verb last: "kannst du mir dringend 500 € überweisen"
final _lateVerbRe = _re(
  _any([
    'überweisen',
    'schicken',
    'senden',
    'leihen',
    'bezahlen',
    'بفرست',
    'بفرستید',
    'واریز کن',
    'واریز کنید',
    'کارت به کارت کن',
    'کارت به کارت کنید',
    '转给我',
    '轉給我',
    '打给我',
    '打給我',
  ]),
);
// ...unless the one saying it is the one paying
final _lateOffer = _re(_any(['ich', 'wir', 'من', 'ما']));
final _sentenceStart = RegExp(r'[.!?。！？\n][^.!?。！？\n]*$');

// urgency that is sure wherever it sits
const _urgentAnywhere = [
  // en
  'urgent', 'urgently', 'immediately', 'asap', 'as soon as possible',
  r'within (?:the next )?\d+ ?(?:mins?|minutes?|h|hrs?|hours?)',
  r'in the next \d+ ?(?:mins?|minutes?|hours?)', 'last chance', 'emergency',
  "before it'?s too late", r"or (?:you'll|you will) lose",
  r'expires? (?:today|tonight|in \d+)', 'today only',
  // es
  'urgente', 'urgentemente', 'inmediatamente', 'cuanto antes',
  'lo antes posible', r'en (?:los próximos )?\d+ (?:minutos|horas)',
  'última oportunidad', 'emergencia',
  // pt
  'imediatamente', 'o quanto antes', 'o mais rápido possível',
  r'em \d+ (?:minutos|horas)', 'última chance', 'emergência',
  // fr
  'urgence', 'immédiatement', 'au plus vite', 'dès que possible',
  r'dans les \d+ (?:minutes|heures)', 'dernière chance',
  // de
  'dringend', 'umgehend', 'schnellstmöglich', 'so schnell wie möglich',
  r'innerhalb von \d+ (?:minuten|stunden)', 'letzte chance', 'notfall',
  // it
  'urgentemente', 'immediatamente', 'al più presto', 'il prima possibile',
  r'entro \d+ (?:minuti|ore)', 'ultima occasione', 'emergenza',
  // ru
  'срочно',
  'немедленно',
  'как можно скорее',
  r'в течение \d+ (?:минут|час\p{L}*)',
  'последний шанс',
  // uk
  'терміново', 'негайно', 'якнайшвидше', r'протягом \d+ (?:хвилин|годин\p{L}*)',
  'останній шанс',
  // tr
  'acil', 'acilen', 'derhal', 'bir an önce', r'\d+ (?:dakika|saat) içinde',
  'son şans',
  // id
  'segera', 'darurat', 'mendesak', r'dalam \d+ (?:menit|jam)',
  'kesempatan terakhir',
  // vi
  'gấp',
  'ngay lập tức',
  'khẩn cấp',
  'càng sớm càng tốt',
  r'trong \d+ (?:phút|giờ)',
  // zh
  '紧急', '緊急', '尽快', '盡快', '今天之内', '今天之內',
  // ar
  'عاجل', 'فورا', 'فورًا', 'في أسرع وقت',
  // fa
  'فوری', 'هر چه زودتر',
];

// urgency that only counts after the ask: "busy right now" is not a rush
const _urgentAfter = [
  'right now',
  'right away',
  'hurry',
  'ahora mismo',
  'ya mismo',
  'date prisa',
  'agora mesmo',
  'tout de suite',
  'sofort',
  'subito',
  'прямо сейчас',
  'прямо зараз',
  'hemen',
  'sekarang juga',
  'ngay bây giờ',
  '马上',
  '馬上',
  '立刻',
  '立即',
  '赶紧',
  '趕緊',
  'حالا',
  'همین الان',
];

// "no hurry", "not urgent", "nothing urgent" say the opposite
const _calm =
    r'(?<!(?:no|not|not in a|not an?|nothing|without|non|sin|no es|não é|sans|pas|ohne|nicht|senza|non è|без|не|tanpa|không|bukan|değil|hiç) )';

final _rushAnywhere = _re(_calm + _any(_urgentAnywhere));
final _rushAfter = _re(_calm + _any(_urgentAfter));
final _payVerbRe = _re(_any(_payVerbs));
final _moneyRe = _re(_any(_money));
// "pay me back" is a friend's tab, not an ask from a stranger
final _payBack = _re(_any(['pay me back', 'pay you back', 'back to you']));

// the one asking is the one paying: "i'll send you the money right away"
final _offer = _re(
  _any([
        "i'll",
        'i will',
        'i can',
        "i'm going to",
        'i am going to',
        'let me',
        "i'd",
        "we'll",
        'we will',
        'i just',
        'i already',
        "i've",
        'i',
        'we',
        'je',
        "j'",
        "je t'",
        'je vous',
        'ich',
        'wir',
        'yo',
        'eu',
        'io',
        'я',
        'мы',
        'ми',
        'aku',
        'saya',
        'kami',
        'tôi',
        'mình',
        'tớ',
      ]) +
      r"[\s\p{P}]*(?:[\p{L}\p{N}']{1,8}[\s\p{P}]*)?$",
);
final _hanOffer = RegExp(r'(?<![给給])我(?:马上|馬上|立刻|现在|現在|会|會|就|先)?$');

bool _offered(String t, int start) {
  final before = t.substring(start < 20 ? 0 : start - 20, start);
  return _offer.hasMatch(before) || _hanOffer.hasMatch(before);
}

bool _payRush(String t, String cased) {
  bool rushed(int at, int end) {
    for (final u in _rushAnywhere.allMatches(t)) {
      if ((u.start - at).abs() <= 120) return true;
    }
    for (final u in _rushAfter.allMatches(t)) {
      if (u.start > at && u.start - end <= 60) return true;
    }
    return false;
  }

  // a wallet address with a rush on it. addresses keep their case
  for (final re in [_btcLegacy, _btcBech32, _eth, _xmr, _trx]) {
    for (final m in re.allMatches(cased)) {
      if (rushed(m.start, m.end)) return true;
    }
  }
  for (final (a, b) in [
    ..._pairs(t, _payVerbRe, _moneyRe, 30),
    ..._pairs(t, _trMoneyRe, _trVerbRe, 30),
  ]) {
    if (_negated(t, a, b) || _offered(t, a)) continue;
    if (_payBack.hasMatch(t.substring(a, b))) continue;
    if (rushed(a, b)) return true;
  }
  for (final (a, b) in _pairs(t, _moneyRe, _lateVerbRe, 30)) {
    final head = t.substring(0, a);
    final cut = _sentenceStart.firstMatch(head);
    final sentence = cut == null ? head : head.substring(cut.start);
    if (_lateOffer.hasMatch(sentence) || _hanOffer.hasMatch(head)) continue;
    if (_negated(t, a, b)) continue;
    if (rushed(a, b)) return true;
  }
  return false;
}

// easy money promised

final _profit = _re(
  _any([
    r'guaranteed (?:profits?|returns?|income|earnings|gains)',
    r'(?:double|triple) your (?:money|bitcoin|btc|crypto|investment|deposit)',
    r'\d+ ?% (?:daily|weekly|a day|per day|per week|every day) (?:profits?|returns?|roi|gains?|interest)',
    r'(?:profits?|returns?|roi|gains?|interest) of \d+ ?% (?:daily|a day|per day|weekly|per week|every day)',
    r'risk[- ]free (?:profits?|investment|returns?|income|trading)',
    // es
    r'(?:ganancias|rentabilidad|beneficios) garantizad[ao]s?',
    r'duplica (?:tu|su) (?:dinero|inversión|bitcoin)',
    // pt
    r'(?:lucro|retorno|rendimento)s? garantidos?',
    r'dobr[ae] (?:seu|o seu) dinheiro',
    // fr
    r'(?:profits?|rendements?|gains?) garantis?',
    r'doublez? (?:votre|ton) (?:argent|investissement)',
    // de
    r'garantierte[nr]? (?:gewinne?|rendite|einnahmen)',
    r'verdoppeln sie ihr (?:geld|investment)',
    // it
    r'(?:profitt[oi]|guadagn[oi]|rendiment[oi]) garantit[oi]',
    r'raddoppia (?:i tuoi soldi|il tuo investimento)',
    // ru
    r'гарантированн\p{L}* (?:доход\p{L}*|прибыл\p{L}*)',
    r'удво\p{L}* (?:деньги|депозит\p{L}*|вложени\p{L}*)',
    // uk
    r'гарантован\p{L}* (?:дох\p{L}*|прибут\p{L}*)',
    // tr
    r'garantili (?:kazanç|kar|kâr|getiri)',
    r'günlük %? ?\d+ ?%? ?(?:kazanç|getiri|kar|kâr)',
    // id
    r'(?:keuntungan|profit|untung) (?:pasti|dijamin)',
    // vi
    r'lợi nhuận (?:đảm bảo|chắc chắn)',
    r'lãi \d+ ?% (?:mỗi ngày|một ngày)',
    // zh
    '稳赚', '穩賺', '日收益', '保证收益', '保證收益', '翻倍收益',
    // ar
    'أرباح مضمونة', 'ربح مضمون',
    // fa
    'سود تضمینی',
  ]),
);

// someone saying they are kryfo, or a big name's support

const _claims = [
  // en
  'this is', 'we are', "we're", 'i am', "i'm", 'on behalf of',
  r'(?:hello|hi|hey|greetings|dear (?:user|customer|member|client))[ ,!]*from',
  r'(?:writing|contacting you|reaching out|messaging you|message|notice|alert|reminder|notification|announcement) from',
  'official',
  // es
  'soy', 'somos', r'(?:le|te) (?:escribe|saluda|contacta)',
  r'(?:le|te) escribimos', r'(?:hola|saludos)[ ,!]*(?:de|desde)',
  r'(?:mensaje|aviso) (?:de|del)', 'oficial',
  // pt
  'sou', 'aqui é', 'aqui fala', r'(?:olá|oi)[ ,!]*(?:da|do|de)',
  r'(?:mensagem|aviso) (?:da|do)',
  // fr
  'je suis', 'nous sommes', 'ici', "c'est", r'de la part (?:de|du)',
  r'(?:bonjour|salut)[ ,!]*(?:de|du)', r'(?:message|avis) (?:de|du)',
  r'officiel(?:le)?',
  // de
  'ich bin', 'wir sind', 'hier ist', 'hier spricht', 'hier schreibt',
  r'(?:hallo|guten tag)[ ,!]*(?:vom|von der|von)',
  r'nachricht (?:vom|von der|von)', r'offizielle?[rs]?',
  // it
  'sono', 'siamo', 'qui è', r'(?:vi|ti) scrive',
  r'(?:ciao|salve|buongiorno)[ ,!]*(?:dal|dalla|da)',
  r'messaggio (?:dal|dalla|da)', 'ufficiale',
  // ru
  'это', 'мы', 'я из', 'мы из', r'(?:вам|тебе) пишет',
  r'(?:вас|тебя) беспокоит', r'официальн\p{L}*',
  // uk
  'це', 'ми', 'я з', 'ми з', r'(?:вам|тобі) пише', r'офіційн\p{L}*',
  // tr
  'ben', 'biz', 'resmi',
  // id
  'saya', 'kami', r'(?:halo|hai)[ ,!]*dari', 'pesan dari',
  // vi
  'tôi là', 'chúng tôi là', 'đây là', 'chính thức',
  // zh
  '我是', '我们是', '我們是', '这里是', '這裡是', '这是', '這是', '官方',
  // ar
  'أنا', 'نحن', 'معك', 'معكم', 'الرسمي',
  // fa
  'من', 'ما', 'اینجا', 'رسمی',
];

// articles and small words that may sit between the claim and the name
const _filler =
    r"(?:[\s,:-]+(?:the|a|an|your|el|la|los|las|le|les|l'|der|die|das|dem|den|il|lo|o|os|as|of|de|del|da|do|di|della|dello|dal|dalla|du|des|von|vom|at|official|oficial|officiel|officielle|offizielle|offizielles|ufficiale|службы|служба|компании|from|dari|في|من|از|لدى))*[\s,:-]*";

const _brands = [
  'binance',
  'coinbase',
  'kraken',
  'kucoin',
  'bybit',
  'okx',
  'metamask',
  'trust wallet',
  'trustwallet',
  'ledger',
  'trezor',
  r'blockchain\.com',
  r'crypto\.com',
  'telegram',
  'whatsapp',
  'signal',
  'paypal',
  'apple',
  'google',
  'microsoft',
  'amazon',
  'facebook',
  'meta',
  'instagram',
  'netflix',
  'revolut',
];

// what a support desk calls itself. a bare "security" or "admin" is a
// person's job, so another company needs the word for a desk
const _desks = [
  // en
  'team', 'support', 'support team', 'staff', 'security team',
  'security department', 'security center', 'security centre',
  'administration', 'moderation team', r'help ?desk',
  r'customer (?:service|care|support)', 'service team',
  r'compliance (?:team|department)', 'trust (?:and|&) safety',
  // es
  'equipo', 'soporte', 'soporte técnico', 'atención al cliente',
  'servicio al cliente', 'equipo de seguridad', 'administración',
  // pt
  'equipe', 'suporte', 'suporte técnico', 'atendimento',
  'equipe de segurança', 'administração',
  // fr
  'équipe', 'assistance', 'service client', 'équipe de sécurité',
  // de
  'kundendienst', 'kundenservice', 'sicherheitsteam',
  // it
  'squadra', 'supporto', 'assistenza', 'servizio clienti',
  // ru
  'команда', 'команды', 'поддержка', 'поддержки', 'служба поддержки',
  'служба безопасности', 'службы безопасности', 'администрация',
  'администрации',
  // uk
  'команди', 'підтримка', 'підтримки', 'служба підтримки', 'служба безпеки',
  'адміністрація',
  // tr
  r'ekib\p{L}*', 'ekip', 'destek', r'destek ekib\p{L}*',
  r'güvenlik ekib\p{L}*', 'müşteri hizmetleri',
  // id
  'tim', 'dukungan', 'tim dukungan', 'layanan pelanggan', 'cs',
  // vi
  'đội ngũ', 'bộ phận hỗ trợ', 'hỗ trợ', 'chăm sóc khách hàng', 'cskh',
  // zh
  '团队', '團隊', '客服', '官方客服', '安全中心', '安全团队', '安全團隊', '支持团队',
  '支援團隊', '技术支持', '技術支援',
  // ar
  'فريق', 'الدعم', 'فريق الدعم', 'خدمة العملاء',
  // fa
  'تیم', 'پشتیبانی', 'تیم پشتیبانی',
];

// kryfo has no desk that writes first, so any staff word will do
const _kryfoDesks = [
  ..._desks,
  'security',
  'admin',
  'admins',
  'moderators?',
  'developers?',
  'dev team',
  'seguridad',
  'segurança',
  'sécurité',
  'sicherheit',
  'sicurezza',
  r'модератор\p{L}*',
  'безопасности',
  'безпеки',
  'güvenlik',
  'keamanan',
  'admin',
  'bảo mật',
  '管理员',
  '管理員',
  'الأمان',
  'امنیت',
  'مدیریت',
];

final _claimRe = _re(_any(_claims));
final _kryfoRe = _re(_any(['kryfo']));
final _brandRe = _re(_any(_brands));
final _deskRe = _re(_any(_desks));
final _kryfoDeskRe = _re(_any(_kryfoDesks));
final _fillerOnly = RegExp('^$_filler\$', unicode: true);
final _feature = RegExp(
  r"^(?:'s|\s+(?:for|of|in|on|is|was|with|that|works)(?![\p{L}\p{N}]))",
  unicode: true,
);

// the first of [ms] that sits right after [from], with only small words
// between
RegExpMatch? _next(String t, int from, List<RegExpMatch> ms) {
  for (final m in ms) {
    if (m.start < from) continue;
    if (m.start - from > 40) return null;
    if (_fillerOnly.hasMatch(t.substring(from, m.start))) return m;
  }
  return null;
}

// a claim, then the name and the desk in either order: "this is the kryfo
// team", "we are the support team of kryfo". where each claim ends
List<int> _claimEnds(String t, RegExp brand, RegExp desk) {
  final out = <int>[];
  final cs = _claimRe.allMatches(t).toList();
  if (cs.isEmpty) return out;
  final bs = brand.allMatches(t).toList();
  if (bs.isEmpty) return out;
  final ds = desk.allMatches(t).toList();
  if (ds.isEmpty) return out;
  RegExpMatch? desks(int from) {
    final d = _next(t, from, ds);
    if (d == null) return null;
    return _next(t, d.end, ds) ?? d;
  }

  for (final c in cs) {
    final b = _next(t, c.end, bs);
    final d = b == null ? null : desks(b.end);
    if (d != null && !_feature.hasMatch(t.substring(d.end))) out.add(d.end);
    final d2 = desks(c.end);
    final b2 = d2 == null ? null : _next(t, d2.end, bs);
    if (b2 != null) out.add(b2.end);
  }
  return out;
}

final _kryfoHeader = _re(
  r'^[^\p{L}\p{N}]*kryfo[ -]?(?:team|support|security|admin)\s*[:|\-]'
  r'|^[^\p{L}\p{N}]*[\[【(（]\s*kryfo[^\]】)）]{0,20}[\]】)）]'
  r'|kryfo (?:team|support|security) here'
  // turkish wears the claim as an ending: "kryfo destek ekibiyiz"
  r'|kryfo (?:destek|güvenlik) ekib\p{L}*',
);
final _brandHeader = _re(
  r'^[^\p{L}\p{N}]*[\[【(（]\s*'
  '${_any(_brands)}'
  r'\s*[\]】)）]',
);

// kryfo has no accounts, and no bank or exchange warns over a request
final _accountThreat = _re(
  _any([
    r'(?:verify|confirm|validate) your (?:account|wallet)',
    r'your (?:\w+ )?(?:account|wallet) (?:will be|is going to be|has been|is being) (?:suspended|locked|frozen|deleted|banned|restricted|disabled|terminated|closed|blocked|deactivated)',
    // es
    r'verifica(?:r)? (?:tu|su) cuenta',
    r'(?:tu|su) cuenta (?:será|ha sido|fue|está) (?:suspendida|bloqueada|eliminada|cerrada|desactivada|restringida)',
    // pt
    r'verifi(?:que|car) (?:sua|a sua) conta',
    r'(?:sua|tua) conta (?:será|foi|está) (?:suspensa|bloqueada|excluída|encerrada|desativada|restrita)',
    // fr
    r'vérifie(?:z|r)? (?:ton|votre) compte',
    r'(?:ton|votre) compte (?:sera|a été|est) (?:suspendu|bloqué|supprimé|fermé|désactivé|restreint)',
    // de
    r'(?:verifiziere|bestätige|verifizieren sie|bestätigen sie) (?:dein|ihr) konto',
    r'(?:dein|ihr) konto (?:wird|wurde|ist) (?:gesperrt|gelöscht|eingeschränkt|deaktiviert|geschlossen)',
    // it
    r'verifica (?:il tuo|il suo) account',
    r"(?:il tuo|il suo) account (?:sarà|è stato|verrà) (?:sospeso|bloccato|eliminato|chiuso|disattivato|limitato)",
    // ru
    r'(?:ваш|твой) (?:аккаунт|сч[её]т|кошел[её]к) (?:будет |был )?(?:заблокирован|удал[её]н|приостановлен|заморожен)\p{L}*',
    r'подтвердите (?:ваш )?(?:аккаунт|личность)',
    // uk
    r'(?:ваш|твій) (?:акаунт|рахунок|гаманець) (?:буде |був )?(?:заблоковано|заблокований|видалено|видалений|призупинено)',
    r'підтвердіть (?:ваш )?(?:акаунт|особу)',
    // tr
    r'hesabınız (?:askıya alın|kapatıl|silin|engellen|dondurul)\p{L}*',
    r'hesabınızı doğrulayın',
    // id
    r'akun (?:anda|kamu|mu) (?:akan )?(?:diblokir|ditangguhkan|dihapus|dinonaktifkan|dibekukan)',
    r'verifikasi akun (?:anda|kamu|mu)',
    // vi
    r'tài khoản của (?:bạn|anh|chị|em) (?:sẽ )?(?:bị khóa|bị tạm ngưng|bị xóa|bị đóng băng)',
    r'xác minh tài khoản',
    // zh
    r'你的(?:账户|账号|帳戶|帳號)(?:将|將|已|已经|已經)?(?:被)?(?:冻结|凍結|封禁|封鎖|停用|删除|刪除|锁定|鎖定)',
    r'验证你的(?:账户|账号)', r'驗證你的(?:帳戶|帳號)',
    // ar
    r'سيتم (?:إيقاف|حظر|إغلاق|تعليق) حسابك', r'تأكيد حسابك',
    // fa
    r'حساب (?:شما|کاربری شما) (?:مسدود|تعلیق|حذف) (?:خواهد شد|شد|می‌شود)',
  ]),
);

// a claim is said, not asked: "is this the kryfo team?" is a question
bool _said(String t, Iterable<int> ends) {
  for (final end in ends) {
    final stop = _stop.firstMatch(t.substring(end));
    final mark = stop == null ? '' : stop[0]!;
    if (mark != '?' && mark != '？' && mark != '؟') return true;
  }
  return false;
}

bool _fakeSupport(String t) =>
    _kryfoHeader.hasMatch(t) ||
    _brandHeader.hasMatch(t) ||
    _said(t, _claimEnds(t, _kryfoRe, _kryfoDeskRe)) ||
    _said(t, _claimEnds(t, _brandRe, _deskRe)) ||
    _said(t, [for (final m in _accountThreat.allMatches(t)) m.end]);

// a long text is read only so far: rules look at an opener, not a novel
const _readUpTo = 4000;

// spaces and quotes made plain, the case kept for wallet addresses
String _plain(String text) {
  var t = text.trim();
  if (t.length > _readUpTo) t = t.substring(0, _readUpTo);
  return t
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll(RegExp(r'\s+'), ' ');
}

// what a stranger wrote, against the rules that are sure on their own
ShieldResult scanRequest(String text) {
  final cased = _plain(text);
  if (cased.isEmpty) return const ShieldResult([]);
  final t = cased.toLowerCase();
  final hits = <ShieldHit>[];
  if (_fakeSupport(t)) hits.add(const ShieldHit('fake_support'));
  if (_asksSecret(t)) hits.add(const ShieldHit('asks_secret'));
  for (final m in _host.allMatches(text)) {
    if (lookalikeHost(m.group(1)!)) {
      hits.add(const ShieldHit('lookalike_link'));
      break;
    }
  }
  if (_payRush(t, cased)) hits.add(const ShieldHit('pay_rush'));
  if (_profit.hasMatch(t)) hits.add(const ShieldHit('profit_promise'));
  return ShieldResult(hits);
}

// both checks on one request: who they say they are, and what they wrote
ShieldResult shieldCheck({
  required String strangerId,
  required String text,
  required Iterable<ShieldContact> contacts,
}) => ShieldResult([
  ...checkImpersonation(strangerId, contacts).hits,
  ...scanRequest(text).hits,
]);
