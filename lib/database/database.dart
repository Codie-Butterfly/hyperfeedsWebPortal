import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/models.dart';

part 'database.g.dart';

class CachedBranches extends Table {
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get address => text()();
  TextColumn get phoneNumber => text()();
  TextColumn get whatsappNumber => text().nullable()();
  TextColumn get openingHours => text().nullable()();
  BoolColumn get collectionEnabled => boolean()();
  BoolColumn get active => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}

class CachedCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get active => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}

class CachedProducts extends Table {
  TextColumn get id => text()();
  TextColumn get sku => text()();
  TextColumn get barcode => text().nullable()();
  TextColumn get categoryId => text()();
  TextColumn get categoryName => text().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get packSize => text()();
  TextColumn get imageUrl => text().nullable()();
  RealColumn get amount => real().nullable()();
  TextColumn get currency => text().nullable()();
  RealColumn get onHand => real().nullable()();
  RealColumn get reserved => real().nullable()();
  RealColumn get available => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [CachedBranches, CachedCategories, CachedProducts])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Branch operations
  Future<void> saveBranches(List<Branch> branches) async {
    await batch((b) {
      b.insertAll(
        cachedBranches,
        branches.map((item) => CachedBranchesCompanion.insert(
          id: item.id,
          code: item.code,
          name: item.name,
          address: item.address,
          phoneNumber: item.phoneNumber,
          whatsappNumber: Value(item.whatsappNumber),
          openingHours: Value(item.openingHours),
          collectionEnabled: item.collectionEnabled,
          active: item.active,
        )).toList(),
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<List<Branch>> loadBranches() async {
    final rows = await select(cachedBranches).get();
    return rows.map((row) => Branch(
      id: row.id,
      code: row.code,
      name: row.name,
      address: row.address,
      phoneNumber: row.phoneNumber,
      whatsappNumber: row.whatsappNumber,
      openingHours: row.openingHours,
      collectionEnabled: row.collectionEnabled,
      active: row.active,
    )).toList();
  }

  // Category operations
  Future<void> saveCategories(List<Category> categories) async {
    await batch((b) {
      b.insertAll(
        cachedCategories,
        categories.map((item) => CachedCategoriesCompanion.insert(
          id: item.id,
          name: item.name,
          description: Value(item.description),
          active: item.active,
        )).toList(),
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<List<Category>> loadCategories() async {
    final rows = await select(cachedCategories).get();
    return rows.map((row) => Category(
      id: row.id,
      name: row.name,
      description: row.description,
      active: row.active,
    )).toList();
  }

  // Product operations
  Future<void> saveProducts(List<Product> products) async {
    await batch((b) {
      b.insertAll(
        cachedProducts,
        products.map((item) => CachedProductsCompanion.insert(
          id: item.id,
          sku: item.sku,
          barcode: Value(item.barcode),
          categoryId: item.categoryId,
          categoryName: Value(item.categoryName),
          name: item.name,
          description: Value(item.description),
          packSize: item.packSize,
          imageUrl: Value(item.imageUrl),
          amount: Value(item.amount),
          currency: Value(item.currency),
          onHand: Value(item.onHand),
          reserved: Value(item.reserved),
          available: Value(item.available),
        )).toList(),
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<void> clearProducts() async {
    await delete(cachedProducts).go();
  }

  Future<List<Product>> loadProducts() async {
    final rows = await select(cachedProducts).get();
    return rows.map((row) => Product(
      id: row.id,
      sku: row.sku,
      barcode: row.barcode,
      categoryId: row.categoryId,
      categoryName: row.categoryName,
      name: row.name,
      description: row.description,
      packSize: row.packSize,
      imageUrl: row.imageUrl,
      published: true,
      active: true,
      amount: row.amount,
      currency: row.currency,
      onHand: row.onHand,
      reserved: row.reserved,
      available: row.available,
    )).toList();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'hyperfeeds.db'));
    return NativeDatabase.createInBackground(file);
  });
}
