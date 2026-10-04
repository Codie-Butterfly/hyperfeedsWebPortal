import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/models.dart';
import 'auth_provider.dart';

class SupportNotificationState {
  final List<LivestockQuestion> userQuestions;
  final List<Map<String, dynamic>>
  expertQueue; // Review questions queue for experts
  final List<NotificationItem> notifications;
  final bool isLoading;
  final String? error;
  final bool isSubmitting;

  SupportNotificationState({
    required this.userQuestions,
    required this.expertQueue,
    required this.notifications,
    required this.isLoading,
    this.error,
    required this.isSubmitting,
  });

  factory SupportNotificationState.initial() => SupportNotificationState(
    userQuestions: [],
    expertQueue: [],
    notifications: [],
    isLoading: false,
    isSubmitting: false,
  );

  SupportNotificationState copyWith({
    List<LivestockQuestion>? userQuestions,
    List<Map<String, dynamic>>? expertQueue,
    List<NotificationItem>? notifications,
    bool? isLoading,
    String? error,
    bool? isSubmitting,
  }) {
    return SupportNotificationState(
      userQuestions: userQuestions ?? this.userQuestions,
      expertQueue: expertQueue ?? this.expertQueue,
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class SupportNotificationNotifier
    extends StateNotifier<SupportNotificationState> {
  final ApiClient _apiClient;
  final UserRole _role;

  SupportNotificationNotifier(this._apiClient, this._role)
    : super(SupportNotificationState.initial()) {
    refreshAll();
  }

  Future<void> refreshAll() async {
    state = state.copyWith(isLoading: true);
    final List<Future> tasks = [fetchNotifications()];

    if (_role == UserRole.customer) {
      tasks.add(fetchUserQuestions());
    } else if (_role == UserRole.animalHealthExpert ||
        _role == UserRole.admin ||
        _role == UserRole.branchManager ||
        _role == UserRole.customerService) {
      tasks.add(fetchExpertQueue());
    }

    await Future.wait(tasks);
    state = state.copyWith(isLoading: false);
  }

  Future<void> fetchUserQuestions() async {
    try {
      final response = await _apiClient.dio.get('/livestock/questions');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final list = data
            .map((json) => LivestockQuestion.fromJson(json))
            .toList();
        state = state.copyWith(userQuestions: list);
      }
    } catch (_) {}
  }

  Future<void> fetchExpertQueue() async {
    try {
      final response = await _apiClient.dio.get('/livestock/questions/review');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final list = List<Map<String, dynamic>>.from(data);
        state = state.copyWith(expertQueue: list);
      }
    } catch (_) {}
  }

  Future<void> fetchNotifications() async {
    try {
      final response = await _apiClient.dio.get('/notifications');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final list = data
            .map((json) => NotificationItem.fromJson(json))
            .toList();
        state = state.copyWith(notifications: list);
      }
    } catch (_) {}
  }

  Future<bool> askQuestion(String subject, String questionText) async {
    if (state.isSubmitting) return false;
    state = state.copyWith(isSubmitting: true);
    try {
      final response = await _apiClient.dio.post(
        '/livestock/questions',
        data: {'subject': subject, 'question': questionText},
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        state = state.copyWith(isSubmitting: false);
        await refreshAll();
        return true;
      }
      state = state.copyWith(isSubmitting: false);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.errorMessage);
      return false;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  Future<bool> answerQuestion(String questionId, String answerText) async {
    if (state.isSubmitting) return false;
    state = state.copyWith(isSubmitting: true);
    try {
      final response = await _apiClient.dio.put(
        '/livestock/questions/$questionId/answer',
        data: {'answer': answerText},
      );
      if (response.statusCode == 204 || response.statusCode == 200) {
        state = state.copyWith(isSubmitting: false);
        await refreshAll();
        return true;
      }
      state = state.copyWith(isSubmitting: false);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.errorMessage);
      return false;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _apiClient.dio.put('/notifications/$notificationId/read');
      // Optimistically update status in current list
      final updatedList = state.notifications.map((n) {
        if (n.id == notificationId) {
          return NotificationItem(
            id: n.id,
            type: n.type,
            title: n.title,
            body: n.body,
            data: n.data,
            readAt: DateTime.now(),
            createdAt: n.createdAt,
          );
        }
        return n;
      }).toList();
      state = state.copyWith(notifications: updatedList);
    } catch (_) {}
  }
}

final supportNotificationStateProvider =
    StateNotifierProvider<
      SupportNotificationNotifier,
      SupportNotificationState
    >((ref) {
      final api = ref.watch(apiClientProvider);
      final auth = ref.watch(authStateProvider);
      return SupportNotificationNotifier(api, auth.role);
    });
