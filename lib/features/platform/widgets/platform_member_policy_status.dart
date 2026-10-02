// 檔案名稱：lib/features/platform/widgets/platform_member_policy_status.dart
// 功能說明：會員詳情中的平台與店家條款確認狀態。只在詳情讀取，不掛在清單每一列。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/models/policy_confirmation_status.dart';
import 'package:petnest_saas/core/services/platform_policy_service.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';
import 'package:petnest_saas/features/shop/pages/policy_version_detail_page.dart';

class PlatformMemberPolicyStatus extends StatefulWidget {
  const PlatformMemberPolicyStatus({
    super.key,
    required this.uid,
    required this.userData,
  });

  final String uid;
  final Map<String, dynamic> userData;

  @override
  State<PlatformMemberPolicyStatus> createState() =>
      _PlatformMemberPolicyStatusState();
}

class _ShopPolicySummary {
  const _ShopPolicySummary({
    required this.shopId,
    required this.name,
    required this.stayVersion,
    required this.daycareVersion,
    required this.publishedAt,
    required this.policy,
  });

  final String shopId;
  final String name;
  final int stayVersion;
  final int daycareVersion;
  final DateTime? publishedAt;
  final Map<String, dynamic>? policy;

  bool get published => stayVersion > 0 || daycareVersion > 0;
}

class _PlatformMemberPolicyStatusState
    extends State<PlatformMemberPolicyStatus> {
  PlatformPolicyAcceptance? _platform;
  String? _platformError;
  bool _platformLoading = true;

  List<_ShopPolicySummary> _shops = const <_ShopPolicySummary>[];
  bool _shopRole = false;
  bool _shopsLoading = true;
  String? _shopsError;
  bool _customerLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPlatform();
    _loadShops();
  }

  Future<void> _loadPlatform() async {
    try {
      final PlatformPolicyAcceptance acceptance = await PlatformPolicyService
          .instance
          .loadAcceptance(uid: widget.uid, userData: widget.userData);
      if (!mounted) return;
      setState(() {
        _platform = acceptance;
        _platformLoading = false;
        _platformError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _platformLoading = false;
        _platformError = '平台條款狀態暫時無法讀取';
      });
    }
  }

  Future<void> _loadShops() async {
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final QuerySnapshot<Map<String, dynamic>> owned = await firestore
          .collection('shops')
          .where('ownerUid', isEqualTo: widget.uid)
          .get();
      final QuerySnapshot<Map<String, dynamic>> members = await firestore
          .collection('shop_members')
          .where('uid', isEqualTo: widget.uid)
          .get();
      final Map<String, String> names = <String, String>{};
      final Set<String> ids = <String>{};
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in owned.docs) {
        ids.add(doc.id);
        final String name = (doc.data()['name'] ?? '').toString().trim();
        if (name.isNotEmpty) names[doc.id] = name;
      }
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in members.docs) {
        final String? shopId = _memberShopId(doc, widget.uid);
        if (shopId == null) continue;
        ids.add(shopId);
      }
      if (ids.isEmpty) {
        if (!mounted) return;
        setState(() {
          _shopRole = false;
          _shopsLoading = false;
        });
        return;
      }
      final List<String> missing = ids
          .where((String id) => (names[id] ?? '').isEmpty)
          .toList();
      if (missing.isNotEmpty) {
        final List<DocumentSnapshot<Map<String, dynamic>>> shops =
            await Future.wait(
              missing.map(
                (String id) => firestore.collection('shops').doc(id).get(),
              ),
            );
        for (final DocumentSnapshot<Map<String, dynamic>> shop in shops) {
          final String name = (shop.data()?['name'] ?? '').toString().trim();
          names[shop.id] = name.isEmpty ? '店名無法讀取' : name;
        }
      }
      final List<_ShopPolicySummary> rows = await Future.wait(
        ids.map((String shopId) async {
          final Map<String, dynamic>? policy = await ShopPolicyService.instance
              .getCheckinPolicy(shopId);
          return _ShopPolicySummary(
            shopId: shopId,
            name: names[shopId] ?? '店名無法讀取',
            stayVersion: policy == null
                ? 0
                : ShopPolicyService.servicePolicyVersion(
                    policy: policy,
                    serviceType: PolicyApplicableService.accommodation,
                  ),
            daycareVersion: policy == null
                ? 0
                : ShopPolicyService.servicePolicyVersion(
                    policy: policy,
                    serviceType: PolicyApplicableService.daycare,
                  ),
            publishedAt: _date(policy?['updatedAt']),
            policy: policy,
          );
        }),
      );
      rows.sort(
        (_ShopPolicySummary a, _ShopPolicySummary b) =>
            a.name.compareTo(b.name),
      );
      if (!mounted) return;
      setState(() {
        _shopRole = true;
        _shops = rows;
        _shopsLoading = false;
        _shopsError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _shopsLoading = false;
        _shopsError = '店家條款狀態暫時無法讀取';
      });
    }
  }

  String? _memberShopId(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String uid,
  ) {
    final String fieldShopId = (doc.data()['shopId'] ?? '').toString().trim();
    if (fieldShopId.isNotEmpty) return fieldShopId;
    final String suffix = '_$uid';
    if (doc.id.endsWith(suffix) && doc.id.length > suffix.length) {
      return doc.id.substring(0, doc.id.length - suffix.length);
    }
    return null;
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _format(DateTime? date) {
    if (date == null) return '尚未記錄';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${date.year}/${two(date.month)}/${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  Future<void> _openText({
    required String title,
    required String meta,
    required String content,
  }) {
    final bool desktop = MediaQuery.sizeOf(context).width >= 900;
    final Widget body = ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(meta, style: const TextStyle(color: Color(0xFF6B7280))),
        const SizedBox(height: 12),
        Text(
          content.trim().isEmpty ? '此版本沒有內容' : content,
          style: const TextStyle(fontSize: 15, height: 1.7),
        ),
      ],
    );
    if (desktop) {
      return showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return Dialog(
            insetPadding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 560,
              height: 520,
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
          );
        },
      );
    }
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: body,
        ),
      ),
    );
  }

  Future<void> _viewLatest() async {
    final PlatformPolicyAcceptance? policy = _platform;
    if (policy == null) return;
    await _openText(
      title: '最新平台條款',
      meta: policy.publishedVersion <= 0
          ? '目前沒有已發布平台條款'
          : '版本 v${policy.publishedVersion}　發布日期 ${_format(policy.publishedAt)}',
      content: policy.content,
    );
  }

  Future<void> _viewAccepted() async {
    final PlatformPolicyAcceptance? policy = _platform;
    if (policy == null || policy.acceptedVersion <= 0) return;
    try {
      final Map<String, dynamic>? data = await PlatformPolicyService.instance
          .loadPublishedVersion(policy.acceptedVersion);
      if (!mounted) return;
      await _openText(
        title: '會員當時確認版本',
        meta: '版本 v${policy.acceptedVersion}',
        content: (data?['content'] ?? '').toString(),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('當時版本暫時無法讀取')));
    }
  }

  Future<void> _openCustomerAcceptances() async {
    setState(() => _customerLoading = true);
    try {
      final QuerySnapshot<Map<String, dynamic>> snap = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(widget.uid)
          .collection('policy_acceptances')
          .get();
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = snap.docs
          .where(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                !doc.id.startsWith('platform_user_policy'),
          )
          .toList();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('已同意的店家條款'),
            content: SizedBox(
              width: 420,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: docs.isEmpty
                    ? const Text('尚無紀錄')
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: docs.length,
                        separatorBuilder: (_, _) => const Divider(height: 16),
                        itemBuilder: (BuildContext context, int index) {
                          final QueryDocumentSnapshot<Map<String, dynamic>>
                          doc = docs[index];
                          return _CustomerAcceptanceTile(
                            shopId: doc.id,
                            data: doc.data(),
                          );
                        },
                      ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('關閉'),
              ),
            ],
          );
        },
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('店家條款同意紀錄暫時無法讀取')));
    } finally {
      if (mounted) setState(() => _customerLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          '條款確認狀態',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        _platformCard(),
        const SizedBox(height: 8),
        _shopCard(),
      ],
    );
  }

  Widget _platformCard() {
    if (_platformLoading) {
      return const _InfoCard(
        child: Text('平台條款讀取中', style: TextStyle(color: Color(0xFF6B7280))),
      );
    }
    if (_platformError != null) {
      return _InfoCard(child: Text(_platformError!));
    }
    final PlatformPolicyAcceptance policy = _platform!;
    final String accepted = policy.acceptedVersion <= 0
        ? '尚未確認'
        : 'v${policy.acceptedVersion}';
    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '平台條款',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _StatusBadge(state: policy.state),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '最新版本：${policy.publishedVersion <= 0 ? '尚未發布' : 'v${policy.publishedVersion}'}',
          ),
          Text('已確認版本：$accepted'),
          Text('確認時間：${_format(policy.acceptedAt)}'),
          Text('最新發布時間：${_format(policy.publishedAt)}'),
          Wrap(
            spacing: 4,
            children: <Widget>[
              TextButton(
                onPressed: policy.publishedVersion <= 0 ? null : _viewLatest,
                child: const Text('查看最新平台條款'),
              ),
              if (policy.acceptedVersion > 0 &&
                  policy.acceptedVersion != policy.publishedVersion)
                TextButton(
                  onPressed: _viewAccepted,
                  child: const Text('查看會員當時確認版本'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shopCard() {
    if (_shopsLoading) {
      return const _InfoCard(
        child: Text('店家條款讀取中', style: TextStyle(color: Color(0xFF6B7280))),
      );
    }
    if (_shopsError != null) {
      return _InfoCard(child: Text(_shopsError!));
    }
    if (!_shopRole) {
      return _InfoCard(
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _customerLoading ? null : _openCustomerAcceptances,
            child: _customerLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('查看已同意的店家條款'),
          ),
        ),
      );
    }
    if (_shops.isEmpty) {
      return const _InfoCard(child: Text('尚無紀錄'));
    }
    return Column(
      children: _shops.map((_ShopPolicySummary shop) {
        final String version =
            shop.daycareVersion > 0 && shop.daycareVersion != shop.stayVersion
            ? '住宿 v${shop.stayVersion}・安親 v${shop.daycareVersion}'
            : (shop.stayVersion > 0 ? 'v${shop.stayVersion}' : '尚未發布');
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  shop.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text('目前版本：$version'),
                Text(shop.published ? '目前狀態：生效中' : '目前狀態：尚未發布'),
                Text('最新發布時間：${_format(shop.publishedAt)}'),
                if (shop.policy != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PolicyVersionDetailPage(
                              data: shop.policy!,
                              serviceType:
                                  PolicyApplicableService.accommodation,
                            ),
                          ),
                        );
                      },
                      child: const Text('查看目前版本'),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CustomerAcceptanceTile extends StatefulWidget {
  const _CustomerAcceptanceTile({required this.shopId, required this.data});

  final String shopId;
  final Map<String, dynamic> data;

  @override
  State<_CustomerAcceptanceTile> createState() =>
      _CustomerAcceptanceTileState();
}

class _CustomerAcceptanceTileState extends State<_CustomerAcceptanceTile> {
  String _name = '店名讀取中';
  String _status = '尚無紀錄';
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> shop =
          await FirebaseFirestore.instance
              .collection('shops')
              .doc(widget.shopId)
              .get();
      final Map<String, dynamic>? policy = await ShopPolicyService.instance
          .getCheckinPolicy(widget.shopId);
      final int latest = policy == null
          ? 0
          : ShopPolicyService.servicePolicyVersion(
              policy: policy,
              serviceType: PolicyApplicableService.accommodation,
            );
      final int accepted = parsePolicyConfirmationVersion(
        widget.data['acceptedVersion'],
      );
      if (!mounted) return;
      setState(() {
        final String name = (shop.data()?['name'] ?? '').toString().trim();
        _name = name.isEmpty ? '店名無法讀取' : name;
        final PolicyConfirmationState state = resolvePolicyConfirmation(
          publishedVersion: latest,
          acceptedVersion: accepted,
        );
        _status = switch (state) {
          PolicyConfirmationState.current => '已確認最新版',
          PolicyConfirmationState.needsUpdate => '待確認更新',
          PolicyConfirmationState.notAccepted => '尚未確認',
          PolicyConfirmationState.noPublished => '尚無店家條款版本',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int accepted = parsePolicyConfirmationVersion(
      widget.data['acceptedVersion'],
    );
    if (_failed) {
      return const Text('此店條款狀態暫時無法讀取');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(_name, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text('已確認版本：${accepted <= 0 ? '尚未確認' : 'v$accepted'}'),
        Text(_status),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state});

  final PolicyConfirmationState state;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (state) {
      PolicyConfirmationState.current => const Color(0xFF166534),
      PolicyConfirmationState.needsUpdate => const Color(0xFF9A6700),
      PolicyConfirmationState.notAccepted ||
      PolicyConfirmationState.noPublished => const Color(0xFF6B7280),
    };
    final Color background = switch (state) {
      PolicyConfirmationState.current => const Color(0xFFECFDF3),
      PolicyConfirmationState.needsUpdate => const Color(0xFFFFFBEB),
      PolicyConfirmationState.notAccepted ||
      PolicyConfirmationState.noPublished => const Color(0xFFF3F4F6),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        policyConfirmationLabel(state),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
