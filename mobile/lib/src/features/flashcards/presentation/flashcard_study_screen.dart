import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/flashcard_repository.dart';
import '../domain/flashcard_models.dart';

class FlashcardStudyScreen extends ConsumerStatefulWidget {
  final String? bookSlug;
  final bool isDailyReview;

  const FlashcardStudyScreen({
    super.key,
    this.bookSlug,
    this.isDailyReview = false,
  });

  @override
  ConsumerState<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends ConsumerState<FlashcardStudyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  int _currentIndex = 0;
  bool _isQuizMode = false;
  int? _selectedQuizOptionIndex;
  bool _isAnswerSubmitted = false;

  final Map<int, String> _cardReviews = {};
  int _masteredCount = 0;
  bool _isDeckFinished = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flipCard() {
    HapticFeedback.selectionClick();
    if (_flipController.isCompleted) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
  }

  Future<void> _recordReview(BookFlashcard card, String status, int totalCards) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _cardReviews[card.id] = status;
      if (status == 'mastered') {
        _masteredCount++;
      }
    });

    // Fire and forget review persistence
    try {
      await ref.read(flashcardRepositoryProvider).reviewCard(
            cardId: card.id,
            status: status,
          );
      ref.invalidate(dailyReviewDeckProvider);
      if (widget.bookSlug != null) {
        ref.invalidate(bookFlashcardsProvider(widget.bookSlug!));
      }
    } catch (e) {
      debugPrint('Failed to save flashcard review: $e');
    }

    _advanceCard(totalCards);
  }

  void _advanceCard(int totalCards) {
    if (_currentIndex + 1 < totalCards) {
      if (_flipController.isCompleted) {
        _flipController.reverse();
      }
      setState(() {
        _currentIndex++;
        _selectedQuizOptionIndex = null;
        _isAnswerSubmitted = false;
      });
    } else {
      setState(() {
        _isDeckFinished = true;
      });
    }
  }

  void _selectQuizOption(int optionIndex, BookFlashcard card, int totalCards) {
    if (_isAnswerSubmitted) return;
    HapticFeedback.lightImpact();

    final isCorrect = card.quizOptions[optionIndex].isCorrect;
    setState(() {
      _selectedQuizOptionIndex = optionIndex;
      _isAnswerSubmitted = true;
    });

    // Record review based on quiz correctness
    final status = isCorrect ? 'mastered' : 'review_later';
    _recordReview(card, status, totalCards);
  }

  void _restartSession(List<BookFlashcard> cards) {
    if (_flipController.isCompleted) {
      _flipController.reverse();
    }
    setState(() {
      _currentIndex = 0;
      _selectedQuizOptionIndex = null;
      _isAnswerSubmitted = false;
      _cardReviews.clear();
      _masteredCount = 0;
      _isDeckFinished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final AsyncValue<List<BookFlashcard>> cardsAsync;
    final String sessionTitle;

    if (widget.isDailyReview) {
      sessionTitle = 'Daily Active Recall';
      cardsAsync = ref.watch(dailyReviewDeckProvider).whenData((deck) => deck.cards);
    } else {
      sessionTitle = 'Knowledge Check & Recall';
      cardsAsync = ref.watch(bookFlashcardsProvider(widget.bookSlug!)).whenData((deck) => deck.cards);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(sessionTitle),
        actions: [
          if (!_isDeckFinished) ...[
            TextButton.icon(
              icon: Icon(
                _isQuizMode ? Icons.style_outlined : Icons.quiz_outlined,
                size: 18,
              ),
              label: Text(_isQuizMode ? 'Flip Cards' : 'Quiz Mode'),
              onPressed: () {
                setState(() {
                  _isQuizMode = !_isQuizMode;
                  _selectedQuizOptionIndex = null;
                  _isAnswerSubmitted = false;
                  if (_flipController.isCompleted) {
                    _flipController.reverse();
                  }
                });
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: cardsAsync.when(
        data: (cards) {
          if (cards.isEmpty) {
            return _buildEmptyState(context);
          }

          if (_isDeckFinished) {
            return _buildCompletionState(context, cards);
          }

          final currentCard = cards[_currentIndex];
          final progress = (_currentIndex + 1) / cards.length;

          return SafeArea(
            child: Column(
              children: [
                // Top Progress indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'Card ${_currentIndex + 1} of ${cards.length}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_masteredCount Mastered',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Main Card View
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: _isQuizMode
                        ? _buildQuizModeView(context, currentCard, cards.length)
                        : _buildFlipCardView(context, currentCard, cards.length),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Generating active recall cards...'),
            ],
          ),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Could not load flashcards: $error'),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () {
                    if (widget.isDailyReview) {
                      ref.invalidate(dailyReviewDeckProvider);
                    } else {
                      ref.invalidate(bookFlashcardsProvider(widget.bookSlug!));
                    }
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 🃏 Flip Card Mode
  // ---------------------------------------------------------
  Widget _buildFlipCardView(
    BuildContext context,
    BookFlashcard card,
    int totalCards,
  ) {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _flipCard,
            child: AnimatedBuilder(
              animation: _flipAnimation,
              builder: (context, child) {
                final angle = _flipAnimation.value * pi;
                final isUnder = _flipAnimation.value > 0.5;

                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(angle),
                  alignment: Alignment.center,
                  child: isUnder
                      ? Transform(
                          transform: Matrix4.identity()..rotateY(pi),
                          alignment: Alignment.center,
                          child: _buildBackCard(context, card),
                        )
                      : _buildFrontCard(context, card),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Action Controls (Available once flipped)
        AnimatedBuilder(
          animation: _flipAnimation,
          builder: (context, _) {
            final isFlipped = _flipAnimation.value > 0.5;
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isFlipped ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !isFlipped,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.orange.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.replay_rounded, color: Colors.orange),
                        label: const Text(
                          'Review Later',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () => _recordReview(card, 'review_later', totalCards),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.green.shade600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text(
                          'Mastered! 🟢',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _recordReview(card, 'mastered', totalCards),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFrontCard(BuildContext context, BookFlashcard card) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top tag
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    card.bookTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                if (card.sectionTitle != null) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '• ${card.sectionTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const Spacer(),
            // Question Prompt
            Text(
              card.frontPrompt,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
            const Spacer(),
            // Bottom Flip Hint
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Tap card to reveal answer',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackCard(BuildContext context, BookFlashcard card) {
    final theme = Theme.of(context);
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: theme.colorScheme.surface,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_rounded, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Core Key Insight',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                card.backAnswer,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                  fontSize: 16,
                ),
              ),
              if (card.keyQuote.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border(
                      left: BorderSide(color: theme.colorScheme.primary, width: 3),
                    ),
                  ),
                  child: Text(
                    card.keyQuote,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 📝 Quiz Mode View
  // ---------------------------------------------------------
  Widget _buildQuizModeView(
    BuildContext context,
    BookFlashcard card,
    int totalCards,
  ) {
    final theme = Theme.of(context);
    final options = card.quizOptions;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Knowledge Check',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  card.frontPrompt,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Select the most accurate insight:',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 10),
          // Multiple Choice Options
          ...List.generate(options.length, (idx) {
            final option = options[idx];
            final isSelected = _selectedQuizOptionIndex == idx;
            final isAnswered = _isAnswerSubmitted;

            Color borderColor = theme.colorScheme.outlineVariant;
            Color bgColor = theme.colorScheme.surface;
            Widget? iconWidget;

            if (isAnswered) {
              if (option.isCorrect) {
                borderColor = Colors.green;
                bgColor = Colors.green.withValues(alpha: 0.12);
                iconWidget = const Icon(Icons.check_circle, color: Colors.green, size: 20);
              } else if (isSelected && !option.isCorrect) {
                borderColor = Colors.red;
                bgColor = Colors.red.withValues(alpha: 0.12);
                iconWidget = const Icon(Icons.cancel, color: Colors.red, size: 20);
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: isAnswered
                    ? null
                    : () => _selectQuizOption(idx, card, totalCards),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                        child: Text(
                          String.fromCharCode(65 + idx), // A, B, C, D
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option.text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.3,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (iconWidget != null) ...[
                        const SizedBox(width: 8),
                        iconWidget,
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),

          // Explanation reveal when answered
          if (_isAnswerSubmitted && _selectedQuizOptionIndex != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: theme.colorScheme.secondary),
                      const SizedBox(width: 6),
                      Text(
                        'Why this is correct:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    options[_selectedQuizOptionIndex!].explanation.isNotEmpty
                        ? options[_selectedQuizOptionIndex!].explanation
                        : card.backAnswer,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Next Question'),
                onPressed: () => _advanceCard(totalCards),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // 🏁 Completion State
  // ---------------------------------------------------------
  Widget _buildCompletionState(BuildContext context, List<BookFlashcard> cards) {
    final theme = Theme.of(context);
    final scorePercent = (cards.isNotEmpty ? (_masteredCount / cards.length) * 100 : 0).toInt();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.military_tech_rounded,
                size: 52,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Session Complete! 🎉',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$_masteredCount of ${cards.length} insights mastered ($scorePercent%)',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Active recall strengthens neural pathways and prevents the forgetting curve.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Practice Again'),
                    onPressed: () => _restartSession(cards),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Done'),
                    onPressed: () => context.pop(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.style_outlined, size: 54, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No flashcards available yet.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Flashcards are generated from key chapter insights.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: () => context.pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
