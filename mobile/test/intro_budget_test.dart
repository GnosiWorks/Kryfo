import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/intro_budget.dart';

// the budget is what caps introductions, so the window math is pinned here

const _day = 24 * 60 * 60 * 1000;

void main() {
  test('empty budget has all five', () {
    final b = IntroBudget(const []);
    expect(b.leftAt(0), 5);
    expect(b.canSendAt(0), true);
    expect(b.refillAt(0), null);
  });

  test('five inside the window spends it', () {
    final now = 100 * _day;
    final b = IntroBudget([for (var i = 0; i < 5; i++) now - i * _day]);
    expect(b.leftAt(now), 0);
    expect(b.canSendAt(now), false);
    // the oldest was 4 days ago, so it frees up 3 days from now
    expect(b.refillAt(now), now - 4 * _day + 7 * _day);
  });

  test('a send older than seven days drops out', () {
    final now = 100 * _day;
    final b = IntroBudget([
      now - 8 * _day,
      now - 7 * _day, // exactly the edge is out too
      now - 6 * _day,
    ]);
    expect(b.liveAt(now).length, 1);
    expect(b.leftAt(now), 4);
  });

  test('recording appends and prunes', () {
    final now = 100 * _day;
    final b = IntroBudget([now - 9 * _day, now - _day]).recordAt(now);
    expect(b.sent, [now - _day, now]);
    expect(b.leftAt(now), 3);
  });

  test('order on input does not matter', () {
    final now = 100 * _day;
    final b = IntroBudget([now - _day, now - 5 * _day, now - 3 * _day]);
    expect(b.sent.first, now - 5 * _day);
    final full = IntroBudget([
      now - _day,
      now - 5 * _day,
      now - 3 * _day,
      now - 2 * _day,
      now - 4 * _day,
    ]);
    expect(full.refillAt(now), now + 2 * _day);
  });

  test('round trips through prefs', () async {
    SharedPreferences.setMockInitialValues({});
    final now = 100 * _day;
    final b = IntroBudget([now - 8 * _day, now - _day]);
    await b.save(now);
    final back = await IntroBudget.load();
    // the stale one was pruned on save
    expect(back.sent, [now - _day]);
  });

  test('each container keeps its own count', () async {
    final now = 100 * _day;
    final spent = jsonEncode([for (var i = 0; i < 5; i++) now - i * _day]);
    SharedPreferences.setMockInitialValues({'kryfo.intro.sent': spent});
    expect((await IntroBudget.load()).leftAt(now), 0);
    final decoy = await IntroBudget.load(HaloContainer.decoy);
    expect(decoy.leftAt(now), 5);
    await decoy.recordAt(now).save(now, HaloContainer.decoy);
    expect((await IntroBudget.load(HaloContainer.decoy)).leftAt(now), 4);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('kryfo.intro.sent'), spent);
    expect(prefs.getString('d.kryfo.intro.sent'), jsonEncode([now]));
    // the sheet counts for the session it is open in
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      expect(src, isNot(contains('IntroBudget.load()')), reason: f.path);
      expect(src, isNot(contains('.save(_now)')), reason: f.path);
    }
  });

  test('garbage in prefs reads as empty', () async {
    SharedPreferences.setMockInitialValues({'kryfo.intro.sent': 'nope'});
    final back = await IntroBudget.load();
    expect(back.leftAt(0), 5);
  });

  test('refill phrase rounds up', () {
    expect(refillPhrase(const Duration(days: 2, hours: 3)), 'in 3 days');
    expect(refillPhrase(const Duration(hours: 25)), 'in 2 days');
    expect(refillPhrase(const Duration(hours: 24)), 'tomorrow');
    expect(refillPhrase(const Duration(hours: 5, minutes: 1)), 'in 6 hours');
    expect(refillPhrase(const Duration(minutes: 61)), 'in 2 hours');
    expect(refillPhrase(const Duration(minutes: 60)), 'in an hour');
    expect(refillPhrase(const Duration(minutes: 12)), 'in a few minutes');
  });
}
