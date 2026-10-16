import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../networking/api_client.dart';
import 'subscription_models.dart';

class SubscriptionRepository {
  final Dio _dio;

  SubscriptionRepository(this._dio);

  Future<SubscriptionInfo?> fetchSubscriptionInfo() async {
    try {
      final response = await _dio.get('/me/');
      return SubscriptionInfo.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Not logged in.
        return null;
      }
      rethrow;
    }
  }

  Future<PaymentInitiation> initiatePayment() async {
    final response = await _dio.post('/payments/initiate/');
    return PaymentInitiation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> cancelSubscription() async {
    await _dio.post('/payments/subscription/cancel/');
  }

  Future<List<SubscriptionPlanModel>> fetchPlans() async {
    final response = await _dio.get('/payments/plans/');
    final list = response.data as List<dynamic>;
    return list
        .map((e) => SubscriptionPlanModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CouponValidationResult> validateCoupon(
    String code, {
    int? planId,
  }) async {
    final response = await _dio.post(
      '/payments/coupons/validate/',
      data: {
        'code': code.trim(),
        if (planId != null) 'plan_id': planId,
      },
    );
    return CouponValidationResult.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<FreeTrialResult> startFreeTrial({int trialDays = 7}) async {
    final response = await _dio.post(
      '/payments/trial/start/',
      data: {'trial_days': trialDays},
    );
    return FreeTrialResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserReferralStats> fetchReferralStats() async {
    final response = await _dio.get('/payments/referral/');
    return UserReferralStats.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PaymentInitiation> createStripeCheckout({
    required int planId,
    String? couponCode,
  }) async {
    final response = await _dio.post(
      '/payments/stripe/checkout/',
      data: {
        'plan_id': planId,
        if (couponCode != null && couponCode.trim().isNotEmpty)
          'coupon_code': couponCode.trim(),
      },
    );
    return PaymentInitiation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> verifyInAppPurchase({
    required String gateway,
    required String productId,
    required String receiptData,
    String? transactionId,
    int? planId,
  }) async {
    final response = await _dio.post(
      '/payments/iap/verify/',
      data: {
        'gateway': gateway,
        'product_id': productId,
        'receipt_data': receiptData,
        if (transactionId != null) 'transaction_id': transactionId,
        if (planId != null) 'plan_id': planId,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<SubscriptionInfo> updateProfile({
    required String firstName,
    required String lastName,
    required String bio,
    required String avatarUrl,
  }) async {
    final response = await _dio.patch(
      '/me/',
      data: {
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'bio': bio.trim(),
        'avatar_url': avatarUrl.trim(),
      },
    );
    return SubscriptionInfo.fromJson(response.data as Map<String, dynamic>);
  }
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return SubscriptionRepository(dio);
});

final subscriptionInfoProvider = FutureProvider<SubscriptionInfo?>((ref) async {
  return ref.watch(subscriptionRepositoryProvider).fetchSubscriptionInfo();
});

final subscriptionPlansProvider =
    FutureProvider<List<SubscriptionPlanModel>>((ref) async {
  return ref.watch(subscriptionRepositoryProvider).fetchPlans();
});

final userReferralProvider = FutureProvider<UserReferralStats>((ref) async {
  return ref.watch(subscriptionRepositoryProvider).fetchReferralStats();
});

