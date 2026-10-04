import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/models.dart';
import '../database/database.dart'
    if (dart.library.js_interop) '../database/database_web.dart';
import 'auth_provider.dart';
import 'branch_provider.dart';

const _notProvided = Object();

class CatalogueState {
  final List<Category> categories;
  final List<Product> products;
  final List<Product> allProducts;
  final String? selectedCategoryId;
  final String? pendingCategoryName;
  final String searchQuery;
  final bool isLoading;
  final String? error;
  final bool isOffline;

  CatalogueState({
    required this.categories,
    required this.products,
    required this.allProducts,
    this.selectedCategoryId,
    this.pendingCategoryName,
    required this.searchQuery,
    required this.isLoading,
    this.error,
    required this.isOffline,
  });

  factory CatalogueState.initial() => CatalogueState(
    categories: [],
    products: [],
    allProducts: [],
    searchQuery: '',
    isLoading: false,
    isOffline: false,
  );

  CatalogueState copyWith({
    List<Category>? categories,
    List<Product>? products,
    List<Product>? allProducts,
    Object? selectedCategoryId = _notProvided,
    Object? pendingCategoryName = _notProvided,
    String? searchQuery,
    bool? isLoading,
    String? error,
    bool? isOffline,
  }) {
    return CatalogueState(
      categories: categories ?? this.categories,
      products: products ?? this.products,
      allProducts: allProducts ?? this.allProducts,
      selectedCategoryId: identical(selectedCategoryId, _notProvided)
          ? this.selectedCategoryId
          : selectedCategoryId as String?,
      pendingCategoryName: identical(pendingCategoryName, _notProvided)
          ? this.pendingCategoryName
          : pendingCategoryName as String?,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

class CatalogueNotifier extends StateNotifier<CatalogueState> {
  final ApiClient _apiClient;
  final AppDatabase _db;
  final String? _branchId;

  CatalogueNotifier(this._apiClient, this._db, this._branchId)
    : super(CatalogueState.initial()) {
    if (_branchId != null) {
      loadCachedAndFetch();
    }
  }

  Future<void> loadCachedAndFetch() async {
    state = state.copyWith(isLoading: true);

    // 1. Load from cache
    List<Category> cachedCategories = [];
    try {
      cachedCategories = await _db.loadCategories();
      final cachedProducts = await _db.loadProducts();

      String? newSelectedId = state.selectedCategoryId;
      String? newPending = state.pendingCategoryName;
      if (newPending != null && cachedCategories.isNotEmpty) {
        final normalizedPending = newPending.trim().toLowerCase();
        final matches = cachedCategories.where(
          (c) => c.name.trim().toLowerCase() == normalizedPending,
        );
        if (matches.isNotEmpty) {
          newSelectedId = matches.first.id;
          newPending = null;
        }
      }

      state = state.copyWith(
        categories: cachedCategories,
        products: cachedProducts,
        allProducts: cachedProducts,
        selectedCategoryId: newSelectedId,
        pendingCategoryName: newPending,
      );
    } catch (_) {}

    // 2. Fetch fresh data
    await refreshCatalogue();
  }

  Future<void> refreshCatalogue() async {
    if (_branchId == null) return;

    state = state.copyWith(isLoading: true);
    try {
      // Fetch categories
      final catResponse = await _apiClient.dio.get('/catalogue/categories');
      final List<dynamic> catData = catResponse.data;
      final freshCategories = catData
          .map((json) => Category.fromJson(json))
          .toList();

      // Save categories to cache
      await _db.saveCategories(freshCategories);

      // Check pending category name
      String? newSelectedId = state.selectedCategoryId;
      String? newPending = state.pendingCategoryName;
      if (newPending != null && freshCategories.isNotEmpty) {
        final normalizedPending = newPending.trim().toLowerCase();
        final matches = freshCategories.where(
          (c) => c.name.trim().toLowerCase() == normalizedPending,
        );
        if (matches.isNotEmpty) {
          newSelectedId = matches.first.id;
          newPending = null;
        }
      }

      // Fetch products for current branch and filters
      final Map<String, dynamic> params = {'branchId': _branchId};
      if (newSelectedId != null) {
        params['categoryId'] = newSelectedId;
      }
      if (state.searchQuery.isNotEmpty) {
        params['q'] = state.searchQuery;
      }

      final prodResponse = await _apiClient.dio.get(
        '/catalogue/products',
        queryParameters: params,
      );
      final List<dynamic> prodData = prodResponse.data;
      final freshProducts = prodData
          .map((json) => Product.fromJson(json))
          .toList();

      // Cache products if this was a full fetch (no filters) so that we store the "last successful catalogue response"
      if (newSelectedId == null && state.searchQuery.isEmpty) {
        await _db.clearProducts();
        await _db.saveProducts(freshProducts);
      }

      final isFullCatalogue =
          newSelectedId == null && state.searchQuery.isEmpty;
      state = state.copyWith(
        categories: freshCategories,
        products: freshProducts,
        allProducts: isFullCatalogue ? freshProducts : state.allProducts,
        selectedCategoryId: newSelectedId,
        pendingCategoryName: newPending,
        isLoading: false,
        isOffline: false,
      );
    } on DioException catch (e) {
      // offline loading fallback already done, mark offline
      state = state.copyWith(
        isLoading: false,
        isOffline: true,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isOffline: true,
        error: e.toString(),
      );
    }
  }

  void selectCategory(String? categoryId) {
    if (state.selectedCategoryId == categoryId) return;
    state = state.copyWith(
      selectedCategoryId: categoryId,
      pendingCategoryName: null,
    );
    refreshCatalogue();
  }

  void selectCategoryByName(String categoryName) {
    final normalizedName = categoryName.trim().toLowerCase();

    // Set pending name first
    state = state.copyWith(pendingCategoryName: categoryName);

    if (state.categories.isNotEmpty) {
      final matches = state.categories.where(
        (category) => category.name.trim().toLowerCase() == normalizedName,
      );
      if (matches.isNotEmpty) {
        state = state.copyWith(
          selectedCategoryId: matches.first.id,
          pendingCategoryName: null,
        );
      } else {
        // Categories are loaded but no match found, clear filter
        state = state.copyWith(
          selectedCategoryId: null,
          pendingCategoryName: null,
        );
      }
    }

    refreshCatalogue();
  }

  void setSearchQuery(String query) {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query);
    refreshCatalogue();
  }
}

// Provider scoped by the selected branch
final catalogueStateProvider =
    StateNotifierProvider<CatalogueNotifier, CatalogueState>((ref) {
      final api = ref.watch(apiClientProvider);
      final db = ref.watch(databaseProvider);
      final branchState = ref.watch(branchStateProvider);
      final branchId = branchState.selectedBranch?.id;
      return CatalogueNotifier(api, db, branchId);
    });
