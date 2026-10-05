import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing/deep_link_service.dart';
import '../data/notification_repository.dart';
import '../domain/notification_models.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _selectedFilter = 'all'; // all, unread, daily_pick, streak_reminder, new_book, system

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          // Simulate Test Notification (for development and deep-link verification)
          IconButton(
            icon: const Icon(Icons.add_alert_outlined),
            tooltip: 'Simulate Notification',
            onPressed: () => _showSimulateSheet(context),
          ),
          // Notification Preferences
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Notification Preferences',
            onPressed: () => _showPreferencesSheet(context),
          ),
          // Mark all as read
          notificationsAsync.maybeWhen(
            data: (list) {
              final hasUnread = list.any((n) => !n.isRead);
              if (!hasUnread) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.done_all_rounded),
                tooltip: 'Mark all read',
                onPressed: () async {
                  await ref.read(notificationRepositoryProvider).markAllRead();
                  ref.invalidate(notificationsProvider);
                  ref.invalidate(unreadNotificationCountProvider);
                },
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: notificationsAsync.when(
              data: (notifications) {
                final filtered = _filterNotifications(notifications);

                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(notificationsProvider);
                    ref.invalidate(unreadNotificationCountProvider);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final notification = filtered[index];
                      return Dismissible(
                        key: ValueKey('notification_${notification.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(Icons.delete_sweep_rounded, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Dismiss',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        onDismissed: (_) async {
                          await ref
                              .read(notificationRepositoryProvider)
                              .deleteNotification(notification.id);
                          ref.invalidate(notificationsProvider);
                          ref.invalidate(unreadNotificationCountProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Notification dismissed'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: _NotificationCard(notification: notification),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    const Text('Failed to load notifications'),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        ref.invalidate(notificationsProvider);
                        ref.invalidate(unreadNotificationCountProvider);
                      },
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'all', 'label': 'All'},
      {'key': 'unread', 'label': 'Unread'},
      {'key': 'daily_pick', 'label': 'Daily Picks'},
      {'key': 'streak_reminder', 'label': 'Streaks'},
      {'key': 'new_book', 'label': 'New Books'},
      {'key': 'system', 'label': 'System'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f['label']!),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = f['key']!;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  List<AppNotification> _filterNotifications(List<AppNotification> list) {
    switch (_selectedFilter) {
      case 'unread':
        return list.where((n) => !n.isRead).toList();
      case 'daily_pick':
        return list.where((n) => n.notificationType == 'daily_pick').toList();
      case 'streak_reminder':
        return list.where((n) => n.notificationType == 'streak_reminder').toList();
      case 'new_book':
        return list.where((n) => n.notificationType == 'new_book').toList();
      case 'system':
        return list.where((n) => n.notificationType == 'system' || n.notificationType == 'subscription').toList();
      case 'all':
      default:
        return list;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _selectedFilter == 'unread'
                  ? 'No unread notifications'
                  : 'All caught up!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'all'
                  ? 'You will see your daily pick notifications, streak reminders, and book updates right here.'
                  : 'There are no notifications matching the selected filter.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPreferencesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => const _NotificationPreferencesSheet(),
    );
  }

  void _showSimulateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => const _SimulateNotificationSheet(),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  final AppNotification notification;

  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (icon, iconColor, iconBg) = _getTypeVisuals(notification.notificationType, theme);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        if (!notification.isRead) {
          await ref.read(notificationRepositoryProvider).markRead(notification.id);
          ref.invalidate(notificationsProvider);
          ref.invalidate(unreadNotificationCountProvider);
        }

        if (context.mounted &&
            notification.actionUrl != null &&
            notification.actionUrl!.isNotEmpty) {
          DeepLinkService.handleActionUrl(context, notification.actionUrl);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notification.isRead
              ? theme.colorScheme.surface
              : theme.colorScheme.primaryContainer.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notification.isRead
                ? theme.colorScheme.outlineVariant.withValues(alpha: 0.5)
                : theme.colorScheme.primary.withValues(alpha: 0.35),
            width: notification.isRead ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: notification.isRead
                                ? FontWeight.w600
                                : FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTimestamp(notification.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      if (notification.actionUrl != null &&
                          notification.actionUrl!.isNotEmpty)
                        Row(
                          children: [
                            Text(
                              'Open',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 10,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color, Color) _getTypeVisuals(String type, ThemeData theme) {
    switch (type) {
      case 'daily_pick':
        return (
          Icons.star_rounded,
          Colors.amber.shade800,
          Colors.amber.withValues(alpha: 0.18),
        );
      case 'streak_reminder':
        return (
          Icons.local_fire_department_rounded,
          Colors.deepOrange,
          Colors.deepOrange.withValues(alpha: 0.18),
        );
      case 'new_book':
        return (
          Icons.menu_book_rounded,
          Colors.teal,
          Colors.teal.withValues(alpha: 0.18),
        );
      case 'subscription':
        return (
          Icons.workspace_premium_rounded,
          Colors.purple,
          Colors.purple.withValues(alpha: 0.18),
        );
      default:
        return (
          Icons.notifications_rounded,
          theme.colorScheme.primary,
          theme.colorScheme.primary.withValues(alpha: 0.15),
        );
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dt.month}/${dt.day}/${dt.year}';
    }
  }
}

class _NotificationPreferencesSheet extends ConsumerStatefulWidget {
  const _NotificationPreferencesSheet();

  @override
  ConsumerState<_NotificationPreferencesSheet> createState() =>
      _NotificationPreferencesSheetState();
}

class _NotificationPreferencesSheetState
    extends ConsumerState<_NotificationPreferencesSheet> {
  bool? _dailyPick;
  bool? _streakReminder;
  String? _reminderTime;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(notificationPreferencesProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: prefsAsync.when(
        data: (prefs) {
          final currentDaily = _dailyPick ?? prefs.dailyPickEnabled;
          final currentStreak = _streakReminder ?? prefs.streakReminderEnabled;
          final currentTime = _reminderTime ?? prefs.reminderTime;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notification Settings',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Free Daily Pick Alert'),
                subtitle: const Text('Receive a reminder when today’s free Blink is unlocked.'),
                value: currentDaily,
                onChanged: _isSaving
                    ? null
                    : (val) async {
                        setState(() => _dailyPick = val);
                        await _updatePreferences(dailyPick: val);
                      },
              ),
              SwitchListTile(
                title: const Text('Habit & Streak Reminders'),
                subtitle: const Text('Keep your reading streak alive with friendly nudges.'),
                value: currentStreak,
                onChanged: _isSaving
                    ? null
                    : (val) async {
                        setState(() => _streakReminder = val);
                        await _updatePreferences(streakReminder: val);
                      },
              ),
              ListTile(
                title: const Text('Preferred Reminder Time'),
                subtitle: Text('Current: ${currentTime.substring(0, 5)}'),
                trailing: const Icon(Icons.access_time_rounded),
                onTap: _isSaving
                    ? null
                    : () async {
                        final parts = currentTime.split(':');
                        final initialHour = int.tryParse(parts[0]) ?? 8;
                        final initialMinute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
                        );

                        if (picked != null) {
                          final formatted =
                              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00';
                          setState(() => _reminderTime = formatted);
                          await _updatePreferences(reminderTime: formatted);
                        }
                      },
              ),
              const SizedBox(height: 12),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text('Error loading preferences: $e')),
        ),
      ),
    );
  }

  Future<void> _updatePreferences({
    bool? dailyPick,
    bool? streakReminder,
    String? reminderTime,
  }) async {
    setState(() => _isSaving = true);
    try {
      await ref.read(notificationRepositoryProvider).updatePreferences(
            dailyPickEnabled: dailyPick,
            streakReminderEnabled: streakReminder,
            reminderTime: reminderTime,
          );
      ref.invalidate(notificationPreferencesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _SimulateNotificationSheet extends ConsumerStatefulWidget {
  const _SimulateNotificationSheet();

  @override
  ConsumerState<_SimulateNotificationSheet> createState() =>
      _SimulateNotificationSheetState();
}

class _SimulateNotificationSheetState
    extends ConsumerState<_SimulateNotificationSheet> {
  bool _isCreating = false;

  final List<Map<String, String>> _presets = [
    {
      'title': '🌟 Daily Blink Unlocked: Atomic Habits',
      'message': 'Today\'s 15-minute insight on building good habits is ready. Read now!',
      'type': 'daily_pick',
      'action_url': '/books/atomic-habits/read',
      'desc': 'Text Reader Deep Link',
    },
    {
      'title': '🎧 Resume Audio: Deep Work',
      'message': 'Pick up right where you left off at Chapter 2 (0:45).',
      'type': 'new_book',
      'action_url': '/books/deep-work/listen?section=1&pos=45',
      'desc': 'Audio Player Seek Deep Link',
    },
    {
      'title': '✨ Curated Bundle: Peak Productivity',
      'message': 'Explore 5 hand-picked books to supercharge your daily workflow.',
      'type': 'system',
      'action_url': '/collections/productivity-masterclass',
      'desc': 'Themed Collection Deep Link',
    },
    {
      'title': '📓 My Notebook & Key Quotes',
      'message': 'Review your highlighted quotes and audio bookmarks.',
      'type': 'system',
      'action_url': '/library?tab=notebook',
      'desc': 'Library Notebook Tab Deep Link',
    },
    {
      'title': '📥 Offline Downloads Ready',
      'message': 'Your audio summaries are stored on your device for offline flights.',
      'type': 'system',
      'action_url': '/library?tab=downloads',
      'desc': 'Library Downloads Tab Deep Link',
    },
    {
      'title': '🔍 Trending Search: Mindfulness',
      'message': 'Discover the highest rated summaries in Mindfulness & Focus.',
      'type': 'system',
      'action_url': '/explore?category=psychology&search=mindfulness',
      'desc': 'Explore Pre-filtered Deep Link',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Simulate Deep Link Alert',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Select a preset to create a live notification and test deep linking across the app:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          if (_isCreating)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _presets.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final preset = _presets[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.bolt_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      preset['title']!,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preset['desc']!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          preset['action_url']!,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _triggerPreset(preset),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _triggerPreset(Map<String, String> preset) async {
    setState(() => _isCreating = true);
    try {
      await ref.read(notificationRepositoryProvider).simulateNotification(
            type: preset['type']!,
            title: preset['title'],
            message: preset['message'],
            actionUrl: preset['action_url'],
          );

      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created notification: ${preset['title']}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to simulate notification: $e')),
        );
      }
    }
  }
}
