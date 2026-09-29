import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/networking/api_client.dart';
import '../../../../core/auth/auth_repository.dart';
import '../domain/onboarding_models.dart';

const List<OnboardingTopic> kDefaultOnboardingTopics = [
  OnboardingTopic(
    id: 'productivity',
    slug: 'personal-development',
    title: 'Productivity & Focus',
    subtitle: 'Build high-performance habits and master your time',
    icon: 'bolt',
  ),
  OnboardingTopic(
    id: 'entrepreneurship',
    slug: 'business',
    title: 'Entrepreneurship & Startups',
    subtitle: 'Scaling companies, leadership, and bold ideas',
    icon: 'rocket_launch',
  ),
  OnboardingTopic(
    id: 'psychology',
    slug: 'psychology',
    title: 'Psychology & Behavior',
    subtitle: 'Understand cognitive biases, emotion, and decisions',
    icon: 'psychology',
  ),
  OnboardingTopic(
    id: 'science',
    slug: 'science',
    title: 'Science & Technology',
    subtitle: 'AI, physics, biology, and the frontier of the future',
    icon: 'biotech',
  ),
  OnboardingTopic(
    id: 'leadership',
    slug: 'business',
    title: 'Management & Leadership',
    subtitle: 'Inspire high-trust teams and execute strategy',
    icon: 'groups',
  ),
  OnboardingTopic(
    id: 'mindfulness',
    slug: 'self-help',
    title: 'Mindfulness & Well-being',
    subtitle: 'Stress resilience, mental clarity, and happiness',
    icon: 'self_improvement',
  ),
  OnboardingTopic(
    id: 'history',
    slug: 'history',
    title: 'History & Society',
    subtitle: 'Timeless lessons from world-shaping events and thinkers',
    icon: 'history_edu',
  ),
  OnboardingTopic(
    id: 'personal_growth',
    slug: 'personal-development',
    title: 'Personal Growth',
    subtitle: 'Communication, creativity, and lifelong learning',
    icon: 'trending_up',
  ),
];

const List<ReadingGoalOption> kReadingGoalOptions = [
  ReadingGoalOption(
    id: 'daily_15',
    title: '15 min / 1 summary daily',
    subtitle: 'The gold standard habit for busy learners',
    badge: 'Popular',
    emoji: '⚡',
  ),
  ReadingGoalOption(
    id: 'commute',
    title: 'During daily commute',
    subtitle: 'Turn travel time into audio knowledge sessions',
    badge: 'Commuter',
    emoji: '🚆',
  ),
  ReadingGoalOption(
    id: 'career',
    title: 'Career & leadership acceleration',
    subtitle: 'Supercharge strategic thinking and team skills',
    badge: 'Growth',
    emoji: '🚀',
  ),
  ReadingGoalOption(
    id: 'casual',
    title: 'Casual curiosity & weekends',
    subtitle: 'Explore mind-expanding ideas at your own pace',
    badge: 'Relaxed',
    emoji: '☕',
  ),
];

class OnboardingRepository {
  final Dio _dio;
  final SharedPreferences _prefs;

  OnboardingRepository(this._dio, this._prefs);

  Future<List<OnboardingTopic>> fetchTopics() async {
    try {
      final response = await _dio.get('/accounts/onboarding/topics/');
      final data = response.data;
      if (data is Map && data['topics'] is List) {
        return (data['topics'] as List)
            .map((json) => OnboardingTopic.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Fall back to default topics if offline or unauthenticated
    }
    return kDefaultOnboardingTopics;
  }

  Future<void> submitPreferences({
    required String readingGoal,
    required String preferredFormat,
    required List<String> interestTopics,
  }) async {
    // 1. Save locally in SharedPreferences
    await _prefs.setBool('has_completed_onboarding', true);
    await _prefs.setString('onboarding_reading_goal', readingGoal);
    await _prefs.setString('onboarding_preferred_format', preferredFormat);
    await _prefs.setStringList('onboarding_interest_topics', interestTopics);

    // 2. Sync to backend if authenticated
    try {
      await _dio.post(
        '/accounts/onboarding/',
        data: {
          'reading_goal': readingGoal,
          'preferred_format': preferredFormat,
          'interest_topics': interestTopics,
        },
      );
    } catch (_) {
      // Offline fallback: preferences saved locally and can sync on next login
    }
  }

  bool isCompleted() {
    return _prefs.getBool('has_completed_onboarding') ?? false;
  }

  String getSavedReadingGoal() {
    return _prefs.getString('onboarding_reading_goal') ?? 'daily_15';
  }

  String getSavedPreferredFormat() {
    return _prefs.getString('onboarding_preferred_format') ?? 'both';
  }

  List<String> getSavedInterestTopics() {
    return _prefs.getStringList('onboarding_interest_topics') ?? [];
  }
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return OnboardingRepository(dio, prefs);
});

final onboardingTopicsProvider = FutureProvider<List<OnboardingTopic>>((ref) async {
  return ref.watch(onboardingRepositoryProvider).fetchTopics();
});

final hasCompletedOnboardingProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(onboardingRepositoryProvider);
  if (repo.isCompleted()) return true;

  // Also check AuthUser if logged in
  final authUser = await ref.watch(authRepositoryProvider).getUserProfile();
  if (authUser != null && authUser.hasCompletedOnboarding) {
    // Persist locally
    final prefs = ref.watch(sharedPreferencesProvider);
    await prefs.setBool('has_completed_onboarding', true);
    return true;
  }

  return false;
});
