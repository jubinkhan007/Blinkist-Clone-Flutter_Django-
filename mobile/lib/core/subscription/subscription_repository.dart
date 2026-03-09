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
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return SubscriptionRepository(dio);
});

final subscriptionInfoProvider = FutureProvider<SubscriptionInfo?>((ref) async {
  return ref.watch(subscriptionRepositoryProvider).fetchSubscriptionInfo();
});
