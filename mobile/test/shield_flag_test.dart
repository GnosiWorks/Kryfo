import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/scam_shield.dart';
import 'package:kryfo/screens/shield_sheet.dart';

void main() {
  test('a clean check is not a flag', () {
    final row = {'headline': '', 'lines': '[]', 'dismissed': 0};
    expect(ShieldFlag.cleanRow(row), isTrue);
    expect(ShieldFlag.fromRow(row), isNull);
  });
  test('a flagged row is a flag and not clean', () {
    final row = {
      'headline': 'looks like a scam',
      'lines': '["x"]',
      'dismissed': 0,
    };
    expect(ShieldFlag.cleanRow(row), isFalse);
    expect(ShieldFlag.fromRow(row)?.headline, 'looks like a scam');
  });
  test('a flag is stored as codes and worded when read', () {
    final r = shieldCheck(
      strangerId: 'alice',
      strangerAvatar: 3,
      firstMessage: 'hi',
      contacts: const [ShieldContact('alicf', avatar: 3)],
    );
    final row = {
      'headline': jsonEncode(r.lead!.toJson()),
      'lines': jsonEncode([for (final h in r.hits) h.toJson()]),
      'dismissed': 0,
    };
    expect(row['lines'], isNot(contains('matches')));
    final f = ShieldFlag.fromRow(row)!;
    expect(f.headline, 'This name matches alicf');
    expect(f.lines, [
      'Name matches your contact alicf',
      'same face as your contact alicf',
    ]);
  });
  test('a request filed on its own id says the name it gave', () {
    const hit = ShieldHit('other_key', 'amber-river-stone');
    final row = {
      'headline': jsonEncode(hit.toJson()),
      'lines': jsonEncode([hit.toJson()]),
      'dismissed': 0,
    };
    final f = ShieldFlag.fromRow(row)!;
    const said = 'Says it is amber-river-stone, but its key does not match';
    expect(f.headline, said);
    expect(f.lines, [said]);
  });
  test('nothing recorded is neither', () {
    expect(ShieldFlag.cleanRow(null), isFalse);
    expect(ShieldFlag.fromRow(null), isNull);
  });
}
