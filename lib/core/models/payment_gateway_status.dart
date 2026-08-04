// lib/core/models/payment_gateway_status.dart
// 💳 共用金流狀態定義
// 功能：集中管理金流服務商、店家審核狀態、付款狀態與付款方式常數。

/// 金流服務商
abstract final class PaymentGateway {
  /// 綠界科技
  static const String ecpay = 'ecpay';
}

/// 店家金流設定審核狀態
abstract final class PaymentGatewayReviewStatus {
  /// 尚未設定
  static const String notConfigured = 'not_configured';

  /// 草稿，尚未送審
  static const String draft = 'draft';

  /// 等待平台審核
  static const String pending = 'pending';

  /// 平台已核准
  static const String approved = 'approved';

  /// 平台退回
  static const String rejected = 'rejected';

  /// 平台暫停此店家金流
  static const String suspended = 'suspended';

  /// 店家金流已停用
  static const String disabled = 'disabled';

  static bool isApproved(String status) {
    return status == approved;
  }

  static bool isPending(String status) {
    return status == pending;
  }

  static bool isLocked(String status) {
    return status == pending || status == approved || status == suspended;
  }
}

/// 付款交易狀態
abstract final class PaymentTransactionStatus {
  /// 尚未建立付款
  static const String pending = 'pending';

  /// 正在建立付款資料
  static const String creating = 'creating';

  /// 等待會員付款
  static const String awaitingPayment = 'awaiting_payment';

  /// 付款處理中
  static const String processing = 'processing';

  /// 付款成功
  static const String paid = 'paid';

  /// 付款失敗
  static const String failed = 'failed';

  /// 付款已逾期
  static const String expired = 'expired';

  /// 付款已取消
  static const String cancelled = 'cancelled';

  /// 退款處理中
  static const String refundPending = 'refund_pending';

  /// 已部分退款
  static const String partiallyRefunded = 'partially_refunded';

  /// 已全額退款
  static const String refunded = 'refunded';

  static bool isPaid(String status) {
    return status == paid;
  }

  static bool canCreatePayment(String status) {
    return status == pending ||
        status == failed ||
        status == expired ||
        status == cancelled;
  }
}

/// 會員付款方式
abstract final class PaymentMethodType {
  /// 到店付款
  static const String cash = 'cash';

  /// 銀行轉帳
  static const String bankTransfer = 'transfer';

  /// 信用卡
  static const String creditCard = 'credit_card';

  /// ATM 虛擬帳號
  static const String atm = 'atm';

  /// 超商代碼
  static const String convenienceStoreCode = 'cvs_code';

  static const List<String> onlineMethods = <String>[
    creditCard,
    atm,
    convenienceStoreCode,
  ];

  static bool isOnlinePayment(String method) {
    return onlineMethods.contains(method);
  }
}

/// 本次訂單收款金額類型
abstract final class PaymentAmountType {
  /// 收取訂金
  static const String deposit = 'deposit';

  /// 收取全額
  static const String full = 'full';
}

/// 店家金流申請類型
abstract final class PaymentGatewayRequestType {
  /// 首次申請設定
  static const String initialSetup = 'initial_setup';

  /// 申請修改已鎖定的金流資料
  static const String changeRequest = 'change_request';

  /// 申請重新啟用
  static const String reactivate = 'reactivate';
}
