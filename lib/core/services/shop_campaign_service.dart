import 'package:cloud_functions/cloud_functions.dart';

class ShopCampaignService {
  ShopCampaignService._();
  static final instance = ShopCampaignService._();
  Future<Map<String, dynamic>> call(
    String shopId,
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    final result = await FirebaseFunctions.instanceFor(region: 'asia-east1')
        .httpsCallable(
          'manageShopCampaign',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
        )
        .call({'shopId': shopId, 'action': action, ...data});
    return Map<String, dynamic>.from(result.data as Map);
  }

  static String error(Object error) => error is FirebaseFunctionsException
      ? error.code == 'not-found' || error.code == 'unimplemented'
            ? '通知服務尚未部署或暫時無法使用，請聯絡管理員。'
            : error.message ?? '操作失敗，請稍後重試。'
      : '操作失敗，請確認網路後重試；草稿仍保留在畫面中。';
}
