// SPDX-License-Identifier: GPL-3.0-or-later
// a sealed text waits for a route before it leaves, and one taken back
// while it waited never does

// what a send says when its message was taken back before it left
const kTextTakenBack = 'cancelled';

Future<String> wireWhenReady({
  required bool Function() ready,
  required Future<bool> Function() kept,
  required Future<String> Function() send,
  Duration step = const Duration(milliseconds: 400),
  Duration patience = const Duration(minutes: 5),
}) async {
  var waited = Duration.zero;
  while (!ready() && waited < patience) {
    await Future<void>.delayed(step);
    waited += step;
  }
  if (!ready()) return 'error: tor not ready';
  if (!await kept()) return kTextTakenBack;
  return send();
}
