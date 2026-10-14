// SPDX-License-Identifier: GPL-3.0-or-later
// a share sheet answers how it ended: an app picked, closed with none, or
// never open. only a pick counts as shared. the platform is a stand-in
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/open_file.dart';
import 'package:kryfo/tools/tools_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answer(String channel, String method, Object? Function() reply) =>
      m.setMockMethodCallHandler(MethodChannel(channel), (call) async {
        if (call.method != method) return null;
        return reply();
      });

  // a tool's share waits for the lock to be down
  setUp(lockState.openForTest);

  tearDown(() {
    m.setMockMethodCallHandler(const MethodChannel('halo/platform'), null);
    m.setMockMethodCallHandler(const MethodChannel('halo/tools'), null);
  });

  test('the answers read as they are meant', () {
    expect(shareEndOf('picked'), ShareEnd.picked);
    expect(shareEndOf('closed'), ShareEnd.closed);
    expect(shareEndOf('failed'), ShareEnd.failed);
    // an older side's yes is not a pick
    expect(shareEndOf(true), ShareEnd.failed);
    expect(shareEndOf(null), ShareEnd.failed);
  });

  for (final (said, end) in [
    ('picked', ShareEnd.picked),
    ('closed', ShareEnd.closed),
    ('failed', ShareEnd.failed),
  ]) {
    test('a file shared from a chat or a backup: $said', () async {
      answer('halo/platform', 'shareFile', () => said);
      expect(await shareFileOut('/x', name: 'a.txt'), end);
    });

    test('a tool\'s result shared: $said', () async {
      answer('halo/tools', 'shareOut', () => said);
      expect(await ToolsBridge.instance.shareOut('/x', 'image/png'), end);
    });
  }

  test('a side that throws is a sheet that never opened', () async {
    answer(
      'halo/platform',
      'shareFile',
      () => throw PlatformException(code: 'x'),
    );
    expect(await shareFileOut('/x'), ShareEnd.failed);
    answer('halo/tools', 'shareOut', () => throw PlatformException(code: 'x'));
    expect(await ToolsBridge.instance.shareOut('/x', 'a/b'), ShareEnd.failed);
  });
}
