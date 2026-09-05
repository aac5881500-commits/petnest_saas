// 檔案名稱：lib/features/admin/pages/admin_daycare_list_page.dart
// 功能說明：臨托訂單列表

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/features/admin/pages/admin_daycare_detail_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_create_daycare_booking_page.dart';

class AdminDaycareListPage extends StatefulWidget {
  const AdminDaycareListPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<AdminDaycareListPage> createState() => _AdminDaycareListPageState();
}

class _AdminDaycareListPageState extends State<AdminDaycareListPage> {
  String _status = 'all';
  String _keyword = '';

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('bookings')
        .where('shopId', isEqualTo: widget.shopId)
        .where('bookingKind', isEqualTo: BookingKind.daycare)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('臨托訂單'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      AdminCreateDaycareBookingPage(shopId: widget.shopId),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜尋會員、電話、寵物、訂單編號',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (String value) =>
                  setState(() => _keyword = value.trim()),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: <Widget>[
                for (final Map<String, String> item in <Map<String, String>>[
                  <String, String>{'id': 'all', 'label': '全部'},
                  <String, String>{'id': 'pending', 'label': '待確認'},
                  <String, String>{'id': 'confirmed', 'label': '待到店'},
                  <String, String>{'id': 'checked_in', 'label': '入住中'},
                  <String, String>{'id': 'completed', 'label': '已完成'},
                  <String, String>{'id': 'cancelled', 'label': '已取消'},
                  <String, String>{'id': 'no_show', 'label': 'No-show'},
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(item['label']!),
                      selected: _status == item['id'],
                      onSelected: (_) => setState(() => _status = item['id']!),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.snapshots(),
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
                    final Iterable<QueryDocumentSnapshot<Map<String, dynamic>>>
                    docs = snapshot.data!.docs.where((
                      QueryDocumentSnapshot<Map<String, dynamic>> doc,
                    ) {
                      final Map<String, dynamic> data = doc.data();
                      if (_status != 'all' &&
                          _status != 'no_show' &&
                          (data['status'] ?? '') != _status) {
                        return false;
                      }
                      if (_keyword.isEmpty) {
                        return true;
                      }
                      final String haystack = <String>[
                        (data['customerName'] ?? '').toString(),
                        (data['customerPhone'] ?? '').toString(),
                        (data['bookingCode'] ?? '').toString(),
                        (data['bookingId'] ?? '').toString(),
                        ((data['pets'] as List?) ?? const <dynamic>[])
                            .map((dynamic e) => e is Map ? '${e['name']}' : '')
                            .join(),
                      ].join(' ').toLowerCase();
                      return haystack.contains(_keyword.toLowerCase());
                    });
                    if (docs.isEmpty) {
                      return const Center(child: Text('沒有符合的臨托訂單'));
                    }
                    return ListView(
                      children: docs.map((
                        QueryDocumentSnapshot<Map<String, dynamic>> doc,
                      ) {
                        final Map<String, dynamic> data = doc.data();
                        final DateTime? start =
                            data['scheduledStartAt'] is Timestamp
                            ? (data['scheduledStartAt'] as Timestamp).toDate()
                            : null;
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: ListTile(
                            title: Text(
                              '${data['customerName'] ?? '會員'}　'
                              '${data['bookingCode'] ?? doc.id}',
                            ),
                            subtitle: Text(
                              '${data['serviceDate'] ?? ''}　'
                              '${start == null ? '' : DaycareTimeHelper.formatHm(start)}　'
                              '${data['status']}',
                            ),
                            trailing: Chip(
                              label: Text(
                                BookingKind.label(BookingKind.daycare),
                              ),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => AdminDaycareDetailPage(
                                    shopId: widget.shopId,
                                    bookingId: doc.id,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }).toList(),
                    );
                  },
            ),
          ),
        ],
      ),
    );
  }
}
