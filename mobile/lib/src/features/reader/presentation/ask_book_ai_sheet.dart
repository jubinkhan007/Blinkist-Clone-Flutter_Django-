import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../book/data/content_repository.dart';
import '../../book/domain/book_models.dart';

class AskBookAiSheet extends ConsumerStatefulWidget {
  final String bookSlug;
  final String bookTitle;
  final String authorName;
  final String? currentSectionSlug;
  final String? currentSectionTitle;

  const AskBookAiSheet({
    super.key,
    required this.bookSlug,
    required this.bookTitle,
    required this.authorName,
    this.currentSectionSlug,
    this.currentSectionTitle,
  });

  static Future<void> show(
    BuildContext context, {
    required String bookSlug,
    required String bookTitle,
    required String authorName,
    String? currentSectionSlug,
    String? currentSectionTitle,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AskBookAiSheet(
        bookSlug: bookSlug,
        bookTitle: bookTitle,
        authorName: authorName,
        currentSectionSlug: currentSectionSlug,
        currentSectionTitle: currentSectionTitle,
      ),
    );
  }

  @override
  ConsumerState<AskBookAiSheet> createState() => _AskBookAiSheetState();
}

class _AskBookAiSheetState extends ConsumerState<AskBookAiSheet> {
  final List<AskAiMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _suggestedPrompts = [
    "💡 Real-world example",
    "⚡ Actionable steps for tomorrow",
    "🎯 Synthesize key takeaways",
    "🤔 Criticisms & counterarguments",
    "🧠 Core mental models",
    "❓ Common beginner pitfalls",
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String question) async {
    final text = question.trim();
    if (text.isEmpty || _isLoading) return;

    final userMessage = AskAiMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
      referencedSection: widget.currentSectionTitle,
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _errorMessage = null;
      _inputController.clear();
    });
    _scrollToBottom();

    try {
      // Build conversation history for context
      final history = _messages
          .take(_messages.length - 1)
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.text,
              })
          .toList();

      final repository = ref.read(contentRepositoryProvider);
      final response = await repository.askBookAi(
        slug: widget.bookSlug,
        question: text,
        sectionSlug: widget.currentSectionSlug,
        history: history.isNotEmpty ? history : null,
      );

      final aiMessage = AskAiMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: response.answer,
        isUser: false,
        timestamp: DateTime.now(),
        suggestedFollowups: response.suggestedFollowups,
        referencedSection: response.sectionTitle ?? widget.currentSectionTitle,
      );

      if (mounted) {
        setState(() {
          _messages.add(aiMessage);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Could not fetch AI response: $e";
        });
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Answer copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clearConversation() {
    setState(() {
      _messages.clear();
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag pill
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.tertiary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Ask Book AI",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "Gemini",
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            widget.currentSectionTitle != null
                                ? "Grounded in: ${widget.currentSectionTitle}"
                                : "Grounded in: ${widget.bookTitle}",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (_messages.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        tooltip: "Reset conversation",
                        onPressed: _isLoading ? null : _clearConversation,
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Chat content or Welcome prompt
              Expanded(
                child: _messages.isEmpty
                    ? _buildWelcomeState(context)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: _messages.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length && _isLoading) {
                            return _buildLoadingBubble(context);
                          }
                          final msg = _messages[index];
                          final isLatestAi = !msg.isUser &&
                              index == _messages.length - 1 &&
                              !_isLoading;
                          return _buildMessageItem(
                            context,
                            message: msg,
                            showFollowups: isLatestAi,
                          );
                        },
                      ),
              ),

              // Error display if any
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: colorScheme.errorContainer,
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 18,
                        color: colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Smart Chips Row (Shown above input when conversation has started)
              if (_messages.isNotEmpty && !_isLoading)
                Container(
                  height: 38,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _suggestedPrompts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final prompt = _suggestedPrompts[i];
                      return ActionChip(
                        label: Text(prompt, style: const TextStyle(fontSize: 12)),
                        padding: EdgeInsets.zero,
                        onPressed: () => _sendMessage(prompt),
                      );
                    },
                  ),
                ),

              // Bottom Input Bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _sendMessage,
                        decoration: InputDecoration(
                          hintText: "Ask anything about this book...",
                          hintStyle: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _isLoading
                          ? null
                          : () => _sendMessage(_inputController.text),
                      icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.psychology_rounded,
              size: 40,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Explore with Gemini AI",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Ask questions grounded strictly in ${widget.bookTitle} by ${widget.authorName}.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Suggested Prompts",
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _suggestedPrompts.map((prompt) {
              return ActionChip(
                elevation: 0,
                backgroundColor: colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                label: Text(
                  prompt,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: () => _sendMessage(prompt),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMessageItem(
    BuildContext context, {
    required AskAiMessage message,
    required bool showFollowups,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            message.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    // Assistant message bubble
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14, right: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Gemini Assistant",
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        tooltip: "Copy answer",
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _copyToClipboard(message.text),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Message text
                  SelectableText(
                    message.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: colorScheme.onSurface,
                    ),
                  ),

                  // Reference pill if section available
                  if (message.referencedSection != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bookmark_outline,
                            size: 12,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              message.referencedSection!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Suggested Followups underneath
            if (showFollowups && message.suggestedFollowups.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  "Suggested follow-ups:",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: message.suggestedFollowups.map((q) {
                  return ActionChip(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    side: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                    ),
                    label: Text(
                      q,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    onPressed: () => _sendMessage(q),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBubble(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "Consulting ${widget.bookTitle}...",
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
