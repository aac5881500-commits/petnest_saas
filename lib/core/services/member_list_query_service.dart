// 檔案名稱：lib/core/services/member_list_query_service.dart
// 功能說明：會員 Firestore cursor 真分頁與 count aggregation 統計。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/services/member_search_fields.dart';

class MemberListPageResult {
  const MemberListPageResult({
    required this.docs,
    required this.hasMore,
    this.cursor,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;
}

class MemberListStats {
  const MemberListStats({
    required this.total,
    required this.blacklisted,
    required this.vip,
    required this.newThisMonth,
  });

  final int total;
  final int blacklisted;
  final int vip;
  final int newThisMonth;
}

class MemberListQueryService {
  MemberListQueryService._();
  static final MemberListQueryService instance = MemberListQueryService._();

  static const int pageSize = 24;

  CollectionReference<Map<String, dynamic>> _col(String shopId) {
    return FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('members');
  }

  Future<MemberListStats> loadStats(String shopId) async {
    final CollectionReference<Map<String, dynamic>> col = _col(shopId);
    final DateTime now = DateTime.now();
    final DateTime monthStart = DateTime(now.year, now.month, 1);
    final List<AggregateQuerySnapshot> snaps =
        await Future.wait(<Future<AggregateQuerySnapshot>>[
          col.where('isArchived', isEqualTo: false).count().get(),
          col.where('isBlacklisted', isEqualTo: true).count().get(),
          col.where('isVip', isEqualTo: true).count().get(),
          col
              .where(
                'createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
              )
              .count()
              .get(),
        ]);
    return MemberListStats(
      total: snaps[0].count ?? 0,
      blacklisted: snaps[1].count ?? 0,
      vip: snaps[2].count ?? 0,
      newThisMonth: snaps[3].count ?? 0,
    );
  }

  Future<MemberListPageResult> loadPage({
    required String shopId,
    required String filter,
    String keyword = '',
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor,
  }) async {
    final String trimmed = keyword.trim();
    Query<Map<String, dynamic>> query = _col(shopId);
    if (trimmed.isNotEmpty) {
      query = _searchQuery(query, trimmed);
    } else {
      query = _filterQuery(query, filter);
    }
    query = query.limit(pageSize);
    if (cursor != null) {
      query = query.startAfterDocument(cursor);
    }
    final QuerySnapshot<Map<String, dynamic>> snap = await query.get();
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = snap.docs
        .where((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          return _matchesFilter(doc.data(), filter) &&
              (trimmed.isEmpty || _matchesKeyword(doc.data(), trimmed));
        })
        .toList();
    return MemberListPageResult(
      docs: docs,
      cursor: snap.docs.isEmpty ? cursor : snap.docs.last,
      hasMore: snap.docs.length >= pageSize,
    );
  }

  Query<Map<String, dynamic>> _filterQuery(
    Query<Map<String, dynamic>> query,
    String filter,
  ) {
    switch (filter) {
      case 'app':
        return query
            .where('memberSource', isEqualTo: 'app')
            .where('isArchived', isEqualTo: false)
            .orderBy('createdAt', descending: true);
      case 'admin':
        return query
            .where('memberSource', isEqualTo: 'admin')
            .where('isArchived', isEqualTo: false)
            .orderBy('createdAt', descending: true);
      case 'archived':
        return query
            .where('isArchived', isEqualTo: true)
            .orderBy('createdAt', descending: true);
      case 'blacklisted':
        return query
            .where('isBlacklisted', isEqualTo: true)
            .orderBy('createdAt', descending: true);
      case 'vip':
        return query
            .where('isVip', isEqualTo: true)
            .where('isArchived', isEqualTo: false)
            .orderBy('createdAt', descending: true);
      case 'activeAll':
      default:
        return query
            .where('isArchived', isEqualTo: false)
            .orderBy('createdAt', descending: true);
    }
  }

  Query<Map<String, dynamic>> _searchQuery(
    Query<Map<String, dynamic>> query,
    String keyword,
  ) {
    final String digits = MemberSearchFields.digitsOnly(keyword);
    if (digits.length == 4 || digits.length == 5) {
      return query
          .where(
            digits.length == 4 ? 'phoneLast4' : 'phoneLast5',
            isEqualTo: digits,
          )
          .orderBy('createdAt', descending: true);
    }
    if (keyword.contains('@')) {
      return query
          .where(
            'emailNormalized',
            isEqualTo: MemberSearchFields.normalizeEmail(keyword),
          )
          .orderBy('createdAt', descending: true);
    }
    final String prefix = MemberSearchFields.normalizeName(keyword);
    final String capped = prefix.length > MemberSearchFields.maxNamePrefixLength
        ? prefix.substring(0, MemberSearchFields.maxNamePrefixLength)
        : prefix;
    return query
        .where('namePrefixes', arrayContains: capped)
        .orderBy('createdAt', descending: true);
  }

  bool _matchesFilter(Map<String, dynamic> data, String filter) {
    final String status = (data['status'] ?? '').toString();
    if (status == 'merged') {
      return false;
    }
    final bool archived =
        data['isArchived'] == true || status == 'archived';
    final String source = (data['memberSource'] ?? data['source'] ?? 'app')
        .toString();
    final bool blacklisted =
        data['isBlacklisted'] == true ||
        data['blacklisted'] == true ||
        data['isBlocked'] == true;
    final List<dynamic> tags = data['tags'] is List
        ? data['tags'] as List<dynamic>
        : const <dynamic>[];
    final bool vip = data['isVip'] == true || tags.contains('vip');
    switch (filter) {
      case 'archived':
        return archived;
      case 'app':
        return !archived && source == 'app';
      case 'admin':
        return !archived && source == 'admin';
      case 'blacklisted':
        return blacklisted;
      case 'vip':
        return !archived && vip;
      default:
        return !archived;
    }
  }

  bool _matchesKeyword(Map<String, dynamic> data, String keyword) {
    final String digits = MemberSearchFields.digitsOnly(keyword);
    final String name = MemberSearchFields.normalizeName(
      (data['name'] ?? '').toString(),
    );
    final String email = MemberSearchFields.normalizeEmail(
      (data['email'] ?? '').toString(),
    );
    final String phone = MemberSearchFields.digitsOnly(
      (data['phone'] ?? '').toString(),
    );
    if (digits.length >= 4 && phone.endsWith(digits)) {
      return true;
    }
    if (keyword.contains('@') && email == MemberSearchFields.normalizeEmail(keyword)) {
      return true;
    }
    return name.startsWith(MemberSearchFields.normalizeName(keyword));
  }
}
