// lib/features/admin/pages/admin_daycare_board_page.dart
// 🐾 今日臨托：當天操作看板，不是第二個訂單列表

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/services/daycare_function_service.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/features/admin/pages/admin_daycare_detail_page.dart';
import 'package:petnest_saas/features/admin/widgets/admin_daycare_assign_room_dialog.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_status_card.dart';

class AdminDaycareBoardPage extends StatelessWidget {
  const AdminDaycareBoardPage({super.key, required this.shopId});

  final String shopId;

  String get _todayKey {
    final DateTime now = DateTime.now();
    final String m = now.month.toString().padLeft(2, '0');
    final String d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('今日臨托')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('shopId', isEqualTo: shopId)
            .where('bookingKind', isEqualTo: BookingKind.daycare)
            .where('serviceDate', isEqualTo: _todayKey)
            .snapshots(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.hasError) {
                return Center(child: Text('載入失敗：${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                  snapshot.data!.docs
                      .where((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                        return (doc.data()['status'] ?? '').toString() !=
                            'cancelled';
                      })
                      .toList();
              if (docs.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: const <Widget>[
                    Card(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 32,
                          horizontal: 20,
                        ),
                        child: Column(
                          children: <Widget>[
                            Icon(Icons.wb_sunny_outlined, size: 36),
                            SizedBox(height: 12),
                            Text(
                              '今日尚無臨托訂單',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
              final DateTime now = DateTime.now();
              final List<QueryDocumentSnapshot<Map<String, dynamic>>> pending =
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final List<QueryDocumentSnapshot<Map<String, dynamic>>> waiting =
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final List<QueryDocumentSnapshot<Map<String, dynamic>>> ongoing =
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final List<QueryDocumentSnapshot<Map<String, dynamic>>> pickup =
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final List<QueryDocumentSnapshot<Map<String, dynamic>>> overtime =
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final List<QueryDocumentSnapshot<Map<String, dynamic>>> done =
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in docs) {
                final Map<String, dynamic> data = doc.data();
                final String status = (data['status'] ?? '').toString();
                if (status == 'completed') {
                  done.add(doc);
                  continue;
                }
                if (status == 'pending') {
                  pending.add(doc);
                  continue;
                }
                if (status == 'checked_in') {
                  final DateTime? end = _ts(data['scheduledEndAt']);
                  if (end != null && now.isAfter(end)) {
                    overtime.add(doc);
                  } else if (end != null &&
                      end.difference(now).inMinutes <= 60) {
                    pickup.add(doc);
                  } else {
                    ongoing.add(doc);
                  }
                  continue;
                }
                waiting.add(doc);
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  _BoardSection(
                    shopId: shopId,
                    title: '待店家確認',
                    items: pending,
                  ),
                  _BoardSection(
                    shopId: shopId,
                    title: '等待送達',
                    items: waiting,
                  ),
                  _BoardSection(
                    shopId: shopId,
                    title: '臨托中',
                    items: ongoing,
                  ),
                  _BoardSection(
                    shopId: shopId,
                    title: '即將接回',
                    items: pickup,
                  ),
                  _BoardSection(
                    shopId: shopId,
                    title: '已超時',
                    items: overtime,
                  ),
                  _BoardSection(
                    shopId: shopId,
                    title: '今日已完成',
                    items: done,
                  ),
                ],
              );
            },
      ),
    );
  }

  static DateTime? _ts(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    return null;
  }
}

class _BoardSection extends StatelessWidget {
  const _BoardSection({
    required this.shopId,
    required this.title,
    required this.items,
  });

  final String shopId;
  final String title;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            '$title（${items.length}）',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        ...items.map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) => _BoardCard(
            shopId: shopId,
            bookingId: doc.id,
            data: doc.data(),
          ),
        ),
      ],
    );
  }
}

class _BoardCard extends StatefulWidget {
  const _BoardCard({
    required this.shopId,
    required this.bookingId,
    required this.data,
  });

  final String shopId;
  final String bookingId;
  final Map<String, dynamic> data;

  @override
  State<_BoardCard> createState() => _BoardCardState();
}

class _BoardCardState extends State<_BoardCard> {
  bool _busy = false;

  Future<void> _run(String action) async {
    setState(() => _busy = true);
    try {
      await DaycareFunctionService.instance.manage(
        shopId: widget.shopId,
        bookingId: widget.bookingId,
        action: action,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data = widget.data;
    final String status = (data['status'] ?? '').toString();
    final bool assigned = (data['assignStatus'] ?? '') == 'assigned' &&
        (data['roomId'] ?? '').toString().isNotEmpty;
    final DateTime? start = data['scheduledStartAt'] is Timestamp
        ? (data['scheduledStartAt'] as Timestamp).toDate()
        : null;
    final DateTime? end = data['scheduledEndAt'] is Timestamp
        ? (data['scheduledEndAt'] as Timestamp).toDate()
        : null;
    final List<dynamic> pets = data['pets'] is List
        ? data['pets'] as List<dynamic>
        : const <dynamic>[];
    final List<String> petNames = pets
        .map((dynamic item) {
          if (item is Map) {
            return (item['name'] ?? '').toString();
          }
          return '';
        })
        .where((String name) => name.isNotEmpty)
        .toList();
    final int petCount = (data['petIds'] is List)
        ? (data['petIds'] as List).length
        : petNames.length;
    final String roomText = assigned
        ? '${data['roomTypeNameSnapshot'] ?? data['roomTypeName'] ?? ''}　'
              '${data['roomNumberSnapshot'] ?? data['roomName'] ?? ''}'
        : '房間將由店家安排';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => AdminDaycareDetailPage(
                      shopId: widget.shopId,
                      bookingId: widget.bookingId,
                    ),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    (data['customerName'] ?? '會員').toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    petNames.isEmpty
                        ? '寵物 $petCount 隻'
                        : '${petNames.join('、')}（$petCount 隻）',
                  ),
                  Text(
                    '${start == null ? '' : DaycareTimeHelper.formatHm(start)}'
                    ' - ${end == null ? '' : DaycareTimeHelper.formatHm(end)}',
                  ),
                  Text(roomText),
                  const SizedBox(height: 6),
                  BookingDetailStatusCard(data: data),
                  Text(
                    '付款：${_payText(data)}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (status == 'pending')
                  FilledButton(
                    onPressed: _busy ? null : () => _run('confirm'),
                    child: const Text('確認訂單'),
                  ),
                if (status == 'confirmed' && !assigned)
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => showDaycareAssignRoomDialog(
                            context: context,
                            shopId: widget.shopId,
                            bookingId: widget.bookingId,
                            booking: data,
                          ),
                    child: const Text('分配房間'),
                  ),
                if (status == 'confirmed' && assigned)
                  FilledButton(
                    onPressed: _busy ? null : () => _run('start'),
                    child: const Text('入住'),
                  ),
                if (status == 'checked_in')
                  FilledButton(
                    onPressed: _busy ? null : () => _run('complete'),
                    child: const Text('完成臨托'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _payText(Map<String, dynamic> data) {
    final String payment = (data['paymentStatus'] ?? '').toString();
    if (payment == 'paid') {
      return '已付款';
    }
    if (payment == 'partial') {
      return '部分付款';
    }
    return '未付款';
  }
}
