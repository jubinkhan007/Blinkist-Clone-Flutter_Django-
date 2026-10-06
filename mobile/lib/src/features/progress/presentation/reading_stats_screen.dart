import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/progress_repository.dart';
import '../domain/reading_stats_models.dart';

class ReadingStatsScreen extends ConsumerStatefulWidget {
  const ReadingStatsScreen({super.key});

  @override
  ConsumerState<ReadingStatsScreen> createState() => _ReadingStatsScreenState();
}

class _ReadingStatsScreenState extends ConsumerState<ReadingStatsScreen> {
  int _selectedPeriodIndex = 0; // 0 = Week, 1 = Month, 2 = All Time
  HeatmapDay? _selectedHeatmapDay;
  String _selectedBadgeCategory = 'all';

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(readingStatsProvider);
    final badgesAsync = ref.watch(badgesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Stats',
            onPressed: () {
              ref.invalidate(readingStatsProvider);
              ref.invalidate(badgesProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: statsAsync.when(
        data: (stats) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(readingStatsProvider);
              ref.invalidate(badgesProvider);
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildHeroStreakCard(context, stats),
                const SizedBox(height: 16),
                _buildPeriodBreakdownCard(context, stats),
                const SizedBox(height: 16),
                _buildHabitHeatmapCard(context, stats),
                const SizedBox(height: 16),
                badgesAsync.when(
                  data: (badges) => _buildBadgesSection(context, badges),
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text('Failed to load reading insights'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  ref.invalidate(readingStatsProvider);
                  ref.invalidate(badgesProvider);
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Hero Streak Flame Card
  Widget _buildHeroStreakCard(BuildContext context, UserReadingStats stats) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF2E1700), const Color(0xFF1F1100)]
              : [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('🔥', style: TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${stats.currentStreak} Day Streak',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.orange.shade300 : Colors.orange.shade900,
                        ),
                      ),
                      Text(
                        stats.isActiveToday
                            ? 'Completed for today! Keep it up!'
                            : (stats.currentStreak > 0
                                ? 'Read or listen today to continue'
                                : 'Start a streak today!'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade700, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      '${stats.longestStreak}d Record',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Quick lifetime metrics summary pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStat('Finished', '${stats.totalBooksCompleted} books'),
                _buildDivider(),
                _buildMiniStat('Read Time', '${stats.totalReadingMinutes}m'),
                _buildDivider(),
                _buildMiniStat('Audio Time', '${stats.totalAudioMinutes}m'),
                _buildDivider(),
                _buildMiniStat('Badges', '${stats.unlockedBadgesCount}/${stats.totalBadgesCount}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 24, color: Colors.grey.withValues(alpha: 0.3));
  }

  // 2. Listening vs. Reading Period Breakdown Card
  Widget _buildPeriodBreakdownCard(BuildContext context, UserReadingStats stats) {
    final theme = Theme.of(context);

    // Select stats by period
    final int readingMinutes;
    final int audioMinutes;
    final int booksCompleted;
    final int daysActive;

    if (_selectedPeriodIndex == 0) {
      readingMinutes = stats.weekly.readingMinutes;
      audioMinutes = stats.weekly.audioMinutes;
      booksCompleted = stats.weekly.booksCompleted;
      daysActive = stats.weekly.daysActive;
    } else if (_selectedPeriodIndex == 1) {
      readingMinutes = stats.monthly.readingMinutes;
      audioMinutes = stats.monthly.audioMinutes;
      booksCompleted = stats.monthly.booksCompleted;
      daysActive = stats.monthly.daysActive;
    } else {
      readingMinutes = stats.totalReadingMinutes;
      audioMinutes = stats.totalAudioMinutes;
      booksCompleted = stats.totalBooksCompleted;
      daysActive = stats.longestStreak;
    }

    final totalMinutes = readingMinutes + audioMinutes;
    final double readingRatio = totalMinutes > 0 ? (readingMinutes / totalMinutes) : 0.5;
    final double audioRatio = totalMinutes > 0 ? (audioMinutes / totalMinutes) : 0.5;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reading & Audio Breakdown',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Segmented control
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Week', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: 1, label: Text('Month', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: 2, label: Text('All', style: TextStyle(fontSize: 11))),
                  ],
                  selected: {_selectedPeriodIndex},
                  onSelectionChanged: (val) {
                    setState(() => _selectedPeriodIndex = val.first);
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Total time banner
            Row(
              children: [
                Text(
                  '${totalMinutes}m',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'total time spent learning',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Dual-tone proportional bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 14,
                child: Row(
                  children: [
                    if (totalMinutes == 0)
                      Expanded(
                        child: Container(color: Colors.grey.withValues(alpha: 0.2)),
                      )
                    else ...[
                      Expanded(
                        flex: (readingRatio * 100).toInt(),
                        child: Container(color: Colors.teal.shade500),
                      ),
                      Expanded(
                        flex: (audioRatio * 100).toInt(),
                        child: Container(color: Colors.purple.shade500),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Metric pills for formats
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.menu_book_rounded, size: 16, color: Colors.teal.shade700),
                            const SizedBox(width: 6),
                            const Text('Text Reading', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${readingMinutes}m',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                        ),
                        Text(
                          totalMinutes > 0 ? '${(readingRatio * 100).toInt()}% of total' : '0%',
                          style: TextStyle(fontSize: 11, color: Colors.teal.shade700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.headphones_rounded, size: 16, color: Colors.purple.shade700),
                            const SizedBox(width: 6),
                            const Text('Audio Listening', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${audioMinutes}m',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple.shade800),
                        ),
                        Text(
                          totalMinutes > 0 ? '${(audioRatio * 100).toInt()}% of total' : '0%',
                          style: TextStyle(fontSize: 11, color: Colors.purple.shade700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Days active & books completed summary row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(
                      'Active: $daysActive ${_selectedPeriodIndex == 2 ? "day record" : "days"}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.bookmark_added_rounded, size: 16, color: Colors.amber),
                    const SizedBox(width: 6),
                    Text(
                      'Completed: $booksCompleted books',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 3. 12-Week Commit Habit Heatmap Card
  Widget _buildHabitHeatmapCard(BuildContext context, UserReadingStats stats) {
    final theme = Theme.of(context);
    final days = stats.activityHeatmap;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Habit Consistency (12 Weeks)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Legend
                Row(
                  children: [
                    const Text('Less ', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    _buildHeatmapCellColor(0),
                    const SizedBox(width: 3),
                    _buildHeatmapCellColor(1),
                    const SizedBox(width: 3),
                    _buildHeatmapCellColor(2),
                    const SizedBox(width: 3),
                    _buildHeatmapCellColor(3),
                    const Text(' More', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Heatmap Grid: 7 rows x 12 columns
            if (days.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Day of week labels
                    Column(
                      children: const [
                        SizedBox(height: 16, child: Text('M', style: TextStyle(fontSize: 9, color: Colors.grey))),
                        SizedBox(height: 16, child: Text('T', style: TextStyle(fontSize: 9, color: Colors.grey))),
                        SizedBox(height: 16, child: Text('W', style: TextStyle(fontSize: 9, color: Colors.grey))),
                        SizedBox(height: 16, child: Text('T', style: TextStyle(fontSize: 9, color: Colors.grey))),
                        SizedBox(height: 16, child: Text('F', style: TextStyle(fontSize: 9, color: Colors.grey))),
                        SizedBox(height: 16, child: Text('S', style: TextStyle(fontSize: 9, color: Colors.grey))),
                        SizedBox(height: 16, child: Text('S', style: TextStyle(fontSize: 9, color: Colors.grey))),
                      ],
                    ),
                    const SizedBox(width: 8),

                    // Grid columns (12 weeks)
                    Row(
                      children: List.generate(12, (colIndex) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Column(
                            children: List.generate(7, (rowIndex) {
                              final dayIndex = (colIndex * 7) + rowIndex;
                              if (dayIndex >= days.length) return const SizedBox(width: 14, height: 16);
                              final day = days[dayIndex];
                              final isSelected = _selectedHeatmapDay?.date == day.date;

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedHeatmapDay = day;
                                  });
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  margin: const EdgeInsets.symmetric(vertical: 1),
                                  decoration: BoxDecoration(
                                    color: _getHeatmapColor(day.intensity),
                                    borderRadius: BorderRadius.circular(3),
                                    border: isSelected
                                        ? Border.all(color: Colors.amber, width: 2)
                                        : null,
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),

            // Selected cell inspection feedback
            if (_selectedHeatmapDay != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_formatDate(_selectedHeatmapDay!.date)}: ${_selectedHeatmapDay!.totalMinutes} min learning',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    if (_selectedHeatmapDay!.booksCompleted > 0)
                      Text(
                        '📚 ${_selectedHeatmapDay!.booksCompleted} book finished',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              const Text(
                'Tip: Tap any day square to see details.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmapCellColor(int intensity) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _getHeatmapColor(intensity),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Color _getHeatmapColor(int intensity) {
    switch (intensity) {
      case 1:
        return const Color(0xFF81C784); // light green
      case 2:
        return const Color(0xFF388E3C); // medium green
      case 3:
        return const Color(0xFF1B5E20); // deep emerald
      case 0:
      default:
        return Colors.grey.withValues(alpha: 0.22);
    }
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  // 4. Milestone Badges Showcase
  Widget _buildBadgesSection(BuildContext context, List<UserBadgeItem> badges) {
    final theme = Theme.of(context);
    final unlockedCount = badges.where((b) => b.isUnlocked).length;

    final filteredBadges = _selectedBadgeCategory == 'all'
        ? badges
        : badges.where((b) => b.category == _selectedBadgeCategory).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Achievement Badges',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$unlockedCount / ${badges.length} Unlocked',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCategoryChip('all', 'All Badges'),
              _buildCategoryChip('streaks', 'Streaks 🔥'),
              _buildCategoryChip('books', 'Books 📚'),
              _buildCategoryChip('audio', 'Audio 🎧'),
              _buildCategoryChip('highlights', 'Quotes 💡'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Grid of Badges
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredBadges.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.25,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final badge = filteredBadges[index];
            return _BadgeCard(badge: badge, onTap: () => _showBadgeDetailSheet(context, badge));
          },
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String category, String label) {
    final isSelected = _selectedBadgeCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: isSelected,
        showCheckmark: false,
        onSelected: (_) {
          setState(() => _selectedBadgeCategory = category);
        },
      ),
    );
  }

  void _showBadgeDetailSheet(BuildContext context, UserBadgeItem badge) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badge.isUnlocked
                      ? Colors.amber.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.15),
                  border: Border.all(
                    color: badge.isUnlocked ? Colors.amber : Colors.grey,
                    width: 2.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    _resolveBadgeIcon(badge.icon),
                    size: 36,
                    color: badge.isUnlocked ? Colors.amber.shade800 : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                badge.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                badge.description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              if (badge.isUnlocked) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Unlocked on ${_formatDate(badge.unlockedAt ?? DateTime.now())}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Progress', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('${badge.currentProgress} / ${badge.targetProgress}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: badge.progressPercent,
                        minHeight: 8,
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  static IconData _resolveBadgeIcon(String iconName) {
    switch (iconName) {
      case 'local_fire_department':
        return Icons.local_fire_department_rounded;
      case 'electric_bolt':
        return Icons.electric_bolt_rounded;
      case 'military_tech':
        return Icons.military_tech_rounded;
      case 'stars':
        return Icons.stars_rounded;
      case 'workspace_premium':
        return Icons.workspace_premium_rounded;
      case 'menu_book':
        return Icons.menu_book_rounded;
      case 'library_books':
        return Icons.library_books_rounded;
      case 'auto_stories':
        return Icons.auto_stories_rounded;
      case 'psychology':
        return Icons.psychology_rounded;
      case 'headphones':
        return Icons.headphones_rounded;
      case 'graphic_eq':
        return Icons.graphic_eq_rounded;
      case 'volume_up':
        return Icons.volume_up_rounded;
      case 'podcasts':
        return Icons.podcasts_rounded;
      case 'edit_note':
        return Icons.edit_note_rounded;
      case 'format_quote':
        return Icons.format_quote_rounded;
      case 'collections_bookmark':
        return Icons.collections_bookmark_rounded;
      case 'weekend':
        return Icons.weekend_rounded;
      default:
        return Icons.star_rounded;
    }
  }
}

class _BadgeCard extends StatelessWidget {
  final UserBadgeItem badge;
  final VoidCallback onTap;

  const _BadgeCard({required this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnlocked = badge.isUnlocked;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUnlocked
              ? Colors.amber.withValues(alpha: 0.08)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnlocked
                ? Colors.amber.withValues(alpha: 0.5)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: isUnlocked ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? Colors.amber.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _ReadingStatsScreenState._resolveBadgeIcon(badge.icon),
                    size: 20,
                    color: isUnlocked ? Colors.amber.shade800 : Colors.grey,
                  ),
                ),
                if (isUnlocked)
                  const Icon(Icons.check_circle_rounded, size: 16, color: Colors.green)
                else
                  Text(
                    '${(badge.progressPercent * 100).toInt()}%',
                    style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  badge.description,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
