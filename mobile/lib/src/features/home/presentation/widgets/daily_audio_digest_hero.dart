import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/networking/api_client.dart';
import '../../../media/data/daily_digest_repository.dart';
import '../../../media/domain/daily_digest_models.dart';
import '../../../media/presentation/daily_digest_sheet.dart';
import '../../../reader/presentation/audio_controller.dart';

class DailyAudioDigestHero extends ConsumerWidget {
  const DailyAudioDigestHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final digestAsync = ref.watch(dailyDigestProvider);

    return digestAsync.when(
      data: (digest) {
        if (digest == null || digest.items.isEmpty) {
          return const SizedBox.shrink();
        }
        return _DailyAudioDigestHeroCard(digest: digest);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _DailyAudioDigestHeroCard extends ConsumerWidget {
  final DailyAudioDigest digest;

  const _DailyAudioDigestHeroCard({required this.digest});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final audioState = ref.watch(audioControllerProvider);
    final controller = ref.read(audioControllerProvider.notifier);

    final isThisDigestActive =
        audioState.isDailyDigestMode && audioState.activeDigestId == digest.id;
    final isPlaying = isThisDigestActive && audioState.isPlaying;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => DailyDigestSheet.show(context, digest),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF1E293B), // slate-800
                        const Color(0xFF0F172A), // slate-900
                      ]
                    : [
                        const Color(0xFFFFF7ED), // amber-50
                        const Color(0xFFFFEDD5), // amber-100
                      ],
              ),
              border: Border.all(
                color: isPlaying
                    ? theme.colorScheme.primary
                    : (isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFFDBA74).withOpacity(0.6)),
                width: isPlaying ? 2.0 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.3)
                      : const Color(0xFFF97316).withOpacity(0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tag & Duration Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF312E81).withOpacity(0.7)
                                : const Color(0xFFEA580C).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('☕', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 5),
                              Text(
                                'DAILY BLINK • MORNING DIGEST',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? const Color(0xFFA5B4FC)
                                      : const Color(0xFFC2410C),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (digest.isCompleted) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    size: 13, color: Colors.green),
                                SizedBox(width: 3),
                                Text(
                                  'Completed',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      digest.formattedDuration,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? Colors.grey.shade400
                            : const Color(0xFF78350F),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Main Title & Subtitle + 3-Book Covers Stack
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            digest.theme,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: isDark ? Colors.white : const Color(0xFF1C1917),
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isPlaying && audioState.currentSectionTitle != null
                                ? 'Now Playing: ${audioState.currentSectionTitle}'
                                : digest.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? Colors.grey.shade400
                                  : const Color(0xFF57534E),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    _buildCoversStack(digest.items),
                  ],
                ),

                const SizedBox(height: 16),

                // Interactive CTA Action Button + Equalizer / Progress
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPlaying
                              ? theme.colorScheme.primary
                              : (isDark
                                  ? theme.colorScheme.primary
                                  : const Color(0xFFEA580C)),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: isPlaying
                            ? const _AnimatedSoundWaves()
                            : Icon(
                                isThisDigestActive
                                    ? Icons.play_arrow_rounded
                                    : (digest.isCompleted
                                        ? Icons.replay_rounded
                                        : Icons.headphones_rounded),
                                size: 20,
                              ),
                        label: Text(
                          _getHeroCtaText(isThisDigestActive, audioState),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        onPressed: () {
                          if (isThisDigestActive) {
                            controller.togglePlayPause();
                          } else {
                            final startIndex = digest.currentTrackIndex
                                .clamp(0, digest.items.length - 1);
                            final startPos = Duration(
                              seconds: digest.currentPositionSeconds,
                            );
                            controller.loadDailyDigest(
                              digest,
                              startIndex: startIndex,
                              startPosition: startPos,
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      tooltip: 'View 3 Insights',
                      icon: const Icon(Icons.format_list_bulleted_rounded, size: 20),
                      onPressed: () => DailyDigestSheet.show(context, digest),
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

  Widget _buildCoversStack(List<DailyAudioDigestItem> items) {
    final covers = items.take(3).toList();
    if (covers.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 52,
      width: 28.0 * (covers.length - 1) + 40.0,
      child: Stack(
        children: covers.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final coverUrl = item.coverImageUrl?.trim();
          final resolvedCover = (coverUrl == null || coverUrl.isEmpty)
              ? null
              : resolveServerUrl(coverUrl);

          return Positioned(
            left: idx * 24.0,
            child: Container(
              width: 38,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(1, 2),
                  ),
                ],
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: resolvedCover != null
                    ? Image.network(
                        resolvedCover,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade700,
                          child: const Icon(Icons.book, size: 16, color: Colors.white70),
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade700,
                        child: const Icon(Icons.book, size: 16, color: Colors.white70),
                      ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getHeroCtaText(bool isThisDigestActive, AudioState audioState) {
    if (isThisDigestActive) {
      if (audioState.isPlaying) {
        return 'Playing • Tap to Pause';
      }
      return 'Resume Daily Blink (${audioState.currentIndex + 1}/${digest.items.length})';
    }
    if (digest.isCompleted) {
      return 'Listen Again • 100% Completed';
    }
    if (digest.currentTrackIndex > 0) {
      return 'Resume Brief (Track ${digest.currentTrackIndex + 1})';
    }
    return 'Start Your Daily Blink (3 Tracks)';
  }
}

class _AnimatedSoundWaves extends StatefulWidget {
  const _AnimatedSoundWaves();

  @override
  State<_AnimatedSoundWaves> createState() => _AnimatedSoundWavesState();
}

class _AnimatedSoundWavesState extends State<_AnimatedSoundWaves>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _bar(10 + (_controller.value * 8)),
            const SizedBox(width: 2.5),
            _bar(16 - (_controller.value * 8)),
            const SizedBox(width: 2.5),
            _bar(8 + (_controller.value * 10)),
          ],
        );
      },
    );
  }

  Widget _bar(double height) {
    return Container(
      width: 3,
      height: height.clamp(4.0, 18.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
