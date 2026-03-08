// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$contentRepositoryHash() => r'ca950613ecba1005569af1560e2ed5d564912072';

/// See also [contentRepository].
@ProviderFor(contentRepository)
final contentRepositoryProvider =
    AutoDisposeProvider<ContentRepository>.internal(
  contentRepository,
  name: r'contentRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$contentRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ContentRepositoryRef = AutoDisposeProviderRef<ContentRepository>;
String _$homeFeedHash() => r'53f20a0197f0da6d3d8b6b4311fcd5d82dde9088';

/// See also [homeFeed].
@ProviderFor(homeFeed)
final homeFeedProvider = AutoDisposeFutureProvider<HomeMerchandising>.internal(
  homeFeed,
  name: r'homeFeedProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$homeFeedHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef HomeFeedRef = AutoDisposeFutureProviderRef<HomeMerchandising>;
String _$bookDetailHash() => r'972d14a8cec27c3535f9a35f94c3f01b85a69206';

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

/// See also [bookDetail].
@ProviderFor(bookDetail)
const bookDetailProvider = BookDetailFamily();

/// See also [bookDetail].
class BookDetailFamily extends Family<AsyncValue<BookDetail>> {
  /// See also [bookDetail].
  const BookDetailFamily();

  /// See also [bookDetail].
  BookDetailProvider call(
    String slug,
  ) {
    return BookDetailProvider(
      slug,
    );
  }

  @override
  BookDetailProvider getProviderOverride(
    covariant BookDetailProvider provider,
  ) {
    return call(
      provider.slug,
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
  String? get name => r'bookDetailProvider';
}

/// See also [bookDetail].
class BookDetailProvider extends AutoDisposeFutureProvider<BookDetail> {
  /// See also [bookDetail].
  BookDetailProvider(
    String slug,
  ) : this._internal(
          (ref) => bookDetail(
            ref as BookDetailRef,
            slug,
          ),
          from: bookDetailProvider,
          name: r'bookDetailProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$bookDetailHash,
          dependencies: BookDetailFamily._dependencies,
          allTransitiveDependencies:
              BookDetailFamily._allTransitiveDependencies,
          slug: slug,
        );

  BookDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.slug,
  }) : super.internal();

  final String slug;

  @override
  Override overrideWith(
    FutureOr<BookDetail> Function(BookDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: BookDetailProvider._internal(
        (ref) => create(ref as BookDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        slug: slug,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<BookDetail> createElement() {
    return _BookDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BookDetailProvider && other.slug == slug;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, slug.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin BookDetailRef on AutoDisposeFutureProviderRef<BookDetail> {
  /// The parameter `slug` of this provider.
  String get slug;
}

class _BookDetailProviderElement
    extends AutoDisposeFutureProviderElement<BookDetail> with BookDetailRef {
  _BookDetailProviderElement(super.provider);

  @override
  String get slug => (origin as BookDetailProvider).slug;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
