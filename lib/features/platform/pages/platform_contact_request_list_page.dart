// 檔案名稱：lib/features/platform/pages/platform_contact_request_list_page.dart
// 功能說明：平台查看店主與會員聯絡案件。寬螢幕左列表右聊天，窄螢幕進入聊天室。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:petnest_saas/features/platform/pages/platform_contact_request_detail_page.dart';
import 'package:petnest_saas/features/support/contact_case_labels.dart';
import 'package:petnest_saas/features/support/widgets/contact_case_chat.dart';

class PlatformContactRequestListPage extends StatefulWidget {
  const PlatformContactRequestListPage({super.key});

  @override
  State<PlatformContactRequestListPage> createState() =>
      _PlatformContactRequestListPageState();
}

class _PlatformContactRequestListPageState
    extends State<PlatformContactRequestListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final TextEditingController _shopSearch;
  late final TextEditingController _memberSearch;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _requests;
  String? _shopSelection;
  String? _memberSelection;
  String _shopQuery = '';
  String _memberQuery = '';
  String _shopStatus = 'all';
  String _memberStatus = 'all';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _shopSearch = TextEditingController();
    _memberSearch = TextEditingController();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && mounted) {
        setState(() {});
      }
    });
    _requests = _open();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _shopSearch.dispose();
    _memberSearch.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _open() {
    return FirebaseFirestore.instance
        .collection('platform_contact_requests')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final bool shopTab = _tabs.index == 0;
    final String source = shopTab ? 'shop_owner' : 'member';
    final String? selected = shopTab ? _shopSelection : _memberSelection;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('聯絡平台案件'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const <Widget>[
            Tab(text: '店主聯絡'),
            Tab(text: '會員聯絡'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _requests,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.hasError) {
                return _PaneMessage(
                  title: '案件讀取失敗',
                  message: '請確認此帳號具有平台案件讀取權限後再試。',
                  action: '重試',
                  onPressed: () => setState(() => _requests = _open()),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool wide = constraints.maxWidth >= 1000;
                  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                      _visible(
                        snapshot.data!.docs,
                        source: source,
                        query: shopTab ? _shopQuery : _memberQuery,
                        status: shopTab ? _shopStatus : _memberStatus,
                      );
                  final Widget list = _RequestColumn(
                    source: source,
                    docs: docs,
                    totalForSource: snapshot.data!.docs
                        .where(
                          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                              (doc.data()['source'] ?? '').toString() == source,
                        )
                        .length,
                    search: shopTab ? _shopSearch : _memberSearch,
                    status: shopTab ? _shopStatus : _memberStatus,
                    selectedId: wide ? selected : null,
                    onQuery: (String value) {
                      setState(() {
                        if (shopTab) {
                          _shopQuery = value;
                        } else {
                          _memberQuery = value;
                        }
                      });
                    },
                    onStatus: (String value) {
                      setState(() {
                        if (shopTab) {
                          _shopStatus = value;
                        } else {
                          _memberStatus = value;
                        }
                      });
                    },
                    onOpen: (String id) {
                      if (!wide) {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                PlatformContactRequestDetailPage(requestId: id),
                          ),
                        );
                        return;
                      }
                      setState(() {
                        if (shopTab) {
                          _shopSelection = id;
                        } else {
                          _memberSelection = id;
                        }
                      });
                    },
                  );
                  if (!wide) {
                    return list;
                  }
                  return Row(
                    children: <Widget>[
                      SizedBox(width: 380, child: list),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: selected == null
                            ? const _PaneMessage(
                                title: '尚未選擇案件',
                                message: '從左側選擇一筆案件後，即可在這裡回覆。',
                              )
                            : ContactCaseChat(
                                key: ValueKey<String>(selected),
                                requestId: selected,
                                viewer: ContactCaseViewer.platform,
                                embedded: true,
                              ),
                      ),
                    ],
                  );
                },
              );
            },
      ),
    );
  }
}

class _RequestColumn extends StatelessWidget {
  const _RequestColumn({
    required this.source,
    required this.docs,
    required this.totalForSource,
    required this.search,
    required this.status,
    required this.selectedId,
    required this.onQuery,
    required this.onStatus,
    required this.onOpen,
  });

  final String source;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final int totalForSource;
  final TextEditingController search;
  final String status;
  final String? selectedId;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onStatus;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            key: ValueKey<String>(source),
            controller: search,
            decoration: const InputDecoration(
              isDense: true,
              hintText: '搜尋標題、店名、店編、分類、姓名、信箱或內容（已載入案件）',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: onQuery,
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: <Widget>[
              _FilterChip(
                label: '全部',
                value: 'all',
                selected: status,
                onSelected: onStatus,
              ),
              _FilterChip(
                label: '待處理',
                value: 'open',
                selected: status,
                onSelected: onStatus,
              ),
              _FilterChip(
                label: '處理中',
                value: 'processing',
                selected: status,
                onSelected: onStatus,
              ),
              _FilterChip(
                label: '已結案',
                value: 'closed',
                selected: status,
                onSelected: onStatus,
              ),
            ],
          ),
        ),
        Expanded(
          child: totalForSource == 0
              ? _PaneMessage(
                  title: source == 'shop_owner' ? '沒有店主案件' : '沒有會員案件',
                  message: '這個分頁目前沒有聯絡紀錄。',
                )
              : docs.isEmpty
              ? const _PaneMessage(
                  title: '沒有符合的案件',
                  message: '請調整狀態或搜尋文字。搜尋只比對目前已載入的案件。',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final QueryDocumentSnapshot<Map<String, dynamic>> doc =
                        docs[index];
                    final Map<String, dynamic> data = doc.data();
                    final bool selected = doc.id == selectedId;
                    final String title = (data['title'] ?? '未填標題').toString();
                    final String category = (data['category'] ?? '未分類')
                        .toString();
                    final String who = source == 'shop_owner'
                        ? (data['shopName'] ?? '').toString()
                        : (data['userName'] ?? data['userEmail'] ?? '')
                              .toString();
                    return Material(
                      color: selected ? const Color(0xFFEFF6FF) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: selected
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onOpen(doc.id),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    contactCaseStatusLabel(
                                      (data['status'] ?? 'open').toString(),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${who.isEmpty ? category : who}　$category',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                contactCaseSummary(data),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected == value,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => onSelected(value),
      ),
    );
  }
}

class _PaneMessage extends StatelessWidget {
  const _PaneMessage({
    required this.title,
    required this.message,
    this.action,
    this.onPressed,
  });

  final String title;
  final String message;
  final String? action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.support_agent, size: 36, color: Color(0xFF94A3B8)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onPressed, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}

List<QueryDocumentSnapshot<Map<String, dynamic>>> _visible(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
  required String source,
  required String query,
  required String status,
}) {
  final String needle = query.trim().toLowerCase();
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> matched =
      docs.where((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        if ((data['source'] ?? '').toString() != source) {
          return false;
        }
        final String caseStatus = (data['status'] ?? 'open').toString();
        if (status != 'all' && caseStatus != status) {
          return false;
        }
        if (needle.isEmpty) {
          return true;
        }
        final String haystack = <String>[
          (data['title'] ?? '').toString(),
          (data['shopName'] ?? '').toString(),
          (data['shopCode'] ?? '').toString(),
          (data['category'] ?? '').toString(),
          (data['userName'] ?? '').toString(),
          (data['userEmail'] ?? '').toString(),
          (data['userPhone'] ?? '').toString(),
          (data['content'] ?? '').toString(),
          (data['lastMessage'] ?? '').toString(),
        ].join('\n').toLowerCase();
        return haystack.contains(needle);
      }).toList()..sort((
        QueryDocumentSnapshot<Map<String, dynamic>> a,
        QueryDocumentSnapshot<Map<String, dynamic>> b,
      ) {
        final int left = _millis(
          a.data()['updatedAt'] ?? a.data()['createdAt'],
        );
        final int right = _millis(
          b.data()['updatedAt'] ?? b.data()['createdAt'],
        );
        return right.compareTo(left);
      });
  return matched;
}

int _millis(Object? value) {
  if (value is Timestamp) {
    return value.millisecondsSinceEpoch;
  }
  return 0;
}
