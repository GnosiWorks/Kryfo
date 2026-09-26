// SPDX-License-Identifier: GPL-3.0-or-later
// search: what the index keeps and what a query becomes, in every script
// kryfo speaks. the full-text engine itself runs on the phone.
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/search.dart';

void main() {
  test('folds case and accents in latin', () {
    expect(indexText('Café CRÈME à Hà Nội'), 'cafe creme a ha noi');
    // the sharp s and the russian yo as people type them
    expect(indexText('Straße'), 'strasse');
    expect(indexText('идём'), 'идем');
    // a keyboard that does not compose: e plus a combining acute
    expect(indexText('café'), 'cafe');
    expect(indexText('İstanbul'), 'istanbul');
  });

  test('folds arabic-script letter variants', () {
    // arabic kaf and yeh, persian keheh and farsi yeh
    expect(indexText('كتاب'), indexText('کتاب'));
    expect(indexText('علي'), indexText('علی'));
    // harakat and tatweel do not change the word
    expect(indexText('مُحَمَّد'), indexText('محمد'));
    expect(indexText('ســلام'), indexText('سلام'));
    // a zero-width non-joiner typed or not
    expect(indexText('می‌خواهم'), indexText('میخواهم'));
  });

  test('each chinese character is a token', () {
    expect(indexText('我们去吃饭'), ' 我  们  去  吃  饭 ');
    expect(indexText('去Kryfo吃饭'), ' 去 kryfo 吃  饭 ');
  });

  test('a query needs every term', () {
    expect(queryTerms('  Pizza   tonight '), ['pizza', 'tonight']);
    expect(queryTerms('吃饭'), ['吃饭']);
    expect(queryTerms('去Kryfo吃饭'), ['去', 'kryfo', '吃饭']);
    expect(queryTerms('...  ?? '), isEmpty);
    expect(queryTerms('،؟'), isEmpty);
  });

  test('builds a safe match expression', () {
    expect(ftsMatch('pizz'), '"pizz"*');
    expect(ftsMatch('Pizza tonight'), '"pizza"* "tonight"*');
    expect(ftsMatch('吃饭'), '"吃 饭"');
    expect(ftsMatch(''), isNull);
    expect(ftsMatch('   '), isNull);
    // match syntax typed as text stays text
    expect(ftsMatch('a OR b'), '"a"* "or"* "b"*');
    expect(ftsMatch('NEAR(x y)'), '"near x"* "y"*');
    expect(ftsMatch('say "hi"'), '"say"* "hi"*');
    expect(ftsMatch('-x'), '"x"*');
    expect(ftsMatch('col:val'), '"col val"*');
    expect(ftsMatch('e-mail'), '"e mail"*');
    // persian with and without the non-joiner: the same match
    expect(ftsMatch('می‌خواهم'), ftsMatch('میخواهم'));
  });

  test('highlights land on the original text', () {
    const t = 'Le café est prêt';
    final r = matchRanges(t, 'cafe pret');
    expect([for (final x in r) t.substring(x.$1, x.$2)], ['café', 'prêt']);
    // a combining mark rides with its letter
    const c = 'café au lait';
    final rc = matchRanges(c, 'cafe');
    expect(c.substring(rc.first.$1, rc.first.$2), 'cafe\u0301');
    // chinese
    const z = '我们今晚去吃饭吧';
    final rz = matchRanges(z, '吃饭');
    expect(z.substring(rz.first.$1, rz.first.$2), '吃饭');
    // persian typed with an arabic kaf
    const f = 'این کتاب خوب است';
    final rf = matchRanges(f, 'كتاب');
    expect(f.substring(rf.first.$1, rf.first.$2), 'کتاب');
    // overlapping terms merge
    expect(matchRanges('pizza', 'pi pizza'), [(0, 5)]);
    expect(matchRanges('', 'x'), isEmpty);
  });

  test('astral characters keep their place', () {
    const t = 'ok 𠀀 pizza';
    final r = matchRanges(t, 'pizza');
    expect(t.substring(r.first.$1, r.first.$2), 'pizza');
  });

  test('a snippet is cut around the first match', () {
    final long = '${'word ' * 60}pizza tonight ${'more ' * 40}';
    final r = matchRanges(long, 'pizza');
    final s = snippet(long, r);
    expect(s.text.startsWith('…'), isTrue);
    expect(s.text.endsWith('…'), isTrue);
    expect(s.text.substring(s.ranges.first.$1, s.ranges.first.$2), 'pizza');
    const short = 'pizza\ntonight';
    final ss = snippet(short, matchRanges(short, 'tonight'));
    expect(ss.text, 'pizza tonight');
    expect(
      ss.text.substring(ss.ranges.first.$1, ss.ranges.first.$2),
      'tonight',
    );
  });

  test('a sticker row has no words', () {
    expect(searchBody({'plaintext': '🔒', 'sticker': 'fokia:17:1'}), '');
    expect(
      searchBody({'plaintext': 'pizza tonight', 'sticker': 'fokia:17:1'}),
      '',
    );
    // a text row is found by its words, as before
    expect(
      searchBody({'plaintext': 'Pizza tonight', 'sticker': null}),
      indexText('Pizza tonight'),
    );
  });

  test('filters are plain sql on the message row', () {
    expect(kindWhere(SearchKind.all), '');
    expect(kindWhere(SearchKind.photos), contains('media_path'));
    expect(kindWhere(SearchKind.videos), contains("'%.mp4'"));
    expect(kindWhere(SearchKind.files), contains("!= 'voice.wav'"));
    expect(kindWhere(SearchKind.links), contains('preview'));
  });
}
