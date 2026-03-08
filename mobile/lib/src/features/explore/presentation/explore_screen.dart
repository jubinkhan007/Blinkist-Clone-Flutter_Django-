import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../explore/data/catalog_repository.dart';
import '../../home/presentation/home_screen.dart'; // Reusing BookCard

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategorySlug;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final searchResultsAsync = ref.watch(
      booksProvider(query: _searchQuery, categorySlug: _selectedCategorySlug),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search titles or authors...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Category Chips
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
                        padding: const EdgeInsets.only(right: 8.0),
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

          // Results Grid
          searchResultsAsync.when(
            data: (books) {
              if (books.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text('No results found.')),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
