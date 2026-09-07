import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/mentions.dart';

void main() {
  group('mentionQuery', () {
    test('reads the partial at the cursor', () {
      expect(mentionQuery('hey @mar', 8), 'mar');
      expect(mentionQuery('@', 1), '');
    });
    test('ignores an @ inside a word or behind a space', () {
      expect(mentionQuery('mail me@x', 9), isNull);
      expect(mentionQuery('hey @mar ok', 11), isNull);
      expect(mentionQuery('plain', 5), isNull);
    });
  });

  test('insertMention replaces the partial and moves the cursor', () {
    final r = insertMention('hey @ma there', 7, 'neon-tiger-saturn');
    expect(r.text, 'hey @neon-tiger-saturn  there');
    expect(r.cursor, 'hey @neon-tiger-saturn '.length);
  });

  test('mentionMatches prefers names, then ids', () {
    final members = [
      (id: 'neon-tiger-saturn', name: 'marina'),
      (id: 'mango-oak-river', name: null),
      (id: 'zinc-wolf-lane', name: 'tomas'),
    ];
    final r = mentionMatches('ma', members, (m) => m.id, (m) => m.name);
    expect(r.map((m) => m.id), ['neon-tiger-saturn', 'mango-oak-river']);
  });

  test('mentionsMe matches the whole id only', () {
    expect(
      mentionsMe('@neon-tiger-saturn can you?', 'neon-tiger-saturn'),
      isTrue,
    );
    expect(mentionsMe('@neon-tiger-saturnx', 'neon-tiger-saturn'), isFalse);
    expect(mentionsMe('neon-tiger-saturn', 'neon-tiger-saturn'), isFalse);
  });
}
