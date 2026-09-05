// 檔案名稱：lib/core/services/store_function_service.dart
// 功能說明：商城 Cloud Functions 呼叫

import 'package:cloud_functions/cloud_functions.dart';

class StoreFunctionService {
  StoreFunctionService._();

  static final StoreFunctionService instance = StoreFunctionService._();

  static const String functionsRegion = 'asia-east1';

  FirebaseFunctions get _functions {
    return FirebaseFunctions.instanceFor(region: functionsRegion);
  }

  Future<Map<String, dynamic>> createStoreOrder({
    required String shopId,
    required List<Map<String, dynamic>> items,
    String fulfillmentType = 'pickup',
    String customerName = '',
    String customerPhone = '',
  }) async {
    final HttpsCallableResult<dynamic> result = await _functions
        .httpsCallable('createStoreOrder')
        .call(<String, dynamic>{
          'shopId': shopId,
          'items': items,
          'fulfillmentType': fulfillmentType,
          'customerName': customerName,
          'customerPhone': customerPhone,
        });

    final Object? data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw Exception('建立商城訂單失敗');
  }

  Future<void> updateStoreOrderStatus({
    required String shopId,
    required String orderId,
    required String action,
    String reason = '',
  }) async {
    await _functions.httpsCallable('updateStoreOrderStatus').call(
      <String, dynamic>{
        'shopId': shopId,
        'orderId': orderId,
        'action': action,
        'reason': reason,
      },
    );
  }
}
