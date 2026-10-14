import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/action_plan_repository.dart';
import '../domain/action_plan_models.dart';

class ActionPlanScreen extends ConsumerStatefulWidget {
  final int? planId;
  final String? bookSlug;

  const ActionPlanScreen({
    super.key,
    this.planId,
    this.bookSlug,
  });

  @override
  ConsumerState<ActionPlanScreen> createState() => _ActionPlanScreenState();
}

class _ActionPlanScreenState extends ConsumerState<ActionPlanScreen> {
  bool _isGenerating = false;
  int _selectedDuration = 7;
  ActionPlan? _localPlan;

  @override
  void initState() {
    super.initState();
    if (widget.planId == null && widget.bookSlug != null) {
      _checkOrGenerateInitialPlan();
    }
  }

  Future<void> _checkOrGenerateInitialPlan() async {
    final repo = ref.read(actionPlanRepositoryProvider);
    try {
      final existing = await repo.fetchActionPlans(bookSlug: widget.bookSlug);
      if (existing.isNotEmpty && mounted) {
        setState(() {
          _localPlan = existing.first;
        });
      } else {
        await _generatePlan(duration: 7);
      }
    } catch (_) {
      // If error, let build state handle or offer generate button
    }
  }

  Future<void> _generatePlan({required int duration, bool force = false}) async {
    if (widget.bookSlug == null && _localPlan == null) return;
    final slug = widget.bookSlug ?? _localPlan?.bookSlug;
    if (slug == null) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      final repo = ref.read(actionPlanRepositoryProvider);
      final newPlan = await repo.generateActionPlan(
        bookSlug: slug,
        durationDays: duration,
        forceRegenerate: force,
      );
      if (mounted) {
        setState(() {
          _localPlan = newPlan;
          _isGenerating = false;
        });
        ref.invalidate(actionPlansListProvider);
        ref.invalidate(activeActionPlanProvider);
        if (widget.planId != null) {
          ref.invalidate(actionPlanDetailProvider(widget.planId!));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate action plan: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _toggleItem(int itemId, bool currentStatus) async {
    final plan = _localPlan;
    if (plan == null) return;

    // Optimistic local update
    final updatedItems = plan.items.map((item) {
      if (item.id == itemId) {
        return item.copyWith(isCompleted: !currentStatus);
      }
      return item;
    }).toList();

    final completedCount = updatedItems.where((i) => i.isCompleted).length;
    final progress = (completedCount / updatedItems.length * 100).round();

    setState(() {
      _localPlan = ActionPlan(
        id: plan.id,
        bookId: plan.bookId,
        bookTitle: plan.bookTitle,
        bookSlug: plan.bookSlug,
        bookAuthor: plan.bookAuthor,
        bookCoverImageUrl: plan.bookCoverImageUrl,
        title: plan.title,
        durationDays: plan.durationDays,
        isActive: plan.isActive,
        isCompleted: completedCount >= updatedItems.length,
        progressPercent: progress,
        completedItemsCount: completedCount,
        totalItemsCount: updatedItems.length,
        items: updatedItems,
        createdAt: plan.createdAt,
        completedAt: completedCount >= updatedItems.length ? DateTime.now() : null,
      );
    });

    try {
      final repo = ref.read(actionPlanRepositoryProvider);
      final savedPlan = await repo.toggleItem(
        planId: plan.id,
        itemId: itemId,
        isCompleted: !currentStatus,
      );

      if (mounted) {
        setState(() {
          _localPlan = savedPlan;
        });
        ref.invalidate(actionPlansListProvider);
        ref.invalidate(activeActionPlanProvider);
        if (widget.planId != null) {
          ref.invalidate(actionPlanDetailProvider(widget.planId!));
        }

        if (!currentStatus) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.local_fire_department, color: Colors.orangeAccent),
                  SizedBox(width: 8),
                  Text('Streak boosted! Day marked complete. 🔥'),
                ],
              ),
              duration: Duration(seconds: 2),
              backgroundColor: Color(0xFF1E293B),
            ),
          );
        }
      }
    } catch (e) {
      // Revert if API failed
      if (mounted) {
        setState(() {
          _localPlan = plan;
        });
      }
    }
  }

  void _showExportModal(ActionPlan plan) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _ExportBottomSheet(
          planId: plan.id,
          planTitle: plan.title,
        );
      },
    );
  }

  void _showDurationPickerModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose Habit Sprint Length',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Synthesize a brand new micro-habit roadmap using Gemini & your saved highlights.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE0E7FF),
                    child: Text('7', style: TextStyle(color: Color(0xFF4338CA), fontWeight: FontWeight.bold)),
                  ),
                  title: const Text('7-Day Habit Sprint'),
                  subtitle: const Text('Fast momentum on the book\'s highest-leverage insight'),
                  trailing: _selectedDuration == 7 ? const Icon(Icons.check, color: Color(0xFF00A86B)) : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: _selectedDuration == 7 ? const Color(0xFFF0FDF4) : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _selectedDuration = 7);
                    _generatePlan(duration: 7, force: true);
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFEF3C7),
                    child: Text('14', style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold)),
                  ),
                  title: const Text('14-Day Micro-Habit Roadmap'),
                  subtitle: const Text('Complete behavior transformation across all core principles'),
                  trailing: _selectedDuration == 14 ? const Icon(Icons.check, color: Color(0xFF00A86B)) : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: _selectedDuration == 14 ? const Color(0xFFF0FDF4) : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _selectedDuration = 14);
                    _generatePlan(duration: 14, force: true);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_localPlan != null) {
      return _buildPlanContent(_localPlan!);
    }

    if (widget.planId != null) {
      final asyncPlan = ref.watch(actionPlanDetailProvider(widget.planId!));
      return asyncPlan.when(
        data: (plan) {
          _localPlan = plan;
          return _buildPlanContent(plan);
        },
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Action Plan')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (err, stack) => Scaffold(
          appBar: AppBar(title: const Text('Action Plan')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading plan: $err'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(actionPlanDetailProvider(widget.planId!)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isGenerating) {
      return Scaffold(
        appBar: AppBar(title: const Text('Action Plan')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF00A86B)),
              const SizedBox(height: 24),
              const Text(
                'Synthesizing Micro-Habits with Gemini...',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Merging book mental models and your personal margin notes into a daily roadmap.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Action Plan & Habits')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.checklist_rtl_rounded, size: 64, color: Color(0xFF00A86B)),
              const SizedBox(height: 16),
              const Text(
                'No Action Plan Yet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Turn this book\'s insights into real-world behavior with an interactive 7 or 14-day habit sprint.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate Action Plan (Gemini)'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00A86B),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () => _generatePlan(duration: 7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanContent(ActionPlan plan) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(plan.bookTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Export & Integrations',
            onPressed: () => _showExportModal(plan),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Plan Options',
            onPressed: _showDurationPickerModal,
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Book Card Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00A86B).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${plan.durationDays}-Day Habit Sprint',
                                style: const TextStyle(
                                  color: Color(0xFF00A86B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${plan.completedItemsCount}/${plan.totalItemsCount} Done',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          plan.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'by ${plan.bookAuthor}',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: plan.totalItemsCount > 0
                                ? plan.completedItemsCount / plan.totalItemsCount
                                : 0.0,
                            minHeight: 8,
                            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              plan.isCompleted ? const Color(0xFF00A86B) : const Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${plan.progressPercent}% Completed',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                            if (plan.isCompleted)
                              const Row(
                                children: [
                                  Icon(Icons.check_circle, color: Color(0xFF00A86B), size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Roadmap Mastered!',
                                    style: TextStyle(
                                      color: Color(0xFF00A86B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Streak Multiplier Callout
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF451A03), const Color(0xFF78350F)]
                            : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_fire_department, color: Colors.orange, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Daily Streak Active: Check off daily habits to multiply your streak!',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.amber[200] : const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Daily Micro-Habit Timeline',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Items Timeline
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = plan.items[index];
                  return _DailyHabitCard(
                    item: item,
                    onToggle: () => _toggleItem(item.id, item.isCompleted),
                  );
                },
                childCount: plan.items.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      ),
    );
  }
}

class _DailyHabitCard extends StatelessWidget {
  final ActionPlanItem item;
  final VoidCallback onToggle;

  const _DailyHabitCard({
    required this.item,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isCompleted
              ? const Color(0xFF00A86B).withOpacity(0.4)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: item.isCompleted ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Custom checkbox
                InkWell(
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: item.isCompleted
                          ? const Color(0xFF00A86B)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: item.isCompleted
                            ? const Color(0xFF00A86B)
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: item.isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.isCompleted
                                  ? const Color(0xFF00A86B).withOpacity(0.12)
                                  : (isDark ? Colors.grey[800] : Colors.grey[200]),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Day ${item.dayNumber}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: item.isCompleted
                                    ? const Color(0xFF00A86B)
                                    : (isDark ? Colors.grey[300] : Colors.grey[700]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (item.isCompleted)
                            const Text(
                              'Completed ✨',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF00A86B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                          color: item.isCompleted
                              ? (isDark ? Colors.grey[500] : Colors.grey[400])
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.description,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? Colors.grey[300] : const Color(0xFF334155),
              ),
            ),
            if (item.suggestedHabit.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💡 ', style: TextStyle(fontSize: 14)),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[300] : const Color(0xFF1E293B),
                          ),
                          children: [
                            const TextSpan(
                              text: 'Micro-Habit Formula: ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: item.suggestedHabit),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (item.associatedQuote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF172554) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.format_quote, size: 16, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.associatedQuote,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExportBottomSheet extends ConsumerStatefulWidget {
  final int planId;
  final String planTitle;

  const _ExportBottomSheet({
    required this.planId,
    required this.planTitle,
  });

  @override
  ConsumerState<_ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends ConsumerState<_ExportBottomSheet> {
  bool _isLoading = false;
  ActionPlanExportPayload? _payload;

  @override
  void initState() {
    super.initState();
    _loadExportData();
  }

  Future<void> _loadExportData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(actionPlanRepositoryProvider);
      final data = await repo.exportPlan(widget.planId);
      if (mounted) {
        setState(() {
          _payload = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: const Color(0xFF00A86B),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.file_upload_outlined, color: Color(0xFF00A86B)),
                const SizedBox(width: 10),
                const Text(
                  'Export & Integrations',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Export your habits to your favorite productivity tools or calendar.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_payload != null) ...[
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE0F2FE),
                  child: Icon(Icons.code, color: Color(0xFF0369A1)),
                ),
                title: const Text('Copy Markdown Checklist'),
                subtitle: const Text('Ready for Obsidian, Logseq, or GitHub notes'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () => _copyToClipboard(_payload!.markdown, 'Markdown checklist'),
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF3E8FF),
                  child: Icon(Icons.edit_note, color: Color(0xFF7E22CE)),
                ),
                title: const Text('Copy Notion-Ready Format'),
                subtitle: const Text('Checkboxes and quote callout blocks for Notion'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () => _copyToClipboard(_payload!.notionText, 'Notion format'),
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFDCFCE7),
                  child: Icon(Icons.calendar_month, color: Color(0xFF15803D)),
                ),
                title: const Text('Export Calendar (.ics)'),
                subtitle: const Text('Copy iCalendar event file text for Apple Calendar & Google Calendar'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () => _copyToClipboard(_payload!.icsContent, 'Calendar .ics content'),
              ),
            ] else
              const Text('Could not load export options. Please try again.'),
          ],
        ),
      ),
    );
  }
}
