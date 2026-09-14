// 檔案名稱：lib/core/services/booking_payment_labels.dart
// 功能說明：住宿／安親結算卡與操作紀錄共用的付款方式、付款狀態中文；不露出代碼

class BookingPaymentLabels {
  BookingPaymentLabels._();

  static String method(dynamic value) {
    final String raw = (value ?? '').toString().trim();
    if (raw.isEmpty || raw == '-' || raw.toLowerCase() == 'null') {
      return '未設定';
    }
    switch (raw.toLowerCase()) {
      case 'cash':
      case 'onsite':
      case 'store_payment':
      case 'pay_at_store':
      case '店內付款':
      case '到店付款':
      case '現場付款':
        return '店內付款';
      case 'transfer':
      case 'bank_transfer':
      case 'banktransfer':
      case '銀行轉帳':
        return '銀行轉帳';
      case 'credit_card':
      case 'ecpay_credit':
      case '信用卡':
        return '信用卡';
      case 'atm':
      case 'ecpay_atm':
      case 'atm 虛擬帳號':
        return 'ATM 虛擬帳號';
      case 'cvs':
      case 'cvs_code':
      case 'ecpay_cvs':
      case '超商代碼':
      case '超商代碼繳費':
        return '超商代碼繳費';
      case 'point':
      case 'points':
        return '點數';
      default:
        if (_looksLikeCode(raw)) {
          return '其他付款方式';
        }
        return raw;
    }
  }

  static String status(dynamic value) {
    final String raw = (value ?? '').toString().trim();
    if (raw.isEmpty || raw == '-' || raw.toLowerCase() == 'null') {
      return '付款狀態待確認';
    }
    switch (raw.toLowerCase()) {
      case 'unpaid':
        return '尚未付款';
      case 'partial':
      case 'partially_paid':
        return '已付部分款項';
      case 'paid':
      case 'collected':
        return '已付清';
      case 'awaiting_supplement':
        return '待補款';
      case 'awaiting_refund':
        return '待退款';
      case 'awaiting_proof':
        return '等待客戶上傳轉帳證明';
      case 'pending_verification':
      case 'pending_review':
        return '待店家核對';
      case 'staff_verified_no_image':
        return '店員現場已核對入帳';
      case 'selected':
      case 'method_selected':
      case '已選擇方式':
      case '已選擇付款方式':
        return '已選擇付款方式';
      case 'rejected':
        return '核對失敗';
      case 'none':
        return '付款狀態待確認';
      default:
        if (_looksLikeCode(raw)) {
          return '付款狀態待確認';
        }
        return raw;
    }
  }

  static bool _looksLikeCode(String raw) {
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(raw)) {
      return false;
    }
    return raw.contains('_') || RegExp(r'^[a-z0-9]+$', caseSensitive: false).hasMatch(raw);
  }
}
