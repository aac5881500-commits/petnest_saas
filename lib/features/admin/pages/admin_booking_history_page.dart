// 檔案名稱：lib/features/admin/pages/admin_booking_history_page.dart
// 功能說明：後台歷史訂單查詢頁
// 功能：
// - 查詢已完成 / 已取消訂單
// - 以月份為單位查詢
// - 不使用即時監聽，避免歷史資料一直同步

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/features/admin/widgets/booking_order_card.dart';
import 'package:petnest_saas/features/admin/pages/admin_booking_detail_page.dart';

class AdminBookingHistoryPage extends StatefulWidget {
  const AdminBookingHistoryPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<AdminBookingHistoryPage> createState() =>
      _AdminBookingHistoryPageState();
}

class _AdminBookingHistoryPageState extends State<AdminBookingHistoryPage> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  final int _pageSize = 10;
  int _currentPage = 0;

  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';

  String _historyStatus = 'completed';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('歷史訂單查詢')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '選擇查詢月份',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month - 1,
                      );
                      _currentPage = 0;
                    });
                  },
                  icon: const Icon(Icons.chevron_left),
                ),

                Expanded(
                  child: Center(
                    child: Text(
                      _formatMonth(_selectedMonth),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),

                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month + 1,
                      );
                      _currentPage = 0;
                    });
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜尋訂單編號 / 顧客姓名 / 手機 / 寵物名 / 房號',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _keyword = value.trim().toLowerCase();
                _currentPage = 0;
              });
            },
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('已完成'),
                  selected: _historyStatus == 'completed',
                  onSelected: (_) {
                    setState(() {
                      _historyStatus = 'completed';
                      _currentPage = 0;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Text('已取消'),
                  selected: _historyStatus == 'cancelled',
                  onSelected: (_) {
                    setState(() {
                      _historyStatus = 'cancelled';
                      _currentPage = 0;
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('bookings')
                .where('shopId', isEqualTo: widget.shopId)
                .where('status', isEqualTo: _historyStatus)
                .where(
                  'startDate',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(
                    DateTime(_selectedMonth.year, _selectedMonth.month, 1),
                  ),
                )
                .where(
                  'startDate',
                  isLessThan: Timestamp.fromDate(
                    DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1),
                  ),
                )
                .get(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '查詢失敗：${snapshot.error}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final docs =
                  snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    final bookingId = doc.id.toLowerCase();

                    final customerName = (data['customerName'] ?? '')
                        .toString()
                        .toLowerCase();

                    final customerPhone = (data['customerPhone'] ?? '')
                        .toString()
                        .toLowerCase();

                    final roomName = (data['roomName'] ?? '')
                        .toString()
                        .toLowerCase();

                    final pets = (data['pets'] as List?) ?? [];

                    final petNames = pets
                        .map((e) {
                          if (e is Map<String, dynamic>) {
                            return (e['name'] ?? '').toString().toLowerCase();
                          }
                          return '';
                        })
                        .join(',');

                    if (_keyword.isEmpty) {
                      return true;
                    }

                    return bookingId.contains(_keyword) ||
                        customerName.contains(_keyword) ||
                        customerPhone.contains(_keyword) ||
                        roomName.contains(_keyword) ||
                        petNames.contains(_keyword);
                  }).toList()..sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;

                    final aDate = (aData['startDate'] as Timestamp).toDate();

                    final bDate = (bData['startDate'] as Timestamp).toDate();

                    return bDate.compareTo(aDate);
                  });

              final totalPages = (docs.length / _pageSize).ceil();

              if (_currentPage >= totalPages && totalPages > 0) {
                _currentPage = totalPages - 1;
              }

              final visibleDocs = docs
                  .skip(_currentPage * _pageSize)
                  .take(_pageSize)
                  .toList();

              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    '這個月份沒有已完成 / 已取消訂單',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  ...visibleDocs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    return BookingOrderCard(
                      bookingId: doc.id,
                      data: data,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AdminBookingDetailPage(bookingId: doc.id),
                          ),
                        );
                      },
                    );
                  }),

                  if (totalPages > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _currentPage <= 0
                                  ? null
                                  : () {
                                      setState(() {
                                        _currentPage--;
                                      });
                                    },
                              icon: const Icon(Icons.chevron_left),
                              label: const Text('上一頁'),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '${_currentPage + 1} / $totalPages',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _currentPage >= totalPages - 1
                                  ? null
                                  : () {
                                      setState(() {
                                        _currentPage++;
                                      });
                                    },
                              icon: const Icon(Icons.chevron_right),
                              label: const Text('下一頁'),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatMonth(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    return '$y-$m';
  }
}
