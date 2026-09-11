import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/address_text.dart';

void main() {
  test('groups of four, remainder at the end', () {
    expect(chunkAddress('bc1qdewmhrwk'), 'bc1q dewm hrwk');
    expect(chunkAddress('bc1qdewmh'), 'bc1q dewm h');
  });
  test('0x prefix stays on its own', () {
    expect(chunkAddress('0x55014AF7'), '0x 5501 4AF7');
  });
  test('nothing lost', () {
    const a = '4ApyZS72ZYCG3z8rtwwX6JgdjSdAcphHSFRxiKrL5yLnYYz8';
    expect(chunkAddress(a).replaceAll(' ', ''), a);
  });
}
