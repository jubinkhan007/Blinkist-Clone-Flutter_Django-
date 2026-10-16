import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../networking/api_client.dart';
import '../storage/local_cache_database.dart';

enum SyncState {
  idle,
  syncing,
  synced,
  offline,
  error,
}

class SyncStatus {
  final SyncState state;
  final int pendingCount;
  final String? lastError;
  final DateTime? lastSyncedAt;

  const SyncStatus({
    this.state = SyncState.idle,
    this.pendingCount = 0,
    this.lastError,
    this.lastSyncedAt,
  });

  SyncStatus copyWith({
    SyncState? state,
    int? pendingCount,
    String? lastError,
    DateTime? lastSyncedAt,
  }) {
    return SyncStatus(
      state: state ?? this.state,
      pendingCount: pendingCount ?? this.pendingCount,
      lastError: lastError,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

class BackgroundSyncService extends StateNotifier<SyncStatus> {
  final Dio _dio;
  final LocalCacheDatabase _cacheDb;
  bool _isSyncing = false;

  BackgroundSyncService({
    required Dio dio,
    required LocalCacheDatabase cacheDb,
  })  : _dio = dio,
        _cacheDb = cacheDb,
        super(const SyncStatus()) {
    checkPendingCount();
  }

  Future<void> checkPendingCount() async {
    final count = await _cacheDb.getPendingSyncCount();
    state = state.copyWith(pendingCount: count);
  }

  Future<bool> syncPendingMutations() async {
    if (_isSyncing) return false;
    _isSyncing = true;

    state = state.copyWith(state: SyncState.syncing);

    try {
      final pendingRows = await _cacheDb.getPendingSyncActions();
      if (pendingRows.isEmpty) {
        state = state.copyWith(
          state: SyncState.synced,
          pendingCount: 0,
          lastSyncedAt: DateTime.now(),
        );
        _isSyncing = false;
        return true;
      }

      final List<int> idsToDelete = [];
      final List<Map<String, dynamic>> itemsPayload = [];

      for (final row in pendingRows) {
        final id = row['id'] as int;
        final actionType = row['action_type'] as String;
        final payloadJson = row['payload_json'] as String;
        try {
          final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
          itemsPayload.add({
            'type': actionType,
            ...payload,
          });
          idsToDelete.add(id);
        } catch (e) {
          debugPrint('Malformed sync payload row $id: $e');
          idsToDelete.add(id);
        }
      }

      if (itemsPayload.isNotEmpty) {
        final response = await _dio.post(
          '/progress/sync/',
          data: {'items': itemsPayload},
        );

        if (response.statusCode == 200) {
          await _cacheDb.deleteSyncActions(idsToDelete);
          final remaining = await _cacheDb.getPendingSyncCount();
          state = state.copyWith(
            state: SyncState.synced,
            pendingCount: remaining,
            lastSyncedAt: DateTime.now(),
          );
          _isSyncing = false;
          return true;
        }
      }

      _isSyncing = false;
      return false;
    } on DioException catch (e) {
      _isSyncing = false;
      final remaining = await _cacheDb.getPendingSyncCount();
      // If network is completely unreachable
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        state = state.copyWith(
          state: SyncState.offline,
          pendingCount: remaining,
          lastError: 'Offline mode: changes queued for sync',
        );
      } else {
        state = state.copyWith(
          state: SyncState.error,
          pendingCount: remaining,
          lastError: e.message ?? 'Sync failed',
        );
      }
      return false;
    } catch (e) {
      _isSyncing = false;
      final remaining = await _cacheDb.getPendingSyncCount();
      state = state.copyWith(
        state: SyncState.error,
        pendingCount: remaining,
        lastError: e.toString(),
      );
      return false;
    }
  }
}

final backgroundSyncServiceProvider =
    StateNotifierProvider<BackgroundSyncService, SyncStatus>((ref) {
  final dio = ref.watch(dioProvider);
  final cacheDb = ref.watch(localCacheDatabaseProvider);
  return BackgroundSyncService(dio: dio, cacheDb: cacheDb);
});
