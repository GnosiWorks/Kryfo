// SPDX-License-Identifier: GPL-3.0-or-later
// polls in groups and rooms. a poll is an ordinary group message: its text
// is the question, and it carries the options. a vote is a small frame, like
// a reaction, sent to every member through the same pairwise sessions. no
// server keeps a count; every phone adds up the votes it has.
//
// a vote names the poll, the choices, and a number that only goes up for
// that voter. the highest number a phone has seen from a voter is their
// vote. that one rule covers a vote that arrives twice (same number, no
// change), votes that arrive out of order (an older one never overwrites a
// newer one) and a member who was offline (everything arrives, the last
// word wins). when the creator closes the poll, the close carries the votes
// as the creator had them, and every phone takes that as the final count,
// so a closed poll reads the same everywhere.
import 'dart:convert';

const kPollMinOptions = 2;
const kPollMaxOptions = 12;
const kPollMaxQuestion = 300;
const kPollMaxOption = 100;

/// the seq the final votes of a closed poll are held at: above any vote a
/// phone can send (a millisecond clock), so nothing late moves them
const kPollFinalSeq = 1 << 52;

class PollSpec {
  final List<String> options;
  final bool multi;
  final bool closed;
  const PollSpec({
    required this.options,
    this.multi = false,
    this.closed = false,
  });

  PollSpec closedNow() =>
      PollSpec(options: options, multi: multi, closed: true);

  /// what rides in the message and sits in the row
  Map<String, Object> toWire() => {'o': options, if (multi) 'mu': 1};

  String toRow() =>
      jsonEncode({'o': options, if (multi) 'mu': 1, if (closed) 'cl': 1});

  /// a poll from the wire or a row. null when it is not one we would draw:
  /// too few or too many options, or options that are empty or too long.
  static PollSpec? parse(Object? raw) {
    Object? j = raw;
    if (raw is String) {
      try {
        j = jsonDecode(raw);
      } catch (_) {
        return null;
      }
    }
    if (j is! Map) return null;
    final o = j['o'];
    if (o is! List) return null;
    final opts = <String>[];
    for (final e in o) {
      if (e is! String) return null;
      final t = e.trim();
      if (t.isEmpty || t.length > kPollMaxOption) return null;
      opts.add(t);
    }
    if (opts.length < kPollMinOptions || opts.length > kPollMaxOptions) {
      return null;
    }
    return PollSpec(
      options: opts,
      multi: j['mu'] == 1 || j['mu'] == true,
      closed: j['cl'] == 1 || j['cl'] == true,
    );
  }
}

/// the draft from the new-poll sheet, tidied: trimmed, empty options gone,
/// the same option twice kept once. null while it cannot be sent.
({String question, List<String> options})? tidyDraft(
  String question,
  List<String> options,
) {
  final q = question.trim();
  if (q.isEmpty || q.length > kPollMaxQuestion) return null;
  final seen = <String>{};
  final out = <String>[];
  for (final o in options) {
    final t = o.trim();
    if (t.isEmpty) continue;
    if (t.length > kPollMaxOption) return null;
    if (seen.add(t.toLowerCase())) out.add(t);
  }
  if (out.length < kPollMinOptions || out.length > kPollMaxOptions) {
    return null;
  }
  return (question: q, options: out);
}

/// choices as a phone keeps them: in range, each once, in order, and at
/// most one on a single-answer poll. anything else in a frame is dropped.
List<int> cleanChoices(Iterable<Object?> raw, PollSpec poll) {
  final out = <int>{};
  for (final c in raw) {
    if (c is! int) continue;
    if (c < 0 || c >= poll.options.length) continue;
    out.add(c);
  }
  final sorted = out.toList()..sort();
  if (!poll.multi && sorted.length > 1) return [sorted.first];
  return sorted;
}

/// a vote as a phone holds it
class PollVote {
  final List<int> choices;
  final int seq;
  const PollVote(this.choices, this.seq);
}

/// whether a vote with [incoming] replaces what is held. equal is a
/// duplicate, lower is an old vote arriving late.
bool voteIsNewer(int? held, int incoming) => held == null || incoming > held;

/// the number the next vote of this phone carries: past anything it sent
/// before on this poll, and past the clock, so a reinstall that forgot its
/// last number still moves forward.
int nextVoteSeq(int? last, int nowMs) =>
    last == null || nowMs > last ? nowMs : last + 1;

class PollTally {
  /// how many voters picked each option
  final List<int> counts;

  /// voters with at least one choice
  final int voters;

  /// what this phone's owner picked
  final List<int> mine;

  /// who picked each option, in the order they are held
  final List<List<String>> who;
  const PollTally(this.counts, this.voters, this.mine, this.who);

  /// share of voters, 0..1. on a several-answers poll the shares add up to
  /// more than one, as they do everywhere else.
  double share(int i) => voters == 0 ? 0 : counts[i] / voters;

  /// the options with the most votes, when there are votes at all
  Set<int> get leaders {
    final top = counts.fold<int>(0, (a, b) => a > b ? a : b);
    if (top == 0) return const {};
    return {
      for (var i = 0; i < counts.length; i++)
        if (counts[i] == top) i,
    };
  }
}

PollTally tallyPoll(PollSpec poll, Map<String, PollVote> votes, String me) {
  final counts = List<int>.filled(poll.options.length, 0);
  final who = List.generate(poll.options.length, (_) => <String>[]);
  var voters = 0;
  var mine = const <int>[];
  for (final e in votes.entries) {
    final picks = cleanChoices(e.value.choices, poll);
    if (picks.isEmpty) continue;
    voters++;
    for (final c in picks) {
      counts[c]++;
      who[c].add(e.key);
    }
    if (e.key == me) mine = picks;
  }
  return PollTally(counts, voters, mine, who);
}

/// the close frame's final votes, as a phone takes them: choices cleaned
/// against the poll, voters with nothing left out
Map<String, List<int>> cleanFinal(Object? raw, PollSpec poll) {
  final out = <String, List<int>>{};
  if (raw is! Map) return out;
  for (final e in raw.entries) {
    final k = e.key;
    final v = e.value;
    if (k is! String || k.isEmpty || v is! List) continue;
    final picks = cleanChoices(v, poll);
    if (picks.isNotEmpty) out[k] = picks;
  }
  return out;
}

/// what happens to a vote that just arrived
enum VoteFate {
  /// the poll is here and open: the vote counts if it is newer
  count,

  /// the poll has not arrived yet: the vote waits for it
  hold,

  /// not a member, another chat's poll, a closed poll, or a poll that went
  drop,
}

VoteFate voteFate({
  required bool member,
  required bool pollHere,
  required bool pollGone,
  bool sameChat = true,
  bool closed = false,
}) {
  if (!member) return VoteFate.drop;
  if (!pollHere) return pollGone ? VoteFate.drop : VoteFate.hold;
  if (!sameChat || closed) return VoteFate.drop;
  return VoteFate.count;
}

/// a close is taken only from the poll's creator, once, in its own chat
bool closeAccepted({
  required bool pollHere,
  required bool fromCreator,
  bool sameChat = true,
  bool closed = false,
}) => pollHere && fromCreator && sameChat && !closed;
