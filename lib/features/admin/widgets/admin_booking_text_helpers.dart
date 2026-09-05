// 檔案名稱：lib/features/admin/widgets/admin_booking_text_helpers.dart
// 功能說明：把 status、付款方式、取消來源、操作者角色轉成中文
// 🔤 後台訂單詳細頁：文字轉換工具

String adminBookingOperatorRoleText(dynamic value) {
  switch (value) {
    case 'customer':
      return '客戶自行取消';
    case 'admin':
      return '店家操作';
    case 'system':
      return '系統自動取消';
    case 'staff':
      return '店家人員';
    default:
      return value?.toString() ?? '-';
  }
}

String adminBookingCancelByText(dynamic value) {
  switch (value) {
    case 'customer':
      return '客戶取消';
    case 'admin':
      return '店家取消';
    case 'system':
      return '系統自動取消';
    default:
      return '-';
  }
}

String adminBookingPaymentMethodText(dynamic value) {
  switch (value) {
    case 'cash':
      return '到店付款';
    case 'transfer':
      return '銀行轉帳';
    case 'credit_card':
      return '綠界信用卡';
    case 'atm':
      return '綠界 ATM';
    case 'cvs_code':
      return '綠界超商代碼';
    default:
      return '-';
  }
}

String adminBookingPayAmountTypeText(dynamic value) {
  switch (value) {
    case 'deposit':
      return '先付訂金';
    case 'full':
      return '一次付清';
    default:
      return '-';
  }
}
