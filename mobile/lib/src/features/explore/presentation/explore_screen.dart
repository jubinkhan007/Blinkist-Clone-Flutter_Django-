import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../explore/data/catalog_repository.dart';
import '../../home/presentation/home_screen.dart';
import 'search_history_widget.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String? _selectedCategorySlug;
  Timer? _debounce;
  bool _isDebouncing = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final searchHistory = ref.watch(searchHistoryProvider);
    final searchResultsAsync = ref.watch(
      booksProvider(query: _searchQuery, categorySlug: _selectedCategorySlug),
    );
    final showRecentSearches =
        _searchFocusNode.hasFocus && _searchController.text.trim().isEmpty;
    final showLoading = _isDebouncing || searchResultsAsync.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(showLoading ? 64 : 60),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search titles or authors...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () async {
                              _debounce?.cancel();
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _isDebouncing = false;
                              });
                              await ref
                                  .read(searchHistoryProvider.notifier)
                                  .clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onTap: () => setState(() {}),
                  onChanged: (value) {
                    setState(() => _isDebouncing = true);
                    _debounce?.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 400),
                      () async {
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          _searchQuery = value.trim();
                          _isDebouncing = false;
                        });
                        if (_searchQuery.isNotEmpty) {
                          await ref
                              .read(searchHistoryProvider.notifier)
                              .add(_searchQuery);
                        }
                      },
                    );
                  },
                ),
              ),
              if (showLoading) const LinearProgressIndicator(minHeight: 4),
            ],
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          if (showRecentSearches)
            SearchHistoryWidget(
              history: searchHistory,
              onSelected: (query) {
                _searchController.text = query;
                _searchController.selection = TextSelection.fromPosition(
                  TextPosition(offset: query.length),
                );
                setState(() => _searchQuery = query);
              },
              onClearAll: () =>
                  ref.read(searchHistoryProvider.notifier).clear(),
            ),
          SliverToBoxAdapter(
            child: categoriesAsync.when(
              data: (categories) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _selectedCategorySlug == null,
                      onSelected: (_) =>
                          setState(() => _selectedCategorySlug = null),
                    ),
                    const SizedBox(width: 8),
                    ...categories.map(
                      (cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat.name),
                          selected: _selectedCategorySlug == cat.slug,
                          onSelected: (_) =>
                              setState(() => _selectedCategorySlug = cat.slug),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          if (!showRecentSearches)
            searchResultsAsync.when(
              data: (books) {
                if (books.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(child: Text('No results found.')),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => BookCard(book: books[index]),
                      childCount: books.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => SliverFillRemaining(
                child: Center(child: Text('Error: $error')),
              ),
            ),
        ],
      ),
    );
  }
}
