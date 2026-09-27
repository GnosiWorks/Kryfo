// SPDX-License-Identifier: GPL-3.0-or-later
// the lists off the chat list: requests, saved, notes and blocked. what
// goes folds away and the empty page fades in after it, a new note grows up
// from the bar, the empty pages breathe three times and rest, and with less
// movement all of it is simply there. the database is a stand-in that keeps
// rows in memory.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show HaloDb, useDatabasesForTest;
import 'package:kryfo/screens/blocked_screen.dart';
import 'package:kryfo/screens/notes_screen.dart';
import 'package:kryfo/screens/requests_screen.dart';
import 'package:kryfo/screens/saved_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/breathing_ring.dart';
import 'package:kryfo/widgets/burn_fade.dart' show FadeFold;
import 'package:kryfo/widgets/row_motion.dart' show GrowIn;
import 'package:shared_preferences/shared_preferences.dart';

// only what these screens ask for; anything else fails on its type
class _Db implements HaloDb {
  List<Map<String, Object?>> people = [];
  List<Map<String, Object?>> requests = [];
  List<Map<String, Object?>> saved = [];
  List<Map<String, Object?>> notes = [];

  @override
  HaloContainer get container => HaloContainer.everyday;
  @override
  Future<List<Map<String, Object?>>> contacts() async => [...people];
  @override
  Future<Map<String, Map<String, Object?>>> lastMessages() async => {};
  @override
  Future<List<Map<String, Object?>>> pendingRequests() async => [...requests];
  @override
  Future<int> pendingRequestCount() async => requests.length;
  @override
  Future<Map<String, Object?>?> shieldFor(String haloId) async => null;
  @override
  Future<List<Map<String, Object?>>> vouchesFor(String haloId) async => [];
  @override
  Future<List<Map<String, Object?>>> messagesFor(String peerId) async =>
      peerId == kNotesPeerId ? [...notes] : [];
  @override
  Future<void> declineRequest(String haloId) async =>
      requests.removeWhere((r) => r['halo_id'] == haloId);
  @override
  Future<List<Map<String, Object?>>> savedMessages() async => [...saved];
  @override
  Future<void> setSaved(String msgUid, bool on) async {
    if (!on) saved.removeWhere((r) => r['msg_uid'] == msgUid);
  }

  @override
  Future<void> setBlocked(String haloId, bool blocked) async {
    people = [
      for (final p in people)
        if (p['halo_id'] == haloId) {...p, 'blocked': blocked ? 1 : 0} else p,
    ];
  }

  @override
  Future<void> saveMessage(
    String peerId,
    String direction,
    String plaintext, {
    int? burnAt,
    int? burnSecs,
    String? msgUid,
    String? replyTo,
    String? groupId,
    String? mediaPath,
    String? filePath,
    String? fileName,
    bool voiceDisguised = false,
    bool saved = false,
    int sent = 1,
    String? preview,
    bool secure = false,
    String? poll,
    String? sticker,
    int? sentAt,
  }) async {
    notes.add({
      'rowid': notes.length + 1,
      'plaintext': plaintext,
      'sent_at': DateTime(2026, 9, 27, 12).millisecondsSinceEpoch,
    });
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the stand-in was asked for ${i.memberName}');
}

Map<String, Object?> _person(String id, {bool blocked = false}) => {
  'halo_id': id,
  'nickname': null,
  'last_seen': 0,
  'blocked': blocked ? 1 : 0,
};

Map<String, Object?> _note(int n, String text) => {
  'rowid': n,
  'plaintext': text,
  'sent_at': DateTime(2026, 9, 27, 10, n).millisecondsSinceEpoch,
};

Map<String, Object?> _saved(String uid, String text) => {
  'msg_uid': uid,
  'peer_id': 'wren-oak-lamp',
  'plaintext': text,
  'sent_at': DateTime(2026, 9, 27, 9).millisecondsSinceEpoch,
};

final _theme = buildHaloTheme();

Widget framed(
  Widget home, {
  bool still = false,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  locale: locale,
  theme: _theme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: child!,
  ),
  home: home,
);

void phone(WidgetTester t) {
  t.view.physicalSize = const Size(1000, 1800);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

// a second at a time, so a ticker started late still gets its frames
Future<void> rest(WidgetTester t, [int seconds = 12]) async {
  for (var i = 0; i < seconds; i++) {
    await t.pump(const Duration(seconds: 1));
  }
}

// the toast, and the page gone
Future<void> drain(WidgetTester t) async {
  await t.pump(const Duration(seconds: 4));
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

// how far the fold has gone on the row holding [text]: 1 is open
double fold(WidgetTester t, String text) => t
    .widget<Align>(
      find.ancestor(of: find.text(text), matching: find.byType(Align)).first,
    )
    .heightFactor!;

void main() {
  late _Db db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    db = _Db();
    useDatabasesForTest(db, Session(db));
  });

  group('requests', () {
    // the lock has not been read here, so the list takes changes as it
    // would under it: an answered card goes at once (row_motion_test has
    // the fold), and the empty page still fades in after the last
    testWidgets('an answered card goes, then the empty page fades in', (
      t,
    ) async {
      phone(t);
      db.requests = [_person('amber-fox-river'), _person('slow-kite-moss')];
      await t.pumpWidget(framed(const RequestsScreen()));
      await t.pump(const Duration(seconds: 1));
      expect(t.hasRunningAnimations, isFalse);
      expect(find.byType(FadeFold), findsNWidgets(2));
      await t.tap(find.text(l10n.requestsDecline).first);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('amber-fox-river'), findsNothing);
      expect(find.text('slow-kite-moss'), findsOneWidget);
      await t.tap(find.text(l10n.requestsDecline));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      // the list fading out, the empty page fading in
      expect(t.hasRunningAnimations, isTrue);
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text(l10n.requestsNoRequests), findsOneWidget);
      await rest(t);
      expect(t.hasRunningAnimations, isFalse, reason: 'the ring rests');
      await drain(t);
    });

    testWidgets('the empty inbox breathes three times, then rests', (t) async {
      phone(t);
      await t.pumpWidget(framed(const RequestsScreen()));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byType(BreathingRing), findsOneWidget);
      expect(t.hasRunningAnimations, isTrue);
      await rest(t);
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });

    testWidgets('reduced motion: cards and the empty page are simply there', (
      t,
    ) async {
      phone(t);
      db.requests = [_person('amber-fox-river')];
      await t.pumpWidget(framed(const RequestsScreen(), still: true));
      await t.pump();
      await t.pump();
      expect(t.hasRunningAnimations, isFalse);
      await t.tap(find.text(l10n.requestsDecline));
      await t.pump();
      await t.pump(const Duration(milliseconds: 200));
      await t.pump(const Duration(milliseconds: 200));
      await t.pump();
      expect(find.text(l10n.requestsNoRequests), findsOneWidget);
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });
  });

  group('saved', () {
    testWidgets('unsaving empties the mark, folds the card, then the empty '
        'page', (t) async {
      phone(t);
      db.saved = [_saved('u1', 'the ferry leaves at nine')];
      await t.pumpWidget(framed(const SavedScreen()));
      await t.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      await t.tap(find.byIcon(Icons.bookmark));
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
      expect(fold(t, 'the ferry leaves at nine'), lessThan(1));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text(l10n.savedNothingSavedYet), findsOneWidget);
      await rest(t);
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });

    testWidgets('reduced motion: the mark swaps and nothing moves', (t) async {
      phone(t);
      db.saved = [_saved('u1', 'the ferry leaves at nine')];
      await t.pumpWidget(framed(const SavedScreen(), still: true));
      await t.pump();
      await t.pump();
      await t.tap(find.byIcon(Icons.bookmark));
      await t.pump();
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsNothing);
      await t.pump(const Duration(milliseconds: 400));
      await t.pump();
      expect(find.text(l10n.savedNothingSavedYet), findsOneWidget);
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });
  });

  group('notes', () {
    testWidgets('the newest sits on the bar and a new one grows up from it', (
      t,
    ) async {
      phone(t);
      db.notes = [_note(1, 'buy lemons'), _note(2, 'call the tailor')];
      await t.pumpWidget(framed(const NotesScreen()));
      await t.pump(const Duration(seconds: 1));
      // the newest is the lower of the two
      expect(
        t.getCenter(find.text('call the tailor')).dy,
        greaterThan(t.getCenter(find.text('buy lemons')).dy),
      );
      final grown = t.widgetList<GrowIn>(find.byType(GrowIn));
      expect(grown.every((g) => !g.active), isTrue, reason: 'first load');
      await t.enterText(find.byType(TextField), 'water the fig');
      await t.pump();
      await t.tap(find.bySemanticsLabel(l10n.commonSave));
      await t.pump();
      await t.pump(const Duration(milliseconds: 20));
      expect(find.text('water the fig'), findsOneWidget);
      expect(
        t
            .widget<GrowIn>(
              find.ancestor(
                of: find.text('water the fig'),
                matching: find.byType(GrowIn),
              ),
            )
            .active,
        isTrue,
      );
      expect(
        t.getCenter(find.text('water the fig')).dy,
        greaterThan(t.getCenter(find.text('call the tailor')).dy),
      );
      await rest(t, 2);
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });

    testWidgets('the send button lights once there is something to keep', (
      t,
    ) async {
      phone(t);
      await t.pumpWidget(framed(const NotesScreen()));
      await t.pump(const Duration(seconds: 1));
      Color? send() =>
          (t
                      .widget<AnimatedContainer>(
                        find.ancestor(
                          of: find.byIcon(Icons.arrow_upward_rounded),
                          matching: find.byType(AnimatedContainer),
                        ),
                      )
                      .decoration
                  as BoxDecoration)
              .color;
      expect(send(), HaloColors.surface3);
      await t.enterText(find.byType(TextField), 'x');
      await t.pump(const Duration(milliseconds: 250));
      expect(send(), HaloColors.amber);
      await rest(t);
      await drain(t);
    });
  });

  group('blocked', () {
    testWidgets('an unblocked row folds away, then the empty page', (t) async {
      phone(t);
      db.people = [_person('grey-owl-dune', blocked: true)];
      await t.pumpWidget(framed(const BlockedScreen()));
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.text(l10n.commonUnblock));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(fold(t, 'grey-owl-dune'), lessThan(1));
      await t.pump(const Duration(milliseconds: 700));
      expect(find.text(l10n.blockedNoOneIsBlocked), findsOneWidget);
      expect(db.people.single['blocked'], 0);
      await rest(t);
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });

    testWidgets('right to left: unblock sits at the start', (t) async {
      phone(t);
      db.people = [_person('grey-owl-dune', blocked: true)];
      await t.pumpWidget(
        framed(const BlockedScreen(), locale: const Locale('ar')),
      );
      await t.pump(const Duration(seconds: 1));
      expect(
        t.getCenter(find.text(l10n.commonUnblock)).dx,
        lessThan(t.getCenter(find.text('grey-owl-dune')).dx),
      );
      await drain(t);
    });

    testWidgets('reduced motion: gone at once, nothing moves', (t) async {
      phone(t);
      db.people = [_person('grey-owl-dune', blocked: true)];
      await t.pumpWidget(framed(const BlockedScreen(), still: true));
      await t.pump();
      await t.pump();
      await t.tap(find.text(l10n.commonUnblock));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump();
      expect(find.text(l10n.blockedNoOneIsBlocked), findsOneWidget);
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });
  });
}
