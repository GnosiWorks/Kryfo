// SPDX-License-Identifier: GPL-3.0-or-later
// the helper app's name for each of the sixteen registrations says its slot
// and nothing about who it serves
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/helper_push.dart';
import 'package:kryfo/helper_slots.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each slot has its own short name, and a renewal keeps it', () {
    final names = [
      for (var s = 0; s < kHelperSlots; s++) slotLabel(slotInstance(s)),
    ];
    expect(names.first, 'Kryfo 1/16');
    expect(names.last, 'Kryfo 16/16');
    expect(names.toSet(), hasLength(kHelperSlots));
    expect(slotLabel(slotInstance(4, 7)), slotLabel(slotInstance(4)));
    for (final n in names) {
      expect(n.length, lessThanOrEqualTo(12));
    }
  });

  test('a name that is not one of ours reads as plain Kryfo', () {
    expect(slotLabel('kryfo-16.0'), 'Kryfo');
    expect(slotLabel('someone-else'), 'Kryfo');
  });

  test('every registration asks for its slot name', () async {
    const ch = MethodChannel('test/helper_label');
    final calls = <Map<Object?, Object?>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, (c) async {
          if (c.method == 'helperRegister') {
            calls.add(c.arguments as Map<Object?, Object?>);
          }
          return true;
        });
    final push = HelperPush(ch);
    final n = await push.register('io.heckel.ntfy', [
      for (var s = 0; s < kHelperSlots; s++) slotInstance(s, 2),
    ]);
    expect(n, kHelperSlots);
    expect(calls, hasLength(kHelperSlots));
    expect(calls[2], {
      'package': 'io.heckel.ntfy',
      'instance': 'kryfo-2.2',
      'label': 'Kryfo 3/16',
    });
  });
}
