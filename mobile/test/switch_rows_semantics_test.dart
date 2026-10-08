// SPDX-License-Identifier: GPL-3.0-or-later
// every switch outside the settings rows, with a screen reader: one node
// named by its row's title and line, on or off, and a tap on it flips it.
// no bare switch beside it
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart' show AppState, HaloEngine, useEngineForTest;
import 'package:kryfo/rooms.dart' show roomDefaultCap;
import 'package:kryfo/screens/bridges_screen.dart';
import 'package:kryfo/screens/getting_messages_screen.dart';
import 'package:kryfo/screens/lock_file_screen.dart';
import 'package:kryfo/screens/pins_screen.dart';
import 'package:kryfo/screens/room_create_sheet.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/tools/lock_words.dart' show neutralLockedName;
import 'package:kryfo/tools/tools_bridge.dart' show PickedFile;
import 'package:kryfo/widgets/new_poll_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart' show FakeHost, MemEngine, MemStore, StillClock;

// a phone with a finger set up
class _Bio implements LockBio {
  @override
  Future<bool> ready() async => true;
  @override
  Future<String> state() async => 'ok';
  @override
  Future<bool> enable() async => true;
  @override
  Future<void> disable() async {}
  @override
  Future<String> unlock(String title, String cancel) async => 'none';
}

class _Engine implements HaloEngine {
  @override
  String bridgeState() => 'false|0|0';
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

const _file = PickedFile(
  uri: 'content://test/thing.bin',
  name: 'thing.bin',
  size: 4321,
  mime: 'application/octet-stream',
);

// a page with one button that opens what is asked for
Widget _app(void Function(BuildContext) open) => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: Builder(
    builder: (ctx) => Scaffold(
      body: Center(
        child: TextButton(onPressed: () => open(ctx), child: const Text('go')),
      ),
    ),
  ),
);

Widget _page(Widget w) => _app(
  (ctx) => Navigator.of(ctx).push(MaterialPageRoute<void>(builder: (_) => w)),
);

Future<void> _rest(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await t.pump(const Duration(milliseconds: 500));
  }
}

Future<void> _open(WidgetTester t, Widget app) async {
  await t.pumpWidget(app);
  await t.tap(find.text('go'));
  await _rest(t);
}

// the switches a screen reader lands on: merged nodes read as their parent
List<SemanticsNode> _toggles(WidgetTester t) {
  final out = <SemanticsNode>[];
  bool visit(SemanticsNode n) {
    if (n.isMergedIntoParent) return true;
    if (_on(n) != Tristate.none) out.add(n);
    n.visitChildren(visit);
    return true;
  }

  visit(t.binding.renderViews.first.debugSemantics!);
  return out;
}

Tristate _on(SemanticsNode n) => n.getSemanticsData().flagsCollection.isToggled;

String _said(SemanticsNode n) => n.getSemanticsData().label;

// the row reads as one switch with its title and line, and a screen
// reader's tap flips it. after: the line it reads once flipped
Future<void> _flips(
  WidgetTester t,
  String title, {
  String? line,
  String? after,
}) async {
  SemanticsNode node() {
    final all = _toggles(t);
    for (final n in all) {
      expect(_said(n), isNotEmpty, reason: 'a switch with no name');
    }
    final mine = all.where((n) => _said(n).startsWith(title)).toList();
    expect(mine, hasLength(1), reason: title);
    return mine.single;
  }

  var n = node();
  final was = _on(n) == Tristate.isTrue;
  expect(
    n,
    isSemantics(
      hasToggledState: true,
      isToggled: was,
      hasEnabledState: true,
      isEnabled: true,
      hasTapAction: true,
    ),
  );
  if (line != null) expect(_said(n), contains(line));
  // the row's bounds, not the pill's
  expect(n.rect.width, greaterThan(120));

  t.semantics.tap(
    find.semantics.byPredicate(
      (s) =>
          !s.isMergedIntoParent &&
          _said(s).startsWith(title) &&
          _on(s) != Tristate.none,
    ),
  );
  await _rest(t);
  n = node();
  expect(n, isSemantics(hasToggledState: true, isToggled: !was), reason: title);
  if (after != null) expect(_said(n), contains(after));
}

void main() {
  late Directory docs;
  late SemanticsHandle sem;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    docs = Directory.systemTemp.createTempSync('switches');
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    m.setMockMethodCallHandler(SystemChannels.textInput, (_) async => null);
    m.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => docs.path,
    );
    m.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/local_auth'),
      (call) async => switch (call.method) {
        'getAvailableBiometrics' => ['fingerprint'],
        'isDeviceSupported' => true,
        _ => null,
      },
    );
  });

  tearDown(() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final c in [
      SystemChannels.platform,
      SystemChannels.textInput,
      const MethodChannel('plugins.flutter.io/path_provider'),
      const MethodChannel('plugins.flutter.io/local_auth'),
    ]) {
      m.setMockMethodCallHandler(c, null);
    }
    docs.deleteSync(recursive: true);
  });

  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(1800, 9000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    sem = t.ensureSemantics();
  }

  Future<void> done(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
    sem.dispose();
  }

  testWidgets('new poll: more than one answer', (t) async {
    phone(t);
    await _open(t, _app((ctx) => showNewPollSheet(ctx)));
    await _flips(t, l10n.pollMultiple, line: l10n.pollMultipleLine);
    await done(t);
  });

  testWidgets('getting messages: hide message preview', (t) async {
    phone(t);
    await _open(t, _page(const GettingMessagesScreen()));
    await _flips(
      t,
      l10n.gettingMessagesHideMessagePreview,
      line: l10n.gettingMessagesAGenericAlertWith,
    );
    await done(t);
  });

  testWidgets('lock a file: hide the file name', (t) async {
    phone(t);
    await _open(t, _page(const LockFileScreen(file: _file)));
    await _flips(
      t,
      l10n.lockFileHideTheFileName,
      line: l10n.lockFileTheNameAloneCan,
      after: l10n.lockFileItWillBeCalled(neutralLockedName),
    );
    await done(t);
  });

  testWidgets('new room: member cap', (t) async {
    phone(t);
    await _open(t, _app((ctx) => showRoomCreateSheet(ctx)));
    await _flips(
      t,
      l10n.roomCreateMemberCap,
      line: l10n.roomCreateOffUpTo(AppState.kGroupMemberCap),
      after: l10n.roomCreateNoOnePastThe(roomDefaultCap),
    );
    await done(t);
  });

  testWidgets('app lock: unlock with fingerprint', (t) async {
    phone(t);
    final store = MemStore()..m['halo.lock.enabled'] = 'true';
    final lock = LockState(
      store: store,
      engine: MemEngine(),
      clock: StillClock(),
      bio: _Bio(),
      revealAfter: Duration.zero,
    );
    await lock.load();
    expect(lock.bioSupported, isTrue);
    await _open(
      t,
      _page(
        PinsScreen(
          lock: lock,
          host: FakeHost(lock: lock),
        ),
      ),
    );
    await _flips(t, l10n.pinsUnlockWithFingerprint);
    expect(lock.biometricShown, isTrue);
    await done(t);
  });

  testWidgets('bridges: use bridges', (t) async {
    phone(t);
    useEngineForTest(_Engine());
    await _open(t, _page(const BridgesScreen()));
    await _flips(t, l10n.bridgesUseBridges, line: l10n.bridgesNoLinesYet);
    await done(t);
  });

  test('every switch outside the rows is covered here', () {
    // a new one needs its row merged and a case above
    final uses = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('halo_switch.dart')) continue;
      if (f.readAsStringSync().contains('HaloSwitch(')) {
        uses.add(f.uri.pathSegments.last);
      }
    }
    expect(uses..sort(), [
      'bridges_screen.dart',
      'getting_messages_screen.dart',
      'halo_rows.dart',
      'handle_screen.dart',
      'lock_file_screen.dart',
      'new_poll_sheet.dart',
      'pins_screen.dart',
      'room_create_sheet.dart',
    ]);
  });
}
