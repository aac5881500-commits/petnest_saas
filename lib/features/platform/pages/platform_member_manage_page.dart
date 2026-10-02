// 檔案名稱：lib/features/platform/pages/platform_member_manage_page.dart
// 功能說明：平台後台查看平台帳號、帳號狀態、最後登入與平台備註
// 👤 平台會員管理頁

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/core/constants/platform_root_admin.dart';
import 'package:petnest_saas/core/services/platform_member_reconciliation_service.dart';
import 'package:petnest_saas/features/platform/models/platform_member_shop_identity.dart';
import 'package:petnest_saas/features/platform/widgets/platform_member_account_detail.dart';

const double _kMemberDesktopWidth = 1100;
const double _kMemberContentMaxWidth = 1440;

enum _MemberListFilter { all, general, owner, workplace, blocked }

class PlatformMemberManagePage extends StatelessWidget {
  const PlatformMemberManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlatformMemberDirectory();
  }
}

class _PlatformMemberDirectory extends StatefulWidget {
  const _PlatformMemberDirectory();

  @override
  State<_PlatformMemberDirectory> createState() =>
      _PlatformMemberDirectoryState();
}

class _PlatformMemberDirectoryState extends State<_PlatformMemberDirectory> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _shopsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _membersStream;
  final TextEditingController _searchController = TextEditingController();
  _MemberListFilter _filter = _MemberListFilter.all;

  @override
  void initState() {
    super.initState();
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    _usersStream = firestore.collection('users').snapshots();
    _shopsStream = firestore.collection('shops').snapshots();
    _membersStream = firestore.collection('shop_members').snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime? _coerceDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  DateTime? _memberSortDate(Map<String, dynamic> data) {
    return _coerceDate(data['createdAt']) ??
        _coerceDate(data['updatedAt']) ??
        _coerceDate(data['lastLoginAt']);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortedMemberDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> sorted =
        List<QueryDocumentSnapshot<Map<String, dynamic>>>.of(docs);
    sorted.sort((
      QueryDocumentSnapshot<Map<String, dynamic>> a,
      QueryDocumentSnapshot<Map<String, dynamic>> b,
    ) {
      final DateTime? aDate = _memberSortDate(a.data());
      final DateTime? bDate = _memberSortDate(b.data());
      if (aDate == null && bDate == null) return a.id.compareTo(b.id);
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      final int compared = bDate.compareTo(aDate);
      if (compared != 0) return compared;
      return a.id.compareTo(b.id);
    });
    return sorted;
  }

  String _memberStatus(Map<String, dynamic> data) {
    final String status = data['platformStatus']?.toString().trim() ?? '';
    return status.isEmpty ? 'active' : status;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'blocked':
        return '已封鎖';
      case 'restricted':
        return '限制預約';
      default:
        return '正常';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'blocked':
        return Colors.red;
      case 'restricted':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool desktop =
        MediaQuery.sizeOf(context).width >= _kMemberDesktopWidth;
    final bool isRoot = PlatformRootAdmin.isRoot(
      FirebaseAuth.instance.currentUser?.uid,
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: desktop
          ? null
          : AppBar(
              title: const Text('平台會員管理'),
              actions: <Widget>[
                if (isRoot)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: _OwnerAccountRepairButton(compact: true),
                  ),
              ],
            ),
      body: Column(
        children: <Widget>[
          if (desktop)
            SafeArea(
              bottom: false,
              child: _DesktopFrame(child: _desktopToolbar(isRoot)),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _usersStream,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> users,
                  ) {
                    if (users.connectionState == ConnectionState.waiting &&
                        !users.hasData) {
                      return _listStatus(
                        desktop: desktop,
                        child: const CircularProgressIndicator(),
                      );
                    }
                    if (users.hasError && !users.hasData) {
                      return _listStatus(
                        desktop: desktop,
                        child: const Text('暫時無法讀取平台會員'),
                      );
                    }
                    final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    docs = _sortedMemberDocs(users.data?.docs ?? const []);
                    if (docs.isEmpty) {
                      return _listStatus(
                        desktop: desktop,
                        child: const Text('目前沒有平台會員'),
                      );
                    }
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _shopsStream,
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                            shops,
                          ) {
                            return StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>
                            >(
                              stream: _membersStream,
                              builder:
                                  (
                                    BuildContext context,
                                    AsyncSnapshot<
                                      QuerySnapshot<Map<String, dynamic>>
                                    >
                                    members,
                                  ) {
                                    final bool identityFailed =
                                        shops.hasError || members.hasError;
                                    final bool identityReady =
                                        !identityFailed &&
                                        shops.hasData &&
                                        members.hasData;
                                    final Map<
                                      String,
                                      PlatformMemberShopIdentity
                                    >
                                    identities = identityReady
                                        ? indexPlatformMemberShopIdentities(
                                            shops: _shopRecords(shops.data!),
                                            members: _memberRecords(
                                              members.data!,
                                            ),
                                          )
                                        : const <
                                            String,
                                            PlatformMemberShopIdentity
                                          >{};
                                    final String query = _searchController.text
                                        .trim()
                                        .toLowerCase();
                                    final List<
                                      QueryDocumentSnapshot<
                                        Map<String, dynamic>
                                      >
                                    >
                                    visible =
                                        <
                                          QueryDocumentSnapshot<
                                            Map<String, dynamic>
                                          >
                                        >[
                                          for (final QueryDocumentSnapshot<
                                                Map<String, dynamic>
                                              >
                                              doc
                                              in docs)
                                            if (_matchesQuery(doc, query) &&
                                                _matchesFilter(
                                                  doc,
                                                  identities[doc.id],
                                                  identityReady: identityReady,
                                                  identityFailed:
                                                      identityFailed,
                                                ))
                                              doc,
                                        ];
                                    final Widget list = visible.isEmpty
                                        ? _emptyResults(desktop: desktop)
                                        : ListView.separated(
                                            padding: EdgeInsets.fromLTRB(
                                              desktop ? 0 : 16,
                                              4,
                                              desktop ? 0 : 16,
                                              16,
                                            ),
                                            itemCount: visible.length,
                                            separatorBuilder: (_, _) =>
                                                SizedBox(
                                                  height: desktop ? 8 : 10,
                                                ),
                                            itemBuilder:
                                                (
                                                  BuildContext context,
                                                  int itemIndex,
                                                ) {
                                                  final QueryDocumentSnapshot<
                                                    Map<String, dynamic>
                                                  >
                                                  doc = visible[itemIndex];
                                                  return _MemberCard(
                                                    doc: doc,
                                                    desktop: desktop,
                                                    identity:
                                                        identities[doc.id] ??
                                                        const PlatformMemberShopIdentity(
                                                          owned:
                                                              <
                                                                PlatformOwnedShopView
                                                              >[],
                                                          workplaces:
                                                              <
                                                                PlatformWorkplaceView
                                                              >[],
                                                        ),
                                                    identityReady:
                                                        identityReady,
                                                    identityFailed:
                                                        identityFailed,
                                                    statusLabel: _statusLabel,
                                                    statusColor: _statusColor,
                                                  );
                                                },
                                          );
                                    final Widget directory = Column(
                                      children: <Widget>[
                                        if (!desktop)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              8,
                                              16,
                                              0,
                                            ),
                                            child: _searchField(),
                                          ),
                                        _filterBar(
                                          docs: docs,
                                          identities: identities,
                                          identityReady:
                                              identityReady && !identityFailed,
                                          resultCount: desktop
                                              ? visible.length
                                              : null,
                                        ),
                                        if (desktop) const _MemberTableHeader(),
                                        Expanded(child: list),
                                      ],
                                    );
                                    if (!desktop) return directory;
                                    return _DesktopFrame(child: directory);
                                  },
                            );
                          },
                    );
                  },
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopToolbar(bool isRoot) {
    return SizedBox(
      height: 64,
      child: Row(
        children: <Widget>[
          if (Navigator.canPop(context))
            IconButton(
              tooltip: '返回',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back),
            ),
          const Text(
            '平台會員管理',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          SizedBox(width: 340, height: 36, child: _searchField()),
          if (isRoot) ...<Widget>[
            const SizedBox(width: 8),
            const _OwnerAccountRepairButton(),
          ],
        ],
      ),
    );
  }

  Widget _listStatus({required bool desktop, required Widget child}) {
    final Widget status = Center(child: child);
    if (!desktop) return status;
    return _DesktopFrame(child: status);
  }

  Widget _emptyResults({required bool desktop}) {
    if (!desktop) {
      return const Center(child: Text('找不到符合的會員'));
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('找不到符合條件的會員'),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() => _filter = _MemberListFilter.all);
            },
            child: const Text('清除搜尋／篩選'),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        hintText: '搜尋姓名、Email 或 UID',
        prefixIcon: const Icon(Icons.search, size: 20),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: '清除',
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close, size: 18),
              ),
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _filterBar({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required Map<String, PlatformMemberShopIdentity> identities,
    required bool identityReady,
    int? resultCount,
  }) {
    int general = 0;
    int owners = 0;
    int workplaces = 0;
    int blocked = 0;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final String status = _memberStatus(doc.data());
      if (status == 'blocked') blocked += 1;
      if (!identityReady) continue;
      final PlatformMemberShopIdentity identity =
          identities[doc.id] ??
          const PlatformMemberShopIdentity(
            owned: <PlatformOwnedShopView>[],
            workplaces: <PlatformWorkplaceView>[],
          );
      if (identity.ownedCount > 0) owners += 1;
      if (identity.workplaceCount > 0) workplaces += 1;
      if (identity.ownedCount == 0 && identity.workplaceCount == 0) {
        general += 1;
      }
    }
    final List<({_MemberListFilter filter, String label, int count})> chips =
        <({_MemberListFilter filter, String label, int count})>[
          (filter: _MemberListFilter.all, label: '全部', count: docs.length),
          (filter: _MemberListFilter.general, label: '一般會員', count: general),
          (filter: _MemberListFilter.owner, label: '店主', count: owners),
          (
            filter: _MemberListFilter.workplace,
            label: '店員／店家身分',
            count: workplaces,
          ),
          (filter: _MemberListFilter.blocked, label: '已封鎖', count: blocked),
        ];
    final bool table = resultCount != null;
    final Widget chipList = SizedBox(
      height: table ? 36 : 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: table
            ? const EdgeInsets.only(top: 2)
            : const EdgeInsets.fromLTRB(16, 8, 16, 0),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final ({_MemberListFilter filter, String label, int count}) chip =
              chips[index];
          final bool selected = _filter == chip.filter;
          return FilterChip(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            label: Text('${chip.label} ${chip.count}'),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => setState(() => _filter = chip.filter),
          );
        },
      ),
    );
    if (!table) return chipList;
    return SizedBox(
      height: 40,
      child: Row(
        children: <Widget>[
          Expanded(child: chipList),
          const SizedBox(width: 12),
          Text(
            '共 $resultCount 位會員',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesQuery(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String query,
  ) {
    if (query.isEmpty) return true;
    final Map<String, dynamic> data = doc.data();
    final String name = (data['displayName'] ?? '').toString().toLowerCase();
    final String email = (data['email'] ?? '').toString().toLowerCase();
    return name.contains(query) ||
        email.contains(query) ||
        doc.id.toLowerCase().contains(query);
  }

  bool _matchesFilter(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    PlatformMemberShopIdentity? identity, {
    required bool identityReady,
    required bool identityFailed,
  }) {
    switch (_filter) {
      case _MemberListFilter.all:
        return true;
      case _MemberListFilter.blocked:
        return _memberStatus(doc.data()) == 'blocked';
      case _MemberListFilter.owner:
        if (!identityReady || identityFailed) return false;
        return (identity?.ownedCount ?? 0) > 0;
      case _MemberListFilter.workplace:
        if (!identityReady || identityFailed) return false;
        return (identity?.workplaceCount ?? 0) > 0;
      case _MemberListFilter.general:
        if (!identityReady || identityFailed) return false;
        final PlatformMemberShopIdentity resolved =
            identity ??
            const PlatformMemberShopIdentity(
              owned: <PlatformOwnedShopView>[],
              workplaces: <PlatformWorkplaceView>[],
            );
        return resolved.ownedCount == 0 && resolved.workplaceCount == 0;
    }
  }

  List<PlatformShopRecord> _shopRecords(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final List<PlatformShopRecord> shops = <PlatformShopRecord>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final PlatformShopRecord? shop = platformShopRecordFromDoc(doc);
      if (shop != null) shops.add(shop);
    }
    return shops;
  }

  List<PlatformShopMemberRecord> _memberRecords(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final List<PlatformShopMemberRecord> members = <PlatformShopMemberRecord>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final PlatformShopMemberRecord? member = platformShopMemberRecordFromDoc(
        doc,
      );
      if (member != null) members.add(member);
    }
    return members;
  }
}

class _DesktopFrame extends StatelessWidget {
  const _DesktopFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kMemberContentMaxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: child,
        ),
      ),
    );
  }
}

class _MemberTableHeader extends StatelessWidget {
  const _MemberTableHeader();

  static const TextStyle _style = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Color(0xFF6B7280),
  );

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 92,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: <Widget>[
                  Expanded(flex: 32, child: Text('會員', style: _style)),
                  Expanded(flex: 18, child: Text('店家身分', style: _style)),
                  Expanded(flex: 14, child: Text('最後登入', style: _style)),
                  Expanded(flex: 14, child: Text('加入日期', style: _style)),
                  Expanded(flex: 14, child: Text('UID', style: _style)),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 8,
            child: Padding(
              padding: EdgeInsets.only(right: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('操作', style: _style),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.doc,
    required this.desktop,
    required this.identity,
    required this.identityReady,
    required this.identityFailed,
    required this.statusLabel,
    required this.statusColor,
  });

  final bool desktop;

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final PlatformMemberShopIdentity? identity;
  final bool identityReady;
  final bool identityFailed;
  final String Function(String status) statusLabel;
  final Color Function(String status) statusColor;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data = doc.data();
    final String email = _textOr(data['email'], '未設定 Email');
    final String displayName = _textOr(data['displayName'], '未設定名稱');
    final String status =
        data['platformStatus']?.toString().trim().isNotEmpty == true
        ? data['platformStatus'].toString()
        : 'active';
    final bool blocked = status == 'blocked';
    final String joined = formatPlatformMemberDate(data['createdAt']);
    final String lastLogin = formatPlatformMemberDate(data['lastLoginAt']);
    final String? shopLabel = _shopLabel();
    if (desktop) {
      return Material(
        color: Colors.white,
        elevation: 0.4,
        shadowColor: const Color(0x14000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE7ECF2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 72,
          child: _desktopRow(
            displayName: displayName,
            email: email,
            status: status,
            blocked: blocked,
            joined: joined,
            lastLogin: lastLogin,
            shopLabel: shopLabel,
            onOpen: () {
              openPlatformMemberAccountDetail(context, uid: doc.id, data: data);
            },
          ),
        ),
      );
    }
    return Material(
      color: blocked ? const Color(0xFFFFFBFB) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: blocked ? const Color(0xFFFECACA) : const Color(0xFFE5E7EB),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          openPlatformMemberAccountDetail(context, uid: doc.id, data: data);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: _mobileBody(
            displayName: displayName,
            email: email,
            status: status,
            lastLogin: lastLogin,
            joined: joined,
            shopLabel: shopLabel,
          ),
        ),
      ),
    );
  }

  Widget _desktopRow({
    required String displayName,
    required String email,
    required String status,
    required bool blocked,
    required String joined,
    required String lastLogin,
    required String? shopLabel,
    required VoidCallback onOpen,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 92,
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: 32,
                    child: _memberIdentity(
                      displayName: displayName,
                      email: email,
                      status: status,
                    ),
                  ),
                  Expanded(
                    flex: 18,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _SummaryChip(label: shopLabel ?? '—'),
                    ),
                  ),
                  Expanded(flex: 14, child: _dateCell(Icons.login, lastLogin)),
                  Expanded(
                    flex: 14,
                    child: _dateCell(Icons.event_available_outlined, joined),
                  ),
                  Expanded(
                    flex: 14,
                    child: Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            _shortUid(doc.id),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                        _CopyUidButton(uid: doc.id),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 8,
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: _keepMemberNoteAction,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text('備註'),
                ),
                PopupMenuButton<String>(
                  tooltip: blocked ? '解除封鎖' : '封鎖',
                  padding: EdgeInsets.zero,
                  child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(Icons.more_horiz, size: 20),
                  ),
                  onSelected: (String value) {
                    if (value == 'block') _keepMemberBlockAction();
                  },
                  itemBuilder: (BuildContext context) {
                    return <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'block',
                        child: Text(
                          blocked ? '解除封鎖' : '封鎖',
                          style: const TextStyle(color: Color(0xFFDC2626)),
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _memberIdentity({
    required String displayName,
    required String email,
    required String status,
  }) {
    return Row(
      children: <Widget>[
        _Avatar(name: displayName),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _StatusBadge(
                    label: statusLabel(status),
                    color: statusColor(status),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dateCell(IconData icon, String value) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 13, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
          ),
        ),
      ],
    );
  }

  Widget _mobileBody({
    required String displayName,
    required String email,
    required String status,
    required String lastLogin,
    required String joined,
    required String? shopLabel,
  }) {
    final List<String> chips = <String>[
      ?shopLabel,
      '最後登入：$lastLogin',
      if (shopLabel == null) '加入：$joined',
    ];
    return Row(
      children: <Widget>[
        _Avatar(name: displayName, radius: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(
                    label: statusLabel(status),
                    color: statusColor(status),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: <Widget>[
                  for (final String chip in chips.take(2))
                    _SummaryChip(label: chip),
                ],
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
      ],
    );
  }

  String? _shopLabel() {
    if (identityFailed) return '身分資料暫時無法讀取';
    if (!identityReady || identity == null) return null;
    final int owned = identity!.ownedCount;
    final int workplaces = identity!.workplaceCount;
    if (owned > 0 && workplaces > 0) {
      return '店家身分・${owned + workplaces} 間';
    }
    if (owned > 0) return '店主・$owned 間店';
    if (workplaces > 0) return '店家身分・$workplaces 間';
    return null;
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.radius = 16});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final String letter = name == '未設定名稱' || name.isEmpty
        ? '?'
        : name.substring(0, 1);
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFEAF3FF),
      child: Text(
        letter,
        style: TextStyle(
          color: const Color(0xFF1565C0),
          fontWeight: FontWeight.w800,
          fontSize: radius > 16 ? 14 : 12,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4B5563),
        ),
      ),
    );
  }
}

class _CopyUidButton extends StatelessWidget {
  const _CopyUidButton({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '複製 UID',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: uid));
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已複製')));
      },
      icon: const Icon(Icons.copy, size: 14, color: Color(0xFF6B7280)),
    );
  }
}

String _shortUid(String uid) {
  if (uid.length <= 10) return uid;
  return '${uid.substring(0, 4)}…${uid.substring(uid.length - 4)}';
}

String _textOr(Object? value, String fallback) {
  final String text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

void _keepMemberNoteAction() {}

void _keepMemberBlockAction() {}

class _OwnerAccountRepairButton extends StatefulWidget {
  const _OwnerAccountRepairButton({this.compact = false});

  final bool compact;

  @override
  State<_OwnerAccountRepairButton> createState() =>
      _OwnerAccountRepairButtonState();
}

class _OwnerAccountRepairButtonState extends State<_OwnerAccountRepairButton> {
  bool _busy = false;

  Future<void> _check() async {
    if (_busy || !mounted) return;
    if (!PlatformRootAdmin.isRoot(FirebaseAuth.instance.currentUser?.uid)) {
      return;
    }
    setState(() => _busy = true);
    try {
      final OwnerPlatformMemberScan scan =
          await PlatformMemberReconciliationService.instance
              .findMissingOwnerPlatformMembers();
      if (!mounted) return;
      if (scan.isClear) {
        await _showNotice(context, '目前所有店主帳號都已存在於平台會員管理');
        return;
      }
      final String? message = await showDialog<String>(
        context: context,
        builder: (_) => _MissingOwnerRepairDialog(scan: scan),
      );
      if (!mounted || message == null || message.isEmpty) return;
      await _showNotice(context, message);
    } catch (error) {
      if (!mounted) return;
      await _showNotice(context, '檢查失敗：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget spinner = const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
    if (widget.compact) {
      return IconButton(
        tooltip: '篩查店主帳號遺漏',
        onPressed: _busy ? null : _check,
        icon: _busy ? spinner : const Icon(Icons.manage_search),
      );
    }
    return OutlinedButton(
      onPressed: _busy ? null : _check,
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(36, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: _busy
          ? spinner
          : const Text('篩查店主帳號遺漏', style: TextStyle(fontSize: 13)),
    );
  }
}

Future<void> _showNotice(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('關閉'),
          ),
        ],
      );
    },
  );
}

class _MissingOwnerRepairDialog extends StatefulWidget {
  const _MissingOwnerRepairDialog({required this.scan});

  final OwnerPlatformMemberScan scan;

  @override
  State<_MissingOwnerRepairDialog> createState() =>
      _MissingOwnerRepairDialogState();
}

class _MissingOwnerRepairDialogState extends State<_MissingOwnerRepairDialog> {
  late List<MissingOwnerPlatformMember> _missing;
  late List<MissingOwnerPlatformMember> _incomplete;
  bool _repairing = false;
  int _created = 0;
  int _completed = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _missing = List<MissingOwnerPlatformMember>.of(widget.scan.missing);
    _incomplete = List<MissingOwnerPlatformMember>.of(widget.scan.incomplete);
  }

  String _summary() {
    final StringBuffer message = StringBuffer();
    if (_created > 0) {
      message.write('已建立 $_created 筆平台會員。');
    }
    if (_completed > 0) {
      message.write('已補齊 $_completed 筆不完整資料。');
    }
    return message.toString();
  }

  Future<void> _repairMissing(List<MissingOwnerPlatformMember> targets) async {
    if (_repairing || targets.isEmpty) return;
    if (!PlatformRootAdmin.isRoot(FirebaseAuth.instance.currentUser?.uid)) {
      return;
    }
    setState(() {
      _repairing = true;
      _error = null;
    });
    try {
      final PlatformMemberRepairResult result =
          await PlatformMemberReconciliationService.instance
              .repairMissingOwnerPlatformMembers(targets);
      if (!mounted) return;
      final Set<String> done = targets
          .map((MissingOwnerPlatformMember item) => item.ownerUid)
          .toSet();
      setState(() {
        _created += result.repairedCount;
        _missing.removeWhere(
          (MissingOwnerPlatformMember item) => done.contains(item.ownerUid),
        );
        _repairing = false;
      });
      if (_missing.isEmpty && _incomplete.isEmpty) {
        Navigator.pop(context, _summary());
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _repairing = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _completeIncomplete(
    List<MissingOwnerPlatformMember> targets,
  ) async {
    if (_repairing || targets.isEmpty) return;
    if (!PlatformRootAdmin.isRoot(FirebaseAuth.instance.currentUser?.uid)) {
      return;
    }
    setState(() {
      _repairing = true;
      _error = null;
    });
    try {
      final PlatformMemberCompleteResult result =
          await PlatformMemberReconciliationService.instance
              .completeIncompleteOwnerPlatformMembers(targets);
      if (!mounted) return;
      final Set<String> done = targets
          .map((MissingOwnerPlatformMember item) => item.ownerUid)
          .toSet();
      setState(() {
        _completed += result.completedCount;
        _incomplete.removeWhere(
          (MissingOwnerPlatformMember item) => done.contains(item.ownerUid),
        );
        _repairing = false;
      });
      if (_missing.isEmpty && _incomplete.isEmpty) {
        Navigator.pop(context, _summary());
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _repairing = false;
        _error = error.toString();
      });
    }
  }

  void _close() {
    if (_created == 0 && _completed == 0) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context, _summary());
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool compact = screenWidth < 600;
    final double inset = compact ? 16 : 40;
    final double width = (screenWidth - inset * 2 - 48)
        .clamp(220, 452)
        .toDouble();
    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(horizontal: inset, vertical: 24),
      title: const Text('店主帳號檢查'),
      content: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              '只建立缺少的 users 文件，或補上既有文件缺少的欄位。不會覆蓋原有資料，也不修改店主、店家權限、訂單或付款。',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            if (_missing.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                '缺少平台會員 ${_missing.length} 人',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _OwnerIssueList(
                items: _missing,
                repairing: _repairing,
                actionLabel: '修復',
                onAction: (MissingOwnerPlatformMember item) {
                  _repairMissing(<MissingOwnerPlatformMember>[item]);
                },
              ),
            ],
            if (_incomplete.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                '發現 ${_incomplete.length} 筆店主平台會員資料不完整',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _OwnerIssueList(
                items: _incomplete,
                repairing: _repairing,
                actionLabel: '補齊資料',
                showMissingFields: true,
                onAction: (MissingOwnerPlatformMember item) {
                  _completeIncomplete(<MissingOwnerPlatformMember>[item]);
                },
              ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _repairing ? null : _close,
          child: const Text('取消'),
        ),
        if (_incomplete.isNotEmpty)
          FilledButton(
            onPressed: _repairing
                ? null
                : () => _completeIncomplete(_incomplete),
            child: Text(_repairing ? '處理中…' : '補齊資料'),
          ),
        if (_missing.isNotEmpty)
          FilledButton(
            onPressed: _repairing ? null : () => _repairMissing(_missing),
            child: Text(_repairing ? '處理中…' : '修復全部'),
          ),
      ],
    );
  }
}

class _OwnerIssueList extends StatelessWidget {
  const _OwnerIssueList({
    required this.items,
    required this.repairing,
    required this.actionLabel,
    required this.onAction,
    this.showMissingFields = false,
  });

  final List<MissingOwnerPlatformMember> items;
  final bool repairing;
  final String actionLabel;
  final ValueChanged<MissingOwnerPlatformMember> onAction;
  final bool showMissingFields;

  @override
  Widget build(BuildContext context) {
    final double listHeight = (items.length * 148.0).clamp(120.0, 280.0);
    return SizedBox(
      height: listHeight,
      child: ListView.separated(
        primary: false,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (BuildContext context, int index) {
          final MissingOwnerPlatformMember item = items[index];
          return _MissingOwnerTile(
            item: item,
            repairing: repairing,
            actionLabel: actionLabel,
            showMissingFields: showMissingFields,
            onAction: () => onAction(item),
          );
        },
      ),
    );
  }
}

class _MissingOwnerTile extends StatelessWidget {
  const _MissingOwnerTile({
    required this.item,
    required this.repairing,
    required this.actionLabel,
    required this.onAction,
    required this.showMissingFields,
  });

  final MissingOwnerPlatformMember item;
  final bool repairing;
  final String actionLabel;
  final VoidCallback onAction;
  final bool showMissingFields;

  @override
  Widget build(BuildContext context) {
    final String email = item.email.trim().isEmpty
        ? '未取得 Email'
        : item.email.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: showMissingFields
            ? const Color(0xFFFFFBF5)
            : const Color(0xFFF3F8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: showMissingFields
              ? const Color(0xFFFDE68A)
              : const Color(0xFFBFDBFE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            item.displayName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            email,
            style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
          ),
          SelectableText(
            'UID：${item.ownerUid}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 4),
          for (final MissingOwnerShop shop in item.shops)
            Text(
              '${shop.shopName}（${shop.shopId}）',
              style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
            ),
          if (showMissingFields && item.missingFields.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              '缺少：${item.missingFields.join('、')}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB45309),
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: repairing ? null : onAction,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
