// 檔案名稱：lib/core/services/member_list_query_service.dart
// 功能說明：會員列表與統計。
// 支援舊版會員資料缺少 isArchived、memberSource、搜尋索引欄位的情況。

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

  /// 舊資料沒有新版布林欄位時，Firestore 的 where(false) 會直接排除它。
  /// 因此統一讀取後，使用下方相容邏輯計算統計數字。
  Future<MemberListStats> loadStats(String shopId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _col(
      shopId,
    ).get();

    final DateTime now = DateTime.now();
    final DateTime monthStart = DateTime(now.year, now.month, 1);

    int total = 0;
    int blacklisted = 0;
    int vip = 0;
    int newThisMonth = 0;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final Map<String, dynamic> data = doc.data();

      if (!_isArchived(data) && !_isMerged(data)) {
        total++;
      }

      if (_isBlacklisted(data)) {
        blacklisted++;
      }

      if (_isVip(data)) {
        vip++;
      }

      final DateTime? createdAt = _dateTimeOf(data['createdAt']);
      if (createdAt != null && !createdAt.isBefore(monthStart)) {
        newThisMonth++;
      }
    }

    return MemberListStats(
      total: total,
      blacklisted: blacklisted,
      vip: vip,
      newThisMonth: newThisMonth,
    );
  }

  Future<MemberListPageResult> loadPage({
    required String shopId,
    required String filter,
    String keyword = '',
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor,
  }) async {
    final String trimmed = keyword.trim();

    // 不能在 Firestore 先用 isArchived / memberSource / namePrefixes 篩選，
    // 否則舊會員缺少這些欄位時會完全消失。
    Query<Map<String, dynamic>> query = _col(
      shopId,
    ).orderBy('createdAt', descending: true);

    QueryDocumentSnapshot<Map<String, dynamic>>? scanCursor = cursor;
    QueryDocumentSnapshot<Map<String, dynamic>>? lastCursor;
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> matchedDocs =
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    bool hasMore = true;

    // 每次頁面保留 pageSize 位符合條件的會員。
    // 若中間有封存或不符合分類的資料，會繼續讀下一批，避免畫面誤顯示空白。
    while (matchedDocs.length < pageSize && hasMore) {
      Query<Map<String, dynamic>> pageQuery = query.limit(pageSize);

      if (scanCursor != null) {
        pageQuery = pageQuery.startAfterDocument(scanCursor);
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await pageQuery
          .get();

      if (snapshot.docs.isEmpty) {
        hasMore = false;
        break;
      }

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        final Map<String, dynamic> data = doc.data();

        if (_matchesFilter(data, filter) &&
            (trimmed.isEmpty || _matchesKeyword(data, trimmed))) {
          matchedDocs.add(doc);

          if (matchedDocs.length >= pageSize) {
            break;
          }
        }
      }

      lastCursor = snapshot.docs.last;
      scanCursor = lastCursor;
      hasMore = snapshot.docs.length >= pageSize;
    }

    return MemberListPageResult(
      docs: matchedDocs,
      cursor: lastCursor ?? cursor,
      hasMore: hasMore,
    );
  }

  bool _matchesFilter(Map<String, dynamic> data, String filter) {
    if (_isMerged(data)) {
      return false;
    }

    final bool archived = _isArchived(data);
    final String source = _memberSource(data);
    final bool blacklisted = _isBlacklisted(data);
    final bool vip = _isVip(data);

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
      case 'activeAll':
      default:
        return !archived;
    }
  }

  bool _matchesKeyword(Map<String, dynamic> data, String keyword) {
    final String digits = MemberSearchFields.digitsOnly(keyword);
    final String normalizedKeyword = MemberSearchFields.normalizeName(keyword);
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

    if (keyword.contains('@') &&
        email == MemberSearchFields.normalizeEmail(keyword)) {
      return true;
    }

    return normalizedKeyword.isNotEmpty && name.startsWith(normalizedKeyword);
  }

  bool _isArchived(Map<String, dynamic> data) {
    return data['isArchived'] == true ||
        (data['status'] ?? '').toString() == 'archived';
  }

  bool _isMerged(Map<String, dynamic> data) {
    return data['isMerged'] == true ||
        (data['status'] ?? '').toString() == 'merged';
  }

  bool _isBlacklisted(Map<String, dynamic> data) {
    return data['isBlacklisted'] == true ||
        data['blacklisted'] == true ||
        data['isBlocked'] == true;
  }

  bool _isVip(Map<String, dynamic> data) {
    final dynamic rawTags = data['tags'];
    final List<dynamic> tags = rawTags is List ? rawTags : const <dynamic>[];

    return data['isVip'] == true || tags.contains('vip');
  }

  String _memberSource(Map<String, dynamic> data) {
    final String raw =
        (data['memberSource'] ?? data['source'] ?? data['createdFrom'] ?? 'app')
            .toString()
            .trim()
            .toLowerCase();

    return raw == 'admin' ? 'admin' : 'app';
  }

  DateTime? _dateTimeOf(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
