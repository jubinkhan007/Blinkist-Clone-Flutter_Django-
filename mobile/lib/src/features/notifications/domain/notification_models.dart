class AppNotification {
  final int id;
  final String title;
  final String message;
  final String notificationType; // 'daily_pick', 'streak_reminder', 'new_book', 'subscription', 'system'
  final String? actionUrl;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.notificationType,
    this.actionUrl,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      notificationType: json['notification_type'] as String? ?? 'system',
      actionUrl: json['action_url'] as String?,
      isRead: json['is_read'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      notificationType: notificationType,
      actionUrl: actionUrl,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}

class NotificationPreferences {
  final bool dailyPickEnabled;
  final bool streakReminderEnabled;
  final String reminderTime; // e.g. "08:30:00"

  const NotificationPreferences({
    required this.dailyPickEnabled,
    required this.streakReminderEnabled,
    required this.reminderTime,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      dailyPickEnabled: json['daily_pick_enabled'] != false,
      streakReminderEnabled: json['streak_reminder_enabled'] != false,
      reminderTime: json['reminder_time'] as String? ?? '08:30:00',
    );
  }

  static NotificationPreferences defaults() {
    return const NotificationPreferences(
      dailyPickEnabled: true,
      streakReminderEnabled: true,
      reminderTime: '08:30:00',
    );
  }
}
