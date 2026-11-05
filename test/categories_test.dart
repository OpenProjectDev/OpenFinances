import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/data/category_repository.dart';
import 'package:openfinances/data/db.dart';
import 'package:openfinances/features/settings/categories_page.dart';
import 'package:openfinances/shared/ui/uicons.g.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await AppDb.instance.open(path: inMemoryDatabasePath);
  });

  test('category icons: UIcons kept, old Material ones mapped', () {
    final cart = kUIconsSolid['shopping-cart']!;
    expect(resolveCategoryIcon(cart.codePoint, cart.fontFamily), cart);
    expect(
      resolveCategoryIcon(Icons.shopping_cart.codePoint, 'MaterialIcons'),
      cart,
    );
    // The default stays the default (drawn with the app's own image).
    expect(
      resolveCategoryIcon(Icons.category.codePoint, 'MaterialIcons'),
      Icons.category,
    );
    expect(resolveCategoryIcon(1, 'MaterialIcons'), Icons.category);
    // Every picker group and mapping points at a real icon.
    for (final (_, names) in kUIconGroups) {
      for (final n in names) {
        expect(kUIconsSolid.containsKey(n), isTrue, reason: n);
      }
    }
  });

  test('deleting a category moves its entries to the heir', () async {
    final db = AppDb.instance.db;
    final repo = CategoryRepository();
    final now = DateTime.utc(2026);
    await repo.upsert(
      CategoryDto(
        gid: 'cat_food',
        name: 'Food',
        sort: 1,
        createdAtUtc: now,
        updatedAtUtc: now,
      ),
    );
    await db.insert('expenses', {
      'gid': 'e1',
      'title': 'Bread',
      'amountMinor': 10,
      'currency': 'IRT',
      'occurredAtUtc': now.toIso8601String(),
      'categoryGid': 'cat_food',
      'version': 1,
      'createdAtUtc': now.toIso8601String(),
      'updatedAtUtc': now.toIso8601String(),
      'isDeleted': 0,
      'isDirty': 0,
    });

    await repo.deleteMovingTo('cat_food', 'cat_general');

    final row = (await db.query('expenses', where: "gid = 'e1'")).single;
    expect(row['categoryGid'], 'cat_general');
    expect((await repo.list()).map((c) => c.gid), isNot(contains('cat_food')));
  });
}
