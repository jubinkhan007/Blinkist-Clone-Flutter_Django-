import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/auth/auth_repository.dart';
import '../../../../core/subscription/subscription_repository.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../progress/data/progress_repository.dart';
import '../../notifications/data/notification_repository.dart';
import '../../onboarding/data/onboarding_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStatusProvider);

    // Show full-screen auth when logged out — no AppBar wrapper
    if (authAsync.valueOrNull == false) {
      return const AuthScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: [
          IconButton(
            tooltip: 'Edit profile',
            onPressed: () => context.push('/profile/edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(subscriptionInfoProvider);
              ref.invalidate(readingStatsProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: authAsync.when(
        data: (loggedIn) {
          if (!loggedIn) return const AuthScreen();

          final subAsync = ref.watch(subscriptionInfoProvider);
          return subAsync.when(
            data: (sub) {
              if (sub == null) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session expired',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please sign in again to manage your subscription.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () async {
                          await ref.read(authRepositoryProvider).logout();
                          ref.invalidate(authStatusProvider);
                          ref.invalidate(subscriptionInfoProvider);
                        },
                        icon: const Icon(Icons.login),
                        label: const Text('Sign in'),
                      ),
                    ],
                  ),
                );
              }

              final fullName = [
                sub.firstName?.trim(),
                sub.lastName?.trim(),
              ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
              final displayName = fullName.isNotEmpty
                  ? fullName
                  : (sub.username?.trim().isNotEmpty == true
                        ? sub.username!.trim()
                        : (sub.email ?? ''));
              final initials = displayName.isNotEmpty
                  ? displayName
                        .split(RegExp(r'\\s+'))
                        .where((p) => p.isNotEmpty)
                        .take(2)
                        .map((p) => p.characters.first.toUpperCase())
                        .join()
                  : 'U';

              final status = sub.subscriptionStatus ?? 'unknown';
              final isTrial = status == 'trialing';
              final trialDays = sub.trialDaysRemaining;
              final trialProgress = isTrial
                  ? ((7 - trialDays).clamp(0, 7) / 7.0)
                  : null;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    elevation: 0,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                            backgroundImage:
                                (sub.avatarUrl?.isNotEmpty ?? false)
                                ? NetworkImage(sub.avatarUrl!)
                                : null,
                            child: (sub.avatarUrl?.isNotEmpty ?? false)
                                ? null
                                : Text(
                                    initials,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if ((sub.email ?? '').isNotEmpty)
                                  Text(
                                    sub.email!,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if ((sub.bio ?? '').trim().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    sub.bio!.trim(),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusPill(
                            label: sub.isPremium ? 'Premium' : 'Free',
                            icon: sub.isPremium
                                ? Icons.verified
                                : Icons.lock_open,
                            color: sub.isPremium
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _ReadingHabitsAndStatsCard(),
                  const SizedBox(height: 16),
                  const _LearningGoalsCard(),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.workspace_premium,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Subscription',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _KeyValue(
                            icon: Icons.shield_outlined,
                            label: 'Status',
                            value: status,
                          ),
                          if (isTrial) ...[
                            const SizedBox(height: 10),
                            _KeyValue(
                              icon: Icons.timer_outlined,
                              label: 'Trial remaining',
                              value: '$trialDays day(s)',
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: trialProgress,
                                minHeight: 8,
                              ),
                            ),
                          ],
                          if (sub.subscriptionEndDate != null) ...[
                            const SizedBox(height: 10),
                            _KeyValue(
                              icon: Icons.event_outlined,
                              label: 'Renews/ends',
                              value: sub.subscriptionEndDate
                                  .toString()
                                  .split('.')
                                  .first,
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => context.push('/paywall'),
                                  icon: const Icon(Icons.manage_accounts),
                                  label: Text(
                                    sub.isPremium ? 'Manage plan' : 'Upgrade',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton.filledTonal(
                                tooltip: 'Refresh',
                                onPressed: () =>
                                    ref.invalidate(subscriptionInfoProvider),
                                icon: const Icon(Icons.refresh),
                              ),
                            ],
                          ),
                          if (status == 'active') ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                  side: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.error.withOpacity(0.5),
                                  ),
                                ),
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Cancel subscription'),
                                onPressed: () => _confirmCancel(context, ref),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _NotificationSettingsCard(),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.help_outline),
                          title: const Text('Help & support'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: null,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.privacy_tip_outlined),
                          title: const Text('Privacy'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await ref.read(authRepositoryProvider).logout();
                      ref.invalidate(authStatusProvider);
                      ref.invalidate(subscriptionInfoProvider);
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load account: $e'),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load auth status: $e')),
      ),
    );
  }
}

Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cancel Premium?'),
      content: const Text(
        'You\'ll lose access to premium features at the end of the current period.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Keep Premium'),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Cancel Subscription'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(subscriptionRepositoryProvider).cancelSubscription();
    ref.invalidate(subscriptionInfoProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Subscription cancelled.')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to cancel: $e')));
    }
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _KeyValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ReadingHabitsAndStatsCard extends ConsumerWidget {
  const _ReadingHabitsAndStatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(readingStatsProvider);

    return statsAsync.when(
      data: (stats) {
        final weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
        final todayWeekdayIndex = DateTime.now().weekday - 1; // 0 = Mon, 6 = Sun

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Flame Icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(
                          'Reading Habits & Stats',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '🏆 Best: ${stats.longestStreak}d',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Streak Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: stats.isActiveToday
                        ? Colors.amber.withValues(alpha: 0.12)
                        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        stats.isActiveToday
                            ? Icons.check_circle_rounded
                            : Icons.schedule_rounded,
                        color: stats.isActiveToday
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          stats.isActiveToday
                              ? '${stats.currentStreak}-day streak active today! Great job!'
                              : (stats.currentStreak > 0
                                  ? '${stats.currentStreak}-day streak! Read today to keep it going.'
                                  : 'Read any summary today to start a 1-day streak.'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Weekly Habit Tracker (M T W T F S S)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (i) {
                    final isDone = i < stats.weeklyActivity.length && stats.weeklyActivity[i];
                    final isToday = i == todayWeekdayIndex;

                    return Column(
                      children: [
                        Text(
                          weekdays[i],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isDone
                                ? Colors.amber.shade400
                                : (isToday ? Colors.amber.withValues(alpha: 0.15) : Colors.transparent),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDone
                                  ? Colors.amber.shade600
                                  : (isToday ? Colors.amber.shade600 : Colors.grey.withValues(alpha: 0.3)),
                              width: isToday ? 2.0 : 1.0,
                            ),
                          ),
                          child: Center(
                            child: isDone
                                ? const Icon(Icons.check, size: 16, color: Colors.black87)
                                : (isToday
                                    ? const Icon(Icons.star_outline, size: 14, color: Colors.amber)
                                    : null),
                          ),
                        ),
                      ],
                    );
                  }),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Lifetime 4-Stat Metric Grid
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.menu_book_rounded,
                        color: Colors.blue,
                        value: '${stats.totalBooksCompleted}',
                        label: 'Books Finished',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.article_outlined,
                        color: Colors.teal,
                        value: '${stats.totalSectionsRead}',
                        label: 'Blanks Read',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.headphones_rounded,
                        color: Colors.purple,
                        value: '${stats.totalAudioMinutes}m',
                        label: 'Audio Listened',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.border_color_rounded,
                        color: Colors.orange,
                        value: '${stats.totalHighlights}',
                        label: 'Quotes Saved',
                      ),
                    ),
                  ],
                ),

                // Badges Preview and Link to Detailed Stats
                if (stats.recentBadges.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Achievements',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${stats.unlockedBadgesCount}/${stats.totalBadgesCount} Unlocked',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: stats.recentBadges.map((badge) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🏅', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              badge.title,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/stats'),
                    icon: const Icon(Icons.insights_rounded, size: 18),
                    label: const Text('View Detailed Insights & Badges 🏆'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _MetricTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationSettingsCard extends ConsumerWidget {
  const _NotificationSettingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPreferencesProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Notifications & Reminders',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            prefsAsync.when(
              data: (prefs) => Column(
                children: [
                  SwitchListTile(
                    title: const Text('Daily Blink Reminder'),
                    subtitle: const Text(
                      'Get notified when today\'s free Blink of the Day is ready',
                    ),
                    value: prefs.dailyPickEnabled,
                    onChanged: (val) async {
                      try {
                        await ref
                            .read(notificationRepositoryProvider)
                            .updatePreferences(dailyPickEnabled: val);
                        ref.invalidate(notificationPreferencesProvider);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to update: $e')),
                          );
                        }
                      }
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Streak Protection Alert'),
                    subtitle: const Text(
                      'Get an evening reminder to protect your active reading streak',
                    ),
                    value: prefs.streakReminderEnabled,
                    onChanged: (val) async {
                      try {
                        await ref
                            .read(notificationRepositoryProvider)
                            .updatePreferences(streakReminderEnabled: val);
                        ref.invalidate(notificationPreferencesProvider);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to update: $e')),
                          );
                        }
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('Preferred Reminder Time'),
                    subtitle: Text(_formatTime(prefs.reminderTime)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final currentParts = prefs.reminderTime.split(':');
                      final initialHour = currentParts.isNotEmpty
                          ? int.tryParse(currentParts[0]) ?? 8
                          : 8;
                      final initialMinute = currentParts.length > 1
                          ? int.tryParse(currentParts[1]) ?? 30
                          : 30;

                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: initialHour,
                          minute: initialMinute,
                        ),
                      );

                      if (picked != null && context.mounted) {
                        final formatted =
                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00';
                        try {
                          await ref
                              .read(notificationRepositoryProvider)
                              .updatePreferences(reminderTime: formatted);
                          ref.invalidate(notificationPreferencesProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Reminder time updated!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to update: $e')),
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Unable to load preferences: $err'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String rawTime) {
    try {
      final parts = rawTime.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final period = hour >= 12 ? 'PM' : 'AM';
      final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      final m = minute.toString().padLeft(2, '0');
      return '$h:$m $period';
    } catch (_) {
      return rawTime;
    }
  }
}

class _LearningGoalsCard extends ConsumerWidget {
  const _LearningGoalsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(onboardingRepositoryProvider);
    final goalKey = repo.getSavedReadingGoal();
    final formatKey = repo.getSavedPreferredFormat();
    final topics = repo.getSavedInterestTopics();

    final goalOption = kReadingGoalOptions.firstWhere(
      (g) => g.id == goalKey,
      orElse: () => kReadingGoalOptions.first,
    );

    final formatLabel = formatKey == 'audio'
        ? '🎧 Listening'
        : (formatKey == 'text' ? '📖 Reading' : '⚡ Both text & audio');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('🎯', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      'Learning Goals & Interests',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.push('/onboarding'),
                  child: const Text('Adjust'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _KeyValue(
              icon: Icons.track_changes_rounded,
              label: 'Daily Goal',
              value: '${goalOption.emoji} ${goalOption.title}',
            ),
            const SizedBox(height: 10),
            _KeyValue(
              icon: Icons.auto_stories_outlined,
              label: 'Preferred Format',
              value: formatLabel,
            ),
            const SizedBox(height: 14),
            Text(
              'Selected Topics',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: (topics.isNotEmpty ? topics : ['productivity', 'psychology']).map((t) {
                final display = t.replaceAll('-', ' ').replaceAll('_', ' ');
                final capitalized = display.isEmpty
                    ? t
                    : '${display[0].toUpperCase()}${display.substring(1)}';

                return Chip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: Text(
                    capitalized,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}



