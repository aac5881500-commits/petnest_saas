// 檔案名稱：lib/core/services/daycare_time_helper.dart
// 功能說明：臨托時間工具：台灣時區顯示、時段重疊、營業時間檢查。

class DaycareTimeHelper {
  DaycareTimeHelper._();

  static const Duration taiwanOffset = Duration(hours: 8);

  static String callableInstant(DateTime value) {
    return value.toUtc().toIso8601String();
  }

  static DateTime toTaiwan(DateTime value) {
    return value.toUtc().add(taiwanOffset);
  }

  static DateTime combineDateAndTime(DateTime date, String hhmm) {
    final List<String> parts = hhmm.split(':');
    final int hour = int.tryParse(parts.first) ?? 0;
    final int minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  static String formatHm(DateTime value) {
    final DateTime local = toTaiwan(value);
    final String h = local.hour.toString().padLeft(2, '0');
    final String m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String formatDate(DateTime value) {
    final DateTime local = toTaiwan(value);
    final String m = local.month.toString().padLeft(2, '0');
    final String d = local.day.toString().padLeft(2, '0');
    return '${local.year}/$m/$d';
  }

  static String formatDateTime(DateTime value) {
    return '${formatDate(value)} ${formatHm(value)}';
  }

  static String formatDateTimeOrUnrecorded(DateTime? value) {
    if (value == null) {
      return '尚未記錄';
    }
    return formatDateTime(value);
  }

  static const String actualEndInFutureMessage = '實際接回時間不可晚於目前時間';
  static const String actualStartInFutureMessage = '實際送達時間不可晚於目前時間';
  static const String actualEndBeforeStartMessage = '實際接回時間不可早於實際送達時間';

  static String? actualTimesError({
    DateTime? actualStartAt,
    required DateTime actualEndAt,
    DateTime? now,
  }) {
    final DateTime current = now ?? DateTime.now();
    if (actualStartAt != null && actualStartAt.isAfter(current)) {
      return actualStartInFutureMessage;
    }
    if (actualEndAt.isAfter(current)) {
      return actualEndInFutureMessage;
    }
    if (actualStartAt != null && actualEndAt.isBefore(actualStartAt)) {
      return actualEndBeforeStartMessage;
    }
    return null;
  }

  static String dateKey(DateTime value) {
    final DateTime day = DateTime(value.year, value.month, value.day);
    final String m = day.month.toString().padLeft(2, '0');
    final String d = day.day.toString().padLeft(2, '0');
    return '${day.year}-$m-$d';
  }

  static String overrideDocId(DateTime value) {
    return dateKey(value).replaceAll('-', '');
  }

  static String durationLabel(int minutes) {
    final int safe = minutes < 0 ? 0 : minutes;
    final int hours = safe ~/ 60;
    final int rest = safe % 60;
    if (hours > 0 && rest > 0) {
      return '$hours 小時 $rest 分';
    }
    if (hours > 0) {
      return '$hours 小時';
    }
    return '$rest 分';
  }

  static bool overlaps(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }

  static bool sameCalendarDay(DateTime a, DateTime b) {
    final DateTime ta = toTaiwan(a);
    final DateTime tb = toTaiwan(b);
    return ta.year == tb.year && ta.month == tb.month && ta.day == tb.day;
  }

  static int weekdayTaiwan(DateTime value) {
    return toTaiwan(value).weekday;
  }

  static int minutesOf(String hhmm) {
    final List<String> parts = hhmm.split(':');
    final int hour = int.tryParse(parts.first) ?? 0;
    final int minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return hour * 60 + minute;
  }

  static List<String> slots({
    required String start,
    required String end,
    required int stepMinutes,
  }) {
    final int from = minutesOf(start);
    final int to = minutesOf(end);
    final int step = stepMinutes <= 0 ? 30 : stepMinutes;
    final List<String> result = <String>[];
    for (int m = from; m <= to; m += step) {
      final int h = m ~/ 60;
      final int min = m % 60;
      result.add(
        '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}',
      );
    }
    return result;
  }

  static bool isSameLocalDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 今天已達或超過最晚接回（含整點），整天不可再預約。
  static bool isTodayPastLatestPickUp({
    required DateTime date,
    required String latestPickUp,
    DateTime? now,
  }) {
    final DateTime clock = now ?? DateTime.now();
    final DateTime day = DateTime(date.year, date.month, date.day);
    final DateTime today = DateTime(clock.year, clock.month, clock.day);
    if (day != today) {
      return false;
    }
    final DateTime latest = combineDateAndTime(day, latestPickUp);
    return !clock.isBefore(latest);
  }

  /// 僅「今天」（台灣時區）會關閉已過時段；未來日期不受現在時刻影響。
  static bool isSlotSelectable({
    required String slot,
    required DateTime date,
    required DateTime now,
    String? afterSlot,
  }) {
    final DateTime nowTw = toTaiwan(now);
    final DateTime selectedDay = DateTime(date.year, date.month, date.day);
    final DateTime todayTw = DateTime(nowTw.year, nowTw.month, nowTw.day);
    if (selectedDay.isBefore(todayTw)) {
      return false;
    }
    if (selectedDay == todayTw) {
      final int nowMinutes = nowTw.hour * 60 + nowTw.minute;
      if (minutesOf(slot) <= nowMinutes) {
        return false;
      }
    }
    if (afterSlot != null && afterSlot.isNotEmpty) {
      if (minutesOf(slot) <= minutesOf(afterSlot)) {
        return false;
      }
    }
    return true;
  }

  static bool hasSelectableSlot({
    required List<String> slots,
    required DateTime date,
    required DateTime now,
    String? afterSlot,
  }) {
    return slots.any(
      (String slot) => isSlotSelectable(
        slot: slot,
        date: date,
        now: now,
        afterSlot: afterSlot,
      ),
    );
  }
}
