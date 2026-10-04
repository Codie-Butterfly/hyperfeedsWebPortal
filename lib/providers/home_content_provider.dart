import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'branch_provider.dart';

class HomeContentState {
  final List<Announcement> announcements;
  final List<Special> specials;
  final List<Map<String, dynamic>> advertisements;
  final bool chickBookingOpen;
  final bool isLoading;
  final String? error;

  HomeContentState({
    required this.announcements,
    required this.specials,
    required this.advertisements,
    required this.chickBookingOpen,
    required this.isLoading,
    this.error,
  });

  factory HomeContentState.initial() => HomeContentState(
    announcements: [],
    specials: [],
    advertisements: [],
    chickBookingOpen: false,
    isLoading: false,
  );

  HomeContentState copyWith({
    List<Announcement>? announcements,
    List<Special>? specials,
    List<Map<String, dynamic>>? advertisements,
    bool? chickBookingOpen,
    bool? isLoading,
    String? error,
  }) {
    return HomeContentState(
      announcements: announcements ?? this.announcements,
      specials: specials ?? this.specials,
      advertisements: advertisements ?? this.advertisements,
      chickBookingOpen: chickBookingOpen ?? this.chickBookingOpen,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class HomeContentNotifier extends StateNotifier<HomeContentState> {
  final ApiClient _apiClient;
  final String? _branchId;

  HomeContentNotifier(this._apiClient, this._branchId)
    : super(HomeContentState.initial()) {
    refreshContent();
  }

  Future<void> refreshContent() async {
    state = state.copyWith(isLoading: true);
    try {
      final Map<String, dynamic> params = {};
      if (_branchId != null) {
        params['branchId'] = _branchId;
      }

      final responses = await Future.wait([
        _apiClient.dio.get('/content/announcements', queryParameters: params),
        _apiClient.dio.get('/content/specials', queryParameters: params),
        _apiClient.dio.get('/advertisements', queryParameters: params),
        _apiClient.dio.get('/chicks/current-batch'),
      ]);

      final List<dynamic> annData = responses[0].data;
      final List<dynamic> specData = responses[1].data;
      final List<dynamic> advertData = responses[2].data;

      final freshAnnouncements = annData
          .map((json) => Announcement.fromJson(json))
          .toList();
      final freshSpecials = specData
          .map((json) => Special.fromJson(json))
          .toList();

      state = HomeContentState(
        announcements: freshAnnouncements,
        specials: freshSpecials,
        advertisements: advertData.cast<Map<String, dynamic>>(),
        chickBookingOpen: (responses[3].data as Map).isNotEmpty,
        isLoading: false,
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final homeContentStateProvider =
    StateNotifierProvider<HomeContentNotifier, HomeContentState>((ref) {
      final api = ref.watch(apiClientProvider);
      final branchState = ref.watch(branchStateProvider);
      final branchId = branchState.selectedBranch?.id;
      return HomeContentNotifier(api, branchId);
    });
