// 檔案名稱：lib/features/admin/widgets/admin_paged_booking_list.dart
// 功能說明：住宿／安親訂單共用 Firestore cursor 真分頁列表。

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/navigation/admin_booking_route.dart';
import 'package:petnest_saas/core/services/booking_list_query_service.dart';
import 'package:petnest_saas/features/admin/pages/admin_create_daycare_booking_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_daycare_detail_page.dart';
import 'package:petnest_saas/features/admin/widgets/booking_advanced_filter_button.dart';
import 'package:petnest_saas/features/admin/widgets/booking_order_card.dart';
import 'package:petnest_saas/features/admin/widgets/booking_search_bar.dart';
import 'package:petnest_saas/features/admin/widgets/booking_sort_bar.dart';
import 'package:petnest_saas/features/admin/widgets/booking_status_filter.dart';

class AdminPagedBookingList extends StatefulWidget {
  const AdminPagedBookingList({
    super.key,
    required this.shopId,
    required this.kind,
    this.initialFilter = 'pending',
    this.showCreateButton = false,
  });

  final String shopId;
  final String kind;
  final String initialFilter;
  final bool showCreateButton;

  @override
  State<AdminPagedBookingList> createState() => _AdminPagedBookingListState();
}

class _AdminPagedBookingListState extends State<AdminPagedBookingList>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  late String _filter;
  String _keyword = '';
  String _sortType = 'createdDesc';
  Timer? _searchDebounce;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _live;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  QueryDocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  Map<String, int> _counts = const <String, int>{};

  bool get _isDaycare => widget.kind == BookingKind.daycare;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter == 'all' || widget.initialFilter.isEmpty
        ? 'pending'
        : widget.initialFilter;
    _reload();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _live?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _live?.cancel();
    setState(() {
      _loading = true;
      _error = null;
      _docs.clear();
      _cursor = null;
      _hasMore = false;
    });
    try {
      final BookingListPageResult page = await BookingListQueryService.instance
          .loadPage(
            shopId: widget.shopId,
            kind: widget.kind,
            filter: _filter,
            keyword: _keyword,
          );
      final Map<String, int> counts = await BookingListQueryService.instance
          .attentionCounts(shopId: widget.shopId, kind: widget.kind);
      if (!mounted) {
        return;
      }
      setState(() {
        _docs
          ..clear()
          ..addAll(page.docs);
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _counts = counts;
        _loading = false;
      });
      _attachLive();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _attachLive() {
    _live?.cancel();
    if (_keyword.isNotEmpty) {
      return;
    }
    final Stream<QuerySnapshot<Map<String, dynamic>>>? stream =
        BookingListQueryService.instance.liveFirstPage(
          shopId: widget.shopId,
          kind: widget.kind,
          filter: _filter,
        );
    if (stream == null) {
      return;
    }
    _live = stream.listen((QuerySnapshot<Map<String, dynamic>> snap) {
      if (!mounted || _docs.length > BookingListQueryService.pageSize) {
        return;
      }
      final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> byId =
          <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
            for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                in _docs)
              doc.id: doc,
          };
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
        byId[doc.id] = doc;
      }
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> next = byId.values
          .toList();
      setState(() {
        _docs
          ..clear()
          ..addAll(next.take(BookingListQueryService.pageSize));
      });
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _cursor == null) {
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final BookingListPageResult page = await BookingListQueryService.instance
          .loadPage(
            shopId: widget.shopId,
            kind: widget.kind,
            filter: _filter,
            keyword: _keyword,
            cursor: _cursor,
          );
      if (!mounted) {
        return;
      }
      final Set<String> seen = _docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.id)
          .toSet();
      setState(() {
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in page.docs) {
          if (seen.add(doc.id)) {
            _docs.add(doc);
          }
        }
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingMore = false;
        _error = error.toString();
      });
    }
  }

  void _onSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _keyword = value.trim();
      _reload();
    });
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
        BookingSearchBar(controller: _searchController, onChanged: _onSearch),
        if (!_isDaycare)
          BookingAdvancedFilterButton(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('此功能將於後續版本提供')),
              );
            },
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: _buildBody(),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          _filterBar(),
          const SizedBox(height: 80),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          _filterBar(),
          const SizedBox(height: 80),
          Center(child: Text('載入失敗：$_error')),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        _filterBar(),
        BookingSortBar(
          totalCount: _docs.length,
          sortType: _sortType,
          isGridMode: false,
          daycareLabels: _isDaycare,
          onSortChanged: (String value) {
            setState(() => _sortType = value);
          },
          onToggleViewMode: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('格子檢視之後再開放')));
          },
        ),
        if (_docs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 80),
            child: Center(
              child: Text(
                _isDaycare
                    ? '沒有符合的安親訂單'
                    : (_filter == 'history' ? '尚無歷史訂單' : '尚無符合條件的訂單'),
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        else
          ..._docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
            final Map<String, dynamic> data = doc.data();
            return BookingOrderCard(
              bookingId: doc.id,
              data: data,
              onTap: () {
                if (_isDaycare) {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AdminDaycareDetailPage(
                        shopId: widget.shopId,
                        bookingId: doc.id,
                      ),
                    ),
                  );
                  return;
                }
                AdminBookingRoute.open(
                  context,
                  bookingId: doc.id,
                  data: data,
                  canEdit: true,
                );
              },
            );
          }),
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: OutlinedButton(
              onPressed: _loadingMore ? null : _loadMore,
              child: Text(_loadingMore ? '載入中…' : '載入更多'),
            ),
          ),
      ],
    );
  }

  Widget _filterBar() {
    return BookingStatusFilter(
      selectedType: _filter,
      counts: _counts,
      items: _isDaycare
          ? BookingStatusFilter.daycareItems
          : BookingStatusFilter.stayItems,
      onChanged: (String type) {
        _filter = type;
        _reload();
      },
    );
  }
}
