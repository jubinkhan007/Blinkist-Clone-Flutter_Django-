import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/networking/api_client.dart';
import '../../reader/presentation/audio_controller.dart';
import '../domain/daily_digest_models.dart';

class DailyDigestSheet extends ConsumerWidget {
  final DailyAudioDigest digest;

  const DailyDigestSheet({
    super.key,
    required this.digest,
  });

  static Future<void> show(BuildContext context, DailyAudioDigest digest) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DailyDigestSheet(digest: digest),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final audioState = ref.watch(audioControllerProvider);
    final controller = ref.read(audioControllerProvider.notifier);

    final isThisDigestActive =
        audioState.isDailyDigestMode && audioState.activeDigestId == digest.id;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.coffee_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'DAILY BLINK',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            digest.formattedDuration,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      digest.theme,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      digest.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // 3-Insight Track List
          Text(
            'TODAY\'S 3 KEY INSIGHTS',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),

          ...digest.items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isPlayingThisItem = isThisDigestActive &&
                audioState.currentIndex == index &&
                audioState.isPlaying;
            final isPausedThisItem = isThisDigestActive &&
                audioState.currentIndex == index &&
                !audioState.isPlaying;

            final coverUrl = item.coverImageUrl?.trim();
            final resolvedCoverUrl = (coverUrl == null || coverUrl.isEmpty)
                ? null
                : resolveServerUrl(coverUrl);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: (isPlayingThisItem || isPausedThisItem)
                    ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                    : theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (isPlayingThisItem || isPausedThisItem)
                      ? theme.colorScheme.primary.withOpacity(0.4)
                      : Colors.transparent,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: resolvedCoverUrl != null
                      ? Image.network(
                          resolvedCoverUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _coverFallback(theme),
                        )
                      : _coverFallback(theme),
                ),
                title: Text(
                  item.insightPrompt,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isPlayingThisItem
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${item.bookTitle} • ${item.authorName}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.formattedDuration,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        isPlayingThisItem
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        color: isPlayingThisItem
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        size: 32,
                      ),
                      onPressed: () {
                        if (isThisDigestActive && audioState.currentIndex == index) {
                          controller.togglePlayPause();
                        } else if (isThisDigestActive) {
                          controller.jumpToSection(index);
                        } else {
                          controller.loadDailyDigest(digest, startIndex: index);
                        }
                      },
                    ),
                  ],
                ),
                onTap: () {
                  if (item.bookSlug.isNotEmpty) {
                    Navigator.of(context).pop();
                    context.push('/books/${item.bookSlug}');
                  }
                },
              ),
            );
          }),

          const SizedBox(height: 12),

          // Sleep Timer Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bedtime_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Sleep Timer',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                children: [
                  _timerChip(context, ref, 'off', 'Off', audioState),
                  _timerChip(context, ref, '15m', '15m', audioState),
                  _timerChip(context, ref, 'end_of_summary', 'End of Brief', audioState),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Main Play / Pause CTA
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: Icon(
              (isThisDigestActive && audioState.isPlaying)
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              size: 24,
            ),
            label: Text(
              _getMainCtaLabel(isThisDigestActive, audioState),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            onPressed: () {
              if (isThisDigestActive) {
                controller.togglePlayPause();
              } else {
                final startIndex = digest.currentTrackIndex.clamp(0, digest.items.length - 1);
                final startPos = Duration(seconds: digest.currentPositionSeconds);
                controller.loadDailyDigest(
                  digest,
                  startIndex: startIndex,
                  startPosition: startPos,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  static Widget _coverFallback(ThemeData theme) {
    return Container(
      width: 44,
      height: 44,
      color: theme.colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.book_rounded, size: 22),
    );
  }

  Widget _timerChip(
    BuildContext context,
    WidgetRef ref,
    String mode,
    String label,
    AudioState audioState,
  ) {
    final theme = Theme.of(context);
    final isSelected = audioState.sleepTimerMode == mode;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (_) {
        ref.read(audioControllerProvider.notifier).setSleepTimer(mode);
      },
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selectedColor: theme.colorScheme.primaryContainer,
    );
  }

  String _getMainCtaLabel(bool isThisDigestActive, AudioState audioState) {
    if (isThisDigestActive) {
      if (audioState.isPlaying) {
        return 'Pause Daily Blink';
      }
      return 'Resume Daily Blink (Track ${audioState.currentIndex + 1})';
    }
    if (digest.isCompleted) {
      return 'Replay Daily Blink (${digest.formattedDuration})';
    }
    if (digest.currentTrackIndex > 0 || digest.currentPositionSeconds > 0) {
      return 'Resume Daily Blink (Track ${digest.currentTrackIndex + 1})';
    }
    return 'Start Your Daily Blink (${digest.formattedDuration})';
  }
}
