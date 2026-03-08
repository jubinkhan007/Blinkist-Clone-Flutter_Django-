// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$catalogRepositoryHash() => r'178cb73ee0acffef726e0da5806ecaba3aaa4156';

/// See also [catalogRepository].
@ProviderFor(catalogRepository)
final catalogRepositoryProvider =
    AutoDisposeProvider<CatalogRepository>.internal(
  catalogRepository,
  name: r'catalogRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$catalogRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CatalogRepositoryRef = AutoDisposeProviderRef<CatalogRepository>;
String _$categoriesHash() => r'e5787fd0efcbbf356883f577592bbab363db875c';

/// See also [categories].
@ProviderFor(categories)
final categoriesProvider = AutoDisposeFutureProvider<List<Category>>.internal(
  categories,
  name: r'categoriesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$categoriesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CategoriesRef = AutoDisposeFutureProviderRef<List<Category>>;
String _$booksHash() => r'09c8305625058d7fd30d8ff5793a464ed859b559';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [books].
@ProviderFor(books)
const booksProvider = BooksFamily();

/// See also [books].
class BooksFamily extends Family<AsyncValue<List<Book>>> {
  /// See also [books].
  const BooksFamily();

  /// See also [books].
  BooksProvider call({
    String? query,
    String? categorySlug,
  }) {
    return BooksProvider(
      query: query,
      categorySlug: categorySlug,
    );
  }

  @override
  BooksProvider getProviderOverride(
    covariant BooksProvider provider,
  ) {
    return call(
      query: provider.query,
      categorySlug: provider.categorySlug,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'booksProvider';
}

/// See also [books].
class BooksProvider extends AutoDisposeFutureProvider<List<Book>> {
  /// See also [books].
  BooksProvider({
    String? query,
    String? categorySlug,
  }) : this._internal(
          (ref) => books(
            ref as BooksRef,
            query: query,
            categorySlug: categorySlug,
          ),
          from: booksProvider,
          name: r'booksProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$booksHash,
          dependencies: BooksFamily._dependencies,
          allTransitiveDependencies: BooksFamily._allTransitiveDependencies,
          query: query,
          categorySlug: categorySlug,
        );

  BooksProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.query,
    required this.categorySlug,
  }) : super.internal();

  final String? query;
  final String? categorySlug;

  @override
  Override overrideWith(
    FutureOr<List<Book>> Function(BooksRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: BooksProvider._internal(
        (ref) => create(ref as BooksRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        query: query,
        categorySlug: categorySlug,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Book>> createElement() {
    return _BooksProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BooksProvider &&
        other.query == query &&
        other.categorySlug == categorySlug;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, query.hashCode);
    hash = _SystemHash.combine(hash, categorySlug.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin BooksRef on AutoDisposeFutureProviderRef<List<Book>> {
  /// The parameter `query` of this provider.
  String? get query;

  /// The parameter `categorySlug` of this provider.
  String? get categorySlug;
}

class _BooksProviderElement extends AutoDisposeFutureProviderElement<List<Book>>
    with BooksRef {
  _BooksProviderElement(super.provider);

  @override
  String? get query => (origin as BooksProvider).query;
  @override
  String? get categorySlug => (origin as BooksProvider).categorySlug;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
