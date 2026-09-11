// 檔案名稱：lib/core/services/booking_search_fields.dart
// 功能說明：訂單搜尋正規化欄位。寫入時補上，查詢不可改成讀取全部歷史。

class BookingSearchFields {
  BookingSearchFields._();

  static String normalizeCode(String raw) {
    return raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  static String digitsOnly(String raw) {
    return raw.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static String normalizeName(String raw) {
    return raw.trim().toLowerCase();
  }

  static List<String> petNames(List<dynamic>? pets) {
    final List<String> names = <String>[];
    if (pets == null) {
      return names;
    }
    for (final dynamic item in pets) {
      if (item is! Map) {
        continue;
      }
      final String name = (item['name'] ?? '').toString().trim().toLowerCase();
      if (name.isEmpty || names.contains(name)) {
        continue;
      }
      names.add(name);
      if (names.length >= 8) {
        break;
      }
    }
    return names;
  }

  static Map<String, dynamic> fromBooking(Map<String, dynamic> data) {
    final String name = (data['customerName'] ?? '').toString();
    final String phone = (data['customerPhone'] ?? '').toString();
    final String code = (data['bookingCode'] ?? data['bookingId'] ?? '')
        .toString();
    final String digits = digitsOnly(phone);
    return <String, dynamic>{
      'customerNameNormalized': normalizeName(name),
      'customerPhoneDigits': digits,
      'customerPhoneLast4': digits.length >= 4
          ? digits.substring(digits.length - 4)
          : digits,
      'customerPhoneLast5': digits.length >= 5
          ? digits.substring(digits.length - 5)
          : digits,
      'bookingCodeNormalized': normalizeCode(code),
      'petNamesNormalized': petNames(
        data['pets'] is List ? data['pets'] as List<dynamic> : null,
      ),
    };
  }
}
