// SPDX-License-Identifier: GPL-3.0-or-later
// no language promises what the decoy and the wipe pin cannot keep: nothing
// here is undetectable, invisible, deniable or safe from anyone. each
// language's own words for those, checked in every string it has.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _banned = {
  'en': [
    'undetectable',
    'invisible',
    'plausible deniability',
    'safe from anyone',
    'untraceable',
  ],
  'de': [
    'unsichtbar',
    'unauffindbar',
    'nicht nachweisbar',
    'abstreitbarkeit',
    'vor jedem sicher',
  ],
  'es': [
    'indetectable',
    'invisible',
    'negación plausible',
    'a salvo de cualquiera',
  ],
  'fr': [
    'indétectable',
    'invisible',
    'déni plausible',
    'à l’abri de tous',
    "à l'abri de tous",
  ],
  'it': [
    'invisibile',
    'non rilevabile',
    'negazione plausibile',
    'al sicuro da chiunque',
  ],
  'pt': [
    'indetectável',
    'invisível',
    'negação plausível',
    'a salvo de qualquer',
  ],
  'ru': ['невидим', 'необнаружим', 'правдоподобное отрицание'],
  'uk': ['невидим', 'невиявлен', 'правдоподібне заперечення'],
  'tr': ['görünmez', 'tespit edilemez', 'makul inkâr', 'makul inkar'],
  'id': [
    'tak terlihat',
    'tidak terlihat',
    'tak terdeteksi',
    'tidak terdeteksi',
    'penyangkalan yang masuk akal',
  ],
  'vi': ['vô hình', 'không thể phát hiện', 'phủ nhận hợp lý'],
  'zh': ['隐形', '无法检测', '不可察觉', '合理推诿'],
  'zh_Hant': ['隱形', '無法偵測', '不可察覺', '合理推諉'],
  'ar': ['غير مرئي', 'لا يمكن اكتشاف', 'الإنكار المعقول'],
  'fa': ['نامرئی', 'غیرقابل شناسایی', 'انکار موجه'],
};

void main() {
  for (final e in _banned.entries) {
    test('${e.key} promises nothing the app cannot keep', () {
      final arb =
          jsonDecode(File('lib/l10n/app_${e.key}.arb').readAsStringSync())
              as Map<String, dynamic>;
      final bad = <String>[];
      for (final kv in arb.entries) {
        if (kv.key.startsWith('@') || kv.value is! String) continue;
        final v = (kv.value as String).toLowerCase();
        for (final w in e.value) {
          if (v.contains(w)) bad.add('${kv.key}: $w');
        }
      }
      expect(bad, isEmpty);
    });
  }

  test('every language has a list', () {
    final locales = Directory('lib/l10n')
        .listSync()
        .map((f) => f.path.split('/').last)
        .where((n) => n.startsWith('app_') && n.endsWith('.arb'))
        .map((n) => n.substring(4, n.length - 4))
        .toSet();
    expect(locales, _banned.keys.toSet());
  });
}
