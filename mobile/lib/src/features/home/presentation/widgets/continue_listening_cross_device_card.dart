import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../book/data/content_repository.dart';
import '../../../progress/data/progress_repository.dart';
import '../../../reader/presentation/audio_controller.dart';

class ContinueListeningCrossDeviceCard extends ConsumerStatefulWidget {
  const ContinueListeningCrossDeviceCard({super.key});

  @override
  ConsumerState<ContinueListeningCrossDeviceCard> createState() =>
      _ContinueListeningCrossDeviceCardState();
}

class _ContinueListeningCrossDeviceCardState
    extends ConsumerState<ContinueListeningCrossDeviceCard> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final sessionAsync = ref.watch(crossDevicePlaybackSessionProvider);

    return sessionAsync.when(
      data: (session) {
        if (session == null ||
            !session.hasActiveSession ||
            !session.canResume ||
            session.deviceType != 'web') {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF064E3B), const Color(0xFF0F172A)]
                  : [const Color(0xFFD1FAE5), const Color(0xFFF0FDF4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.laptop_mac_rounded,
                          size: 16,
                          color: Color(0xFF059669),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CONTINUE FROM DESKTOP WEB',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF059669),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: Colors.grey,
                    onPressed: () => setState(() => _dismissed = true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (session.coverImageUrl != null &&
                      session.coverImageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        session.coverImageUrl!,
                        width: 48,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 48,
                          height: 64,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.book, size: 24),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.bookTitle ?? 'Audio Summary',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          session.authorName ?? 'Author',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pick up at ${session.formattedPosition}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF059669),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    setState(() => _dismissed = true);
                    final bookSlug = session.bookSlug;
                    if (bookSlug == null) return;

                    // Handoff to mobile
                    await ref
                        .read(progressRepositoryProvider)
                        .handoffPlaybackSession();

                    // Load book in audio controller and seek
                    try {
                      final book = await ref
                          .read(contentRepositoryProvider)
                          .getBookDetail(bookSlug);

                      await ref.read(audioControllerProvider.notifier).loadBook(
                            bookId: book.id,
                            bookSlug: book.slug,
                            bookTitle: book.title,
                            authorName: book.author.name,
                            coverImageUrl: book.coverImageUrl,
                            sections: book.sections,
                            startIndex:
                                (session.sectionOrder - 1).clamp(0, book.sections.length - 1),
                            startPosition: Duration(
                              seconds: session.positionSeconds.toInt(),
                            ),
                            autoPlay: true,
                          );

                      if (context.mounted) {
                        context.push('/audio-player');
                      }
                    } catch (e) {
                      debugPrint('Failed to resume handoff: $e');
                    }
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text('Resume at ${session.formattedPosition}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
