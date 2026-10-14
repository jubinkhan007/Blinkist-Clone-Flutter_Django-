import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/networking/api_client.dart';
import '../domain/action_plan_models.dart';

class ActionPlanRepository {
  final Dio _dio;

  ActionPlanRepository(this._dio);

  Future<List<ActionPlan>> fetchActionPlans({
    String? bookSlug,
    bool? active,
  }) async {
    final query = <String, dynamic>{};
    if (bookSlug != null) query['book_slug'] = bookSlug;
    if (active != null) query['active'] = active.toString();

    final response = await _dio.get(
      '/progress/action-plans/',
      queryParameters: query.isNotEmpty ? query : null,
    );

    final list = response.data as List<dynamic>? ?? [];
    return list
        .map((e) => ActionPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ActionPlan> fetchActionPlanDetail(int planId) async {
    final response = await _dio.get('/progress/action-plans/$planId/');
    return ActionPlan.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ActionPlan> generateActionPlan({
    required String bookSlug,
    int durationDays = 7,
    bool forceRegenerate = false,
  }) async {
    final response = await _dio.post(
      '/progress/books/$bookSlug/action-plan/generate/',
      data: {
        'duration_days': durationDays,
        'force_regenerate': forceRegenerate,
      },
    );
    return ActionPlan.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ActionPlan> toggleItem({
    required int planId,
    required int itemId,
    bool? isCompleted,
  }) async {
    final data = <String, dynamic>{};
    if (isCompleted != null) {
      data['is_completed'] = isCompleted;
    }

    final response = await _dio.patch(
      '/progress/action-plans/$planId/items/$itemId/toggle/',
      data: data.isNotEmpty ? data : null,
    );
    return ActionPlan.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ActionPlanExportPayload> exportPlan(int planId) async {
    final response = await _dio.get('/progress/action-plans/$planId/export/');
    return ActionPlanExportPayload.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<void> deletePlan(int planId) async {
    await _dio.delete('/progress/action-plans/$planId/');
  }
}

final actionPlanRepositoryProvider = Provider<ActionPlanRepository>((ref) {
  return ActionPlanRepository(ref.watch(dioProvider));
});

final actionPlansListProvider = FutureProvider<List<ActionPlan>>((ref) async {
  return ref.watch(actionPlanRepositoryProvider).fetchActionPlans();
});

final actionPlanDetailProvider =
    FutureProvider.family<ActionPlan, int>((ref, planId) async {
  return ref.watch(actionPlanRepositoryProvider).fetchActionPlanDetail(planId);
});

final bookActionPlanProvider =
    FutureProvider.family<ActionPlan?, String>((ref, slug) async {
  final plans = await ref
      .watch(actionPlanRepositoryProvider)
      .fetchActionPlans(bookSlug: slug);
  return plans.isNotEmpty ? plans.first : null;
});

final activeActionPlanProvider = FutureProvider<ActionPlan?>((ref) async {
  final plans = await ref
      .watch(actionPlanRepositoryProvider)
      .fetchActionPlans(active: true);
  if (plans.isEmpty) return null;
  // Pick active plan with lowest completion (in progress) or most recently updated
  final inProgress = plans.where((p) => !p.isCompleted).toList();
  return inProgress.isNotEmpty ? inProgress.first : plans.first;
});
