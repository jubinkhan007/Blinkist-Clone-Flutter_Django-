import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/networking/api_client.dart';
import '../domain/notification_models.dart';

class NotificationRepository {
  final Dio _dio;

  NotificationRepository(this._dio);

  Future<List<AppNotification>> fetchNotifications({bool unreadOnly = false}) async {
    try {
      final response = await _dio.get(
        '/notifications/',
        queryParameters: unreadOnly ? {'unread': 'true'} : null,
      );
      final data = response.data;
      final List<dynamic> list = data is Map ? (data['results'] ?? []) : data;
      return list
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return [];
      }
      rethrow;
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _dio.get('/notifications/unread-count/');
      return (response.data['unread_count'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return 0;
      }
      return 0;
    }
  }

  Future<void> markRead(int id) async {
    await _dio.post('/notifications/$id/read/');
  }

  Future<void> markAllRead() async {
    await _dio.post('/notifications/read-all/');
  }

  Future<NotificationPreferences> getPreferences() async {
    try {
      final response = await _dio.get('/notifications/preferences/');
      return NotificationPreferences.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return NotificationPreferences.defaults();
      }
      return NotificationPreferences.defaults();
    }
  }

  Future<NotificationPreferences> updatePreferences({
    bool? dailyPickEnabled,
    bool? streakReminderEnabled,
    String? reminderTime,
  }) async {
    final Map<String, dynamic> payload = {};
    if (dailyPickEnabled != null) payload['daily_pick_enabled'] = dailyPickEnabled;
    if (streakReminderEnabled != null) payload['streak_reminder_enabled'] = streakReminderEnabled;
    if (reminderTime != null) payload['reminder_time'] = reminderTime;

    final response = await _dio.patch('/notifications/preferences/', data: payload);
    return NotificationPreferences.fromJson(response.data as Map<String, dynamic>);
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(dioProvider));
});

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  return ref.watch(notificationRepositoryProvider).fetchNotifications();
});

final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  return ref.watch(notificationRepositoryProvider).getUnreadCount();
});

final notificationPreferencesProvider =
    FutureProvider<NotificationPreferences>((ref) async {
  return ref.watch(notificationRepositoryProvider).getPreferences();
});
