// 檔案名稱：lib/core/models/daily_care_date_helper.dart
// 功能說明：每日照護有效日期
// 規則：入住日包含、退房日不包含。
// checkInDate <= careDate < checkOutDate
// 不改 booking checkIn / checkOut、房價 nights 或庫存。

class DailyCareDateHelper {
  const DailyCareDateHelper._();

  static DateTime dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  /// 以 Asia/Taipei（UTC+8）取日曆日，不用 UTC 當天當照護日。
  static DateTime calendarDateInTaipei(DateTime value) {
    final DateTime utc = value.toUtc();
    final DateTime taipei = utc.add(const Duration(hours: 8));
    return DateTime(taipei.year, taipei.month, taipei.day);
  }

  static DateTime todayInTaipei([DateTime? now]) {
    return calendarDateInTaipei(now ?? DateTime.now());
  }

  static String dateKey(DateTime value) {
    final DateTime day = dateOnly(value);
    return '${day.year}/'
        '${day.month.toString().padLeft(2, '0')}/'
        '${day.day.toString().padLeft(2, '0')}';
  }

  static DateTime? parseDateKey(String key) {
    final List<String> parts = key.split('/');
    if (parts.length != 3) {
      return null;
    }
    final int? year = int.tryParse(parts[0]);
    final int? month = int.tryParse(parts[1]);
    final int? day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }
    return DateTime(year, month, day);
  }

  /// DailyCareRecordService.buildRecordId 使用的 yyyymmdd
  static String recordIdDateKey(DateTime value) {
    final DateTime day = dateOnly(value);
    return '${day.year.toString().padLeft(4, '0')}'
        '${day.month.toString().padLeft(2, '0')}'
        '${day.day.toString().padLeft(2, '0')}';
  }

  /// 可填寫／可顯示的照護日期（不含退房日）
  static List<DateTime> careDates({
    required DateTime? checkIn,
    required DateTime? checkOut,
  }) {
    if (checkIn == null || checkOut == null) {
      return const <DateTime>[];
    }

    final DateTime start = calendarDateInTaipei(checkIn);
    final DateTime endExclusive = calendarDateInTaipei(checkOut);
    if (!endExclusive.isAfter(start)) {
      return const <DateTime>[];
    }

    final List<DateTime> dates = <DateTime>[];
    DateTime cursor = start;
    while (cursor.isBefore(endExclusive)) {
      dates.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    return dates;
  }

  static List<String> careDateKeys({
    required DateTime? checkIn,
    required DateTime? checkOut,
  }) {
    return careDates(
      checkIn: checkIn,
      checkOut: checkOut,
    ).map(dateKey).toList();
  }

  /// 首頁／今日狀態：今天若在有效照護日就用今天，否則用今天之前最近的有效日。
  /// 例如入住 8/29、退房 8/30，8/30 仍入住時查 8/29。
  static DateTime resolveCurrentCareDate({
    required DateTime? checkIn,
    required DateTime? checkOut,
    DateTime? now,
  }) {
    final DateTime today = todayInTaipei(now);
    final List<DateTime> dates = careDates(
      checkIn: checkIn,
      checkOut: checkOut,
    );
    if (dates.isEmpty) {
      return today;
    }

    for (final DateTime date in dates) {
      if (date == today) {
        return today;
      }
    }

    DateTime? latestOnOrBefore;
    for (final DateTime date in dates) {
      if (!date.isAfter(today)) {
        latestOnOrBefore = date;
      }
    }
    return latestOnOrBefore ?? dates.first;
  }

  static bool isCareDate({
    required DateTime date,
    required DateTime? checkIn,
    required DateTime? checkOut,
  }) {
    if (checkIn == null || checkOut == null) {
      return true;
    }
    return careDateKeys(
      checkIn: checkIn,
      checkOut: checkOut,
    ).contains(dateKey(date));
  }
}
