// 檔案名稱：lib/features/shop/widgets/chat/shop_chat_recent_orders.dart
// 功能說明：聊天格「最近訂單」：此店此客戶最近 5 筆住宿／安親，點擊走既有訂單路由。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/navigation/admin_booking_route.dart';
import 'package:petnest_saas/core/services/daycare_status_labels.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';

class ShopChatRecentOrderItem {
  const ShopChatRecentOrderItem({
    required this.id,
    required this.data,
    required this.kindLabel,
    required this.code,
    required this.petText,
    required this.dateText,
    required this.statusText,
    required this.roomName,
    required this.isDaycare,
  });

  final String id;
  final Map<String, dynamic> data;
  final String kindLabel;
  final String code;
  final String petText;
  final String dateText;
  final String statusText;
  final String roomName;
  final bool isDaycare;

  static List<ShopChatRecentOrderItem> fromBookings(
    List<Map<String, dynamic>> bookings,
  ) {
    return bookings
        .map(ShopChatRecentOrderItem.fromBooking)
        .toList(growable: false);
  }

  static ShopChatRecentOrderItem fromBooking(Map<String, dynamic> data) {
    final bool daycare = BookingKind.isDaycare(data);
    final String id = (data['id'] ?? data['bookingId'] ?? '').toString();
    return ShopChatRecentOrderItem(
      id: id,
      data: data,
      kindLabel: daycare ? '安親' : '住宿',
      code: _codeOf(data, id),
      petText: _petsOf(data),
      dateText: daycare ? _daycareTime(data) : _stayDates(data),
      statusText: daycare
          ? DaycareStatusLabels.primary(data)
          : _stayStatus(data),
      roomName: daycare ? '' : (data['roomName'] ?? '').toString().trim(),
      isDaycare: daycare,
    );
  }

  static String _codeOf(Map<String, dynamic> data, String id) {
    final String code = (data['bookingCode'] ?? '').toString().trim();
    if (code.isNotEmpty) {
      return code;
    }
    if (id.length <= 8) {
      return id;
    }
    return id.substring(id.length - 8);
  }

  static String _petsOf(Map<String, dynamic> data) {
    final Object? names = data['petNames'];
    if (names is Iterable) {
      final List<String> list = names
          .map((dynamic item) => item.toString().trim())
          .where((String item) => item.isNotEmpty)
          .toList();
      if (list.isNotEmpty) {
        return list.join('、');
      }
    }
    final Object? pets = data['pets'];
    if (pets is Iterable) {
      final List<String> list = <String>[];
      for (final Object? raw in pets) {
        if (raw is Map) {
          final String name = (raw['name'] ?? raw['petName'] ?? '')
              .toString()
              .trim();
          if (name.isNotEmpty) {
            list.add(name);
          }
        } else {
          final String name = raw.toString().trim();
          if (name.isNotEmpty) {
            list.add(name);
          }
        }
      }
      if (list.isNotEmpty) {
        return list.join('、');
      }
    }
    return (data['petName'] ?? '').toString().trim();
  }

  static String _stayDates(Map<String, dynamic> data) {
    final DateTime? start = _dateOf(data['startDate']);
    final DateTime? end = _dateOf(data['endDate']);
    if (start == null && end == null) {
      return '';
    }
    if (start != null && end != null) {
      return '${DateFormat('M/d').format(start)}～${DateFormat('M/d').format(end)}';
    }
    return DateFormat('M/d').format(start ?? end!);
  }

  static String _daycareTime(Map<String, dynamic> data) {
    final DateTime? start =
        _dateOf(data['actualStartAt']) ?? _dateOf(data['scheduledStartAt']);
    final DateTime? end =
        _dateOf(data['actualEndAt']) ?? _dateOf(data['scheduledEndAt']);
    if (start != null && end != null) {
      return '${DateFormat('M/d HH:mm').format(start)}～${DateFormat('HH:mm').format(end)}';
    }
    if (start != null) {
      return DateFormat('M/d HH:mm').format(start);
    }
    final String serviceDate = (data['serviceDate'] ?? '').toString().trim();
    return serviceDate;
  }

  static String _stayStatus(Map<String, dynamic> data) {
    switch ((data['status'] ?? '').toString()) {
      case 'pending':
      case 'pending_confirmation':
      case 'unpaid':
        return '待確認';
      case 'confirmed':
        return '已確認';
      case 'checked_in':
        return '入住中';
      case 'checked_out':
        return '已退房';
      case 'completed':
        return '已完成';
      case 'cancelled':
        return '已取消';
      default:
        return (data['status'] ?? '').toString();
    }
  }

  static DateTime? _dateOf(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}

Future<void> showShopChatRecentOrders({
  required BuildContext context,
  required String shopId,
  required String customerUid,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: ShopChatService.instance.listRecentBookings(
              shopId: shopId,
              customerUid: customerUid,
            ),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
                ) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final List<ShopChatRecentOrderItem> items =
                      ShopChatRecentOrderItem.fromBookings(snapshot.data!);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          '最近訂單',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: items.isEmpty
                            ? const Center(child: Text('此會員尚無訂單紀錄'))
                            : ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (BuildContext context, int index) {
                                  final ShopChatRecentOrderItem item =
                                      items[index];
                                  return ListTile(
                                    title: Text(
                                      '${item.kindLabel} ${item.code}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      <String>[
                                        if (item.petText.isNotEmpty)
                                          item.petText,
                                        if (item.dateText.isNotEmpty)
                                          item.dateText,
                                        if (item.roomName.isNotEmpty)
                                          item.roomName,
                                        item.statusText,
                                      ].join('・'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      AdminBookingRoute.open(
                                        context,
                                        bookingId: item.id,
                                        data: item.data,
                                        shopId: shopId,
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
          ),
        ),
      );
    },
  );
}
