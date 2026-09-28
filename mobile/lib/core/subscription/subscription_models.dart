class SubscriptionInfo {
  final String? email;
  final String? username;
  final String? firstName;
  final String? lastName;
  final String? bio;
  final String? avatarUrl;
  final bool isPremium;
  final int trialDaysRemaining;
  final String? subscriptionStatus;
  final DateTime? subscriptionEndDate;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActiveDate;

  const SubscriptionInfo({
    required this.email,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.bio,
    required this.avatarUrl,
    required this.isPremium,
    required this.trialDaysRemaining,
    required this.subscriptionStatus,
    required this.subscriptionEndDate,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActiveDate,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    final endDateRaw = json['subscription_end_date'];
    final activeDateRaw = json['last_active_date'];
    return SubscriptionInfo(
      email: json['email'] as String?,
      username: json['username'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isPremium: json['is_premium'] == true,
      trialDaysRemaining: (json['trial_days_remaining'] as num?)?.toInt() ?? 0,
      subscriptionStatus: json['subscription_status'] as String?,
      subscriptionEndDate: endDateRaw is String
          ? DateTime.tryParse(endDateRaw)
          : null,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      lastActiveDate: activeDateRaw is String
          ? DateTime.tryParse(activeDateRaw)
          : null,
    );
  }
}

class PaymentInitiation {
  final String tranId;
  final String gatewayUrl;
  final String mode;

  const PaymentInitiation({
    required this.tranId,
    required this.gatewayUrl,
    required this.mode,
  });

  factory PaymentInitiation.fromJson(Map<String, dynamic> json) {
    return PaymentInitiation(
      tranId: (json['tran_id'] as String?) ?? '',
      gatewayUrl: (json['gateway_url'] as String?) ?? '',
      mode: (json['mode'] as String?) ?? 'unknown',
    );
  }
}
