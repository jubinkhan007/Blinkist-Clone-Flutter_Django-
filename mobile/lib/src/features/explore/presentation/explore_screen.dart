import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../explore/data/catalog_repository.dart';
import '../../explore/domain/catalog_models.dart';
import '../../home/presentation/home_screen.dart';
import 'search_history_widget.dart';
import 'search_suggestions_dropdown.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  final String? initialCategorySlug;
  final String? initialQuery;
  final String? initialFormat;
  final String? initialDuration;
  final String? initialSortBy;

  const ExploreScreen({
    super.key,
    this.initialCategorySlug,
    this.initialQuery,
    this.initialFormat,
    this.initialDuration,
    this.initialSortBy,
  });

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _searchQuery = '';
  String? _selectedCategorySlug;
  String _selectedFormat = 'all'; // 'all', 'audio', 'text'
  String _selectedDuration = 'all'; // 'all', 'short', 'medium', 'long'
  String _selectedSortBy = 'popularity'; // 'popularity', 'newest', 'highest_rated'

  Timer? _debounce;
  bool _isDebouncing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategorySlug != null) {
      _selectedCategorySlug = widget.initialCategorySlug;
    }
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchQuery = widget.initialQuery!;
      _searchController.text = widget.initialQuery!;
    }
    if (widget.initialFormat != null) {
      _selectedFormat = widget.initialFormat!;
    }
    if (widget.initialDuration != null) {
      _selectedDuration = widget.initialDuration!;
    }
    if (widget.initialSortBy != null) {
      _selectedSortBy = widget.initialSortBy!;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _resetAllFilters() {
    setState(() {
      _selectedCategorySlug = null;
      _selectedFormat = 'all';
      _selectedDuration = 'all';
      _selectedSortBy = 'popularity';
      _searchQuery = '';
      _searchController.clear();
      _isDebouncing = false;
    });
  }

  String _getSortLabel() {
    switch (_selectedSortBy) {
      case 'highest_rated':
        return 'Highest Rated ⭐';
      case 'newest':
        return 'Newest Releases ⚡';
      case 'popularity':
      default:
        return 'Most Popular 🔥';
    }
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Sort Books By',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.local_fire_department_rounded, color: Colors.deepOrange),
                  title: const Text('Most Popular'),
                  subtitle: const Text('Trending bookmarks and active readers'),
                  trailing: _selectedSortBy == 'popularity'
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setState(() => _selectedSortBy = 'popularity');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.star_rounded, color: Colors.amber),
                  title: const Text('Highest Rated'),
                  subtitle: const Text('Top reader ratings and review scores'),
                  trailing: _selectedSortBy == 'highest_rated'
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setState(() => _selectedSortBy = 'highest_rated');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bolt_rounded, color: Colors.blue),
                  title: const Text('Newest Releases'),
                  subtitle: const Text('Freshly published book summaries'),
                  trailing: _selectedSortBy == 'newest'
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setState(() => _selectedSortBy = 'newest');
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categoriesAsync = ref.watch(categoriesProvider);
    final searchHistory = ref.watch(searchHistoryProvider);
    final trendingSearches =
        ref.watch(trendingSearchesProvider).valueOrNull ?? [];

    final currentFilter = ExploreFilter(
      query: _searchQuery,
      categorySlug: _selectedCategorySlug,
      format: _selectedFormat,
      duration: _selectedDuration,
      sortBy: _selectedSortBy,
    );

    final searchResultsAsync = ref.watch(filteredBooksProvider(currentFilter));
    final showRecentAndTrending =
        _searchFocusNode.hasFocus && _searchController.text.trim().isEmpty;
    final showSuggestions =
        _searchFocusNode.hasFocus && _searchController.text.trim().isNotEmpty;
    final isSearchingOverlay = showRecentAndTrending || showSuggestions;

    final suggestionsAsync = showSuggestions
        ? ref.watch(searchSuggestionsProvider(_searchController.text.trim()))
        : null;
    final suggestions = suggestionsAsync?.valueOrNull ?? [];
    final isSuggestionsLoading = suggestionsAsync?.isLoading ?? false;

    final showLoading = _isDebouncing || searchResultsAsync.isLoading;
    final hasActiveFilterRules = currentFilter.hasActiveFilters;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore & Search'),
        actions: [
          if (hasActiveFilterRules)
            TextButton.icon(
              onPressed: _resetAllFilters,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
              label: const Text('Reset', style: TextStyle(fontSize: 13)),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(showLoading ? 66 : 62),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search titles, authors, topics...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _debounce?.cancel();
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _isDebouncing = false;
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onTap: () => setState(() {}),
                  onSubmitted: (value) {
                    final q = value.trim();
                    _searchFocusNode.unfocus();
                    setState(() {
                      _searchQuery = q;
                      _isDebouncing = false;
                    });
                    if (q.isNotEmpty) {
                      ref.read(searchHistoryProvider.notifier).add(q);
                      ref.read(catalogRepositoryProvider).logSearchQuery(q);
                    }
                  },
                  onChanged: (value) {
                    setState(() {
                      _isDebouncing = true;
                    });
                    _debounce?.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 250),
                      () {
                        if (!mounted) return;
                        setState(() {
                          _searchQuery = value.trim();
                          _isDebouncing = false;
                        });
                      },
                    );
                  },
                ),
              ),
              if (showLoading) const LinearProgressIndicator(minHeight: 3),
            ],
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Live Debounced Search Suggestions Dropdown
          if (showSuggestions)
            SearchSuggestionsDropdown(
              query: _searchController.text.trim(),
              suggestions: suggestions,
              isLoading: isSuggestionsLoading,
              onSelectBook: (slug) {
                _searchFocusNode.unfocus();
                final currentText = _searchController.text.trim();
                if (currentText.isNotEmpty) {
                  ref.read(searchHistoryProvider.notifier).add(currentText);
                  ref.read(catalogRepositoryProvider).logSearchQuery(currentText);
                }
                context.push('/books/$slug');
              },
              onSelectAuthor: (author) {
                _searchController.text = author;
                _searchController.selection = TextSelection.fromPosition(
                  TextPosition(offset: author.length),
                );
                _searchFocusNode.unfocus();
                setState(() {
                  _searchQuery = author;
                  _isDebouncing = false;
                });
                ref.read(searchHistoryProvider.notifier).add(author);
                ref.read(catalogRepositoryProvider).logSearchQuery(author);
              },
              onSelectCategory: (categorySlug) {
                _searchFocusNode.unfocus();
                setState(() {
                  _selectedCategorySlug = categorySlug;
                  _isDebouncing = false;
                });
              },
              onSelectQuery: (query) {
                _searchController.text = query;
                _searchController.selection = TextSelection.fromPosition(
                  TextPosition(offset: query.length),
                );
                _searchFocusNode.unfocus();
                setState(() {
                  _searchQuery = query;
                  _isDebouncing = false;
                });
                ref.read(searchHistoryProvider.notifier).add(query);
                ref.read(catalogRepositoryProvider).logSearchQuery(query);
              },
            ),

          // 2. Recent Searches & Trending Now
          if (showRecentAndTrending)
            SearchHistoryWidget(
              history: searchHistory,
              trending: trendingSearches,
              onSelected: (query) {
                _searchController.text = query;
                _searchController.selection = TextSelection.fromPosition(
                  TextPosition(offset: query.length),
                );
                _searchFocusNode.unfocus();
                setState(() {
                  _searchQuery = query;
                  _isDebouncing = false;
                });
                ref.read(searchHistoryProvider.notifier).add(query);
                ref.read(catalogRepositoryProvider).logSearchQuery(query);
              },
              onRemove: (query) {
                ref.read(searchHistoryProvider.notifier).remove(query);
              },
              onClearAll: () =>
                  ref.read(searchHistoryProvider.notifier).clear(),
            ),

          // 2. Interactive Filter Controls Bar
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Filter Chips: Sort Pill & Formats & Durations
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 4),
                  child: Row(
                    children: [
                      // Sort selector button
                      ActionChip(
                        avatar: const Icon(Icons.sort_rounded, size: 16),
                        label: Text(_getSortLabel()),
                        onPressed: _showSortBottomSheet,
                      ),
                      const SizedBox(width: 8),

                      // Format Chips
                      FilterChip(
                        label: const Text('All Formats'),
                        selected: _selectedFormat == 'all',
                        onSelected: (_) => setState(() => _selectedFormat = 'all'),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        avatar: const Icon(Icons.headphones_rounded, size: 15),
                        label: const Text('Audio'),
                        selected: _selectedFormat == 'audio',
                        onSelected: (_) => setState(() => _selectedFormat = 'audio'),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        avatar: const Icon(Icons.menu_book_rounded, size: 15),
                        label: const Text('Text'),
                        selected: _selectedFormat == 'text',
                        onSelected: (_) => setState(() => _selectedFormat = 'text'),
                      ),
                      const SizedBox(width: 12),

                      // Duration Chips
                      FilterChip(
                        label: const Text('Any Length'),
                        selected: _selectedDuration == 'all',
                        onSelected: (_) => setState(() => _selectedDuration = 'all'),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        avatar: const Icon(Icons.timer_outlined, size: 14),
                        label: const Text('< 10 min'),
                        selected: _selectedDuration == 'short',
                        onSelected: (_) => setState(() => _selectedDuration = 'short'),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        avatar: const Icon(Icons.timer_outlined, size: 14),
                        label: const Text('10–20 min'),
                        selected: _selectedDuration == 'medium',
                        onSelected: (_) => setState(() => _selectedDuration = 'medium'),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        avatar: const Icon(Icons.timer_outlined, size: 14),
                        label: const Text('20+ min'),
                        selected: _selectedDuration == 'long',
                        onSelected: (_) => setState(() => _selectedDuration = 'long'),
                      ),
                    ],
                  ),
                ),

                // Category Filter Chips
                categoriesAsync.when(
                  data: (categories) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('All Topics'),
                          selected: _selectedCategorySlug == null,
                          onSelected: (_) =>
                              setState(() => _selectedCategorySlug = null),
                        ),
                        const SizedBox(width: 6),
                        ...categories.map(
                          (cat) => Padding(
                            padding: const EdgeInsets.only(right: 6),
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
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                const Divider(height: 1),
              ],
            ),
          ),

          // 3. Category Browsing Hub (Visual Topic Grid)
          // Displayed when no search query and 'All Topics' selected
          if (_searchQuery.isEmpty && _selectedCategorySlug == null && !isSearchingOverlay)
            categoriesAsync.maybeWhen(
              data: (categories) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.category_rounded, size: 20, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Browse by Category',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _CategoryBrowsingGrid(
                        categories: categories,
                        onCategoryTapped: (slug) {
                          setState(() => _selectedCategorySlug = slug);
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'All Catalog Books',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              orElse: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),

          // 4. Search Results Header & Filter Summary
          if (!isSearchingOverlay && (_searchQuery.isNotEmpty || _selectedCategorySlug != null))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedCategorySlug != null
                            ? 'Category: ${_selectedCategorySlug!.toUpperCase().replaceAll('-', ' ')}'
                            : 'Results for "$_searchQuery"',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (currentFilter.activeFiltersCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${currentFilter.activeFiltersCount} filters active',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // 5. Books Results Grid
          if (!isSearchingOverlay)
            searchResultsAsync.when(
              data: (books) {
                if (books.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.search_off_rounded,
                                size: 40,
                                color: colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Books Found',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'No summaries match your selected filters. Try broadening your criteria or reset filters.',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            FilledButton.tonalIcon(
                              onPressed: _resetAllFilters,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Reset All Filters'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.62,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 20,
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
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 40, color: Colors.red),
                        const SizedBox(height: 10),
                        Text('Failed to load catalog: $error', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => ref.invalidate(filteredBooksProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryBrowsingGrid extends StatelessWidget {
  final List<Category> categories;
  final ValueChanged<String> onCategoryTapped;

  const _CategoryBrowsingGrid({
    required this.categories,
    required this.onCategoryTapped,
  });

  _CategoryTheme _getTheme(String slug) {
    switch (slug.toLowerCase()) {
      case 'productivity':
        return const _CategoryTheme(Icons.timer_outlined, Color(0xFF1E88E5), Color(0xFF0D47A1));
      case 'leadership':
        return const _CategoryTheme(Icons.military_tech_outlined, Color(0xFF8E24AA), Color(0xFF4A148C));
      case 'technology':
        return const _CategoryTheme(Icons.computer_rounded, Color(0xFF00ACC1), Color(0xFF006064));
      case 'psychology':
        return const _CategoryTheme(Icons.psychology_outlined, Color(0xFFFB8C00), Color(0xFFE65100));
      case 'science':
        return const _CategoryTheme(Icons.science_outlined, Color(0xFF43A047), Color(0xFF1B5E20));
      case 'business':
        return const _CategoryTheme(Icons.business_center_outlined, Color(0xFF546E7A), Color(0xFF263238));
      case 'health':
        return const _CategoryTheme(Icons.favorite_outline_rounded, Color(0xFFE53935), Color(0xFFB71C1C));
      default:
        return const _CategoryTheme(Icons.bookmark_outline, Color(0xFF3949AB), Color(0xFF1A237E));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: categories.map((cat) {
            final theme = _getTheme(cat.slug);
            final itemWidth = (constraints.maxWidth - 20) / 3;

            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onCategoryTapped(cat.slug),
              child: Container(
                width: itemWidth.clamp(100.0, 150.0),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.gradientStart.withOpacity(0.12),
                      theme.gradientEnd.withOpacity(0.20),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.gradientStart.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.gradientStart.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(theme.icon, color: theme.gradientStart, size: 20),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cat.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _CategoryTheme {
  final IconData icon;
  final Color gradientStart;
  final Color gradientEnd;

  const _CategoryTheme(this.icon, this.gradientStart, this.gradientEnd);
}
