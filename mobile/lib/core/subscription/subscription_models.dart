class SubscriptionInfo {
  final bool isPremium;
  final int trialDaysRemaining;
  final String? subscriptionStatus;
  final DateTime? subscriptionEndDate;

  const SubscriptionInfo({
    required this.isPremium,
    required this.trialDaysRemaining,
    required this.subscriptionStatus,
    required this.subscriptionEndDate,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    final endDateRaw = json['subscription_end_date'];
    return SubscriptionInfo(
      isPremium: json['is_premium'] == true,
      trialDaysRemaining: (json['trial_days_remaining'] as num?)?.toInt() ?? 0,
      subscriptionStatus: json['subscription_status'] as String?,
      subscriptionEndDate: endDateRaw is String
          ? DateTime.tryParse(endDateRaw)
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
