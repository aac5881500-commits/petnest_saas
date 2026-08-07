// lib/core/services/payment_function_service.dart
// 💳 PetNest 金流 Cloud Functions Service
// 功能：呼叫 Firebase Callable Function 建立綠界付款，
// 並統一解析付款網址、ATM 虛擬帳號與超商代碼。
// 注意：Flutter 不得傳送或保存 MerchantID、HashKey、HashIV。

import 'package:cloud_functions/cloud_functions.dart';

import '../models/create_payment_request_model.dart';
import '../models/create_payment_result_model.dart';

class PaymentFunctionService {
  PaymentFunctionService._();

  static final PaymentFunctionService instance = PaymentFunctionService._();

  /// Cloud Functions 部署區域
  ///
  /// 之後後端 Functions 必須部署在相同區域。
  static const String functionsRegion = 'asia-east1';

  /// 建立綠界付款的 Callable Function 名稱
  static const String createPaymentFunctionName = 'createEcpayPayment';

  FirebaseFunctions get _functions {
    return FirebaseFunctions.instanceFor(region: functionsRegion);
  }

  /// 呼叫 Cloud Functions 建立綠界付款
  ///
  /// Flutter 只傳送訂單、付款方式與防重複 requestId。
  /// 後端必須重新從 Firestore 驗證：
  /// 1. 使用者是否登入
  /// 2. 訂單是否屬於目前使用者
  /// 3. 訂單是否可付款
  /// 4. 付款金額是否正確
  /// 5. 店家與平台金流是否啟用
  Future<CreatePaymentResultModel> createPayment({
    required CreatePaymentRequestModel request,
  }) async {
    if (!request.isValid) {
      throw const PaymentFunctionException(
        code: 'invalid-payment-request',
        message: '付款資料不完整，請重新確認後再試。',
      );
    }

    try {
      final HttpsCallable callable = _functions.httpsCallable(
        createPaymentFunctionName,
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );

      final HttpsCallableResult<dynamic> result = await callable.call<dynamic>(
        request.toCallableMap(),
      );

      final Map<String, dynamic> responseData = _mapFromDynamic(result.data);

      final CreatePaymentResultModel paymentResult =
          CreatePaymentResultModel.fromMap(responseData);

      if (!paymentResult.success) {
        throw PaymentFunctionException(
          code: 'payment-create-failed',
          message: paymentResult.message.trim().isNotEmpty
              ? paymentResult.message.trim()
              : '建立付款失敗，請稍後再試。',
          details: responseData,
        );
      }

      if (paymentResult.paymentId.trim().isEmpty) {
        throw PaymentFunctionException(
          code: 'invalid-function-response',
          message: '付款服務回傳資料不完整，請稍後再試。',
          details: responseData,
        );
      }

      return paymentResult;
    } on FirebaseFunctionsException catch (error) {
      throw PaymentFunctionException(
        code: error.code,
        message: _resolveFunctionsErrorMessage(error),
        details: error.details,
      );
    } on PaymentFunctionException {
      rethrow;
    } catch (error) {
      throw PaymentFunctionException(
        code: 'unknown',
        message: '建立付款時發生錯誤，請稍後再試。',
        details: error.toString(),
      );
    }
  }

  /// 將 Functions 回傳的 dynamic 安全轉成 Map
  static Map<String, dynamic> _mapFromDynamic(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map<String, dynamic>((dynamic key, dynamic mapValue) {
        return MapEntry<String, dynamic>(key.toString(), mapValue);
      });
    }

    throw PaymentFunctionException(
      code: 'invalid-function-response',
      message: '付款服務回傳格式錯誤，請稍後再試。',
      details: value,
    );
  }

  /// 將 Functions 錯誤代碼轉換成會員可讀訊息
  static String _resolveFunctionsErrorMessage(
    FirebaseFunctionsException error,
  ) {
    switch (error.code) {
      case 'unauthenticated':
        return '請先登入會員帳號後再付款。';

      case 'permission-denied':
        return '你沒有執行這筆付款的權限。';

      case 'invalid-argument':
        return _messageOrDefault(error.message, '付款資料不正確，請重新確認。');

      case 'not-found':
        return _messageOrDefault(error.message, '找不到指定的訂單或付款資料。');

      case 'already-exists':
        return _messageOrDefault(error.message, '這筆付款已經建立，請勿重複操作。');

      case 'failed-precondition':
        return _messageOrDefault(error.message, '目前無法建立付款，請確認訂單與店家付款狀態。');

      case 'resource-exhausted':
        return '付款操作過於頻繁，請稍後再試。';

      case 'deadline-exceeded':
        return '付款服務回應逾時，請先確認是否已建立付款紀錄。';

      case 'unavailable':
        return '付款服務目前無法使用，請稍後再試。';

      case 'internal':
        return _messageOrDefault(error.message, '付款服務發生錯誤，請稍後再試。');

      default:
        return _messageOrDefault(error.message, '建立付款失敗，請稍後再試。');
    }
  }

  static String _messageOrDefault(String? message, String defaultMessage) {
    final String normalizedMessage = message?.trim() ?? '';

    return normalizedMessage.isNotEmpty ? normalizedMessage : defaultMessage;
  }

  /// 📝 送出店家的綠界金流設定
  ///
  /// 功能：
  /// - 呼叫 submitEcpayPaymentSetting Cloud Function
  /// - 將 MerchantID、HashKey、HashIV 安全送往後端
  /// - 建立等待平台審核的金流設定
  Future<void> submitEcpayPaymentSetting({
    required String shopId,
    required String merchantName,
    required String merchantId,
    required String hashKey,
    required String hashIv,
    required String environment,
    required bool creditCardEnabled,
    required bool atmEnabled,
    required bool cvsCodeEnabled,
  }) async {
    if (shopId.trim().isEmpty ||
        merchantName.trim().isEmpty ||
        merchantId.trim().isEmpty ||
        hashKey.trim().isEmpty ||
        hashIv.trim().isEmpty) {
      throw const PaymentFunctionException(
        code: 'invalid-payment-setting',
        message: '綠界金流設定資料不完整，請重新確認。',
      );
    }

    if (!creditCardEnabled && !atmEnabled && !cvsCodeEnabled) {
      throw const PaymentFunctionException(
        code: 'payment-method-required',
        message: '請至少選擇一種付款方式。',
      );
    }

    try {
      final HttpsCallable callable = _functions.httpsCallable(
        'submitEcpayPaymentSetting',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );

      await callable.call<dynamic>({
        'shopId': shopId.trim(),
        'merchantName': merchantName.trim(),
        'merchantId': merchantId.trim(),
        'hashKey': hashKey.trim(),
        'hashIv': hashIv.trim(),
        'environment': environment.trim(),
        'creditCardEnabled': creditCardEnabled,
        'atmEnabled': atmEnabled,
        'cvsCodeEnabled': cvsCodeEnabled,
      });
    } on FirebaseFunctionsException catch (error) {
      throw PaymentFunctionException(
        code: error.code,
        message: _messageOrDefault(error.message, '送出綠界金流設定失敗，請稍後再試。'),
        details: error.details,
      );
    } on PaymentFunctionException {
      rethrow;
    } catch (error) {
      throw PaymentFunctionException(
        code: 'unknown',
        message: '送出綠界金流設定時發生錯誤，請稍後再試。',
        details: error.toString(),
      );
    }
  }

  /// ⚙️ 更新店家收款方式營運設定
  ///
  /// 功能：
  /// - 呼叫 updatePaymentOperationSettings Cloud Function
  /// - 更新銀行轉帳與綠界付款營運開關
  /// - 到店付款由後端固定維持啟用
  Future<void> updatePaymentOperationSettings({
    required String shopId,
    required bool bankTransferEnabled,
    required bool ecpayEnabled,
    required bool creditCardEnabled,
    required bool atmEnabled,
    required bool cvsCodeEnabled,
  }) async {
    if (shopId.trim().isEmpty) {
      throw const PaymentFunctionException(
        code: 'invalid-shop-id',
        message: '店家資料不完整，請重新整理後再試。',
      );
    }

    try {
      final HttpsCallable callable = _functions.httpsCallable(
        'updatePaymentOperationSettings',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      await callable.call<dynamic>({
        'shopId': shopId.trim(),
        'bankTransferEnabled': bankTransferEnabled,
        'ecpayEnabled': ecpayEnabled,
        'creditCardEnabled': creditCardEnabled,
        'atmEnabled': atmEnabled,
        'cvsCodeEnabled': cvsCodeEnabled,
      });
    } on FirebaseFunctionsException catch (error) {
      throw PaymentFunctionException(
        code: error.code,
        message: _messageOrDefault(error.message, '更新收款方式失敗，請稍後再試。'),
        details: error.details,
      );
    } catch (error) {
      throw PaymentFunctionException(
        code: 'unknown',
        message: '更新收款方式時發生錯誤，請稍後再試。',
        details: error.toString(),
      );
    }
  }
}

/// Flutter 金流 Functions 統一例外
class PaymentFunctionException implements Exception {
  const PaymentFunctionException({
    required this.code,
    required this.message,
    this.details,
  });

  final String code;
  final String message;
  final dynamic details;

  @override
  String toString() {
    return 'PaymentFunctionException('
        'code: $code, '
        'message: $message'
        ')';
  }
}
