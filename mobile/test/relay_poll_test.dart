// SPDX-License-Identifier: GPL-3.0-or-later
// the relay poll is one json entry per event: the lane it came in on and
// what it carried, whatever that holds. an entry of another shape is passed
// over on its own and costs none of the others.
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/relay_poll.dart';

void main() {
  test('one entry per event, in order', () {
    final got = parseRelayPoll(
      '[{"t":"firstcontact","c":"AAAA"},'
      '{"t":"room:ab:cd","c":"{\\"t\\":\\"a|b\\\\nc\\"}"}]',
    );
    expect(got, [
      (peer: 'firstcontact', cipher: 'AAAA'),
      (peer: 'room:ab:cd', cipher: '{"t":"a|b\\nc"}'),
    ]);
  });

  test('an entry of another shape costs none of the others', () {
    final got = parseRelayPoll(
      '[{"t":"a","c":"1"},{"t":2,"c":"x"},{"t":"b"},"c|d",null,'
      '{"t":"c","c":"3"}]',
    );
    expect(got, [(peer: 'a', cipher: '1'), (peer: 'c', cipher: '3')]);
  });

  test('what the engine escapes comes back as it was sent', () {
    final got = parseRelayPoll(
      '[{"t":"room:ab:cd","c":"\\u003cb\\u003e \\u0026 \\u2028 é"}]',
    );
    expect(got, [(peer: 'room:ab:cd', cipher: '<b> &   é')]);
  });

  test('nothing, or something that is not a list, is no events', () {
    expect(parseRelayPoll(''), isEmpty);
    expect(parseRelayPoll('a|b\nc|d'), isEmpty);
    expect(parseRelayPoll('{"t":"a","c":"b"}'), isEmpty);
  });
}
