// SPDX-License-Identifier: GPL-3.0-or-later
// a decoy asks the badge service nothing: no invoice is made and no
// receipt fetched, and the page falls back to the fixed addresses as when
// the service cannot be reached. the everyday app still asks
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/badge_client.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show HaloDb, HaloEngine, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/session.dart';
import 'package:kryfo/supporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// the onion calls, counted
class _Spy implements HaloEngine {
  final asked = <String>[];
  @override
  Future<String> torPost(String url, String body) async {
    asked.add(url);
    return 'error: down';
  }

  @override
  Future<String> torGetJson(String url) async {
    asked.add(url);
    return 'error: down';
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late _Spy spy;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    spy = _Spy();
    useEngineForTest(spy);
  });

  tearDown(() {
    final e = HaloDb();
    useDatabasesForTest(e, Session(e));
  });

  void open(HaloContainer c) {
    final d = HaloDb(c);
    useDatabasesForTest(HaloDb(), Session(d));
  }

  test('a decoy makes no invoice and fetches no receipt', () async {
    open(HaloContainer.decoy);
    expect((await createInvoice('supporter')).invoice, isNull);
    expect((await fetchReceipt('inv1')).state, ReceiptState.error);
    // one remembered in it is left as it was
    await saveOpenInvoice('inv1', SupporterTier.supporter, HaloContainer.decoy);
    expect(await settleOpenInvoice(HaloContainer.decoy), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('d.badge_open_invoice'), 'inv1|supporter');
    expect(spy.asked, isEmpty);
  });

  test('the everyday app asks', () async {
    open(HaloContainer.everyday);
    expect((await createInvoice('supporter')).invoice, isNull);
    expect((await fetchReceipt('inv1')).state, ReceiptState.error);
    // the invoice ask that does not get through is made once more
    expect(spy.asked, hasLength(3));
  });
}
