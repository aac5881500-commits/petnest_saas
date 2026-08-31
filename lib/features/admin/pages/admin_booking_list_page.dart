// lib/features/admin/pages/admin_booking_list_page.dart
// 📦 店家訂單列表頁（完整版🔥 + 已修正取消訂單）

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/features/admin/pages/admin_booking_detail_page.dart';
import 'package:petnest_saas/features/admin/widgets/booking_search_bar.dart';
import 'package:petnest_saas/features/admin/widgets/booking_status_filter.dart';
import 'package:petnest_saas/features/admin/widgets/booking_sort_bar.dart';
import 'package:petnest_saas/features/admin/widgets/booking_order_card.dart';
import 'package:petnest_saas/features/admin/widgets/booking_advanced_filter_button.dart';
import 'package:petnest_saas/features/admin/pages/admin_booking_history_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_create_booking_page.dart';
import 'package:petnest_saas/core/services/shop_permission_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';

class AdminBookingListPage extends StatefulWidget {
  const AdminBookingListPage({
    super.key,
    required this.shopId,
    this.filterType,
  });

  final String shopId;
  final String? filterType;

  @override
  State<AdminBookingListPage> createState() => _AdminBookingListPageState();
}

class _AdminBookingListPageState extends State<AdminBookingListPage> {
  late String _filterType;

  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';
  String _sortType = 'startDesc';
  final int _pageSize = 5;
  int _currentPage = 0;
  @override
  void initState() {
    super.initState();

    _filterType = widget.filterType ?? 'pending';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('訂單管理'),
        actions: [
          ShopTaskCenterButton(shopId: widget.shopId),
          StreamBuilder<Map<String, dynamic>?>(
            stream: ShopService.instance.streamShop(widget.shopId),
            builder: (context, shopSnapshot) {
              final shop = shopSnapshot.data ?? {};
              final canCreateOrder = ShopPermissionService.canCreateOrder(shop);

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  onPressed: canCreateOrder
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AdminCreateBookingPage(shopId: widget.shopId),
                            ),
                          );
                        }
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ShopPermissionService.restrictedMessage(),
                              ),
                            ),
                          );
                        },
                  icon: Icon(canCreateOrder ? Icons.add : Icons.lock_outline),
                  label: Text(canCreateOrder ? '手動新增訂單' : '手動新增訂單'),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          BookingSearchBar(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _keyword = value.trim();
                _currentPage = 0;
              });
            },
          ),

          BookingAdvancedFilterButton(
            onTap: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('此功能將於後續版本提供')));
            },
          ),

          /// 🔥 列表
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('shopId', isEqualTo: widget.shopId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                final statusCounts = _buildStatusCounts(docs);

                final now = DateTime.now();
                final todayStart = DateTime(now.year, now.month, now.day);
                final todayEnd = todayStart.add(const Duration(days: 1));

                final filteredDocs =
                    docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      final start = (data['startDate'] as Timestamp).toDate();
                      final end = (data['endDate'] as Timestamp).toDate();
                      final status = data['status'] ?? '';

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

                      final keyword = _keyword.toLowerCase();

                      final matchKeyword =
                          keyword.isEmpty ||
                          bookingId.contains(keyword) ||
                          customerName.contains(keyword) ||
                          customerPhone.contains(keyword) ||
                          roomName.contains(keyword) ||
                          petNames.contains(keyword);

                      if (!matchKeyword) {
                        return false;
                      }

                      final shopUnreadMessageCount =
                          (data['shopUnreadMessageCount'] ?? 0) as int;

                      switch (_filterType) {
                        case 'pending':
                          return status == 'pending' || status == 'unpaid';

                        case 'depositReview':
                          final depositStatus = (data['depositStatus'] ?? '')
                              .toString();

                          return depositStatus == 'pending_review' &&
                              status != 'completed' &&
                              status != 'cancelled';

                        case 'messageUnread':
                          return shopUnreadMessageCount > 0;

                        case 'confirmed':
                          return status == 'confirmed';

                        case 'checked_in':
                          return status == 'checked_in';

                        case 'todayCheckIn':
                          return status != 'cancelled' &&
                              start.isAfter(todayStart) &&
                              start.isBefore(todayEnd);

                        case 'todayCheckOut':
                          return status != 'cancelled' &&
                              end.isAfter(todayStart) &&
                              end.isBefore(todayEnd);

                        case 'futureCheckIn':
                          return status != 'cancelled' &&
                              status != 'completed' &&
                              start.isAfter(todayEnd);

                        case 'history':
                          return false;

                        case 'active':
                        default:
                          return status == 'pending' ||
                              status == 'unpaid' ||
                              status == 'confirmed' ||
                              status == 'checked_in';
                      }
                    }).toList()..sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;

                      DateTime getDate(Map<String, dynamic> data, String key) {
                        final value = data[key];
                        if (value is Timestamp) return value.toDate();
                        return DateTime.fromMillisecondsSinceEpoch(0);
                      }

                      switch (_sortType) {
                        case 'startAsc':
                          return getDate(
                            aData,
                            'startDate',
                          ).compareTo(getDate(bData, 'startDate'));

                        case 'createdDesc':
                          return getDate(
                            bData,
                            'createdAt',
                          ).compareTo(getDate(aData, 'createdAt'));

                        case 'createdAsc':
                          return getDate(
                            aData,
                            'createdAt',
                          ).compareTo(getDate(bData, 'createdAt'));

                        case 'startDesc':
                        default:
                          return getDate(
                            bData,
                            'startDate',
                          ).compareTo(getDate(aData, 'startDate'));
                      }
                    });

                final totalPages = (filteredDocs.length / _pageSize).ceil();

                if (_currentPage >= totalPages && totalPages > 0) {
                  _currentPage = totalPages - 1;
                }

                final visibleDocs = filteredDocs
                    .skip(_currentPage * _pageSize)
                    .take(_pageSize)
                    .toList();

                if (filteredDocs.isEmpty) {
                  return ListView(
                    children: [
                      BookingStatusFilter(
                        selectedType: _filterType,
                        counts: statusCounts,
                        onChanged: (type) {
                          if (type == 'history') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminBookingHistoryPage(
                                  shopId: widget.shopId,
                                ),
                              ),
                            );
                            return;
                          }

                          setState(() {
                            _filterType = type;
                            _currentPage = 0;
                          });
                        },
                      ),

                      BookingSortBar(
                        totalCount: filteredDocs.length,
                        sortType: _sortType,
                        isGridMode: false,
                        onSortChanged: (value) {
                          setState(() {
                            _sortType = value;
                          });
                        },
                        onToggleViewMode: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('格子檢視之後再開放')),
                          );
                        },
                      ),

                      const SizedBox(height: 80),

                      Center(
                        child: Text(
                          _filterType == 'history'
                              ? '歷史查詢之後會改成用月份搜尋'
                              : '尚無符合條件的訂單',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return ListView(
                  children: [
                    BookingStatusFilter(
                      selectedType: _filterType,
                      counts: statusCounts,
                      onChanged: (type) {
                        if (type == 'history') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminBookingHistoryPage(
                                shopId: widget.shopId,
                              ),
                            ),
                          );
                          return;
                        }

                        setState(() {
                          _filterType = type;
                          _currentPage = 0;
                        });
                      },
                    ),

                    BookingSortBar(
                      totalCount: filteredDocs.length,
                      sortType: _sortType,
                      isGridMode: false,
                      onSortChanged: (value) {
                        setState(() {
                          _sortType = value;
                        });
                      },
                      onToggleViewMode: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('格子檢視之後再開放')),
                        );
                      },
                    ),

                    ...visibleDocs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return BookingOrderCard(
                        bookingId: doc.id,
                        data: data,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminBookingDetailPage(
                                bookingId: doc.id,
                                canEdit: true,
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),

                    const SizedBox(height: 8),

                    if (totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
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
          ),
        ],
      ),
    );
  }

  Map<String, int> _buildStatusCounts(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final counts = <String, int>{
      'active': 0,
      'pending': 0,
      'depositReview': 0,
      'messageUnread': 0,
      'confirmed': 0,
      'checked_in': 0,
      'todayCheckIn': 0,
      'todayCheckOut': 0,
      'futureCheckIn': 0,
      'history': 0,
    };

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? 'pending').toString();

      final depositStatus = (data['depositStatus'] ?? '').toString();

      final shopUnreadMessageCount =
          (data['shopUnreadMessageCount'] ?? 0) as int;

      if (shopUnreadMessageCount > 0) {
        counts['messageUnread'] = (counts['messageUnread'] ?? 0) + 1;
      }

      if (status == 'pending' || status == 'unpaid') {
        counts['pending'] = (counts['pending'] ?? 0) + 1;
        counts['active'] = (counts['active'] ?? 0) + 1;
      }

      if (depositStatus == 'pending_review' &&
          status != 'completed' &&
          status != 'cancelled') {
        counts['depositReview'] = (counts['depositReview'] ?? 0) + 1;
      }

      if (status == 'confirmed') {
        counts['confirmed'] = (counts['confirmed'] ?? 0) + 1;
        counts['active'] = (counts['active'] ?? 0) + 1;
      }

      if (status == 'checked_in') {
        counts['checked_in'] = (counts['checked_in'] ?? 0) + 1;
        counts['active'] = (counts['active'] ?? 0) + 1;
      }

      if (status == 'completed' || status == 'cancelled') {
        counts['history'] = (counts['history'] ?? 0) + 1;
      }

      final startRaw = data['startDate'];
      final endRaw = data['endDate'];

      if (startRaw is Timestamp) {
        final start = startRaw.toDate();

        if (start.isAfter(todayStart) && start.isBefore(todayEnd)) {
          counts['todayCheckIn'] = (counts['todayCheckIn'] ?? 0) + 1;
        }

        if (status != 'completed' &&
            status != 'cancelled' &&
            start.isAfter(todayEnd)) {
          counts['futureCheckIn'] = (counts['futureCheckIn'] ?? 0) + 1;
        }
      }

      if (endRaw is Timestamp) {
        final end = endRaw.toDate();
        if (end.isAfter(todayStart) && end.isBefore(todayEnd)) {
          counts['todayCheckOut'] = (counts['todayCheckOut'] ?? 0) + 1;
        }
      }
    }

    return counts;
  }
}
