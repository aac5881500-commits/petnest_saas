// lib/core/services/daycare_time_helper.dart
// 🐾 臨托時間工具：台灣時區顯示、時段重疊、營業時間檢查。

class DaycareTimeHelper {
  DaycareTimeHelper._();

  static const Duration taiwanOffset = Duration(hours: 8);

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
}
