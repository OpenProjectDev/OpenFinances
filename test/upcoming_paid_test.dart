// Paying a due payment (lib/features/upcoming/upcoming_sheet.dart): History
// gets an expense only with the sheet's Record box ticked, for "Paid" and
// "Pay & reschedule" alike; an amount changed on the sheet is what's paid,
// on the item and on its expense (the owner, 2026-10-27).
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/data/db.dart';
import 'package:openfinances/data/expense_provider.dart';
import 'package:openfinances/data/upcoming_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await AppDb.instance.open(path: inMemoryDatabasePath);
  });

  test('records only when asked, with the amount paid', () async {
    final up = UpcomingProvider();
    final ep = ExpenseProvider();
    await up.load();
    await ep.loadExpenses();
    final before = ep.raw.length;
    final due = DateTime.now();

    // Not recorded: paid, nothing in History.
    final a = await up.add(
      title: 'قبض آب',
      amountMinor: 50000,
      dueLocal: due,
      currency: 'IRT',
    );
    await up.markPaid(up.items.firstWhere((e) => e.gid == a), null);
    await ep.loadExpenses();
    expect(ep.raw.length, before);
    expect(up.paid.firstWhere((e) => e.gid == a).ledgerGid, isNull);

    // Recorded, paid a different amount: the item and its expense take it.
    final b = await up.add(
      title: 'قبض گاز',
      amountMinor: 450000,
      dueLocal: due,
      currency: 'IRT',
    );
    await up.markPaid(
      up.items.firstWhere((e) => e.gid == b),
      ep,
      amountMinor: 480000,
    );
    await ep.loadExpenses();
    expect(ep.raw.length, before + 1);
    final paid = up.paid.firstWhere((e) => e.gid == b);
    expect(paid.amountMinor, 480000);
    final entry = ep.raw.firstWhere((r) => r['gid'] == paid.ledgerGid);
    expect(entry['amountMinor'], 480000);
  });
}
