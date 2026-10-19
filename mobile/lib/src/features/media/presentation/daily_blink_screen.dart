import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/networking/api_client.dart';
import '../../reader/presentation/audio_controller.dart';
import '../data/daily_digest_repository.dart';

class DailyBlinkScreen extends ConsumerStatefulWidget {
  final bool autoPlayOnLaunch;
  const DailyBlinkScreen({super.key, this.autoPlayOnLaunch = false});

  @override
  ConsumerState<DailyBlinkScreen> createState() => _DailyBlinkScreenState();
}

class _DailyBlinkScreenState extends ConsumerState<DailyBlinkScreen> {
  bool _hasAutoPlayed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final digestAsync = ref.watch(dailyDigestProvider);
    final audioState = ref.watch(audioControllerProvider);
    final controller = ref.read(audioControllerProvider.notifier);

    if (widget.autoPlayOnLaunch && !_hasAutoPlayed) {
      digestAsync.whenData((digest) {
        if (digest != null && digest.items.isNotEmpty && !_hasAutoPlayed) {
          _hasAutoPlayed = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!audioState.isPlaying || audioState.activeDigestId != digest.id) {
              final startIdx = digest.currentTrackIndex.clamp(0, digest.items.length - 1);
              final startPos = Duration(seconds: digest.currentPositionSeconds);
              controller.loadDailyDigest(
                digest,
                startIndex: startIdx,
                startPosition: startPos,
                autoPlay: true,
              );
            }
          });
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Blink ☕'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Digest',
            onPressed: () => ref.refresh(dailyDigestProvider),
          ),
        ],
      ),
      body: digestAsync.when(
        data: (digest) {
          if (digest == null || digest.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.headset_off_rounded, size: 56, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No audio digest available for today.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Back to Home'),
                  ),
                ],
              ),
            );
          }

          final isThisActive = audioState.isDailyDigestMode &&
              audioState.activeDigestId == digest.id;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [const Color(0xFFFFF7ED), const Color(0xFFFFEDD5)],
                  ),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFFDBA74).withOpacity(0.6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA580C).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'MORNING RITUAL',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: const Color(0xFFC2410C),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          digest.formattedDuration,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF78350F),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      digest.theme,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      digest.subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        (isThisActive && audioState.isPlaying)
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(
                        (isThisActive && audioState.isPlaying)
                            ? 'Pause Audio Stream'
                            : (isThisActive
                                ? 'Resume Daily Blink'
                                : 'Start Continuous Stream (${digest.formattedDuration})'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        if (isThisActive) {
                          controller.togglePlayPause();
                        } else {
                          final startIdx = digest.currentTrackIndex
                              .clamp(0, digest.items.length - 1);
                          final startPos =
                              Duration(seconds: digest.currentPositionSeconds);
                          controller.loadDailyDigest(
                            digest,
                            startIndex: startIdx,
                            startPosition: startPos,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                '3 CURATED KEY INSIGHTS',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 12),

              ...digest.items.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final isPlayingThis = isThisActive &&
                    audioState.currentIndex == idx &&
                    audioState.isPlaying;

                final coverUrl = item.coverImageUrl?.trim();
                final resolvedCover = (coverUrl == null || coverUrl.isEmpty)
                    ? null
                    : resolveServerUrl(coverUrl);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isPlayingThis
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: resolvedCover != null
                              ? Image.network(
                                  resolvedCover,
                                  width: 50,
                                  height: 68,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 50,
                                    height: 68,
                                    color: Colors.grey.shade800,
                                    child: const Icon(Icons.book, size: 24),
                                  ),
                                )
                              : Container(
                                  width: 50,
                                  height: 68,
                                  color: Colors.grey.shade800,
                                  child: const Icon(Icons.book, size: 24),
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.insightPrompt,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isPlayingThis
                                      ? theme.colorScheme.primary
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item.bookTitle} • ${item.authorName}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 13,
                                    color: theme.colorScheme.outline,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.formattedDuration,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton.filledTonal(
                                    icon: Icon(
                                      isPlayingThis
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      if (isThisActive &&
                                          audioState.currentIndex == idx) {
                                        controller.togglePlayPause();
                                      } else if (isThisActive) {
                                        controller.jumpToSection(idx);
                                      } else {
                                        controller.loadDailyDigest(
                                          digest,
                                          startIndex: idx,
                                        );
                                      }
                                    },
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
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Failed to load Daily Blink digest.'),
              TextButton(
                onPressed: () => ref.refresh(dailyDigestProvider),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
