import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum QuoteTheme { midnight, forest, sunrise, paper }

class QuoteCardDialog extends StatefulWidget {
  final String quoteText;
  final String bookTitle;
  final String bookAuthor;

  const QuoteCardDialog({
    super.key,
    required this.quoteText,
    required this.bookTitle,
    required this.bookAuthor,
  });

  static Future<void> show(
    BuildContext context, {
    required String quoteText,
    required String bookTitle,
    required String bookAuthor,
  }) {
    return showDialog(
      context: context,
      builder: (_) => QuoteCardDialog(
        quoteText: quoteText,
        bookTitle: bookTitle,
        bookAuthor: bookAuthor,
      ),
    );
  }

  @override
  State<QuoteCardDialog> createState() => _QuoteCardDialogState();
}

class _QuoteCardDialogState extends State<QuoteCardDialog> {
  QuoteTheme _selectedTheme = QuoteTheme.midnight;

  LinearGradient _getGradient(QuoteTheme theme) {
    switch (theme) {
      case QuoteTheme.midnight:
        return const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case QuoteTheme.forest:
        return const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF065F46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case QuoteTheme.sunrise:
        return const LinearGradient(
          colors: [Color(0xFF9D174D), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case QuoteTheme.paper:
        return const LinearGradient(
          colors: [Color(0xFFFAF7F2), Color(0xFFF3EFE6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  Color _getTextColor(QuoteTheme theme) {
    return theme == QuoteTheme.paper ? const Color(0xFF1C1917) : Colors.white;
  }

  Color _getAccentColor(QuoteTheme theme) {
    switch (theme) {
      case QuoteTheme.midnight:
        return const Color(0xFFFBBF24);
      case QuoteTheme.forest:
        return const Color(0xFF6EE7B7);
      case QuoteTheme.sunrise:
        return const Color(0xFFFDE68A);
      case QuoteTheme.paper:
        return const Color(0xFFB45309);
    }
  }

  void _copyToClipboard() {
    final text =
        '"${widget.quoteText.trim()}"\n\n— ${widget.bookAuthor}, ${widget.bookTitle} (via Blinkist)';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Quote copied to clipboard! Ready to share.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _getGradient(_selectedTheme);
    final textColor = _getTextColor(_selectedTheme);
    final accentColor = _getAccentColor(_selectedTheme);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The Quote Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Branding & Big Quote Symbol
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '“',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: accentColor.withOpacity(0.6),
                        height: 0.8,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded, size: 14, color: accentColor),
                          const SizedBox(width: 4),
                          Text(
                            'BLINKIST',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Selected Quote Text
                Text(
                  widget.quoteText.trim(),
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                    color: textColor,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),

                // Divider line
                Container(
                  height: 1,
                  color: textColor.withOpacity(0.15),
                  width: double.infinity,
                ),
                const SizedBox(height: 16),

                // Citation
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.bookTitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.bookAuthor,
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withOpacity(0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Theme Chooser Pills
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ThemePill(
                  label: 'Midnight',
                  isSelected: _selectedTheme == QuoteTheme.midnight,
                  color: const Color(0xFF0F172A),
                  onTap: () => setState(() => _selectedTheme = QuoteTheme.midnight),
                ),
                _ThemePill(
                  label: 'Forest',
                  isSelected: _selectedTheme == QuoteTheme.forest,
                  color: const Color(0xFF064E3B),
                  onTap: () => setState(() => _selectedTheme = QuoteTheme.forest),
                ),
                _ThemePill(
                  label: 'Sunrise',
                  isSelected: _selectedTheme == QuoteTheme.sunrise,
                  color: const Color(0xFFD97706),
                  onTap: () => setState(() => _selectedTheme = QuoteTheme.sunrise),
                ),
                _ThemePill(
                  label: 'Paper',
                  isSelected: _selectedTheme == QuoteTheme.paper,
                  color: const Color(0xFFFAF7F2),
                  onTap: () => setState(() => _selectedTheme = QuoteTheme.paper),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy Formatted Quote'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: _copyToClipboard,
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemePill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _ThemePill({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.withOpacity(0.5)),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
