import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../progress/data/action_plan_repository.dart';
import '../../../progress/domain/action_plan_models.dart';

class ActionPlanHomeWidget extends ConsumerWidget {
  const ActionPlanHomeWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activePlanAsync = ref.watch(activeActionPlanProvider);

    return activePlanAsync.when(
      data: (plan) {
        if (plan == null) {
          return _buildEmptyState(context);
        }
        return _buildActivePlanCard(context, ref, plan);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildActivePlanCard(
    BuildContext context,
    WidgetRef ref,
    ActionPlan plan,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final nextItem = plan.nextPendingItem;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0F291E), const Color(0xFF0D1F17)]
              : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00A86B).withOpacity(0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00A86B).withOpacity(isDark ? 0.15 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/action-plans/${plan.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A86B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'TODAY\'S MICRO-HABIT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            color: Colors.orange,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Streak Multiplier',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  plan.bookTitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : const Color(0xFF065F46),
                  ),
                ),
                const SizedBox(height: 4),
                if (nextItem != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'Day ${nextItem.dayNumber}: ${nextItem.title}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.check_circle_outline,
                          color: Color(0xFF00A86B),
                          size: 26,
                        ),
                        tooltip: 'Mark Complete',
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final repo = ref.read(actionPlanRepositoryProvider);
                          await repo.toggleItem(
                            planId: plan.id,
                            itemId: nextItem.id,
                            isCompleted: true,
                          );
                          ref.invalidate(activeActionPlanProvider);
                          ref.invalidate(actionPlansListProvider);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Habit checked off! Streak boosted 🔥'),
                              backgroundColor: Color(0xFF00A86B),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  if (nextItem.suggestedHabit.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      nextItem.suggestedHabit,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[300] : const Color(0xFF1E293B),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ] else ...[
                  const Text(
                    'All scheduled days completed! 🎉',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: plan.totalItemsCount > 0
                        ? plan.completedItemsCount / plan.totalItemsCount
                        : 0.0,
                    minHeight: 6,
                    backgroundColor:
                        isDark ? Colors.grey[800] : Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF00A86B),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${plan.progressPercent}% of ${plan.durationDays}-Day Sprint',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const Row(
                      children: [
                        Text(
                          'View Roadmap',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00A86B),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 10,
                          color: Color(0xFF00A86B),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return const SizedBox.shrink();
  }
}
