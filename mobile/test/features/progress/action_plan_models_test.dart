import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/progress/domain/action_plan_models.dart';

void main() {
  group('ActionPlan Models Tests', () {
    test('ActionPlanItem fromJson and toJson serialization', () {
      final json = {
        'id': 101,
        'day_number': 1,
        'title': 'Audit Your Cue Environment',
        'description': 'Inspect physical cues and remove trigger obstacles.',
        'suggested_habit': 'When I make morning coffee, I will place my book on the desk.',
        'associated_quote': 'Make it obvious.',
        'is_completed': false,
        'completed_at': null,
      };

      final item = ActionPlanItem.fromJson(json);
      expect(item.id, 101);
      expect(item.dayNumber, 1);
      expect(item.title, 'Audit Your Cue Environment');
      expect(item.suggestedHabit, contains('coffee'));
      expect(item.isCompleted, false);

      final serialized = item.toJson();
      expect(serialized['id'], 101);
      expect(serialized['day_number'], 1);
      expect(serialized['title'], 'Audit Your Cue Environment');
      expect(serialized['is_completed'], false);
    });

    test('ActionPlanItem copyWith updates completion state', () {
      const item = ActionPlanItem(
        id: 1,
        dayNumber: 2,
        title: 'Micro-Habit Formula',
        description: '2-minute rule',
        suggestedHabit: 'Read 1 page',
        isCompleted: false,
      );

      final updated = item.copyWith(isCompleted: true);
      expect(updated.id, 1);
      expect(updated.dayNumber, 2);
      expect(updated.isCompleted, true);
    });

    test('ActionPlan fromJson calculates progress and nextPendingItem', () {
      final json = {
        'id': 10,
        'book': 42,
        'book_title': 'Atomic Habits',
        'book_slug': 'atomic-habits',
        'book_author': 'James Clear',
        'book_cover_image_url': 'https://example.com/cover.jpg',
        'title': 'Atomic Habits: 7-Day Sprint',
        'duration_days': 7,
        'is_active': true,
        'is_completed': false,
        'progress_percent': 14,
        'completed_items_count': 1,
        'total_items_count': 2,
        'items': [
          {
            'id': 1,
            'day_number': 1,
            'title': 'Day 1: Audit',
            'description': 'Audit cue environment',
            'suggested_habit': 'Place shoes by bed',
            'associated_quote': 'Make it obvious',
            'is_completed': true,
          },
          {
            'id': 2,
            'day_number': 2,
            'title': 'Day 2: 2-Minute Rule',
            'description': 'Scale down to 2 mins',
            'suggested_habit': 'Put shoes on',
            'associated_quote': 'Make it easy',
            'is_completed': false,
          },
        ],
      };

      final plan = ActionPlan.fromJson(json);
      expect(plan.id, 10);
      expect(plan.bookSlug, 'atomic-habits');
      expect(plan.durationDays, 7);
      expect(plan.items.length, 2);
      expect(plan.completedItemsCount, 1);
      expect(plan.progressPercent, 14);

      final next = plan.nextPendingItem;
      expect(next, isNotNull);
      expect(next!.dayNumber, 2);
      expect(next.title, 'Day 2: 2-Minute Rule');
    });

    test('ActionPlanExportPayload fromJson parsing', () {
      final json = {
        'plan_id': 10,
        'title': 'Atomic Habits: 7-Day Sprint',
        'book_title': 'Atomic Habits',
        'duration_days': 7,
        'progress_percent': 28,
        'markdown': '# ⚡ Atomic Habits\n- [ ] Day 1: Audit',
        'notion_text': '# Atomic Habits\n[ ] Day 1: Audit',
        'ics_content': 'BEGIN:VCALENDAR\nEND:VCALENDAR',
      };

      final payload = ActionPlanExportPayload.fromJson(json);
      expect(payload.planId, 10);
      expect(payload.markdown, contains('# ⚡ Atomic Habits'));
      expect(payload.notionText, contains('[ ] Day 1: Audit'));
      expect(payload.icsContent, contains('BEGIN:VCALENDAR'));
    });
  });
}
