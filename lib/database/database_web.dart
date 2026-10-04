import '../models/models.dart';

/// Browser-session cache only. The API remains the source of truth; mutations
/// require connectivity. Native builds retain their existing SQLite cache.
class AppDatabase {
  List<Branch> _branches = [];
  List<Category> _categories = [];
  List<Product> _products = [];
  Future<void> saveBranches(List<Branch> rows) async {
    _branches = List.of(rows);
  }

  Future<List<Branch>> loadBranches() async => List.of(_branches);
  Future<void> saveCategories(List<Category> rows) async {
    _categories = List.of(rows);
  }

  Future<List<Category>> loadCategories() async => List.of(_categories);
  Future<void> saveProducts(List<Product> rows) async {
    _products = List.of(rows);
  }

  Future<List<Product>> loadProducts() async => List.of(_products);
  Future<void> clearProducts() async {
    _products.clear();
  }
}
