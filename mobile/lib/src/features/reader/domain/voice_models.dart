class VoicePersona {
  final String id;
  final String name;
  final String persona;
  final String gender;
  final String accent;
  final String description;
  final String avatar;
  final bool isDefault;
  final bool isPremium;
  final bool isUnlocked;
  final double speedRecommendation;

  const VoicePersona({
    required this.id,
    required this.name,
    required this.persona,
    required this.gender,
    required this.accent,
    required this.description,
    required this.avatar,
    this.isDefault = false,
    this.isPremium = false,
    this.isUnlocked = true,
    this.speedRecommendation = 1.0,
  });

  factory VoicePersona.fromJson(Map<String, dynamic> json) {
    return VoicePersona(
      id: json['id'] as String? ?? 'christopher',
      name: json['name'] as String? ?? 'Christopher',
      persona: json['persona'] as String? ?? 'The Thoughtful Strategist',
      gender: json['gender'] as String? ?? 'male',
      accent: json['accent'] as String? ?? 'US English',
      description: json['description'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '👨‍💼',
      isDefault: json['is_default'] as bool? ?? false,
      isPremium: json['is_premium'] as bool? ?? false,
      isUnlocked: json['is_unlocked'] as bool? ?? true,
      speedRecommendation:
          (json['speed_recommendation'] as num?)?.toDouble() ?? 1.0,
    );
  }

  static const List<VoicePersona> defaultCatalog = [
    VoicePersona(
      id: 'christopher',
      name: 'Christopher',
      persona: 'The Thoughtful Strategist',
      gender: 'male',
      accent: 'US English',
      description:
          'Warm, authoritative, deliberate cadence. Ideal for strategy, leadership, and deep focus.',
      avatar: '👨‍💼',
      isDefault: true,
      isPremium: false,
      isUnlocked: true,
    ),
    VoicePersona(
      id: 'jenny',
      name: 'Jenny',
      persona: 'The Calm Storyteller',
      gender: 'female',
      accent: 'US English',
      description:
          'Empathetic, clear, and engaging rhythm. Ideal for mindfulness, psychology, and personal growth.',
      avatar: '👩‍💼',
      isDefault: false,
      isPremium: false,
      isUnlocked: true,
    ),
    VoicePersona(
      id: 'guy',
      name: 'Guy',
      persona: 'The Energetic Executive',
      gender: 'male',
      accent: 'US English',
      description:
          'Crisp, dynamic, high-momentum delivery. Perfect for productivity, business, and economics.',
      avatar: '⚡',
      isDefault: false,
      isPremium: false,
      isUnlocked: true,
      speedRecommendation: 1.1,
    ),
    VoicePersona(
      id: 'sonia',
      name: 'Sonia',
      persona: 'The Refined Scholar',
      gender: 'female',
      accent: 'British English',
      description:
          'Articulate, nuanced, British eloquence. Best for science, philosophy, and historical deep dives.',
      avatar: '🎓',
      isDefault: false,
      isPremium: true,
      isUnlocked: false,
    ),
    VoicePersona(
      id: 'brian',
      name: 'Brian',
      persona: 'The Modern Innovator',
      gender: 'male',
      accent: 'US English',
      description:
          'Fresh, conversational, upbeat delivery. Great for technology, creativity, and modern biographies.',
      avatar: '🚀',
      isDefault: false,
      isPremium: true,
      isUnlocked: false,
      speedRecommendation: 1.05,
    ),
  ];
}
