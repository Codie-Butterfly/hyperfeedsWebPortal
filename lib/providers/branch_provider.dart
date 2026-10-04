import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/models.dart';
import '../database/database.dart'
    if (dart.library.js_interop) '../database/database_web.dart';
import 'auth_provider.dart';

class BranchState {
  final List<Branch> branches;
  final Branch? selectedBranch;
  final bool isLoading;
  final String? error;
  final bool isOffline;

  BranchState({
    required this.branches,
    this.selectedBranch,
    required this.isLoading,
    this.error,
    required this.isOffline,
  });

  factory BranchState.initial() => BranchState(
        branches: [],
        isLoading: false,
        isOffline: false,
      );

  BranchState copyWith({
    List<Branch>? branches,
    Branch? selectedBranch,
    bool? isLoading,
    String? error,
    bool? isOffline,
  }) {
    return BranchState(
      branches: branches ?? this.branches,
      selectedBranch: selectedBranch ?? this.selectedBranch,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

class BranchNotifier extends StateNotifier<BranchState> {
  final ApiClient _apiClient;
  final SecureStorage _storage;
  final AppDatabase _db;

  BranchNotifier(this._apiClient, this._storage, this._db) : super(BranchState.initial()) {
    init();
  }

  Future<void> init() async {
    state = state.copyWith(isLoading: true);

    // 1. Load selected branch from secure storage
    final branchId = await _storage.getSelectedBranchId();
    final branchName = await _storage.getSelectedBranchName();

    // 2. Load cached branches from Drift database
    List<Branch> cached = [];
    try {
      cached = await _db.loadBranches();
    } catch (_) {}

    Branch? selected;
    if (branchId != null && branchName != null) {
      selected = cached.firstWhere(
        (b) => b.id == branchId,
        orElse: () => Branch(
          id: branchId,
          code: '',
          name: branchName,
          address: '',
          phoneNumber: '',
          collectionEnabled: false,
          active: true,
        ),
      );
    }

    state = state.copyWith(
      branches: cached,
      selectedBranch: selected,
      isLoading: false,
    );

    // 3. Fetch fresh branches from network
    await fetchBranches();
  }

  Future<void> fetchBranches() async {
    try {
      final response = await _apiClient.dio.get('/branches');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final list = data.map((json) => Branch.fromJson(json)).toList();

        // Save to Drift cache
        try {
          await _db.saveBranches(list);
        } catch (_) {}

        // Match selected branch details with latest data
        Branch? selected = state.selectedBranch;
        if (selected != null) {
          selected = list.firstWhere((b) => b.id == selected!.id, orElse: () => selected!);
        }

        state = state.copyWith(
          branches: list,
          selectedBranch: selected,
          isLoading: false,
          isOffline: false,
        );
      }
    } on DioException catch (e) {
      // If offline or network error, use cached
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

  Future<void> selectBranch(Branch branch) async {
    await _storage.saveSelectedBranch(branch.id, branch.name);
    state = state.copyWith(selectedBranch: branch);
  }

  Future<void> clearSelectedBranch() async {
    await _storage.saveSelectedBranch('', '');
    state = state.copyWith(selectedBranch: null);
  }
}

// Providers
final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final branchStateProvider = StateNotifierProvider<BranchNotifier, BranchState>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  final db = ref.watch(databaseProvider);
  return BranchNotifier(api, storage, db);
});
