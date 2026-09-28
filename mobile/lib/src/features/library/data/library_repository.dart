import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/networking/api_client.dart';
import '../../book/data/content_repository.dart';
import '../../explore/domain/catalog_models.dart';

class LibraryRepository {
  final Dio _dio;

  LibraryRepository(this._dio);

  Future<List<Book>> fetchLibraryBooks() async {
    final response = await _dio.get('/catalog/library/');
    final data = response.data as List<dynamic>;
    return data
        .map((item) => Book.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<bool> toggleSavedBook(String bookSlug) async {
    final response = await _dio.post('/catalog/library/$bookSlug/');
    return response.data['saved'] == true;
  }
}

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository(ref.watch(dioProvider));
});

final libraryBooksProvider = FutureProvider<List<Book>>((ref) async {
  final books = await ref.watch(libraryRepositoryProvider).fetchLibraryBooks();
  ref.read(savedBooksProvider.notifier).hydrate(books);
  return books;
});

class SavedBooksController extends StateNotifier<Map<String, bool>> {
  SavedBooksController(this._ref) : super(const {});

  final Ref _ref;

  void hydrate(List<Book> books) {
    state = {...state, for (final book in books) book.slug: true};
  }

  bool isSaved(Book book) => state[book.slug] ?? book.isSaved;

  Future<void> toggle(Book book) async {
    final previous = isSaved(book);
    state = {...state, book.slug: !previous};

    try {
      final saved = await _ref
          .read(libraryRepositoryProvider)
          .toggleSavedBook(book.slug);
      state = {...state, book.slug: saved};
      _ref.invalidate(libraryBooksProvider);
      _ref.invalidate(homeFeedProvider);
      _ref.invalidate(bookDetailProvider(book.slug));
    } catch (_) {
      state = {...state, book.slug: previous};
      rethrow;
    }
  }
}

final savedBooksProvider =
    StateNotifierProvider<SavedBooksController, Map<String, bool>>((ref) {
      return SavedBooksController(ref);
    });
