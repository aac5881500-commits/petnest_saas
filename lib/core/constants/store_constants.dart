// 檔案名稱：lib/core/constants/store_constants.dart
// 功能說明：統一商城訂單狀態、履約方式、Firestore 路徑與庫存保留期限。
// 🛒 賣場 / 商城常數

class StoreConstants {
  StoreConstants._();

  static const String productsCollection = 'store_products';
  static const String promotionsCollection = 'store_promotions';
  static const String categoriesCollection = 'store_categories';
  static const String ordersCollection = 'store_orders';
  static const String cartsCollection = 'store_carts';
  static const String reservationsCollection = 'store_reservations';
  static const String settingsCollection = 'store_settings';
  static const String settingsDocId = 'main';
  static const String countersCollection = 'store_counters';

  static const String imageFolder = 'store';
  static const String bannerImageFolder = 'store/banners';
  static const int reservationMinutes = 20;

  static const String fulfillmentPickup = 'pickup';
  static const String fulfillmentDelivery = 'delivery';

  static const String statusPendingPayment = 'pending_payment';
  static const String statusPaid = 'paid';
  static const String statusPreparing = 'preparing';
  static const String statusReadyForPickup = 'ready_for_pickup';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';

  static const String paymentUnpaid = 'unpaid';
  static const String paymentPaid = 'paid';
  static const String paymentRefunded = 'refunded';

  static const String reservationHeld = 'held';
  static const String reservationConverted = 'converted';
  static const String reservationReleased = 'released';
  static const String reservationExpired = 'expired';

  static const String stockUnlimited = 'unlimited';
  static const String stockInStock = 'in_stock';
  static const String stockLow = 'low_stock';
  static const String stockOutOfStock = 'out_of_stock';

  /// 前台「低庫存」門檻：可售件數（不含成本或安全庫存數字）。
  static const int lowStockSellableThreshold = 3;

  static const List<String> orderStatuses = <String>[
    statusPendingPayment,
    statusPaid,
    statusPreparing,
    statusReadyForPickup,
    statusCompleted,
    statusCancelled,
  ];

  static String statusLabel(String status) {
    switch (status) {
      case statusPendingPayment:
        return '待付款';
      case statusPaid:
        return '已付款';
      case statusPreparing:
        return '備貨中';
      case statusReadyForPickup:
        return '可取貨';
      case statusCompleted:
        return '已完成';
      case statusCancelled:
        return '已取消';
      default:
        return status;
    }
  }

  static String paymentStatusLabel(String status) {
    switch (status) {
      case paymentPaid:
        return '已付款';
      case paymentRefunded:
        return '已退款';
      default:
        return '未付款';
    }
  }

  static String fulfillmentLabel(String value) {
    if (value == fulfillmentDelivery) {
      return '宅配（尚未開放）';
    }
    return '店內自取';
  }
}
