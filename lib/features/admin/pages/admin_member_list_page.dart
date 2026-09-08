// 檔案名稱：lib/features/admin/pages/admin_member_list_page.dart
// 功能說明：會員管理列表：暖色專業卡片、即時頭像、手機單欄

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
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
    {'key': 'activeAll', 'label': '全部'},
    {'key': 'app', 'label': '店家會員'},
    {'key': 'admin', 'label': '手動新增'},
    {'key': 'archived', 'label': '封存'},
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
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('shops')
                      .doc(widget.shopId)
                      .collection('members')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('會員資料讀取失敗'),
                            TextButton(
                              onPressed: () => setState(() {}),
                              child: const Text('重試'),
                            ),
                          ],
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return {
                        ...data,
                        'userId': doc.id,
                        'bookingCount': data['bookingCount'] ?? 0,
                        'tags': data['tags'] ?? [],
                      };
                    }).toList();
                    if (docs.isEmpty) {
                      return const Center(child: Text('尚無會員'));
                    }
                    final List<Map<String, dynamic>> visibleDocs =
                        _filterMembersWithProfile(docs);
                    final _MemberStats stats = _statsFrom(docs);
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: _statsBar(theme, stats),
                        ),
                        Expanded(
                          child: visibleDocs.isEmpty
                              ? Center(
                                  child: Text(
                                    keyword.isEmpty ? '尚無會員' : '沒有符合搜尋的會員',
                                  ),
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    final int columns =
                                        constraints.maxWidth >= 720 ? 2 : 1;
                                    return ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        4,
                                        12,
                                        16,
                                      ),
                                      itemCount: (visibleDocs.length / columns)
                                          .ceil(),
                                      itemBuilder: (context, rowIndex) {
                                        final int start = rowIndex * columns;
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: List<Widget>.generate(
                                              columns,
                                              (int col) {
                                                final int index = start + col;
                                                if (index >=
                                                    visibleDocs.length) {
                                                  return const Expanded(
                                                    child: SizedBox.shrink(),
                                                  );
                                                }
                                                return Expanded(
                                                  child: Padding(
                                                    padding: EdgeInsets.only(
                                                      right: col == columns - 1
                                                          ? 0
                                                          : 10,
                                                    ),
                                                    child: AdminMemberListCard(
                                                      shopId: widget.shopId,
                                                      data: visibleDocs[index],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
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
      },
    );
  }

  Widget _statsBar(ShopFrontendTheme theme, _MemberStats stats) {
    Widget item(String label, String value) {
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

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          item('會員', '${stats.total}'),
          item('黑名單', '${stats.blacklisted}'),
          item('常客', '${stats.vip}'),
          item('本月新增', '${stats.newThisMonth}'),
        ],
      ),
    );
  }

  _MemberStats _statsFrom(List<Map<String, dynamic>> docs) {
    int total = 0;
    int blacklisted = 0;
    int vip = 0;
    int newThisMonth = 0;
    final DateTime now = DateTime.now();
    for (final Map<String, dynamic> data in docs) {
      if ((data['status'] ?? '').toString() == 'merged') {
        continue;
      }
      if ((data['status'] ?? '').toString() == 'archived') {
        continue;
      }
      total += 1;
      if (data['blacklisted'] == true || data['isBlocked'] == true) {
        blacklisted += 1;
      }
      final tags = List<String>.from(data['tags'] ?? []);
      if (tags.contains('vip')) {
        vip += 1;
      }
      final created = data['createdAt'];
      if (created is Timestamp) {
        final DateTime d = created.toDate();
        if (d.year == now.year && d.month == now.month) {
          newThisMonth += 1;
        }
      }
    }
    return _MemberStats(
      total: total,
      blacklisted: blacklisted,
      vip: vip,
      newThisMonth: newThisMonth,
    );
  }

  String _normalizePhoneForSearch(String value) {
    String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('09')) {
      digits = digits.substring(2);
    }
    return digits;
  }

  List<Map<String, dynamic>> _filterMembersWithProfile(
    List<Map<String, dynamic>> docs,
  ) {
    return docs.where((data) {
      final status = data['status']?.toString() ?? '';
      final source = data['source']?.toString().trim().isNotEmpty == true
          ? data['source'].toString()
          : 'app';
      final name = data['name']?.toString().toLowerCase() ?? '';
      final phone = data['phone']?.toString().toLowerCase() ?? '';
      final normalizedPhone = _normalizePhoneForSearch(phone);
      final email = data['email']?.toString().toLowerCase() ?? '';
      final searchText = keyword.toLowerCase();
      final normalizedSearchText = _normalizePhoneForSearch(searchText);
      if (status == 'merged') {
        return false;
      }
      if (memberFilter == 'archived') {
        if (status != 'archived') return false;
      } else {
        if (status == 'archived') return false;
      }
      if (memberFilter == 'app' && source != 'app') {
        return false;
      }
      if (memberFilter == 'admin' && source != 'admin') {
        return false;
      }
      if (searchText.isNotEmpty &&
          !name.contains(searchText) &&
          !phone
              .replaceAll(RegExp(r'[^0-9]'), '')
              .contains(searchText.replaceAll(RegExp(r'[^0-9]'), '')) &&
          !normalizedPhone.contains(normalizedSearchText) &&
          !email.contains(searchText)) {
        return false;
      }
      return true;
    }).toList();
  }
}

class _MemberStats {
  const _MemberStats({
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
