import 'package:flutter/material.dart';

import '../domain/catalog_models.dart';

class SearchSuggestionsDropdown extends StatelessWidget {
  const SearchSuggestionsDropdown({
    super.key,
    required this.query,
    required this.suggestions,
    required this.isLoading,
    required this.onSelectBook,
    required this.onSelectAuthor,
    required this.onSelectCategory,
    required this.onSelectQuery,
  });

  final String query;
  final List<SearchSuggestion> suggestions;
  final bool isLoading;
  final ValueChanged<String> onSelectBook;
  final ValueChanged<String> onSelectAuthor;
  final ValueChanged<String> onSelectCategory;
  final ValueChanged<String> onSelectQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final books = suggestions.where((s) => s.type == 'book').toList();
    final authors = suggestions.where((s) => s.type == 'author').toList();
    final categories = suggestions.where((s) => s.type == 'category').toList();

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Direct Search Action Row
            ListTile(
              dense: true,
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_rounded,
                  size: 16,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              title: RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  children: [
                    const TextSpan(text: 'Search for '),
                    TextSpan(
                      text: '“$query”',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: ' in all summaries'),
                  ],
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_rounded, size: 16),
              onTap: () => onSelectQuery(query),
            ),

            if (isLoading && suggestions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else ...[
              // 2. Books Section
              if (books.isNotEmpty) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Text(
                    'BOOKS & SUMMARIES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                ...books.map((b) {
                  return ListTile(
                    dense: true,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: b.coverImageUrl != null && b.coverImageUrl!.isNotEmpty
                          ? Image.network(
                              b.coverImageUrl!,
                              width: 32,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 32,
                                height: 44,
                                color: colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.book, size: 16),
                              ),
                            )
                          : Container(
                              width: 32,
                              height: 44,
                              color: colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.book, size: 16),
                            ),
                    ),
                    title: Text(
                      b.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      b.author ?? '',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: b.rating != null
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 15, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(
                                b.rating!.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right_rounded, size: 16),
                            ],
                          )
                        : const Icon(Icons.chevron_right_rounded, size: 16),
                    onTap: () {
                      if (b.slug != null && b.slug!.isNotEmpty) {
                        onSelectBook(b.slug!);
                      } else {
                        onSelectQuery(b.title);
                      }
                    },
                  );
                }),
              ],

              // 3. Authors Section
              if (authors.isNotEmpty) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Text(
                    'AUTHORS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                ...authors.map((a) {
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      child: Icon(Icons.person_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                    ),
                    title: Text(
                      a.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: a.bookCount != null
                        ? Text(
                            '${a.bookCount} summary ${a.bookCount == 1 ? '' : 'ies'} available',
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          )
                        : null,
                    trailing: const Icon(Icons.arrow_forward_rounded, size: 16),
                    onTap: () => onSelectAuthor(a.title),
                  );
                }),
              ],

              // 4. Categories Section
              if (categories.isNotEmpty) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Text(
                    'TOPICS & CATEGORIES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                ...categories.map((c) {
                  return ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.category_rounded, size: 16, color: colorScheme.onSecondaryContainer),
                    ),
                    title: Text(
                      c.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    trailing: const Icon(Icons.arrow_forward_rounded, size: 16),
                    onTap: () => onSelectCategory(c.slug ?? c.title),
                  );
                }),
              ],

              if (books.isEmpty && authors.isEmpty && categories.isEmpty && !isLoading)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: colorScheme.outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No quick matches. Tap above or press enter to search full text.',
                          style: TextStyle(fontSize: 12, color: colorScheme.outline),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
