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

class SubscriptionPlanModel {
  final int id;
  final String name;
  final String slug;
  final String billingInterval;
  final double priceUsd;
  final double priceBdt;
  final String stripePriceId;
  final String appleProductId;
  final String googleProductId;

  const SubscriptionPlanModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.billingInterval,
    required this.priceUsd,
    required this.priceBdt,
    required this.stripePriceId,
    required this.appleProductId,
    required this.googleProductId,
  });

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      billingInterval: (json['billing_interval'] as String?) ?? 'month',
      priceUsd: (json['price_usd'] as num?)?.toDouble() ?? 0.0,
      priceBdt: (json['price_bdt'] as num?)?.toDouble() ?? 0.0,
      stripePriceId: (json['stripe_price_id'] as String?) ?? '',
      appleProductId: (json['apple_product_id'] as String?) ?? '',
      googleProductId: (json['google_product_id'] as String?) ?? '',
    );
  }
}

class CouponValidationResult {
  final String code;
  final bool isValid;
  final int discountPercent;
  final double discountAmountUsd;
  final double finalPriceUsd;
  final String message;

  const CouponValidationResult({
    required this.code,
    required this.isValid,
    required this.discountPercent,
    required this.discountAmountUsd,
    required this.finalPriceUsd,
    required this.message,
  });

  factory CouponValidationResult.fromJson(Map<String, dynamic> json) {
    return CouponValidationResult(
      code: (json['code'] as String?) ?? '',
      isValid: json['is_valid'] == true,
      discountPercent: (json['discount_percent'] as num?)?.toInt() ?? 0,
      discountAmountUsd: (json['discount_amount_usd'] as num?)?.toDouble() ?? 0.0,
      finalPriceUsd: (json['final_price_usd'] as num?)?.toDouble() ?? 0.0,
      message: (json['message'] as String?) ?? '',
    );
  }
}

class UserReferralStats {
  final String referralCode;
  final String shareUrl;
  final int discountPercent;
  final int bonusDaysEarned;
  final int successfulReferralsCount;
  final int bonusDaysPerReferral;

  const UserReferralStats({
    required this.referralCode,
    required this.shareUrl,
    required this.discountPercent,
    required this.bonusDaysEarned,
    required this.successfulReferralsCount,
    required this.bonusDaysPerReferral,
  });

  factory UserReferralStats.fromJson(Map<String, dynamic> json) {
    return UserReferralStats(
      referralCode: (json['referral_code'] as String?) ?? '',
      shareUrl: (json['share_url'] as String?) ?? '',
      discountPercent: (json['discount_percent'] as num?)?.toInt() ?? 30,
      bonusDaysEarned: (json['bonus_days_earned'] as num?)?.toInt() ?? 0,
      successfulReferralsCount: (json['successful_referrals_count'] as num?)?.toInt() ?? 0,
      bonusDaysPerReferral: (json['bonus_days_per_referral'] as num?)?.toInt() ?? 7,
    );
  }
}

class FreeTrialResult {
  final bool success;
  final String message;
  final int daysRemaining;
  final DateTime? trialEndDate;

  const FreeTrialResult({
    required this.success,
    required this.message,
    required this.daysRemaining,
    this.trialEndDate,
  });

  factory FreeTrialResult.fromJson(Map<String, dynamic> json) {
    final endRaw = json['trial_end_date'];
    return FreeTrialResult(
      success: json['success'] == true,
      message: (json['message'] as String?) ?? '',
      daysRemaining: (json['days_remaining'] as num?)?.toInt() ?? 0,
      trialEndDate: endRaw is String ? DateTime.tryParse(endRaw) : null,
    );
  }
}

