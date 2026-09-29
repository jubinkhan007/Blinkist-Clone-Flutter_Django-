class OnboardingTopic {
  final String id;
  final String slug;
  final String title;
  final String subtitle;
  final String icon;

  const OnboardingTopic({
    required this.id,
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  factory OnboardingTopic.fromJson(Map<String, dynamic> json) {
    return OnboardingTopic(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      icon: json['icon'] as String? ?? 'bolt',
    );
  }
}

class ReadingGoalOption {
  final String id;
  final String title;
  final String subtitle;
  final String badge;
  final String emoji;

  const ReadingGoalOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.emoji,
  });
}

class OnboardingPreferences {
  final String readingGoal;
  final String preferredFormat;
  final List<String> interestTopics;

  const OnboardingPreferences({
    required this.readingGoal,
    required this.preferredFormat,
    required this.interestTopics,
  });

  Map<String, dynamic> toJson() {
    return {
      'reading_goal': readingGoal,
      'preferred_format': preferredFormat,
      'interest_topics': interestTopics,
    };
  }
}
