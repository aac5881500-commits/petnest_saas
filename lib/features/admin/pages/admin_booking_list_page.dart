// lib/features/admin/pages/admin_booking_list_page.dart
// 📦 店家訂單列表頁（完整版）

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/features/admin/pages/admin_booking_detail_page.dart';

class AdminBookingListPage extends StatefulWidget {
  const AdminBookingListPage({
    super.key,
    required this.shopId,
    this.filterType, // 🔥 加這行
  });

  final String shopId;
  final String? filterType; // 🔥 加這行

  @override
  State<AdminBookingListPage> createState() =>
      _AdminBookingListPageState();
}

class _AdminBookingListPageState extends State<AdminBookingListPage> {
  late String _filterType;

  @override
  void initState() {
    super.initState();
    _filterType = widget.filterType ?? 'all';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('訂單管理'),
      ),
      body: Column(
        children: [
          /// 🔥 Tab
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceAround,
              children: [
                _buildTab('all', '全部'),
                _buildTab('checkIn', '今日入住'),
                _buildTab('checkOut', '今日退房'),
                _buildTab('future', '未來'),
              ],
            ),
          ),

          /// 🔥 列表
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('shopId',
                      isEqualTo: widget.shopId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child:
                          CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                final now = DateTime.now();
                final todayStart =
                    DateTime(now.year, now.month, now.day);
                final todayEnd =
                    todayStart.add(const Duration(days: 1));

                final filteredDocs = docs.where((doc) {
                  final data =
                      doc.data() as Map<String, dynamic>;

                  final start = (data['startDate']
                          as Timestamp)
                      .toDate();
                  final end =
                      (data['endDate'] as Timestamp)
                          .toDate();
                  final status = data['status'] ?? '';

                  if (status == 'cancelled') return false;

                  switch (_filterType) {
                    case 'checkIn':
                      return start
                              .isAfter(todayStart) &&
                          start.isBefore(todayEnd);
                    case 'checkOut':
                      return end.isAfter(todayStart) &&
                          end.isBefore(todayEnd);
                    case 'future':
                      return start.isAfter(todayEnd);
                    default:
                      return true;
                  }
                }).toList()
                  ..sort((a, b) {
                    final aData =
                        a.data() as Map<String, dynamic>;
                    final bData =
                        b.data() as Map<String, dynamic>;

                    final aDate = (aData['startDate']
                            as Timestamp)
                        .toDate();
                    final bDate = (bData['startDate']
                            as Timestamp)
                        .toDate();

                    return bDate.compareTo(aDate);
                  });

                if (filteredDocs.isEmpty) {
                  return const Center(
                      child:
                          Text('尚無符合條件的訂單'));
                }

                return ListView(
                  children: filteredDocs.map((doc) {
                    final data =
                        doc.data() as Map<String, dynamic>;

                    final start = (data['startDate']
                            as Timestamp)
                        .toDate();
                    final end =
                        (data['endDate'] as Timestamp)
                            .toDate();

                    final status =
                        data['status'] ?? 'pending';

                    Color statusColor;
                    String statusText;

                    switch (status) {
                      case 'confirmed':
                        statusColor = Colors.green;
                        statusText = '已確認';
                        break;
                      case 'checked_in':
                        statusColor = Colors.blue;
                        statusText = '入住中';
                        break;
                      case 'completed':
                        statusColor = Colors.grey;
                        statusText = '已完成';
                        break;
                      case 'cancelled':
                        statusColor = Colors.red;
                        statusText = '已取消';
                        break;
                      default:
                        statusColor = Colors.orange;
                        statusText = '待確認';
                    }

                    return Card(
                      child: ListTile(
                        leading:
                            const Icon(Icons.home),
                        title: Text(
                            data['roomName'] ?? '房型'),

                        subtitle: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            /// 日期
                            Text(
                              '${_formatDate(start)} ～ ${_formatDate(end)}',
                            ),

                            const SizedBox(height: 4),

                            /// 客人
                            Text(
                              '👤 ${data['customerName'] ?? '未填姓名'}',
                            ),

                            const SizedBox(height: 4),

                            /// 寵物
                            Builder(
                              builder: (_) {
                                final pets =
                                    (data['pets'] as List?)
                                            ?.map((e) => e
                                                as Map<String,
                                                    dynamic>)
                                            .toList() ??
                                        [];

                                if (pets.isEmpty) {
                                  return const Text(
                                      '🐾 無寵物資料');
                                }

                                final names = pets
                                    .map((p) =>
                                        p['name'])
                                    .join(', ');
                                return Text(
                                    '🐾 $names');
                              },
                            ),

                            const SizedBox(height: 6),

                            /// 狀態
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration:
                                  BoxDecoration(
                                color: statusColor
                                    .withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(
                                        12),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AdminBookingDetailPage(
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

  /// 🔥 Tab UI
  Widget _buildTab(String type, String text) {
    final selected = _filterType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _filterType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              selected ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color:
                selected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}