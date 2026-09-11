// SPDX-License-Identifier: GPL-3.0-or-later
// a wallet address in groups of four, so it can be checked against the
// wallet by eye before anything is sent. a 0x prefix stays on its own.
String chunkAddress(String addr) {
  var body = addr;
  var prefix = '';
  if (body.startsWith('0x')) {
    prefix = '0x ';
    body = body.substring(2);
  }
  final parts = <String>[];
  for (var i = 0; i < body.length; i += 4) {
    parts.add(body.substring(i, i + 4 > body.length ? body.length : i + 4));
  }
  return prefix + parts.join(' ');
}
