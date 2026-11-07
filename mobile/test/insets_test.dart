// SPDX-License-Identifier: GPL-3.0-or-later
// the app's pages, home and its tabs, the tools and the sheets on a phone
// with a cutout, a gesture or button bar and a keyboard, upright and on its
// side: nothing drawn under them, and a sheet sits as far above the
// keyboard as above the bar, never both
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/app_shell.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        HaloEngine,
        appState,
        useDatabasesForTest,
        useEngineForTest,
        AppStateRoute;
import 'package:kryfo/container.dart';
import 'package:kryfo/file_kind.dart';
import 'package:kryfo/gifs/gif_opt_in.dart';
import 'package:kryfo/rooms.dart' show RoomLink;
import 'package:kryfo/screens/appearance_screen.dart';
import 'package:kryfo/screens/auto_get_screen.dart';
import 'package:kryfo/screens/bridge_share_sheet.dart';
import 'package:kryfo/screens/bridge_sheets.dart';
import 'package:kryfo/screens/fast_servers_screen.dart';
import 'package:kryfo/screens/helper_sheet.dart';
import 'package:kryfo/screens/linked_devices_screen.dart';
import 'package:kryfo/screens/notes_export_screen.dart';
import 'package:kryfo/screens/pin_flow_screen.dart';
import 'package:kryfo/screens/pins_screen.dart';
import 'package:kryfo/screens/room_link_sheet.dart';
import 'package:kryfo/screens/room_preview_sheet.dart';
import 'package:kryfo/screens/tip_screen.dart';
import 'package:kryfo/screens/update_pins_screen.dart';
import 'package:kryfo/screens/wallpaper_sheet.dart';
import 'package:kryfo/atmosphere.dart' show Atmo;
import 'package:kryfo/stickers/sticker_recents.dart';
import 'package:kryfo/stickers/sticker_sheet.dart';
import 'package:kryfo/widgets/attach_grid.dart';
import 'package:kryfo/widgets/file_sheet.dart';
import 'package:kryfo/widgets/photo_sheet.dart';
import 'package:kryfo/screens/archived_screen.dart';
import 'package:kryfo/screens/backup_screen.dart';
import 'package:kryfo/screens/blocked_screen.dart';
import 'package:kryfo/screens/bridges_screen.dart';
import 'package:kryfo/screens/clean_screen.dart';
import 'package:kryfo/screens/contact_screen.dart' show showRenameSheet;
import 'package:kryfo/screens/donate_screen.dart';
import 'package:kryfo/screens/notifications_screen.dart';
import 'package:kryfo/screens/handle_screen.dart';
import 'package:kryfo/screens/lock_file_screen.dart';
import 'package:kryfo/screens/modes_screen.dart';
import 'package:kryfo/screens/moved_screen.dart';
import 'package:kryfo/screens/my_kryfo_screen.dart';
import 'package:kryfo/screens/new_group_screen.dart';
import 'package:kryfo/screens/notes_screen.dart';
import 'package:kryfo/screens/open_locked_screen.dart';
import 'package:kryfo/screens/pair_code_screen.dart';
import 'package:kryfo/screens/photo_knows_screen.dart';
import 'package:kryfo/screens/profile_screen.dart';
import 'package:kryfo/screens/qr_screen.dart';
import 'package:kryfo/screens/requests_screen.dart';
import 'package:kryfo/screens/restore_screen.dart';
import 'package:kryfo/screens/room_create_sheet.dart';
import 'package:kryfo/screens/saved_screen.dart';
import 'package:kryfo/screens/search_screen.dart';
import 'package:kryfo/screens/seen_screen.dart';
import 'package:kryfo/screens/settings_screen.dart';
import 'package:kryfo/screens/support_screen.dart';
import 'package:kryfo/screens/transport_screen.dart';
import 'package:kryfo/screens/why_kryfo_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/tools/tools_bridge.dart' show PickedFile;
import 'package:kryfo/widgets/confirm_sheet.dart';
import 'package:kryfo/widgets/desk_menu.dart' show showMenuSheet;
import 'package:kryfo/widgets/halo_sheet.dart';
import 'package:kryfo/widgets/language_sheet.dart';
import 'package:kryfo/widgets/message_menu.dart';
import 'package:kryfo/widgets/nav_bar.dart' show HaloTab;
import 'package:kryfo/widgets/new_poll_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bars_check.dart';
import 'dev_chat_fakes.dart' show DevTestDb, devHome, devMem, devWorld;
import 'sticker_test_util.dart' show useLibrary;

class _Db extends DevTestDb {
  _Db() : super(devMem);
  @override
  Future<Set<String>> blockedIds() async => {};
  @override
  Future<List<Map<String, Object?>>> messagesFor(String peerId) async => [];
  @override
  Future<List<Map<String, Object?>>> requestsInbox() async => [];
  @override
  Future<List<Map<String, Object?>>> savedMessages() async => [];
}

class _Engine implements HaloEngine {
  @override
  String setBridgeMode(String mode, String opts) => 'ok';
  @override
  String bridgeLineChecks() => '[]';
  @override
  Map<String, dynamic> transportState() => {
    'relays': [
      {'url': 'wss://relay.example', 'fails': 0},
    ],
    'sub_count': 0,
    'secs_since_recv': -1,
    'secs_since_send': -1,
    'hsdir_uploads': 0,
    'publishing_secs': -1,
  };
  @override
  Map<String, dynamic> memStats() => const {};
  @override
  String lastReconnect() => '';
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

typedef Phone = ({String name, double nav, double kb, bool side, double top});

// the android 15 and 16 sizes: the thinnest and the tallest status bar, the
// thinnest handle and the three buttons
const android15 = <Phone>[
  (name: '15 thin', nav: gestureThin, kb: 0, side: false, top: statusLow),
  (name: '15 buttons', nav: buttonBar, kb: 0, side: false, top: statusTall),
  (
    name: '15 keyboard',
    nav: buttonBar,
    kb: keyboardUp,
    side: false,
    top: statusTall,
  ),
];

const upright = <Phone>[
  (name: 'gesture bar', nav: gestureBar, kb: 0, side: false, top: cutoutTop),
  (name: 'button bar', nav: buttonBar, kb: 0, side: false, top: cutoutTop),
  (
    name: 'keyboard',
    nav: gestureBar,
    kb: keyboardUp,
    side: false,
    top: cutoutTop,
  ),
  ...android15,
];

const _file = PickedFile(
  uri: 'content://test/photo.jpg',
  name: 'photo.jpg',
  size: 4321,
  mime: 'image/jpeg',
);

const _age = PickedFile(
  uri: 'content://test/locked.age',
  name: 'locked.age',
  size: 4321,
  mime: 'application/octet-stream',
);

// a sheet without a field: opening it takes the focus, and the keyboard goes
const _noKeyboard = <Phone>[
  (name: 'gesture bar', nav: gestureBar, kb: 0, side: false, top: cutoutTop),
  (name: 'button bar', nav: buttonBar, kb: 0, side: false, top: cutoutTop),
  (name: '15 thin', nav: gestureThin, kb: 0, side: false, top: statusLow),
  (name: '15 buttons', nav: buttonBar, kb: 0, side: false, top: statusTall),
];

final _nav = GlobalKey<NavigatorState>();

// the screen in the app's own MaterialApp, as the phone runs it
Widget _shell(Widget home) => haloAppShell(
  navigatorKey: _nav,
  home: home,
  lock: (n) => n,
  locale: const Locale('en'),
);

void _quiet(WidgetTester t) {
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
  // the tools' file copy fails at once: each tool shows its failure page
  const tools = MethodChannel('halo/tools');
  m.setMockMethodCallHandler(tools, (c) async {
    if (c.method == 'copyIn') throw PlatformException(code: 'read');
    return null;
  });
  addTearDown(() => m.setMockMethodCallHandler(tools, null));
}

Future<void> _rest(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await t.pump(const Duration(seconds: 1));
  }
}

Future<void> _gone(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 2));
}

void _caught(List<String> hits, String phone, FlutterErrorDetails d) {
  final what = d.exceptionAsString().split('\n').first;
  if (what.startsWith('A RenderFlex overflowed')) return;
  hits.add('$phone: $what');
}

// a page on each phone; what lies under a bar, by phone
Future<List<String>> sweepBars(
  WidgetTester t,
  Widget Function() page, {
  List<Phone> phones = upright,
  Future<void> Function(WidgetTester t)? after,
}) async {
  _quiet(t);
  final hits = <String>[];
  // any other error is a hit too, with the phone it was on. the test
  // font's square letters overflow rows that real fonts fit, so an
  // overflow is left to the layout tests
  final was = FlutterError.onError;
  var now = '';
  FlutterError.onError = (d) => _caught(hits, now, d);
  try {
    for (final p in phones) {
      now = p.name;
      barsPhone(
        t,
        nav: p.nav,
        keyboard: p.kb,
        landscape: p.side,
        status: p.top,
      );
      await t.pumpWidget(
        KeyedSubtree(key: ValueKey(p.name), child: _shell(page())),
      );
      await _rest(t);
      if (after != null) {
        await after(t);
        await _rest(t);
      }
      for (final h in underBars(t)) {
        hits.add('${p.name}: $h');
      }
      await scrollAllToEnd(t);
      for (final h in underBars(t)) {
        hits.add('${p.name}, scrolled: $h');
      }
      await _gone(t);
    }
  } finally {
    FlutterError.onError = was;
  }
  return hits;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({});
    appState.sendModeForTest = 'balanced';
    useEngineForTest(_Engine());
    await devWorld(
      chats: [('amber-slow-river', 3, true), ('quiet-green-fox', 2, false)],
    );
    final db = _Db();
    useDatabasesForTest(db, Session(db));
    setL10nLocale(const Locale('en'));
  });
  tearDown(() => HaloColors.setLight(false));

  group('pages', () {
    final pages = <String, Widget Function()>{
      'settings': () => const SettingsScreen(),
      'bridges': () => const BridgesScreen(),
      'modes': () => const ModesScreen(),
      'getting messages': () => const NotificationsScreen(),
      'blocked': () => const BlockedScreen(),
      'transport': () => const TransportScreen(),
      'backup': () => const BackupScreen(),
      'restore': () => const RestoreScreen(),
      'why': () => const WhyKryfoScreen(),
      'seen': () => const SeenScreen(),
      'profile': () => const ProfileScreen(),
      'donate': () => const DonateScreen(),
      'support': () => const SupportScreen(),
      'my kryfo': () => const MyKryfoScreen(),
      'handle': () => const HandleScreen(),
      'archived': () => const ArchivedScreen(),
      'moved': () => const MovedScreen(),
      'new group': () => const NewGroupScreen(),
      'notes': () => const NotesScreen(),
      'pair code': () => const PairCodeScreen(),
      'requests': () => const RequestsScreen(),
      'saved': () => const SavedScreen(),
      'search': () => const SearchScreen(),
      'lock a file': () => const LockFileScreen(file: _file),
      'open a locked file': () => const OpenLockedScreen(file: _age),
      'clean': () => const CleanScreen(file: _file),
      'photo cleaner': () => const PhotoKnowsScreen(file: _file),
      'appearance': () => const AppearanceScreen(),
      'auto get': () => const AutoGetScreen(),
      'fast servers': () => const FastServersScreen(),
      'linked devices': () => const LinkedDevicesScreen(),
      'link a device': () => const LinkDeviceScreen(),
      'notes export': () => const NotesExportScreen(),
      'pins': () => const PinsScreen(),
      'tip': () => const TipScreen(),
      'decoy pin': () => const PinFlowScreen(flow: PinFlow.decoy),
      'wipe pin': () => const PinFlowScreen(flow: PinFlow.wipe),
      'decoy pin, typed': () =>
          const PinFlowScreen(flow: PinFlow.decoy, skipIntro: true),
    };
    for (final e in pages.entries) {
      testWidgets(e.key, (t) async {
        final hits = await sweepBars(t, e.value);
        expect(hits, isEmpty, reason: hits.join('\n'));
      });
    }

    // a pad of its own: no keyboard comes up over it
    testWidgets('update pins', (t) async {
      final hits = await sweepBars(
        t,
        () => const UpdatePinsScreen(),
        phones: _noKeyboard,
      );
      expect(hits, isEmpty, reason: hits.join('\n'));
    });

    testWidgets('qr', (t) async {
      final hits = await sweepBars(t, () => const QrScreen());
      expect(hits, isEmpty, reason: hits.join('\n'));
    });

    testWidgets('settings, light', (t) async {
      HaloColors.setLight(true);
      final hits = await sweepBars(t, () => const SettingsScreen());
      expect(hits, isEmpty, reason: hits.join('\n'));
    });
  });

  group('home', () {
    for (final tab in HaloTab.values) {
      testWidgets(tab.name, (t) async {
        final hits = await sweepBars(
          t,
          devHome,
          after: (t) async {
            final label = switch (tab) {
              HaloTab.chats => l10n.navBarChats,
              HaloTab.tools => l10n.navBarTools,
              HaloTab.support => l10n.navBarSupport,
              HaloTab.me => l10n.navBarMe,
            };
            await t.tap(find.bySemanticsLabel(label).last);
          },
        );
        expect(hits, isEmpty, reason: hits.join('\n'));
      });
    }
  });

  group('sheets', () {
    // a page with one button that opens the sheet
    Future<List<String>> sheet(
      WidgetTester t,
      Future<void> Function(BuildContext) open, {
      Finder? last,
      List<Phone> phones = upright,
      // taller than the room above a keyboard, so it scrolls there
      bool tall = false,
    }) async {
      _quiet(t);
      final hits = <String>[];
      final gaps = <String, double>{};
      final was = FlutterError.onError;
      var now = '';
      FlutterError.onError = (d) => _caught(hits, now, d);
      try {
        for (final p in phones) {
          now = p.name;
          barsPhone(
            t,
            nav: p.nav,
            keyboard: p.kb,
            landscape: p.side,
            status: p.top,
          );
          await t.pumpWidget(
            KeyedSubtree(
              key: ValueKey(p.name),
              child: _shell(
                Scaffold(
                  body: Builder(
                    builder: (ctx) => Center(
                      child: TextButton(
                        onPressed: () => open(ctx),
                        child: const Text('open'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.tap(find.text('open'));
          await t.pump();
          await _rest(t);
          // the page under the dim is not what is checked
          for (final h in underBars(t)) {
            if (h.contains('"open"')) continue;
            hits.add('${p.name}: $h');
          }
          await scrollAllToEnd(t);
          for (final h in underBars(t)) {
            if (h.contains('"open"')) continue;
            hits.add('${p.name}, scrolled: $h');
          }
          if (last != null) {
            // a tall sheet scrolls above the keyboard: its last button
            // comes into view there
            await t.ensureVisible(last.last);
            await t.pump(const Duration(milliseconds: 400));
            gaps[p.name] = gapAboveBottom(t, last.last);
          }
          await _gone(t);
        }
      } finally {
        FlutterError.onError = was;
      }
      for (final g in gaps.values) {
        expect(g, greaterThanOrEqualTo(0), reason: 'out of reach: $gaps');
        if (!tall) {
          expect(
            g,
            closeTo(gaps.values.first, 0.5),
            reason: 'pushed up twice: $gaps',
          );
        }
      }
      return hits;
    }

    testWidgets('a confirm', (t) async {
      final hits = await sheet(
        t,
        (c) => showConfirmSheet(
          c,
          title: 'Delete?',
          line: 'Gone for good.',
          yes: 'Delete',
        ),
        last: find.text(l10n.confirmSheetKeep),
      );
      expect(hits, isEmpty, reason: hits.join('\n'));
    });

    testWidgets('a choice', (t) async {
      final hits = await sheet(
        t,
        (c) => showChoiceSheet<int>(
          c,
          title: 'How long',
          choices: const [
            SheetChoice(1, 'An hour'),
            SheetChoice(2, 'A day'),
            SheetChoice(3, 'A week'),
          ],
          current: 2,
        ),
        last: find.text('A week'),
        phones: _noKeyboard,
      );
      expect(hits, isEmpty, reason: hits.join('\n'));
    });

    testWidgets('a line typed in', (t) async {
      final hits = await sheet(
        t,
        (c) => showInputSheet(c, title: 'Name', initial: 'Anna', save: 'Save'),
        last: find.text('Save'),
      );
      expect(hits, isEmpty, reason: hits.join('\n'));
    });

    testWidgets('a rename', (t) async {
      final hits = await sheet(
        t,
        (c) => showRenameSheet(c, initial: 'Anna', haloId: 'amber-slow-river'),
        last: find.byType(TextField),
      );
      expect(hits, isEmpty, reason: hits.join('\n'));
    });

    testWidgets('a new poll', (t) async {
      final hits = await sheet(
        t,
        showNewPollSheet,
        last: find.text(l10n.pollSend),
        tall: true,
      );
      expect(hits, isEmpty, reason: hits.join('\n'));
    });

    testWidgets('a new room', (t) async {
      final hits = await sheet(
        t,
        showRoomCreateSheet,
        last: find.text(l10n.roomCreateCreateRoom),
        tall: true,
      );
      expect(hits, isEmpty, reason: hits.join('\n'));
    });

    testWidgets('the languages', (t) async {
      final hits = await sheet(t, pickLanguage, phones: _noKeyboard);
      expect(hits, isEmpty, reason: hits.join('\n'));
    });

    testWidgets('a menu', (t) async {
      final hits = await sheet(
        t,
        (c) => showHaloSheet<void>(
          c,
          scroll: true,
          builder: (ctx) => SingleChildScrollView(
            child: MenuSheet(
              groups: [
                [
                  MenuSheetRow(
                    icon: Icons.push_pin_outlined,
                    label: 'Pin',
                    onTap: () {},
                  ),
                  MenuSheetRow(
                    icon: Icons.archive_outlined,
                    label: 'Archive',
                    onTap: () {},
                  ),
                ],
                [
                  MenuSheetRow(
                    icon: Icons.delete_outline,
                    label: 'Delete',
                    danger: true,
                    onTap: () {},
                  ),
                ],
              ],
            ),
          ),
        ),
        last: find.text('Delete'),
        phones: _noKeyboard,
      );
      expect(hits, isEmpty, reason: hits.join('\n'));
    });

    Future<void> plain(
      WidgetTester t,
      String name,
      Future<void> Function(BuildContext) open,
    ) async {
      final hits = await sheet(t, open, phones: _noKeyboard);
      expect(hits, isEmpty, reason: '$name\n${hits.join('\n')}');
    }

    testWidgets('the attach tray', (t) async {
      await plain(
        t,
        'attach',
        (c) => showHaloSheet<void>(
          c,
          builder: (_) => AttachGrid(
            note: l10n.chatNoExifNeverSaved,
            items: [
              for (final w in ['Camera', 'Gallery', 'Video', 'File', 'Place'])
                AttachItem(
                  icon: (k) => Icon(Icons.photo_outlined, color: k),
                  tint: HaloColors.amber,
                  label: w,
                  onTap: () {},
                ),
            ],
          ),
        ),
      );
    });

    testWidgets('the sticker panel', (t) async {
      final lib = useLibrary();
      await plain(
        t,
        'stickers',
        (c) => showHaloSheet<void>(
          c,
          scroll: true,
          builder: (_) => StickerSheet(
            recents: StickerRecents(HaloContainer.everyday),
            library: lib,
          ),
        ),
      );
    });

    testWidgets('the gif question', (t) async {
      await plain(t, 'gif', (c) => showGifOptInSheet(c, overTor: true));
    });

    testWidgets('a photo sheet', (t) async {
      await plain(
        t,
        'photo',
        (c) => showPhotoSheet(
          c,
          title: 'Your photo',
          line: 'Only your contacts see it.',
          seed: 'amber-slow-river',
          add: false,
          has: true,
        ),
      );
    });

    testWidgets('a file sheet', (t) async {
      await plain(
        t,
        'file',
        (c) => showFileSheet(
          c,
          path: '/nowhere/report.pdf',
          name: 'report.pdf',
          facts: const FileFacts(FileKind.pdf, 'pdf'),
        ),
      );
    });

    testWidgets('a notice', (t) async {
      await plain(
        t,
        'notice',
        (c) => showNoticeSheet(c, title: 'Saved', line: 'All done.', ok: 'Ok'),
      );
    });

    testWidgets('change or remove', (t) async {
      await plain(
        t,
        'change',
        (c) => showChangeOrRemoveSheet(
          c,
          title: 'Your photo',
          line: 'Pick one.',
          change: 'Change',
          remove: 'Remove',
          more: 'More',
        ),
      );
    });

    testWidgets('confirm or more', (t) async {
      await plain(
        t,
        'confirm more',
        (c) => showConfirmOrMoreSheet(
          c,
          title: 'Leave?',
          line: 'You can come back.',
          yes: 'Leave',
          more: 'Why',
          detail: 'A longer line about it.',
        ),
      );
    });

    testWidgets('the helper apps', (t) async {
      await plain(t, 'helper', showHelperSheet);
    });

    testWidgets('a wallpaper', (t) async {
      await plain(
        t,
        'wallpaper',
        (c) => showWallpaperSheet(c, Atmo.values.first, allowPhoto: true),
      );
    });

    testWidgets('a bridge to share', (t) async {
      await plain(
        t,
        'bridge share',
        (c) => showBridgeShareSheet(
          c,
          'obfs4 192.0.2.1:443 ABCDEF cert=x iat-mode=0',
        ),
      );
    });

    testWidgets('tor blocked', (t) async {
      await plain(t, 'tor blocked', showTorBlockedSheet);
    });

    testWidgets('a blocked start', (t) async {
      await plain(t, 'blocked start', showBlockedStartSheet);
    });

    testWidgets('tor project consent', (t) async {
      await plain(t, 'consent', showTorProjectConsentSheet);
    });

    testWidgets('a friend\'s lines', (t) async {
      final hits = await sheet(t, showFriendLinesSheet);
      expect(hits, isEmpty, reason: hits.join('\n'));
    });

    final room = RoomLink(
      roomId: 'r1',
      name: 'Book club',
      expiresAt: DateTime(2030).millisecondsSinceEpoch,
      creatorPub: 'aa' * 32,
      fcPk: 'bb' * 32,
    );

    testWidgets('a room link', (t) async {
      await plain(
        t,
        'room link',
        (c) => showRoomLinkSheet(c, room, fresh: true),
      );
    });

    testWidgets('a room preview', (t) async {
      await plain(t, 'room preview', (c) => showRoomPreviewSheet(c, room));
    });
  });

  // android 15 and 16 sizes, kept as pictures: settings and a menu sheet
  group('android 15 goldens', () {
    for (final (name, nav, top) in [
      ('gesture', gestureThin, statusLow),
      ('buttons', buttonBar, statusTall),
    ]) {
      testWidgets('settings, $name', (t) async {
        _quiet(t);
        barsPhone(t, nav: nav, status: top);
        await t.pumpWidget(_shell(const SettingsScreen()));
        await _rest(t);
        expectClearOfBars(t);
        await expectLater(
          find.byType(SettingsScreen),
          matchesGoldenFile('goldens/a15_settings_$name.png'),
        );
        await _gone(t);
      });

      testWidgets('a menu sheet, $name', (t) async {
        _quiet(t);
        barsPhone(t, nav: nav, status: top);
        await t.pumpWidget(
          _shell(
            Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: TextButton(
                    onPressed: () => showMenuSheet<void>(
                      ctx,
                      groups: (_) => [
                        [
                          MenuSheetRow(
                            icon: Icons.push_pin_outlined,
                            label: 'Pin',
                            onTap: () {},
                          ),
                          MenuSheetRow(
                            icon: Icons.archive_outlined,
                            label: 'Archive',
                            onTap: () {},
                          ),
                        ],
                        [
                          MenuSheetRow(
                            icon: Icons.delete_outline,
                            label: 'Delete',
                            danger: true,
                            onTap: () {},
                          ),
                        ],
                      ],
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('open'));
        await t.pump();
        await _rest(t);
        final hits = underBars(t).where((h) => !h.contains('"open"'));
        expect(hits, isEmpty);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/a15_menu_$name.png'),
        );
        await _gone(t);
      });
    }
  });
}
