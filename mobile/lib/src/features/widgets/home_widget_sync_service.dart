import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import '../../../core/routing/deep_link_service.dart';
import '../media/data/daily_digest_repository.dart';
import '../media/domain/daily_digest_models.dart';
import '../progress/data/action_plan_repository.dart';
import '../progress/data/progress_repository.dart';
import '../progress/domain/action_plan_models.dart';

class HomeWidgetSyncService {
  static const String appGroupId = 'group.com.blinkist.clone';
  static const String androidDailyWidget = 'DailyBlinkWidgetProvider';
  static const String androidStreakWidget = 'StreakGoalWidgetProvider';
  static const String iOSDailyWidget = 'DailyBlinkWidget';
  static const String iOSStreakWidget = 'StreakGoalWidget';

  StreamSubscription<Uri?>? _widgetClickSubscription;

  /// Initializes the AppGroup ID on iOS and Android
  Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);
    } catch (e) {
      debugPrint('[HomeWidgetSyncService] Failed to set appGroupId: $e');
    }
  }

  /// Syncs today's Daily Audio Blink to home screen widgets
  Future<void> syncDailyDigest(DailyAudioDigest? digest) async {
    try {
      if (digest != null && digest.items.isNotEmpty) {
        final firstItem = digest.items.first;
        await HomeWidget.saveWidgetData<String>('daily_title', firstItem.bookTitle);
        await HomeWidget.saveWidgetData<String>('daily_author', firstItem.authorName);
        await HomeWidget.saveWidgetData<String>('daily_theme', digest.theme);
        await HomeWidget.saveWidgetData<String>('daily_formatted_duration', digest.formattedDuration);
        await HomeWidget.saveWidgetData<String>(
          'daily_first_prompt',
          firstItem.insightPrompt.isNotEmpty
              ? firstItem.insightPrompt
              : "1-tap play morning audio digest",
        );
        await HomeWidget.saveWidgetData<String>('daily_book_slug', firstItem.bookSlug);
        await HomeWidget.saveWidgetData<int>('daily_book_id', firstItem.bookId);
      } else {
        await HomeWidget.saveWidgetData<String>('daily_title', 'Daily Audio Blink');
        await HomeWidget.saveWidgetData<String>('daily_author', 'Blinkist');
        await HomeWidget.saveWidgetData<String>('daily_theme', 'Morning Digest');
        await HomeWidget.saveWidgetData<String>('daily_formatted_duration', '15 min');
        await HomeWidget.saveWidgetData<String>(
          'daily_first_prompt',
          '3 key insights to power your morning',
        );
      }

      await HomeWidget.updateWidget(
        name: androidDailyWidget,
        androidName: androidDailyWidget,
        iOSName: iOSDailyWidget,
      );
    } catch (e) {
      debugPrint('[HomeWidgetSyncService] syncDailyDigest error: $e');
    }
  }

  /// Syncs reading streak, daily goal progress, and active micro-habit action items
  Future<void> syncStreakAndGoal({
    required int currentStreak,
    required int todayMinutes,
    int goalMinutes = 15,
    String? activeActionPlanTitle,
    String? activeActionItem,
  }) async {
    try {
      await HomeWidget.saveWidgetData<int>('user_streak', currentStreak);
      await HomeWidget.saveWidgetData<int>('today_minutes', todayMinutes);
      await HomeWidget.saveWidgetData<int>('goal_minutes', goalMinutes.clamp(1, 120));
      await HomeWidget.saveWidgetData<String>(
        'active_action_plan_title',
        activeActionPlanTitle ?? "TODAY'S HABIT",
      );
      await HomeWidget.saveWidgetData<String>(
        'active_action_item',
        activeActionItem ?? "Listen to today's Blink to keep your streak",
      );

      await HomeWidget.updateWidget(
        name: androidStreakWidget,
        androidName: androidStreakWidget,
        iOSName: iOSStreakWidget,
      );
    } catch (e) {
      debugPrint('[HomeWidgetSyncService] syncStreakAndGoal error: $e');
    }
  }

  /// Synchronizes all home screen widgets at once using active app state
  Future<void> syncAll(WidgetRef ref) async {
    try {
      // 1. Sync Daily Digest
      final digest = ref.read(dailyDigestProvider).valueOrNull;
      if (digest != null) {
        await syncDailyDigest(digest);
      }

      // 2. Sync Streak & Daily Reading Goal
      final stats = ref.read(readingStatsProvider).valueOrNull;
      final plans = ref.read(actionPlansListProvider).valueOrNull;

      int currentStreak = stats?.currentStreak ?? 0;
      int todayMinutes = (stats?.totalReadingMinutes ?? 0) > 0 ? (stats!.totalReadingMinutes % 30) : 0;
      if (stats?.isActiveToday == true && todayMinutes == 0) {
        todayMinutes = 15;
      }

      String? planTitle;
      String? nextHabit;

      if (plans != null && plans.isNotEmpty) {
        final activePlan = plans.firstWhere(
          (p) => p.isActive && !p.isCompleted,
          orElse: () => plans.first,
        );

        planTitle = 'HABIT • ${activePlan.bookTitle}';
        final pendingItem = activePlan.items.firstWhere(
          (i) => !i.isCompleted,
          orElse: () => activePlan.items.isNotEmpty
              ? activePlan.items.last
              : ActionPlanItem(
                  id: 0,
                  dayNumber: 1,
                  title: 'Daily Action',
                  description: '',
                  suggestedHabit: '',
                ),
        );
        nextHabit = 'Day ${pendingItem.dayNumber}: ${pendingItem.title}';
      }

      await syncStreakAndGoal(
        currentStreak: currentStreak,
        todayMinutes: todayMinutes,
        goalMinutes: 15,
        activeActionPlanTitle: planTitle,
        activeActionItem: nextHabit,
      );
    } catch (e) {
      debugPrint('[HomeWidgetSyncService] syncAll error: $e');
    }
  }

  /// Listens to widget launch intents and interactive button taps
  void listenToWidgetClicks(BuildContext context) {
    _widgetClickSubscription?.cancel();

    // Check if initial cold launch came from a widget tap
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      if (uri != null && context.mounted) {
        _handleWidgetUri(context, uri);
      }
    });

    // Listen to background/foreground taps while app is running
    _widgetClickSubscription = HomeWidget.widgetClicked.listen((uri) {
      if (uri != null && context.mounted) {
        _handleWidgetUri(context, uri);
      }
    });
  }

  void _handleWidgetUri(BuildContext context, Uri uri) {
    debugPrint('[HomeWidgetSyncService] Handled widget click: $uri');
    final raw = uri.toString();
    DeepLinkService.handleActionUrl(context, raw);
  }

  void dispose() {
    _widgetClickSubscription?.cancel();
    _widgetClickSubscription = null;
  }
}

final homeWidgetSyncServiceProvider = Provider<HomeWidgetSyncService>((ref) {
  final service = HomeWidgetSyncService();
  service.init();
  ref.onDispose(() => service.dispose());
  return service;
});
