import 'package:cloud_functions/cloud_functions.dart';

abstract class PlatformBillingStore {
  Future<Map<String, dynamic>> load(String shopId);
  Future<Map<String, dynamic>> refresh(String shopId);
  Future<Map<String, dynamic>> checkout(Map<String, dynamic> request);
  Future<Map<String, dynamic>> cancel(String shopId);
}

class PlatformBillingService implements PlatformBillingStore {
  PlatformBillingService._();
  static final instance = PlatformBillingService._();
  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await FirebaseFunctions.instanceFor(
        region: 'asia-east1',
      ).httpsCallable(name).call(data);
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (error) {
      final message = error.message ?? '';
      throw PlatformBillingException(
        RegExp(r'[\u4e00-\u9fff]').hasMatch(message)
            ? message
            : '平台付款暫時無法使用，請稍後重試或聯絡平台。',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> load(String shopId) =>
      _call('getPlatformBilling', {'shopId': shopId});
  @override
  Future<Map<String, dynamic>> refresh(String shopId) =>
      _call('refreshPlatformBilling', {'shopId': shopId});
  @override
  Future<Map<String, dynamic>> checkout(Map<String, dynamic> request) =>
      _call('checkoutPlatformSubscription', request);
  @override
  Future<Map<String, dynamic>> cancel(String shopId) =>
      _call('cancelPlatformSubscription', {'shopId': shopId});
}

class PlatformBillingException implements Exception {
  const PlatformBillingException(this.message);
  final String message;
  @override
  String toString() => message;
}
