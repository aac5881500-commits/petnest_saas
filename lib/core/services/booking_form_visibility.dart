// 檔案名稱：lib/core/services/booking_form_visibility.dart
// 功能說明：住宿／安親訂單上三種自訂表單的顯示規則（客戶端永不顯示手動表單）。

class BookingFormVisibility {
  BookingFormVisibility._();

  static bool isAdminCreated(Map<String, dynamic> data) {
    return (data['source'] ?? '').toString().trim() == 'admin';
  }

  static bool isCustomerSelfSubmit(Map<String, dynamic> data) {
    return !isAdminCreated(data);
  }

  static bool showCustomerSubmitForm({
    required Map<String, dynamic> data,
    required bool hasAnswers,
  }) {
    return isCustomerSelfSubmit(data) && hasAnswers;
  }

  static bool showAdminCreateForm({
    required Map<String, dynamic> data,
    required bool isShopView,
    bool hasAnswers = false,
  }) {
    return isShopView && isAdminCreated(data);
  }

  static bool showInternalHandover({required bool isShopView}) {
    return isShopView;
  }
}
