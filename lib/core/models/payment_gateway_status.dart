// 檔案名稱：lib/core/models/payment_gateway_status.dart
// 功能說明：集中管理金流服務商、店家審核狀態、付款狀態與付款方式常數。
// 💳 共用金流狀態定義

/// 金流服務商
abstract final class PaymentGateway {
  /// 綠界科技
  static const String ecpay = 'ecpay';
}

/// 付款來源類型
///
/// 舊住宿付款沒有 sourceType 時，視為 booking。
abstract final class PaymentSourceType {
  static const String booking = 'booking';
  static const String storeOrder = 'store_order';

  static String resolve(dynamic value, {String bookingId = ''}) {
    final String raw = (value ?? '').toString().trim().toLowerCase();
    if (raw == storeOrder) {
      return storeOrder;
    }

    if (raw == booking || bookingId.trim().isNotEmpty) {
      return booking;
    }

    return booking;
  }

  static bool isStoreOrder(String value) {
    return value == storeOrder;
  }
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

  /// 結算金額已更新，這筆待付款已失效（真實收款 callback 仍可入帳）
  static const String superseded = 'superseded';

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

/// 本次付款用途
///
/// 與 PaymentAmountType 不同：
/// PaymentAmountType 負責決定後端如何計算付款金額；
/// PaymentPurpose 負責記錄這筆付款實際是用來支付什麼。
abstract final class PaymentPurpose {
  /// 預約訂金
  static const String deposit = 'deposit';

  /// 預約尾款
  static const String balance = 'balance';

  /// 預約一次付清
  static const String full = 'full';

  /// 加購服務、延長住宿或其他補款（舊資料相容讀取）
  static const String additional = 'additional';

  /// 其他人工指定付款（舊資料相容讀取）
  static const String other = 'other';

  /// 舊結算補款（相容讀取，新資料寫 balance）
  static const String topUp = 'top_up';

  /// 退款
  static const String refund = 'refund';

  static const List<String> values = <String>[
    deposit,
    balance,
    full,
    additional,
    other,
    topUp,
    refund,
  ];

  static bool isValid(String value) {
    return values.contains(value);
  }

  static String normalize(String purpose) {
    final String raw = purpose.trim();
    if (raw == additional || raw == topUp || raw == other) {
      return balance;
    }
    return raw;
  }

  /// 顯示用途。舊 additional／top_up 視為結算尾款；amountType=deposit 優先顯示訂金。
  static String displayLabel(String purpose, {String amountType = ''}) {
    if (purpose == deposit || amountType == PaymentAmountType.deposit) {
      return '訂金';
    }
    if (purpose == refund || amountType == refund) {
      return '退款';
    }
    if (purpose == balance ||
        purpose == additional ||
        purpose == topUp ||
        purpose == other) {
      return '結算尾款';
    }
    if (purpose == full) {
      return '全額付款';
    }
    if (amountType == PaymentAmountType.full) {
      return '全額付款';
    }
    return '付款';
  }
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
