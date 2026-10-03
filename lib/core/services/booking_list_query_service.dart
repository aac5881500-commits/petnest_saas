// 檔案名稱：lib/core/services/booking_list_query_service.dart
// 功能說明：住宿／安親訂單 Firestore cursor 真分頁與低成本待處理數量。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/daily_care_date_helper.dart';
import 'package:petnest_saas/core/services/booking_search_fields.dart';
import 'package:petnest_saas/core/services/daycare_status_labels.dart';

class BookingListPageResult {
  const BookingListPageResult({
    required this.docs,
    required this.hasMore,
    this.cursor,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;
}

class BookingListCountResult {
  const BookingListCountResult({required this.counts, this.error});

  final Map<String, int> counts;
  final Object? error;
}

class BookingListQueryService {
  BookingListQueryService._();
  static final BookingListQueryService instance = BookingListQueryService._();

  static const int pageSize = 20;

  static const List<String> stayChipKeys = <String>[
    'active',
    'pending',
    'depositReview',
    'confirmed',
    'awaitingRoom',
    'checked_in',
    'todayCheckIn',
    'todayCheckOut',
    'futureCheckIn',
    'settled',
    'cancelled',
  ];

  static const List<String> daycareChipKeys = <String>[
    'active',
    'pending',
    'depositReview',
    'confirmed',
    'awaitingRoom',
    'checked_in',
    'todayDropOff',
    'todayPickUp',
    'futureCheckIn',
    'settled',
    'cancelled',
  ];

  /// 尚未結清、尚未取消的訂單。不含 completed／cancelled／no_show。
  static const List<String> activeStatuses = <String>[
    'pending',
    'pending_confirmation',
    'unpaid',
    'confirmed',
    'checked_in',
    'checked_out',
  ];

  static const List<String> _pendingStatuses = <String>[
    'pending',
    'pending_confirmation',
    'unpaid',
  ];

  static const List<String> _depositReviewStatuses = <String>[
    'pending',
    'pending_confirmation',
    'unpaid',
    'confirmed',
    'checked_in',
  ];

  /// 住宿今日／未來入住退房：排除 completed、cancelled、no_show。
  static const List<String> _stayOpenStatuses = <String>[
    'pending',
    'pending_confirmation',
    'unpaid',
    'confirmed',
    'checked_in',
  ];

  /// 安親今日送達／接回：可通過 !isHistory 的常見狀態（不含 completed／cancelled／no_show）。
  static const List<String> _daycareOpenStatuses = <String>[
    'pending',
    'pending_confirmation',
    'unpaid',
    'confirmed',
    'checked_in',
    'checked_out',
  ];

  CollectionReference<Map<String, dynamic>> get _bookings =>
      FirebaseFirestore.instance.collection('bookings');

  Query<Map<String, dynamic>> _base({
    required String shopId,
    required String kind,
  }) {
    Query<Map<String, dynamic>> query = _bookings.where(
      'shopId',
      isEqualTo: shopId,
    );
    if (kind == BookingKind.daycare) {
      query = query.where('bookingKind', isEqualTo: BookingKind.daycare);
    } else {
      query = query.where('bookingKind', isEqualTo: BookingKind.accommodation);
    }
    return query;
  }

  Future<BookingListPageResult> loadPage({
    required String shopId,
    required String kind,
    required String filter,
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor,
    String keyword = '',
  }) async {
    final String trimmed = keyword.trim();
    if (trimmed.isNotEmpty) {
      return _search(
        shopId: shopId,
        kind: kind,
        filter: filter,
        keyword: trimmed,
        cursor: cursor,
      );
    }
    Query<Map<String, dynamic>> query = _filterQuery(
      _base(shopId: shopId, kind: kind),
      kind: kind,
      filter: filter,
    );
    query = query.limit(pageSize);
    if (cursor != null) {
      query = query.startAfterDocument(cursor);
    }
    final QuerySnapshot<Map<String, dynamic>> snap = await query.get();
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = snap.docs
        .where((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          return _matchesKindAndFilter(doc.data(), kind, filter);
        })
        .toList();
    if (filter == 'active' && cursor == null && kind == BookingKind.daycare) {
      final QuerySnapshot<Map<String, dynamic>> awaiting =
          await _base(shopId: shopId, kind: kind)
              .where('status', isEqualTo: 'completed')
              .orderBy('createdAt', descending: true)
              .limit(pageSize)
              .get();
      final Set<String> seen = docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.id)
          .toSet();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in awaiting.docs) {
        if (!seen.add(doc.id)) {
          continue;
        }
        if (_matchesKindAndFilter(doc.data(), kind, filter)) {
          docs.add(doc);
        }
      }
    }
    return BookingListPageResult(
      docs: docs,
      cursor: snap.docs.isEmpty ? cursor : snap.docs.last,
      hasMore: snap.docs.length >= pageSize,
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>? liveFirstPage({
    required String shopId,
    required String kind,
    required String filter,
  }) {
    if (!_isLiveFilter(filter)) {
      return null;
    }
    return _filterQuery(
      _base(shopId: shopId, kind: kind),
      kind: kind,
      filter: filter,
    ).limit(pageSize).snapshots();
  }

  Future<BookingListCountResult> attentionCounts({
    required String shopId,
    required String kind,
  }) async {
    final List<String> keys = kind == BookingKind.daycare
        ? daycareChipKeys
        : stayChipKeys;
    final Query<Map<String, dynamic>> base = _base(shopId: shopId, kind: kind);
    final Map<String, int> counts = <String, int>{};
    Object? error;
    await Future.wait(
      keys.map((String key) async {
        try {
          counts[key] = await _count(
            _filterQuery(base, kind: kind, filter: key),
          );
        } catch (e) {
          error = e;
        }
      }),
    );
    return BookingListCountResult(counts: counts, error: error);
  }

  bool matchesListFilter(
    Map<String, dynamic> data,
    String kind,
    String filter,
  ) {
    return _matchesKindAndFilter(data, kind, filter);
  }

  Future<int> _count(Query<Map<String, dynamic>> query) async {
    final AggregateQuerySnapshot snap = await query.count().get();
    return snap.count ?? 0;
  }

  Query<Map<String, dynamic>> _searchScope(
    Query<Map<String, dynamic>> base, {
    required String kind,
    required String filter,
  }) {
    final List<String> statuses = searchStatusesFor(kind: kind, filter: filter);
    if (statuses.length == 1) {
      return base.where('status', isEqualTo: statuses.single);
    }
    return base.where('status', whereIn: statuses);
  }

  static List<String> searchStatusesFor({
    required String kind,
    required String filter,
  }) {
    switch (filter) {
      case 'settled':
        return const <String>['completed'];
      case 'cancelled':
        return const <String>['cancelled', 'no_show'];
      case 'pending':
        return _pendingStatuses;
      case 'depositReview':
        return _depositReviewStatuses;
      case 'confirmed':
        return const <String>['confirmed'];
      case 'awaitingRoom':
        return kind == BookingKind.daycare
            ? const <String>['confirmed', 'checked_in']
            : const <String>['confirmed'];
      case 'checked_in':
        return const <String>['checked_in'];
      case 'todayDropOff':
      case 'todayPickUp':
        return _daycareOpenStatuses;
      case 'todayCheckIn':
      case 'todayCheckOut':
        return _stayOpenStatuses;
      case 'futureCheckIn':
        return kind == BookingKind.daycare
            ? _daycareOpenStatuses
            : _stayOpenStatuses;
      case 'history':
        return const <String>['completed', 'cancelled', 'no_show'];
      case 'active':
      default:
        return activeStatuses;
    }
  }

  bool _isLiveFilter(String filter) {
    return filter == 'active' ||
        filter == 'pending' ||
        filter == 'depositReview' ||
        filter == 'confirmed' ||
        filter == 'awaitingRoom' ||
        filter == 'checked_in' ||
        filter == 'todayDropOff' ||
        filter == 'todayPickUp' ||
        filter == 'todayCheckIn' ||
        filter == 'todayCheckOut' ||
        filter == 'futureCheckIn';
  }

  Query<Map<String, dynamic>> _filterQuery(
    Query<Map<String, dynamic>> base, {
    required String kind,
    required String filter,
  }) {
    final ({DateTime startUtc, DateTime endUtc}) taipei =
        DailyCareDateHelper.taipeiTodayUtcRange();
    final Timestamp todayStart = Timestamp.fromDate(taipei.startUtc);
    final Timestamp todayEnd = Timestamp.fromDate(taipei.endUtc);
    switch (filter) {
      case 'active':
        return base
            .where('status', whereIn: activeStatuses)
            .orderBy('createdAt', descending: true);
      case 'settled':
        return base
            .where('status', isEqualTo: 'completed')
            .orderBy('createdAt', descending: true);
      case 'cancelled':
        return base
            .where('status', whereIn: const <String>['cancelled', 'no_show'])
            .orderBy('createdAt', descending: true);
      case 'pending':
        return base
            .where('status', whereIn: _pendingStatuses)
            .orderBy('createdAt', descending: true);
      case 'depositReview':
        return base
            .where('depositStatus', isEqualTo: 'pending_review')
            .where('status', whereIn: _depositReviewStatuses)
            .orderBy('createdAt', descending: true);
      case 'confirmed':
        return base
            .where('status', isEqualTo: 'confirmed')
            .orderBy('createdAt', descending: true);
      case 'awaitingRoom':
        if (kind == BookingKind.daycare) {
          return base
              .where('status', whereIn: <String>['confirmed', 'checked_in'])
              .where('assignStatus', isEqualTo: 'unassigned')
              .orderBy('createdAt', descending: true);
        }
        return base
            .where('status', isEqualTo: 'confirmed')
            .where('assignStatus', isEqualTo: 'unassigned')
            .orderBy('createdAt', descending: true);
      case 'checked_in':
        return base
            .where('status', isEqualTo: 'checked_in')
            .orderBy('createdAt', descending: true);
      case 'todayDropOff':
        return base
            .where('status', whereIn: _daycareOpenStatuses)
            .where('scheduledStartAt', isGreaterThanOrEqualTo: todayStart)
            .where('scheduledStartAt', isLessThan: todayEnd)
            .orderBy('scheduledStartAt', descending: true);
      case 'todayPickUp':
        return base
            .where('status', whereIn: _daycareOpenStatuses)
            .where('scheduledEndAt', isGreaterThanOrEqualTo: todayStart)
            .where('scheduledEndAt', isLessThan: todayEnd)
            .orderBy('scheduledEndAt', descending: true);
      case 'todayCheckIn':
        return base
            .where('status', whereIn: _stayOpenStatuses)
            .where('startDate', isGreaterThanOrEqualTo: todayStart)
            .where('startDate', isLessThan: todayEnd)
            .orderBy('startDate', descending: true);
      case 'todayCheckOut':
        return base
            .where('status', whereIn: _stayOpenStatuses)
            .where('endDate', isGreaterThanOrEqualTo: todayStart)
            .where('endDate', isLessThan: todayEnd)
            .orderBy('endDate', descending: true);
      case 'futureCheckIn':
        if (kind == BookingKind.daycare) {
          return base
              .where('status', whereIn: _daycareOpenStatuses)
              .where('scheduledStartAt', isGreaterThanOrEqualTo: todayEnd)
              .orderBy('scheduledStartAt', descending: true);
        }
        return base
            .where('status', whereIn: _stayOpenStatuses)
            .where('startDate', isGreaterThanOrEqualTo: todayEnd)
            .orderBy('startDate');
      case 'history':
        return base
            .where(
              'status',
              whereIn: <String>['completed', 'cancelled', 'no_show'],
            )
            .orderBy('createdAt', descending: true);
      default:
        return base.orderBy('createdAt', descending: true);
    }
  }

  bool _matchesKindAndFilter(
    Map<String, dynamic> data,
    String kind,
    String filter,
  ) {
    if (kind == BookingKind.daycare) {
      if (!BookingKind.isDaycare(data)) {
        return false;
      }
      return DaycareStatusLabels.matchesFilter(data, filter);
    }
    if (!BookingKind.isAccommodation(data)) {
      return false;
    }
    if (filter == 'awaitingRoom') {
      return (data['status'] ?? '').toString() == 'confirmed' &&
          (data['assignStatus'] ?? '').toString() == 'unassigned' &&
          !DaycareStatusLabels.isHistory(data);
    }
    if (filter == 'checked_in') {
      return !DaycareStatusLabels.isHistory(data) &&
          (data['status'] ?? '').toString() == 'checked_in';
    }
    return DaycareStatusLabels.matchesFilter(data, filter);
  }

  Future<BookingListPageResult> _search({
    required String shopId,
    required String kind,
    required String filter,
    required String keyword,
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor,
  }) async {
    final String digits = BookingSearchFields.digitsOnly(keyword);
    Query<Map<String, dynamic>> query = _searchScope(
      _base(shopId: shopId, kind: kind),
      kind: kind,
      filter: filter,
    );
    if (RegExp(r'^[a-zA-Z0-9\-]{4,}$').hasMatch(keyword) &&
        digits.length != keyword.replaceAll(RegExp(r'[\s-]'), '').length) {
      query = query.where(
        'bookingCodeNormalized',
        isEqualTo: BookingSearchFields.normalizeCode(keyword),
      );
    } else if (digits.length == 4 || digits.length == 5) {
      query = query.where(
        digits.length == 4 ? 'customerPhoneLast4' : 'customerPhoneLast5',
        isEqualTo: digits,
      );
    } else if (digits.length >= 6) {
      query = query.where(
        'bookingCodeNormalized',
        isEqualTo: BookingSearchFields.normalizeCode(keyword),
      );
    } else {
      final String name = BookingSearchFields.normalizeName(keyword);
      query = query
          .where('petNamesNormalized', arrayContains: name)
          .orderBy('createdAt', descending: true);
      Query<Map<String, dynamic>> nameQuery =
          _searchScope(
                _base(shopId: shopId, kind: kind),
                kind: kind,
                filter: filter,
              )
              .where('customerNameNormalized', isGreaterThanOrEqualTo: name)
              .where('customerNameNormalized', isLessThan: '$name\uf8ff')
              .orderBy('customerNameNormalized')
              .limit(pageSize);
      if (cursor != null) {
        nameQuery = nameQuery.startAfterDocument(cursor);
      }
      final QuerySnapshot<Map<String, dynamic>> nameSnap = await nameQuery
          .get();
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = nameSnap
          .docs
          .where(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                _matchesKindAndFilter(doc.data(), kind, filter),
          )
          .toList();
      if (docs.isNotEmpty || nameSnap.docs.isNotEmpty) {
        return BookingListPageResult(
          docs: docs,
          cursor: nameSnap.docs.isEmpty ? cursor : nameSnap.docs.last,
          hasMore: nameSnap.docs.length >= pageSize,
        );
      }
    }
    query = query.orderBy('createdAt', descending: true).limit(pageSize);
    if (cursor != null) {
      query = query.startAfterDocument(cursor);
    }
    final QuerySnapshot<Map<String, dynamic>> snap = await query.get();
    if (snap.docs.isEmpty &&
        BookingSearchFields.normalizeCode(keyword).isNotEmpty) {
      Query<Map<String, dynamic>> legacy = _searchScope(
        _base(shopId: shopId, kind: kind),
        kind: kind,
        filter: filter,
      ).where('bookingCode', isEqualTo: keyword.trim()).limit(pageSize);
      final QuerySnapshot<Map<String, dynamic>> legacySnap = await legacy.get();
      return BookingListPageResult(
        docs: legacySnap.docs
            .where(
              (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                  _matchesKindAndFilter(doc.data(), kind, filter),
            )
            .toList(),
        cursor: legacySnap.docs.isEmpty ? null : legacySnap.docs.last,
        hasMore: false,
      );
    }
    return BookingListPageResult(
      docs: snap.docs
          .where(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                _matchesKindAndFilter(doc.data(), kind, filter),
          )
          .toList(),
      cursor: snap.docs.isEmpty ? cursor : snap.docs.last,
      hasMore: snap.docs.length >= pageSize,
    );
  }
}
