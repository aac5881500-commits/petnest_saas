// 檔案名稱：lib/core/services/shop_commercial_service.dart
// 功能說明：呼叫後端處理業務、激活碼、創店、訂閱收款與分潤。

import 'package:cloud_functions/cloud_functions.dart';

class ShopCommercialException implements Exception {
  const ShopCommercialException(this.message, {this.permissionDenied = false});

  final String message;
  final bool permissionDenied;

  @override
  String toString() => message;
}

class ShopCommercialService {
  ShopCommercialService._();

  static final instance = ShopCommercialService._();

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'asia-east1');

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await _functions.httpsCallable(name).call(data);
      final value = result.data;
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      return <String, dynamic>{};
    } on FirebaseFunctionsException catch (error) {
      throw ShopCommercialException(
        error.message ?? '操作失敗',
        permissionDenied: error.code == 'permission-denied',
      );
    }
  }

  Future<String> createShop({
    required String name,
    required String city,
    required String district,
    required String activationCode,
    required int acceptedShopOwnerPolicyVersion,
    required String requestId,
  }) async {
    final data = await _call('createShopWithActivation', {
      'name': name,
      'city': city,
      'district': district,
      'activationCode': activationCode,
      'acceptedShopOwnerPolicyVersion': acceptedShopOwnerPolicyVersion,
      'requestId': requestId,
    });
    return (data['shopId'] ?? '').toString();
  }

  Future<List<Map<String, dynamic>>> listSalesReps() async {
    final data = await _call('listSalesReps', {});
    return _maps(data['reps']);
  }

  Future<String> saveSalesRep(Map<String, dynamic> payload) async {
    final data = await _call('saveSalesRep', payload);
    return (data['repId'] ?? '').toString();
  }

  Future<Map<String, dynamic>> listActivationCodes({
    String query = '',
    String status = '',
    String salesRepId = '',
    String cursor = '',
  }) {
    return _call('listActivationCodes', {
      'query': query,
      'status': status,
      'salesRepId': salesRepId,
      'cursor': cursor,
    });
  }

  Future<void> saveActivationCode(Map<String, dynamic> payload) {
    return _call('saveActivationCode', payload);
  }

  Future<Map<String, dynamic>> listSubscriptionShops({
    String status = '',
    String cursor = '',
  }) {
    return _call('listSubscriptionShops', {
      'status': status,
      'cursor': cursor,
    });
  }

  Future<Map<String, dynamic>> listCommissionEntries({
    String repId = '',
    String month = '',
    String status = '',
    String cursor = '',
  }) {
    return _call('listCommissionEntries', {
      'repId': repId,
      'month': month,
      'status': status,
      'cursor': cursor,
    });
  }

  Future<List<Map<String, dynamic>>> listCommissionRules() async {
    final data = await _call('listCommissionRules', {});
    return _maps(data['items']);
  }

  Future<Map<String, dynamic>> migrateActivationCodes({
    required bool dryRun,
    String cursor = '',
  }) {
    return _call('migrateActivationCodes', {
      'dryRun': dryRun,
      'cursor': cursor,
      'limit': 50,
    });
  }

  Future<Map<String, dynamic>> listSubscriptionPayments({String shopId = ''}) {
    return _call('listSubscriptionPayments', {'shopId': shopId});
  }

  Future<Map<String, dynamic>> registerSubscriptionPayment({
    required String shopId,
    required String plan,
    required String cycle,
    required String paymentDate,
    required String method,
    required String requestId,
    required int amountDueMinor,
    required int amountReceivedMinor,
    String differenceReason = '',
    bool grantFullPeriodDespiteShortfall = false,
    String reference = '',
    String note = '',
  }) {
    return _call('registerSubscriptionPayment', {
      'shopId': shopId,
      'plan': plan,
      'cycle': cycle,
      'paymentDate': paymentDate,
      'method': method,
      'requestId': requestId,
      'amountDueMinor': amountDueMinor,
      'amountReceivedMinor': amountReceivedMinor,
      'differenceReason': differenceReason,
      'grantFullPeriodDespiteShortfall': grantFullPeriodDespiteShortfall,
      'reference': reference,
      'note': note,
    });
  }

  Future<Map<String, dynamic>> previewSubscriptionPayment({
    required String shopId,
    required String plan,
    required String cycle,
    required int amountDueMinor,
    required int amountReceivedMinor,
    String differenceReason = '',
    bool grantFullPeriodDespiteShortfall = false,
    String paymentDate = '',
  }) {
    return _call('previewSubscriptionPayment', {
      'shopId': shopId,
      'plan': plan,
      'cycle': cycle,
      'amountDueMinor': amountDueMinor,
      'amountReceivedMinor': amountReceivedMinor,
      'differenceReason': differenceReason,
      'grantFullPeriodDespiteShortfall': grantFullPeriodDespiteShortfall,
      'paymentDate': paymentDate,
    });
  }

  Future<void> confirmSubscriptionPayment(String paymentId) {
    return _call('confirmSubscriptionPayment', {'paymentId': paymentId});
  }

  Future<void> refundSubscriptionPayment({
    required String paymentId,
    required int refundMinor,
    required String reason,
    required String requestId,
    String reference = '',
  }) {
    return _call('refundSubscriptionPayment', {
      'paymentId': paymentId,
      'refundMinor': refundMinor,
      'reason': reason,
      'requestId': requestId,
      'reference': reference,
    });
  }

  Future<void> updateShopPlan({
    required String shopId,
    required String plan,
  }) {
    return _call('updateShopPlan', {
      'shopId': shopId,
      'plan': plan,
    });
  }

  Future<void> grantEntitlement({
    required String shopId,
    required int days,
    required String reason,
  }) {
    return _call('grantShopEntitlement', {
      'shopId': shopId,
      'days': days,
      'reason': reason,
    });
  }

  Future<void> assignShopSales({
    required String shopId,
    required String mode,
    required String salesRepId,
    String reason = '',
  }) {
    return _call('assignShopSales', {
      'shopId': shopId,
      'mode': mode,
      'salesRepId': salesRepId,
      'reason': reason,
    });
  }

  Future<void> saveCommissionRule(Map<String, dynamic> payload) {
    return _call('saveCommissionRule', payload);
  }

  Future<void> settleCommission({
    required String entryId,
    required String action,
    String paidOn = '',
    String reference = '',
    int? amountMinor,
  }) {
    return _call('settleCommission', {
      'entryId': entryId,
      'action': action,
      'paidOn': paidOn,
      'reference': reference,
      'amountMinor': ?amountMinor,
    });
  }

  Future<List<Map<String, dynamic>>> salesMonthSummary(String month) async {
    final data = await _call('salesMonthSummary', {'month': month});
    return _maps(data['items']);
  }

  Future<Map<String, dynamic>> listResponsibleShops({
    String repId = '',
    String cursor = '',
  }) {
    return _call('listResponsibleShops', {
      'repId': repId,
      'cursor': cursor,
    });
  }

  Future<Map<String, dynamic>> shopSummary(String shopId) {
    return _call('getShopCommercial', {'shopId': shopId});
  }

  Future<Map<String, dynamic>> migrate({
    required bool dryRun,
    String cursor = '',
  }) {
    return _call('migrateShopCommercialData', {
      'dryRun': dryRun,
      'cursor': cursor,
      'limit': 100,
    });
  }

  List<Map<String, dynamic>> _maps(Object? value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }
}

String commercialPlanLabel(String plan) {
  switch (plan) {
    case 'free':
      return '免費版';
    case 'basic':
      return '專業版';
    case 'pro':
      return '全模組';
    default:
      return '未設定';
  }
}

String commercialSourceLabel(String source) {
  switch (source) {
    case 'platform_direct':
      return '平台直客';
    case 'sales':
      return '業務';
    case 'campaign':
      return '活動';
    case 'other':
      return '其他';
    default:
      return '未填';
  }
}

String commercialStatusLabel(String status) {
  switch (status) {
    case 'trial':
      return '試用中';
    case 'paid_active':
      return '付費有效';
    case 'gift':
      return '贈送權益';
    case 'expired':
      return '到期未續';
    case 'legacy_unconfirmed':
      return '歷史權益，收款紀錄待確認';
    case 'active':
      return '啟用中';
    case 'disabled':
      return '已停用';
    case 'used_up':
    case 'exhausted':
      return '已用完';
    case 'draft':
      return '待確認';
    case 'confirmed':
      return '已確認';
    default:
      return '未分類';
  }
}

String commercialMoney(Object? minor) {
  final cents = minor is num ? minor.toInt() : int.tryParse('$minor') ?? 0;
  final value = cents ~/ 100;
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final yuan = buffer.toString();
  return negative ? '-NT\$$yuan' : 'NT\$$yuan';
}
