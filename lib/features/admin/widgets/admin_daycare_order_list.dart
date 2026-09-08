// 檔案名稱：lib/features/admin/widgets/admin_daycare_order_list.dart
// 功能說明：安親訂單列表：搜尋、狀態、排序、即時更新；訂單管理分頁與舊 route 共用

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/services/daycare_status_labels.dart';
import 'package:petnest_saas/features/admin/pages/admin_create_daycare_booking_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_daycare_detail_page.dart';
import 'package:petnest_saas/features/admin/widgets/booking_order_card.dart';
import 'package:petnest_saas/features/admin/widgets/booking_search_bar.dart';
import 'package:petnest_saas/features/admin/widgets/booking_sort_bar.dart';

class AdminDaycareOrderList extends StatefulWidget {
  const AdminDaycareOrderList({
    super.key,
    required this.shopId,
    this.showCreateButton = false,
  });

  final String shopId;
  final bool showCreateButton;

  @override
  State<AdminDaycareOrderList> createState() => _AdminDaycareOrderListState();
}

class _AdminDaycareOrderListState extends State<AdminDaycareOrderList>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;
  String _status = 'all';
  String _keyword = '';
  String _sortType = 'createdDesc';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('bookings')
        .where('shopId', isEqualTo: widget.shopId)
        .where('bookingKind', isEqualTo: BookingKind.daycare)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: <Widget>[
        if (widget.showCreateButton)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        AdminCreateDaycareBookingPage(shopId: widget.shopId),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('新增安親訂單'),
            ),
          ),
        BookingSearchBar(
          controller: _searchController,
          onChanged: (String value) {
            setState(() => _keyword = value.trim());
          },
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: <Widget>[
              for (final Map<String, String> item
                  in DaycareStatusLabels.listFilters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(item['label']!),
                    selected: _status == item['id'],
                    onSelected: (_) {
                      setState(() => _status = item['id']!);
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream,
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
                      snapshot.data!.docs.where((
                        QueryDocumentSnapshot<Map<String, dynamic>> doc,
                      ) {
                        final Map<String, dynamic> data = doc.data();
                        if (!DaycareStatusLabels.matchesFilter(data, _status)) {
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
                          doc.id,
                          (data['roomName'] ?? '').toString(),
                          ((data['pets'] as List?) ?? const <dynamic>[])
                              .map(
                                (dynamic e) => e is Map ? '${e['name']}' : '',
                              )
                              .join(),
                        ].join(' ').toLowerCase();
                        return haystack.contains(_keyword.toLowerCase());
                      }).toList()..sort(_sortDocs);

                  return ListView(
                    children: <Widget>[
                      BookingSortBar(
                        totalCount: docs.length,
                        sortType: _sortType,
                        isGridMode: false,
                        daycareLabels: true,
                        onSortChanged: (String value) {
                          setState(() => _sortType = value);
                        },
                        onToggleViewMode: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('格子檢視之後再開放')),
                          );
                        },
                      ),
                      if (docs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: Center(child: Text('沒有符合的安親訂單')),
                        )
                      else
                        ...docs.map((
                          QueryDocumentSnapshot<Map<String, dynamic>> doc,
                        ) {
                          final Map<String, dynamic> data = doc.data();
                          return BookingOrderCard(
                            bookingId: doc.id,
                            data: data,
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
                          );
                        }),
                    ],
                  );
                },
          ),
        ),
      ],
    );
  }

  int _sortDocs(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    DateTime getDate(Map<String, dynamic> data, String key) {
      final dynamic value = data[key];
      if (value is Timestamp) {
        return value.toDate();
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    final Map<String, dynamic> aData = a.data();
    final Map<String, dynamic> bData = b.data();
    switch (_sortType) {
      case 'startAsc':
        return getDate(
          aData,
          'scheduledStartAt',
        ).compareTo(getDate(bData, 'scheduledStartAt'));
      case 'createdAsc':
        return getDate(
          aData,
          'createdAt',
        ).compareTo(getDate(bData, 'createdAt'));
      case 'startDesc':
        return getDate(
          bData,
          'scheduledStartAt',
        ).compareTo(getDate(aData, 'scheduledStartAt'));
      case 'createdDesc':
      default:
        return getDate(
          bData,
          'createdAt',
        ).compareTo(getDate(aData, 'createdAt'));
    }
  }
}
