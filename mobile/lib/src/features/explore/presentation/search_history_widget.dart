import 'package:flutter/material.dart';

class SearchHistoryWidget extends StatelessWidget {
  const SearchHistoryWidget({
    super.key,
    required this.history,
    required this.onSelected,
    required this.onClearAll,
  });

  final List<String> history;
  final ValueChanged<String> onSelected;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Recent Searches',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: onClearAll,
                  child: const Text('Clear all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: history
                  .map(
                    (query) => ActionChip(
                      label: Text(query),
                      onPressed: () => onSelected(query),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
