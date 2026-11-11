import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_parse.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreArrivalShortcut {
  const PreArrivalShortcut(this.userId, this.shopId, this.bookingId);

  final String userId, shopId, bookingId;
  static final changes = ValueNotifier<int>(0);

  String get scope => '$userId/$shopId/$bookingId';
  String get preferenceKey => '${shopPrefix(userId, shopId)}$bookingId';
  static String shopPrefix(String userId, String shopId) =>
      'preparation/home/v1/$userId/$shopId/';

  static String progressKey(String scope, String serviceType) =>
      'preparation/v1/$scope/$serviceType';

  static String itemKey(PreArrivalGuideBlock block) =>
      jsonEncode(<String>[block.id, block.text]);

  bool? choice(SharedPreferences prefs) => prefs.getBool(preferenceKey);

  Future<bool> saveChoice(SharedPreferences prefs, bool pin) async {
    try {
      final saved = await prefs.setBool(preferenceKey, pin);
      if (saved) changes.value++;
      return saved;
    } catch (_) {
      return false;
    }
  }

  static bool canPrepare(BookingDetailViewData view) =>
      view.checkInAt == null &&
      view.actualStartAt == null &&
      view.checkOutAt == null &&
      view.cancelledAt == null &&
      !const {
        'checked_in',
        'checked_out',
        'completed',
        'cancelled',
        'canceled',
        'no_show',
        'rejected',
        'expired',
      }.contains(view.status);

  static bool eligible(BookingDetailViewData view) =>
      !view.isDaycare && view.startDate != null && canPrepare(view);

  static DateTime taipei(DateTime value) =>
      value.toUtc().add(const Duration(hours: 8));

  static String countdown(DateTime arrival, DateTime now) {
    DateTime day(DateTime value) {
      final local = taipei(value);
      return DateTime.utc(local.year, local.month, local.day);
    }

    final days = day(arrival).difference(day(now)).inDays;
    if (days < 0) return '尚待辦理入住';
    if (days == 0) return '今天入住';
    return '距離入住還有 $days 天';
  }

  static String schedule(BookingDetailViewData view) {
    final date = taipei(view.scheduledStartAt!);
    final dateLabel =
        '${date.month}/${date.day}（${'一二三四五六日'[date.weekday - 1]}）';
    // Older accommodation orders store a selected arrival window as a time add-on.
    for (final addon in BookingDetailParse.parseMapList(view.raw['addons'])) {
      final type = addon['type'];
      final label = BookingDetailParse.parseString(addon['name']);
      if ((type == 'time' || type == 'time_addon') && label.contains('入住')) {
        final times = RegExp(
          r'(?:[01]?\d|2[0-3]):[0-5]\d',
        ).allMatches(label).map((match) => match.group(0)!).take(2).join('–');
        if (times.isNotEmpty) return '$dateLabel $times 入住';
      }
    }
    final hasScheduledTime =
        BookingDetailParse.parseDate(view.raw['scheduledStartAt']) != null;
    final time = !hasScheduledTime || (date.hour == 0 && date.minute == 0)
        ? ''
        : ' ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '$dateLabel$time 入住';
  }
}
