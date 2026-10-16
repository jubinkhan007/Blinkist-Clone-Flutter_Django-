import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../src/features/book/domain/book_models.dart';
import '../../src/features/home/domain/home_models.dart';

class LocalCacheDatabase {
  static const String _dbName = 'blinkist_cache_v1.db';
  static const int _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_books (
            slug TEXT PRIMARY KEY,
            title TEXT,
            author TEXT,
            data_json TEXT,
            cached_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_sections (
            id TEXT PRIMARY KEY,
            book_slug TEXT,
            data_json TEXT,
            order_index INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_home_feed (
            id INTEGER PRIMARY KEY,
            data_json TEXT,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE offline_sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action_type TEXT,
            payload_json TEXT,
            created_at INTEGER,
            retry_count INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE local_reading_progress (
            book_slug TEXT PRIMARY KEY,
            book_id INTEGER,
            completed_sections_count INTEGER,
            total_sections INTEGER,
            is_completed INTEGER DEFAULT 0,
            audio_section_id INTEGER,
            audio_position_seconds REAL DEFAULT 0.0,
            updated_at INTEGER
          )
        ''');
      },
    );
  }

  // ==========================================
  // Home Feed Caching
  // ==========================================

  Future<void> cacheHomeFeed(Map<String, dynamic> data) async {
    try {
      final db = await database;
      await db.insert(
        'cached_home_feed',
        {
          'id': 1,
          'data_json': jsonEncode(data),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Failed to cache home feed: $e');
    }
  }

  Future<HomeMerchandising?> getCachedHomeFeed() async {
    try {
      final db = await database;
      final results = await db.query(
        'cached_home_feed',
        where: 'id = ?',
        whereArgs: [1],
      );
      if (results.isNotEmpty) {
        final jsonStr = results.first['data_json'] as String;
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return HomeMerchandising.fromJson(map);
      }
    } catch (e) {
      debugPrint('Failed to load cached home feed: $e');
    }
    return null;
  }

  // ==========================================
  // Book Detail & Sections Caching
  // ==========================================

  Future<void> cacheBookDetail(BookDetail book) async {
    try {
      final db = await database;
      await db.insert(
        'cached_books',
        {
          'slug': book.slug,
          'title': book.title,
          'author': book.author.name,
          'data_json': jsonEncode(book.toJson()),
          'cached_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Also cache its sections
      if (book.sections.isNotEmpty) {
        await cacheSections(book.slug, book.sections);
      }
    } catch (e) {
      debugPrint('Failed to cache book ${book.slug}: $e');
    }
  }

  Future<BookDetail?> getCachedBookDetail(String slug) async {
    try {
      final db = await database;
      final results = await db.query(
        'cached_books',
        where: 'slug = ?',
        whereArgs: [slug],
      );
      if (results.isNotEmpty) {
        final jsonStr = results.first['data_json'] as String;
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return BookDetail.fromJson(map);
      }
    } catch (e) {
      debugPrint('Failed to load cached book detail: $e');
    }
    return null;
  }

  Future<void> cacheSections(String bookSlug, List<SummarySection> sections) async {
    try {
      final db = await database;
      final batch = db.batch();
      for (final s in sections) {
        batch.insert(
          'cached_sections',
          {
            'id': '${bookSlug}_${s.slug}',
            'book_slug': bookSlug,
            'data_json': jsonEncode(s.toJson()),
            'order_index': s.order,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('Failed to cache sections for $bookSlug: $e');
    }
  }

  Future<List<SummarySection>> getCachedSections(String bookSlug) async {
    try {
      final db = await database;
      final results = await db.query(
        'cached_sections',
        where: 'book_slug = ?',
        whereArgs: [bookSlug],
        orderBy: 'order_index ASC',
      );
      if (results.isNotEmpty) {
        return results
            .map((r) => SummarySection.fromJson(jsonDecode(r['data_json'] as String)))
            .toList();
      }
    } catch (e) {
      debugPrint('Failed to load cached sections: $e');
    }
    return [];
  }

  // ==========================================
  // Offline Sync Queue
  // ==========================================

  Future<int> enqueueSyncAction(String actionType, Map<String, dynamic> payload) async {
    try {
      final db = await database;
      return await db.insert('offline_sync_queue', {
        'action_type': actionType,
        'payload_json': jsonEncode(payload),
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'retry_count': 0,
      });
    } catch (e) {
      debugPrint('Failed to enqueue sync action: $e');
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getPendingSyncActions() async {
    try {
      final db = await database;
      return await db.query(
        'offline_sync_queue',
        orderBy: 'created_at ASC',
      );
    } catch (e) {
      debugPrint('Failed to get pending sync actions: $e');
      return [];
    }
  }

  Future<void> deleteSyncActions(List<int> ids) async {
    if (ids.isEmpty) return;
    try {
      final db = await database;
      final placeholders = List.filled(ids.length, '?').join(',');
      await db.delete(
        'offline_sync_queue',
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
    } catch (e) {
      debugPrint('Failed to delete synced actions: $e');
    }
  }

  Future<int> getPendingSyncCount() async {
    try {
      final db = await database;
      final res = await db.rawQuery('SELECT COUNT(*) as count FROM offline_sync_queue');
      return Sqflite.firstIntValue(res) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // ==========================================
  // Local Reading Progress Tracking
  // ==========================================

  Future<void> saveLocalProgress({
    required String bookSlug,
    int? bookId,
    int? completedSectionsCount,
    int? totalSections,
    bool? isCompleted,
    int? audioSectionId,
    double? audioPositionSeconds,
  }) async {
    try {
      final db = await database;
      final existing = await db.query(
        'local_reading_progress',
        where: 'book_slug = ?',
        whereArgs: [bookSlug],
      );

      final now = DateTime.now().millisecondsSinceEpoch;
      if (existing.isNotEmpty) {
        await db.update(
          'local_reading_progress',
          {
            if (bookId != null) 'book_id': bookId,
            if (completedSectionsCount != null)
              'completed_sections_count': completedSectionsCount,
            if (totalSections != null) 'total_sections': totalSections,
            if (isCompleted != null) 'is_completed': isCompleted ? 1 : 0,
            if (audioSectionId != null) 'audio_section_id': audioSectionId,
            if (audioPositionSeconds != null)
              'audio_position_seconds': audioPositionSeconds,
            'updated_at': now,
          },
          where: 'book_slug = ?',
          whereArgs: [bookSlug],
        );
      } else {
        await db.insert('local_reading_progress', {
          'book_slug': bookSlug,
          'book_id': bookId ?? 0,
          'completed_sections_count': completedSectionsCount ?? 0,
          'total_sections': totalSections ?? 0,
          'is_completed': (isCompleted ?? false) ? 1 : 0,
          'audio_section_id': audioSectionId,
          'audio_position_seconds': audioPositionSeconds ?? 0.0,
          'updated_at': now,
        });
      }
    } catch (e) {
      debugPrint('Failed to save local progress: $e');
    }
  }

  Future<Map<String, dynamic>?> getLocalProgress(String bookSlug) async {
    try {
      final db = await database;
      final results = await db.query(
        'local_reading_progress',
        where: 'book_slug = ?',
        whereArgs: [bookSlug],
      );
      if (results.isNotEmpty) return results.first;
    } catch (e) {
      debugPrint('Failed to get local progress: $e');
    }
    return null;
  }
}

final localCacheDatabaseProvider = Provider<LocalCacheDatabase>((ref) {
  return LocalCacheDatabase();
});
