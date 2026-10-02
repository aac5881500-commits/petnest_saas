import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/features/platform/models/platform_member_shop_identity.dart';
import 'package:petnest_saas/features/platform/widgets/platform_member_policy_status.dart';

const double _kMemberDetailDesktopWidth = 900;

Future<void> openPlatformMemberAccountDetail(
  BuildContext context, {
  required String uid,
  required Map<String, dynamic> data,
}) {
  final Map<String, dynamic> account = Map<String, dynamic>.from(data);
  if (MediaQuery.sizeOf(context).width >= _kMemberDetailDesktopWidth) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final Size size = MediaQuery.sizeOf(dialogContext);
        final double width = (size.width - 48).clamp(320.0, 720.0);
        final double height = (size.height - 48).clamp(420.0, 680.0);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: PlatformMemberAccountDetail(
              uid: uid,
              data: account,
              showClose: true,
            ),
          ),
        );
      },
    );
  }
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => PlatformMemberAccountDetailPage(uid: uid, data: account),
    ),
  );
}

class PlatformMemberAccountDetailPage extends StatelessWidget {
  const PlatformMemberAccountDetailPage({
    super.key,
    required this.uid,
    required this.data,
  });

  final String uid;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final String name = _accountName(data);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: Text(name)),
      body: PlatformMemberAccountDetail(uid: uid, data: data),
    );
  }
}

class PlatformMemberAccountDetail extends StatelessWidget {
  const PlatformMemberAccountDetail({
    super.key,
    required this.uid,
    required this.data,
    this.showClose = false,
  });

  final String uid;
  final Map<String, dynamic> data;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    final String name = _accountName(data);
    final String status = _platformStatus(data);
    final String note = data['platformNote']?.toString().trim() ?? '';
    final bool blocked = status == 'blocked';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        Row(
          children: <Widget>[
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFEAF3FF),
              child: Text(
                name == '未設定名稱' ? '?' : name.substring(0, 1),
                style: const TextStyle(
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _accountEmail(data),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            Text(
              platformAccountStatusLabel(status),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (showClose)
              IconButton(
                tooltip: '關閉',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _UidRow(uid: uid),
        _DetailRow(
          label: '平台角色',
          value: platformAccountRoleLabel(uid: uid, user: data),
        ),
        const _SectionTitle('使用摘要'),
        const SizedBox(height: 8),
        _DetailRow(
          label: '加入日期',
          value: formatPlatformMemberDate(data['createdAt']),
        ),
        _DetailRow(
          label: '最後登入',
          value: formatPlatformMemberDate(data['lastLoginAt']),
        ),
        _DetailRow(
          label: '最後更新',
          value: formatPlatformMemberDate(data['updatedAt']),
        ),
        const _SectionTitle('店家身分'),
        const SizedBox(height: 8),
        _ShopIdentityTab(uid: uid),
        const SizedBox(height: 16),
        PlatformMemberPolicyStatus(uid: uid, userData: data),
        const SizedBox(height: 8),
        const _SectionTitle('平台備註'),
        const SizedBox(height: 8),
        Text(
          note.isEmpty ? '尚未填寫' : note,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _keepExistingNoteAction,
            icon: const Icon(Icons.edit_note, size: 18),
            label: const Text('備註'),
          ),
        ),
        const _SectionTitle('帳號操作'),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _keepExistingBlockAction,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
            ),
            icon: Icon(
              blocked ? Icons.check_circle_outline : Icons.block,
              size: 18,
            ),
            label: Text(blocked ? '解除封鎖' : '封鎖'),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '平台操作紀錄將在後續提供',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
        ),
      ],
    );
  }
}

void _keepExistingNoteAction() {}

void _keepExistingBlockAction() {}

class _ShopIdentityTab extends StatefulWidget {
  const _ShopIdentityTab({required this.uid});

  final String uid;

  @override
  State<_ShopIdentityTab> createState() => _ShopIdentityTabState();
}

class _ShopIdentityTabState extends State<_ShopIdentityTab> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _shopsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _membersSub;
  List<PlatformShopRecord> _shops = const <PlatformShopRecord>[];
  List<PlatformShopMemberRecord> _members = const <PlatformShopMemberRecord>[];
  final Map<String, String> _shopNames = <String, String>{};
  bool _shopsReady = false;
  bool _membersReady = false;
  bool _shopsFailed = false;
  bool _membersFailed = false;
  int _nameRequest = 0;

  @override
  void initState() {
    super.initState();
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    _shopsSub = firestore
        .collection('shops')
        .where('ownerUid', isEqualTo: widget.uid)
        .snapshots()
        .listen(_onShops, onError: _onShopsFailed);
    _membersSub = firestore
        .collection('shop_members')
        .where('uid', isEqualTo: widget.uid)
        .snapshots()
        .listen(_onMembers, onError: _onMembersFailed);
  }

  void _onShopsFailed(Object _) {
    if (!mounted) return;
    setState(() {
      _shopsFailed = true;
      _shopsReady = true;
    });
  }

  void _onMembersFailed(Object _) {
    if (!mounted) return;
    setState(() {
      _membersFailed = true;
      _membersReady = true;
    });
  }

  void _onShops(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final List<PlatformShopRecord> shops = <PlatformShopRecord>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final PlatformShopRecord? shop = platformShopRecordFromDoc(doc);
      if (shop == null) continue;
      shops.add(shop);
      _shopNames[shop.shopId] = shop.name;
    }
    if (!mounted) return;
    setState(() {
      _shops = shops;
      _shopsReady = true;
    });
    _resolveWorkplaceNames();
  }

  void _onMembers(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final List<PlatformShopMemberRecord> members = <PlatformShopMemberRecord>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final PlatformShopMemberRecord? member = platformShopMemberRecordFromDoc(
        doc,
        fallbackUid: widget.uid,
      );
      if (member == null) continue;
      members.add(member);
    }
    if (!mounted) return;
    setState(() {
      _members = members;
      _membersReady = true;
    });
    _resolveWorkplaceNames();
  }

  Future<void> _resolveWorkplaceNames() async {
    final int request = ++_nameRequest;
    final Set<String> missing = <String>{
      for (final PlatformShopMemberRecord member in _members)
        if (member.shopId.isNotEmpty && !_shopNames.containsKey(member.shopId))
          member.shopId,
    };
    if (missing.isEmpty) return;
    try {
      for (final String shopId in missing) {
        final DocumentSnapshot<Map<String, dynamic>> snap =
            await FirebaseFirestore.instance
                .collection('shops')
                .doc(shopId)
                .get();
        final String name = snap.data()?['name']?.toString().trim() ?? '';
        _shopNames[shopId] = name.isEmpty ? '未命名店家' : name;
      }
    } catch (_) {
      for (final String shopId in missing) {
        _shopNames.putIfAbsent(shopId, () => '未命名店家');
      }
    }
    if (!mounted || request != _nameRequest) return;
    setState(() {});
  }

  @override
  void dispose() {
    _shopsSub?.cancel();
    _membersSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_shopsReady || !_membersReady) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final PlatformMemberShopIdentity identity =
        assemblePlatformMemberShopIdentity(
          uid: widget.uid,
          shops: _shopsFailed ? const <PlatformShopRecord>[] : _shops,
          members: _membersFailed
              ? const <PlatformShopMemberRecord>[]
              : _members,
          shopNamesById: _shopNames,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionTitle('擁有的店家'),
        const SizedBox(height: 8),
        if (_shopsFailed)
          const _EmptyLine('身分資料暫時無法讀取')
        else if (identity.owned.isEmpty)
          const _EmptyLine('目前沒有擁有的店家')
        else
          for (final PlatformOwnedShopView shop in identity.owned)
            _OwnedShopTile(shop: shop),
        const SizedBox(height: 16),
        const _SectionTitle('任職／受邀店家'),
        const SizedBox(height: 8),
        if (_membersFailed)
          const _EmptyLine('身分資料暫時無法讀取')
        else if (identity.workplaces.isEmpty)
          const _EmptyLine('目前沒有店家工作身分')
        else
          for (final PlatformWorkplaceView shop in identity.workplaces)
            _WorkplaceTile(shop: shop),
      ],
    );
  }
}

class _OwnedShopTile extends StatelessWidget {
  const _OwnedShopTile({required this.shop});

  final PlatformOwnedShopView shop;

  @override
  Widget build(BuildContext context) {
    return _ShopTile(
      name: shop.name,
      shopId: shop.shopId,
      lines: <String>['方案：${shop.planLabel}', '店家狀態：${shop.statusLabel}'],
      tag: '店主',
    );
  }
}

class _WorkplaceTile extends StatelessWidget {
  const _WorkplaceTile({required this.shop});

  final PlatformWorkplaceView shop;

  @override
  Widget build(BuildContext context) {
    return _ShopTile(name: shop.name, shopId: shop.shopId, tag: shop.roleLabel);
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({
    required this.name,
    required this.shopId,
    required this.tag,
    this.lines = const <String>[],
  });

  final String name;
  final String shopId;
  final String tag;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            shopId,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          for (final String line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(line, style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: Color(0xFF6B7280)));
  }
}

class _UidRow extends StatelessWidget {
  const _UidRow({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(
            width: 96,
            child: Text(
              'UID',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ),
          Expanded(
            child: SelectableText(
              uid,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: '複製 UID',
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: uid));
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已複製 UID')));
            },
            icon: const Icon(Icons.copy, size: 18),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

String formatPlatformMemberDate(dynamic value) {
  DateTime? date;
  if (value is Timestamp) {
    date = value.toDate();
  } else if (value is DateTime) {
    date = value;
  }
  if (date == null) return '尚未設定';
  String two(int number) => number.toString().padLeft(2, '0');
  return '${date.year}/${two(date.month)}/${two(date.day)}';
}

String _accountName(Map<String, dynamic> data) {
  final String name = data['displayName']?.toString().trim() ?? '';
  return name.isEmpty ? '未設定名稱' : name;
}

String _accountEmail(Map<String, dynamic> data) {
  final String email = data['email']?.toString().trim() ?? '';
  return email.isEmpty ? '未設定 Email' : email;
}

String _platformStatus(Map<String, dynamic> data) {
  final String platform = data['platformStatus']?.toString().trim() ?? '';
  if (platform.isNotEmpty) return platform;
  final String status = data['status']?.toString().trim() ?? '';
  if (status == 'active' || status == 'restricted' || status == 'blocked') {
    return status;
  }
  return 'active';
}

PlatformShopRecord? platformShopRecordFromDoc(
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
) {
  try {
    final Map<String, dynamic> data = doc.data();
    return PlatformShopRecord(
      shopId: doc.id,
      name: data['name']?.toString() ?? '',
      ownerUid: data['ownerUid']?.toString().trim() ?? '',
      plan: data['plan']?.toString() ?? '',
      status: data['status']?.toString() ?? '',
    );
  } catch (_) {
    return null;
  }
}

PlatformShopMemberRecord? platformShopMemberRecordFromDoc(
  QueryDocumentSnapshot<Map<String, dynamic>> doc, {
  String fallbackUid = '',
}) {
  try {
    final Map<String, dynamic> data = doc.data();
    final String uid = data['uid']?.toString().trim().isNotEmpty == true
        ? data['uid'].toString().trim()
        : fallbackUid.trim();
    if (uid.isEmpty) return null;
    final String fieldShopId = data['shopId']?.toString().trim() ?? '';
    final String suffix = '_$uid';
    final String shopId = fieldShopId.isNotEmpty
        ? fieldShopId
        : (doc.id.endsWith(suffix) && doc.id.length > suffix.length
              ? doc.id.substring(0, doc.id.length - suffix.length)
              : '');
    if (shopId.isEmpty) return null;
    return PlatformShopMemberRecord(
      shopId: shopId,
      uid: uid,
      role: data['role']?.toString() ?? '',
    );
  } catch (_) {
    return null;
  }
}
