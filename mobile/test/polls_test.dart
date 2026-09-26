// SPDX-License-Identifier: GPL-3.0-or-later
// polls: the rules every phone applies to the votes it gets. the small book
// below keeps votes the way the database does.
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/polls.dart';

const lunch = PollSpec(options: ['pizza', 'noodles', 'salad']);
const toppings = PollSpec(options: ['olives', 'basil', 'chili'], multi: true);

// the store's rules, the same functions the app calls
class Book {
  final PollSpec poll;
  final Map<String, PollVote> votes = {};
  bool closed = false;
  Book(this.poll);

  bool vote(String voter, List<Object?> choices, int seq) {
    if (closed) return false;
    if (!voteIsNewer(votes[voter]?.seq, seq)) return false;
    votes[voter] = PollVote(cleanChoices(choices, poll), seq);
    return true;
  }

  void close(Object? finals) {
    final f = cleanFinal(finals, poll);
    votes
      ..clear()
      ..addAll({
        for (final e in f.entries) e.key: PollVote(e.value, kPollFinalSeq),
      });
    closed = true;
  }

  PollTally tally(String me) => tallyPoll(poll, votes, me);
}

void main() {
  test('a vote counts and shows as mine', () {
    final b = Book(lunch);
    expect(b.vote('ana', [0], 100), isTrue);
    expect(b.vote('ben', [1], 100), isTrue);
    final t = b.tally('ana');
    expect(t.counts, [1, 1, 0]);
    expect(t.voters, 2);
    expect(t.mine, [0]);
    expect(t.share(0), 0.5);
    expect(t.who[1], ['ben']);
  });

  test('a changed vote replaces the old one', () {
    final b = Book(lunch);
    b.vote('ana', [0], 100);
    b.vote('ana', [2], 200);
    final t = b.tally('ana');
    expect(t.counts, [0, 0, 1]);
    expect(t.voters, 1);
    expect(t.mine, [2]);
  });

  test('the same vote twice is counted once', () {
    final b = Book(lunch);
    expect(b.vote('ana', [1], 100), isTrue);
    expect(b.vote('ana', [1], 100), isFalse);
    expect(b.tally('x').counts, [0, 1, 0]);
  });

  test('the newest vote wins in any order', () {
    final b = Book(lunch);
    // ana voted pizza, then noodles, then salad; they arrive shuffled
    b.vote('ana', [2], 300);
    b.vote('ana', [0], 100);
    b.vote('ana', [1], 200);
    expect(b.tally('ana').mine, [2]);
    expect(b.tally('x').voters, 1);
  });

  test('a vote taken back leaves no voter behind', () {
    final b = Book(lunch);
    b.vote('ana', [0], 100);
    b.vote('ana', [], 200);
    final t = b.tally('ana');
    expect(t.voters, 0);
    expect(t.mine, isEmpty);
    expect(t.counts, [0, 0, 0]);
    expect(t.leaders, isEmpty);
  });

  test('multi-answer shares add up past one', () {
    final b = Book(toppings);
    b.vote('ana', [0, 2], 100);
    b.vote('ben', [2], 100);
    final t = b.tally('ben');
    expect(t.counts, [1, 0, 2]);
    expect(t.voters, 2);
    expect(t.share(2), 1.0);
    expect(t.leaders, {2});
  });

  test('a single-answer poll keeps one choice', () {
    expect(cleanChoices([2, 0, 1], lunch), [0]);
    expect(cleanChoices([5, -1, 'x', 1, 1], lunch), [1]);
    expect(cleanChoices([2, 0, 2], toppings), [0, 2]);
  });

  test('the creator\'s close sets the final count', () {
    // this phone had a vote the creator never got
    final here = Book(lunch)
      ..vote('ana', [0], 100)
      ..vote('ben', [1], 100)
      ..vote('cy', [1], 100);
    here.close({
      'ana': [0],
      'ben': [1],
    });
    final t = here.tally('x');
    expect(t.counts, [1, 1, 0]);
    expect(t.voters, 2);
    expect(t.leaders, {0, 1});
    // nothing moves a closed poll, not even a vote newer than the close
    expect(here.vote('cy', [2], 1 << 60), isFalse);
    expect(here.tally('x').counts, [1, 1, 0]);
  });

  test('a close keeps only valid votes', () {
    final f = cleanFinal({
      'ana': [0],
      'ben': [9],
      '': [1],
      'cy': 'x',
      'dee': [2, 1],
    }, lunch);
    expect(f, {
      'ana': [0],
      'dee': [1],
    });
  });

  test('a vote counts, waits or drops', () {
    expect(
      voteFate(member: true, pollHere: true, pollGone: false),
      VoteFate.count,
    );
    // a vote can overtake its poll: it waits
    expect(
      voteFate(member: true, pollHere: false, pollGone: false),
      VoteFate.hold,
    );
    // the poll burned or was deleted: the vote is dropped
    expect(
      voteFate(member: true, pollHere: false, pollGone: true),
      VoteFate.drop,
    );
    expect(
      voteFate(member: false, pollHere: true, pollGone: false),
      VoteFate.drop,
    );
    expect(
      voteFate(member: true, pollHere: true, pollGone: false, closed: true),
      VoteFate.drop,
    );
    expect(
      voteFate(member: true, pollHere: true, pollGone: false, sameChat: false),
      VoteFate.drop,
    );
  });

  test('only the creator closes, once', () {
    expect(closeAccepted(pollHere: true, fromCreator: true), isTrue);
    expect(closeAccepted(pollHere: true, fromCreator: false), isFalse);
    expect(closeAccepted(pollHere: false, fromCreator: true), isFalse);
    expect(
      closeAccepted(pollHere: true, fromCreator: true, closed: true),
      isFalse,
    );
    expect(
      closeAccepted(pollHere: true, fromCreator: true, sameChat: false),
      isFalse,
    );
  });

  test('a phone\'s own seq always moves forward', () {
    expect(nextVoteSeq(null, 1000), 1000);
    expect(nextVoteSeq(900, 1000), 1000);
    // a clock that went back still gives a newer vote
    expect(nextVoteSeq(5000, 1000), 5001);
    expect(kPollFinalSeq > DateTime(2200).millisecondsSinceEpoch, isTrue);
  });

  test('parses only polls we would draw', () {
    expect(
      PollSpec.parse({
        'o': ['a', 'b'],
      })?.options,
      ['a', 'b'],
    );
    expect(
      PollSpec.parse({
        'o': ['a'],
      }),
      isNull,
    );
    expect(PollSpec.parse({'o': List.filled(13, 'x')}), isNull);
    expect(
      PollSpec.parse({
        'o': ['a', ''],
      }),
      isNull,
    );
    expect(
      PollSpec.parse({
        'o': ['a', 'x' * 101],
      }),
      isNull,
    );
    expect(
      PollSpec.parse({
        'o': ['a', 2],
      }),
      isNull,
    );
    expect(PollSpec.parse('not json'), isNull);
    final p = PollSpec.parse({
      'o': ['a', 'b'],
      'mu': 1,
    })!;
    expect(p.multi, isTrue);
    expect(p.closed, isFalse);
    // the row keeps closed, the wire never sends it
    final row = PollSpec.parse(p.closedNow().toRow())!;
    expect(row.closed, isTrue);
    expect(p.toWire().containsKey('cl'), isFalse);
  });

  test('tidies a draft before sending', () {
    final d = tidyDraft('  Lunch?  ', [' pizza ', '', 'Pizza', 'noodles', ' ']);
    expect(d?.question, 'Lunch?');
    expect(d?.options, ['pizza', 'noodles']);
    expect(tidyDraft('', ['a', 'b']), isNull);
    expect(tidyDraft('q', ['a', 'A']), isNull);
    expect(tidyDraft('q', List.generate(13, (i) => 'o$i')), isNull);
    expect(tidyDraft('q', List.generate(12, (i) => 'o$i'))?.options.length, 12);
  });
}
