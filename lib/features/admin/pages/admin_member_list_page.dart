// 檔案名稱：lib/features/admin/pages/admin_member_list_page.dart
// 功能說明：會員管理列表：暖色專業卡片、即時頭像、手機單欄

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/services/member_list_query_service.dart';
import 'package:petnest_saas/core/widgets/member_avatar.dart';
import 'package:petnest_saas/core/widgets/shop_frontend_theme_scope.dart';
import 'package:petnest_saas/features/admin/pages/admin_member_detail_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_member_merge_page.dart';

class AdminMemberListPage extends StatefulWidget {
  const AdminMemberListPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<AdminMemberListPage> createState() => _AdminMemberListPageState();
}

class _AdminMemberListPageState extends State<AdminMemberListPage> {
  String keyword = '';
  String memberFilter = 'activeAll';
  final List<Map<String, String>> memberFilters = const [
    {'key': 'activeAll', 'label': '全部有效會員'},
    {'key': 'app', 'label': '店家會員'},
    {'key': 'admin', 'label': '手動新增會員'},
    {'key': 'archived', 'label': '封存會員'},
    {'key': 'blacklisted', 'label': '黑名單'},
    {'key': 'vip', 'label': '常客'},
  ];

  @override
  Widget build(BuildContext context) {
    return ShopFrontendThemeScope(
      shopId: widget.shopId,
      builder: (BuildContext context) {
        final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
        return Scaffold(
          backgroundColor: theme.pageBackgroundColor,
          appBar: AppBar(title: const Text('會員管理')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '搜尋姓名 / 電話 / Email',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: theme.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.borderColor),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      keyword = value.trim();
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: memberFilters.map((filter) {
                            final selected = memberFilter == filter['key'];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(filter['label']!),
                                selected: selected,
                                onSelected: (_) {
                                  setState(() {
                                    memberFilter = filter['key']!;
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '會員合併',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AdminMemberMergePage(shopId: widget.shopId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.merge_type),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _MemberPagedBody(
                  shopId: widget.shopId,
                  keyword: keyword,
                  memberFilter: memberFilter,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MemberPagedBody extends StatefulWidget {
  const _MemberPagedBody({
    required this.shopId,
    required this.keyword,
    required this.memberFilter,
  });

  final String shopId;
  final String keyword;
  final String memberFilter;

  @override
  State<_MemberPagedBody> createState() => _MemberPagedBodyState();
}

class _MemberPagedBodyState extends State<_MemberPagedBody> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  QueryDocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  MemberListStats _stats = const MemberListStats(
    total: 0,
    blacklisted: 0,
    vip: 0,
    newThisMonth: 0,
  );

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant _MemberPagedBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keyword != widget.keyword ||
        oldWidget.memberFilter != widget.memberFilter) {
      _reload();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _docs.clear();
      _cursor = null;
    });
    try {
      final MemberListPageResult page = await MemberListQueryService.instance
          .loadPage(
            shopId: widget.shopId,
            filter: widget.memberFilter,
            keyword: widget.keyword,
          );
      final MemberListStats stats = await MemberListQueryService.instance
          .loadStats(widget.shopId);
      if (!mounted) {
        return;
      }
      setState(() {
        _docs
          ..clear()
          ..addAll(page.docs);
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _stats = stats;
        _loading = false;
      });
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

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore || _cursor == null) {
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final MemberListPageResult page = await MemberListQueryService.instance
          .loadPage(
            shopId: widget.shopId,
            filter: widget.memberFilter,
            keyword: widget.keyword,
            cursor: _cursor,
          );
      if (!mounted) {
        return;
      }
      final Set<String> seen = _docs.map((d) => d.id).toSet();
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

  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    final List<Map<String, dynamic>> visibleDocs = _docs.map((doc) {
      final Map<String, dynamic> data = doc.data();
      return <String, dynamic>{
        ...data,
        'userId': doc.id,
        'bookingCount': data['bookingCount'] ?? 0,
        'tags': data['tags'] ?? [],
      };
    }).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.borderColor.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                _statItem(theme, '會員', '${_stats.total}'),
                _statItem(theme, '黑名單', '${_stats.blacklisted}'),
                _statItem(theme, '常客', '${_stats.vip}'),
                _statItem(theme, '本月新增', '${_stats.newThisMonth}'),
              ],
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text('會員資料讀取失敗'))
              : visibleDocs.isEmpty
              ? Center(
                  child: Text(widget.keyword.isEmpty ? '尚無會員' : '沒有符合搜尋的會員'),
                )
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final int columns = constraints.maxWidth >= 720 ? 2 : 1;
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                        itemCount:
                            (visibleDocs.length / columns).ceil() +
                            (_hasMore ? 1 : 0),
                        itemBuilder: (context, rowIndex) {
                          final int rowCount = (visibleDocs.length / columns)
                              .ceil();
                          if (rowIndex >= rowCount) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: OutlinedButton(
                                onPressed: _loadingMore ? null : _loadMore,
                                child: Text(_loadingMore ? '載入中…' : '載入更多'),
                              ),
                            );
                          }
                          final int start = rowIndex * columns;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: List<Widget>.generate(columns, (
                                int col,
                              ) {
                                final int index = start + col;
                                if (index >= visibleDocs.length) {
                                  return const Expanded(
                                    child: SizedBox.shrink(),
                                  );
                                }
                                return Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: col == columns - 1 ? 0 : 10,
                                    ),
                                    child: AdminMemberListCard(
                                      shopId: widget.shopId,
                                      data: visibleDocs[index],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _statItem(ShopFrontendTheme theme, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: theme.titleColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: theme.subtitleColor),
          ),
        ],
      ),
    );
  }
}

class AdminMemberListCard extends StatelessWidget {
  const AdminMemberListCard({
    super.key,
    required this.shopId,
    required this.data,
  });

  final String shopId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    final Color primary = theme.primaryColor;
    final Color card = theme.cardColor;
    final Color title = theme.titleColor;
    final Color muted = theme.subtitleColor;
    final userId = data['userId']?.toString() ?? '';
    final rawName = data['name']?.toString().trim() ?? '';
    final rawPhone = data['phone']?.toString().trim() ?? '';
    final name = rawName.isEmpty ? '未填姓名' : rawName;
    final tags = List<String>.from(data['tags'] ?? []);
    final isBlacklisted =
        data['blacklisted'] == true || data['isBlocked'] == true;
    final source = data['source']?.toString() == 'admin' ? 'admin' : 'app';
    final sourceLabel = source == 'admin' ? '手動會員' : '店家會員';
    final lastAt = data['lastBookingAt'];
    String lastText = '';
    if (lastAt is Timestamp) {
      final d = lastAt.toDate();
      lastText = '${d.year}/${d.month}/${d.day}';
    }
    final Color accent = isBlacklisted
        ? const Color(0xFFC45C5C)
        : (tags.contains('vip') ? const Color(0xFFC9A227) : primary);

    return Material(
      color: Color.alphaBlend(primary.withValues(alpha: 0.06), card),
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AdminMemberDetailPage(userId: userId, shopId: shopId),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
                    child: Row(
                      children: [
                        ShopMemberLiveAvatar(
                          shopId: shopId,
                          userId: userId,
                          name: name,
                          size: 52,
                          member: data,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: title,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                rawPhone.isEmpty ? '未填電話' : rawPhone,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: muted, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '寵物 ${data['petCount'] ?? 0}  ·  訂單 ${data['bookingCount'] ?? 0}'
                                '${lastText.isEmpty ? '' : '  ·  $lastText'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: muted),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _chip(sourceLabel, primary),
                                  if (isBlacklisted)
                                    _chip('黑名單', const Color(0xFFC45C5C)),
                                  if (tags.contains('vip'))
                                    _chip('常客', const Color(0xFFC9A227)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: muted),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
