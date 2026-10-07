// SPDX-License-Identifier: GPL-3.0-or-later
// the relay poll is a batch with its token and one json entry per event:
// the lane it came in on, what it carried, whatever that holds, and when
// the sender wrote it where the lane knows. an entry
// of another shape is passed over on its own and costs none of the others.
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/relay_poll.dart';

void main() {
  test('one entry per event, in order', () {
    final got = parseRelayPoll(
      '{"k":"3","m":[{"t":"firstcontact","c":"AAAA"},'
      '{"t":"room:ab:cd","c":"{\\"t\\":\\"a|b\\\\nc\\"}"}]}',
    );
    expect(got.token, '3');
    expect(got.msgs, [
      (peer: 'firstcontact', cipher: 'AAAA'),
      (peer: 'room:ab:cd', cipher: '{"t":"a|b\\nc"}'),
    ]);
    expect(got.places, [0, 1]);
  });

  test('an entry of another shape costs none of the others', () {
    final got = parseRelayPoll(
      '{"k":"1","m":[{"t":"a","c":"1"},{"t":2,"c":"x"},{"t":"b"},"c|d",null,'
      '{"t":"c","c":"3"}]}',
    );
    expect(got.msgs, [(peer: 'a', cipher: '1'), (peer: 'c', cipher: '3')]);
    expect(got.places, [0, 5]);
  });

  test('when each was written comes along, in ms, where the lane says', () {
    final got = parseRelayPoll(
      '{"k":"4","m":[{"t":"a","c":"1","a":1791381223},{"t":"b","c":"2"},'
      '{"t":2,"c":"x","a":5},{"t":"c","c":"3","a":"soon"},'
      '{"t":"d","c":"4","a":0}]}',
    );
    expect(got.msgs.map((m) => m.peer), ['a', 'b', 'c', 'd']);
    expect(got.written, [1791381223000, null, null, null]);
  });

  test('nothing, or something that is not a batch, is no events', () {
    for (final raw in [
      '',
      'a|b\nc|d',
      '{"t":"a","c":"b"}',
      '[{"t":"a","c":"1"}]',
      '{"k":1,"m":[]}',
    ]) {
      final got = parseRelayPoll(raw);
      expect(got.msgs, isEmpty, reason: raw);
      expect(got.token, isEmpty, reason: raw);
    }
  });
}
