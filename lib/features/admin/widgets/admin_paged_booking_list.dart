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
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  late String _filter;
  String _keyword = '';
  String _sortType = 'createdDesc';
  Timer? _searchDebounce;
  Timer? _countsDebounce;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _live;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  QueryDocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  Object? _countError;
  Map<String, int> _counts = const <String, int>{};

  bool get _isDaycare => widget.kind == BookingKind.daycare;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _filter = widget.initialFilter == 'all' || widget.initialFilter.isEmpty
        ? 'pending'
        : widget.initialFilter;
    _reload();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_reload());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _countsDebounce?.cancel();
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
    BookingListPageResult page;
    try {
      page = await BookingListQueryService.instance.loadPage(
        shopId: widget.shopId,
        kind: widget.kind,
        filter: _filter,
        keyword: _keyword,
      );
    } catch (error, stackTrace) {
      debugPrint('訂單列表載入失敗：$error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
      return;
    }
    BookingListCountResult countResult;
    try {
      countResult = await BookingListQueryService.instance.attentionCounts(
        shopId: widget.shopId,
        kind: widget.kind,
      );
    } catch (error, stackTrace) {
      debugPrint('訂單篩選計數失敗：$error');
      debugPrintStack(stackTrace: stackTrace);
      countResult = BookingListCountResult(counts: _counts, error: error);
    }
    if (!mounted) {
      return;
    }
    if (countResult.error != null) {
      debugPrint('訂單篩選計數失敗：${countResult.error}');
    }
    setState(() {
      _docs
        ..clear()
        ..addAll(page.docs);
      _cursor = page.cursor;
      _hasMore = page.hasMore;
      _counts = countResult.counts;
      _countError = countResult.error;
      _loading = false;
    });
    _attachLive();
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
    _live = stream.listen(
      (QuerySnapshot<Map<String, dynamic>> snap) {
        if (!mounted) {
          return;
        }
        _scheduleCountsRefresh();
        if (_docs.length > BookingListQueryService.pageSize) {
          return;
        }
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> next = snap.docs
            .where((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
              return BookingListQueryService.instance.matchesListFilter(
                doc.data(),
                widget.kind,
                _filter,
              );
            })
            .toList();
        setState(() {
          _docs
            ..clear()
            ..addAll(next.take(BookingListQueryService.pageSize));
          _cursor = snap.docs.isEmpty ? null : snap.docs.last;
          _hasMore = snap.docs.length >= BookingListQueryService.pageSize;
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('訂單列表即時更新失敗：$error');
        debugPrintStack(stackTrace: stackTrace);
        if (!mounted) {
          return;
        }
        setState(() => _countError = error);
      },
    );
  }

  void _scheduleCountsRefresh() {
    _countsDebounce?.cancel();
    _countsDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_refreshCounts());
    });
  }

  Future<void> _refreshCounts() async {
    try {
      final BookingListCountResult countResult = await BookingListQueryService
          .instance
          .attentionCounts(shopId: widget.shopId, kind: widget.kind);
      if (!mounted) {
        return;
      }
      if (countResult.error != null) {
        debugPrint('訂單篩選計數失敗：${countResult.error}');
      }
      setState(() {
        _counts = countResult.counts;
        _countError = countResult.error;
      });
    } catch (error, stackTrace) {
      debugPrint('訂單篩選計數失敗：$error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      setState(() => _countError = error);
    }
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
    } catch (error, stackTrace) {
      debugPrint('訂單列表載入更多失敗：$error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingMore = false;
        _error = error;
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
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('此功能將於後續版本提供')));
            },
          ),
        Expanded(
          child: RefreshIndicator(onRefresh: _reload, child: _buildBody()),
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
          _countErrorBanner(),
          const SizedBox(height: 80),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[_filterBar(), _countErrorBanner(), _listErrorCard()],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        _filterBar(),
        _countErrorBanner(),
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
              onTap: () async {
                if (_isDaycare) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AdminDaycareDetailPage(
                        shopId: widget.shopId,
                        bookingId: doc.id,
                      ),
                    ),
                  );
                } else {
                  await AdminBookingRoute.open(
                    context,
                    bookingId: doc.id,
                    data: data,
                    canEdit: true,
                  );
                }
                if (mounted) {
                  await _reload();
                }
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

  bool _isMissingIndexError(Object error) {
    String code = '';
    String message = '';
    if (error is FirebaseException) {
      code = error.code.toLowerCase();
      message = (error.message ?? '').toLowerCase();
    }
    final String text = error.toString().toLowerCase();
    final String haystack = '$code $message $text';
    return haystack.contains('requires an index') ||
        haystack.contains('index is currently building') ||
        haystack.contains('indexes are currently building') ||
        ((haystack.contains('failed-precondition') ||
                haystack.contains('failed_precondition')) &&
            haystack.contains('index'));
  }

  Widget _listErrorCard() {
    final Object error = _error!;
    final bool indexError = _isMissingIndexError(error);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Material(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                indexError ? '篩選索引建立中' : '載入失敗',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                indexError ? '此篩選資料正在準備中，完成後會自動可用。請稍後重新整理。' : '載入失敗，請稍後再試。',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => unawaited(_reload()),
                  child: const Text('重新整理'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _countErrorBanner() {
    if (_countError == null) {
      return const SizedBox.shrink();
    }
    final bool indexError = _isMissingIndexError(_countError!);
    final String message = indexError
        ? '部分篩選資料正在建立索引，完成後會自動恢復。請稍後重新整理。'
        : '部分篩選資料暫時無法載入，請重新整理後再試。';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: <Widget>[
              Icon(Icons.info_outline, color: Colors.orange.shade800, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => unawaited(_reload()),
                child: const Text('重新整理'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterBar() {
    return BookingStatusFilter(
      selectedType: _filter,
      counts: _counts,
      countsIncomplete: _countError != null,
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
