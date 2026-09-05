// 檔案名稱：lib/core/models/booking_kind.dart
// 功能說明：訂單服務種類：住宿 / 臨托
// 舊訂單沒有 bookingKind 時一律視為住宿，不可讀取錯誤。

class BookingKind {
  BookingKind._();

  static const String accommodation = 'accommodation';
  static const String daycare = 'daycare';

  static String resolve(Map<String, dynamic>? data) {
    if (data == null) {
      return accommodation;
    }
    final String kind = (data['bookingKind'] ?? '').toString().trim();
    if (kind == daycare) {
      return daycare;
    }
    if (kind == accommodation) {
      return accommodation;
    }
    final String serviceType = (data['serviceType'] ?? '').toString().trim();
    if (serviceType == daycare) {
      return daycare;
    }
    return accommodation;
  }

  static bool isDaycare(Map<String, dynamic>? data) {
    return resolve(data) == daycare;
  }

  static bool isAccommodation(Map<String, dynamic>? data) {
    return resolve(data) == accommodation;
  }

  static String label(String kind) {
    return kind == daycare ? '安親' : '住宿';
  }
}
