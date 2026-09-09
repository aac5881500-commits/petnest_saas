// 檔案名稱：lib/features/shop/pages/shop_policy_page.dart
// 功能說明：條款設定：住宿／安親／退款分頁編輯，互不污染同意版本

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/policy_version_history_page.dart';

class ShopPolicyPage extends StatefulWidget {
  const ShopPolicyPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopPolicyPage> createState() => _ShopPolicyPageState();
}

class _ShopPolicyPageState extends State<ShopPolicyPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{
        'checkinTime': TextEditingController(),
        'checkOutFlow': TextEditingController(),
        'basicCondition': TextEditingController(),
        'ownerNotice': TextEditingController(),
        'checkinNotice': TextEditingController(),
        'facility': TextEditingController(),
        'specialCase': TextEditingController(),
        'activity': TextEditingController(),
        'extraNotice': TextEditingController(),
        'cancelPolicy': TextEditingController(),
      };
  Map<String, bool> _enabled = <String, bool>{
    'checkinTime': true,
    'checkOutFlow': true,
    'basicCondition': true,
    'ownerNotice': true,
    'checkinNotice': true,
    'facility': true,
    'specialCase': true,
    'activity': true,
    'extraNotice': true,
    'cancelPolicy': true,
  };
  final Map<String, Map<String, String>> _drafts =
      <String, Map<String, String>>{
        PolicyApplicableService.accommodation: <String, String>{},
        PolicyApplicableService.daycare: <String, String>{},
      };
  final Map<String, Map<String, bool>> _enabledDrafts =
      <String, Map<String, bool>>{
        PolicyApplicableService.accommodation: <String, bool>{},
        PolicyApplicableService.daycare: <String, bool>{},
      };
  final TextEditingController _refundTitle = TextEditingController(
    text: '退款條款',
  );
  final TextEditingController _refundDescription = TextEditingController();
  final TextEditingController _refundBody = TextEditingController();
  bool _refundEnabled = true;
  bool _loading = true;
  bool _dirty = false;
  int _stayVersion = 0;
  int _daycareVersion = 0;
  int _refundVersion = 0;
  final Set<String> _expanded = <String>{};

  String get _activeService => _tabs.index == 1
      ? PolicyApplicableService.daycare
      : PolicyApplicableService.accommodation;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) {
        _storeCurrentDraft();
      } else {
        if (_tabs.index != 2) {
          _restoreDraft(_activeService);
        }
        if (mounted) {
          setState(() {});
        }
      }
    });
    _loadPolicy();
  }

  @override
  void dispose() {
    for (final TextEditingController c in _controllers.values) {
      c.dispose();
    }
    _refundTitle.dispose();
    _refundDescription.dispose();
    _refundBody.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) {
      setState(() => _dirty = true);
    }
  }

  void _storeCurrentDraft() {
    final int from = _tabs.previousIndex;
    if (from == 2) {
      return;
    }
    final String service = from == 1
        ? PolicyApplicableService.daycare
        : PolicyApplicableService.accommodation;
    _drafts[service] = _controllers.map(
      (String key, TextEditingController ctrl) => MapEntry(key, ctrl.text),
    );
    _enabledDrafts[service] = Map<String, bool>.from(_enabled);
  }

  void _restoreDraft(String service) {
    final Map<String, String> draft = _drafts[service] ?? <String, String>{};
    _controllers.forEach((String key, TextEditingController ctrl) {
      ctrl.text = draft[key] ?? '';
    });
    _enabled = Map<String, bool>.from(_enabledDrafts[service] ?? _enabled);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadPolicy() async {
    final Map<String, dynamic>? data = await ShopService.instance
        .getCheckinPolicy(widget.shopId);
    if (data != null) {
      for (final String service in <String>[
        PolicyApplicableService.accommodation,
        PolicyApplicableService.daycare,
      ]) {
        final Map<String, dynamic> filtered = ShopPolicyService.instance
            .filterPolicyForService(policy: data, serviceType: service);
        final Map<String, dynamic> sections = Map<String, dynamic>.from(
          filtered['sections'] ?? <String, dynamic>{},
        );
        _drafts[service] = <String, String>{
          for (final String key in _controllers.keys)
            key: (sections[key] ?? '').toString(),
        };
        final Map<String, dynamic> enabled = Map<String, dynamic>.from(
          filtered['enabled'] ?? <String, dynamic>{},
        );
        _enabledDrafts[service] = <String, bool>{
          for (final String key in _controllers.keys)
            key: enabled[key] != false,
        };
      }
      _stayVersion = ShopPolicyService.servicePolicyVersion(
        policy: data,
        serviceType: PolicyApplicableService.accommodation,
      );
      _daycareVersion = ShopPolicyService.servicePolicyVersion(
        policy: data,
        serviceType: PolicyApplicableService.daycare,
      );
      _restoreDraft(PolicyApplicableService.accommodation);
    }
    final Map<String, dynamic>? refund = await ShopPolicyService.instance
        .getRefundPolicy(widget.shopId);
    if (refund != null) {
      _refundTitle.text = (refund['title'] ?? '退款條款').toString();
      _refundDescription.text = (refund['description'] ?? '').toString();
      _refundBody.text = (refund['body'] ?? '').toString();
      _refundEnabled = refund['enabled'] != false;
      _refundVersion =
          (refund['refundPolicyVersion'] as num?)?.toInt() ??
          (refund['version'] as num?)?.toInt() ??
          0;
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _dirty = false;
      });
    }
  }

  Future<void> _save() async {
    if (_tabs.index == 2) {
      await ShopPolicyService.instance.updateRefundPolicy(
        shopId: widget.shopId,
        title: _refundTitle.text,
        description: _refundDescription.text,
        body: _refundBody.text,
        enabled: _refundEnabled,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已更新退款條款')));
      await _loadPolicy();
      return;
    }
    _storeCurrentDraft();
    final Map<String, dynamic> sections = <String, dynamic>{
      for (final MapEntry<String, TextEditingController> e
          in _controllers.entries)
        e.key: e.value.text.trim(),
    };
    await ShopPolicyService.instance.updateServicePolicy(
      shopId: widget.shopId,
      serviceType: _activeService,
      sections: sections,
      enabled: _enabled,
      customPoliciesPage1: const <String>[],
      customPoliciesPage2: const <String>[],
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _activeService == PolicyApplicableService.daycare
              ? '已更新安親條款（住宿條款版本不變）'
              : '已更新住宿條款（安親條款版本不變）',
        ),
      ),
    );
    await _loadPolicy();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop || !_dirty) {
          return;
        }
        final bool? leave = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('尚未儲存'),
            content: const Text('離開此頁將捨棄未儲存的條款變更。'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('繼續編輯'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('離開'),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('條款設定'),
          bottom: TabBar(
            controller: _tabs,
            tabs: const <Widget>[
              Tab(text: '預約／入住條款'),
              Tab(text: '安親條款'),
              Tab(text: '退款條款'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    children: <Widget>[
                      Expanded(
                        child: TabBarView(
                          controller: _tabs,
                          children: <Widget>[
                            _serviceEditor(isDaycare: false),
                            _serviceEditor(isDaycare: true),
                            _refundEditor(),
                          ],
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              onPressed: _save,
                              child: Text(
                                _tabs.index == 2 ? '儲存退款條款' : '儲存此分頁條款',
                              ),
                            ),
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

  Widget _serviceEditor({required bool isDaycare}) {
    final int version = isDaycare ? _daycareVersion : _stayVersion;
    final List<List<String>> sections = <List<String>>[
      <String>['checkinTime', '營業時間與環境參觀時間'],
      <String>['checkOutFlow', isDaycare ? '送達與接回安排' : '入住與退房安排'],
      <String>['basicCondition', '貓咪基本條件'],
      <String>['ownerNotice', '飼主應告知資訊'],
      <String>['checkinNotice', isDaycare ? '安親須知' : '入住須知'],
      <String>['facility', '本店提供的基本設施'],
      <String>['specialCase', '特殊情況處理'],
      <String>['activity', '探索活動安排'],
      <String>['extraNotice', '額外注意事項'],
      <String>['cancelPolicy', '取消政策'],
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          isDaycare
              ? '目前安親條款版本：v$version。修改不會要求住宿客人重新勾選。'
              : '目前住宿條款版本：v$version。修改不會要求安親客人重新勾選。',
        ),
        Wrap(
          spacing: 8,
          children: <Widget>[
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PolicyVersionHistoryPage(shopId: widget.shopId),
                  ),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text('查看歷史版本'),
            ),
            TextButton(
              onPressed: () {
                final String other = isDaycare
                    ? PolicyApplicableService.accommodation
                    : PolicyApplicableService.daycare;
                _storeCurrentDraft();
                _drafts[other] = _controllers.map(
                  (String key, TextEditingController ctrl) =>
                      MapEntry(key, ctrl.text),
                );
                _enabledDrafts[other] = Map<String, bool>.from(_enabled);
                _markDirty();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isDaycare ? '已複製到住宿條款草稿' : '已複製到安親條款草稿'),
                  ),
                );
              },
              child: Text(isDaycare ? '複製到住宿條款' : '複製到安親條款'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...sections.map((List<String> item) {
          final String key = item.first;
          final String title = item.last;
          final bool open = _expanded.contains(key);
          final String preview = (_controllers[key]?.text ?? '').trim();
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Switch(
                        value: _enabled[key] ?? true,
                        onChanged: (bool value) {
                          setState(() {
                            _enabled[key] = value;
                            _dirty = true;
                          });
                        },
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (open) {
                              _expanded.remove(key);
                            } else {
                              _expanded.add(key);
                            }
                          });
                        },
                        child: Text(open ? '收合' : '編輯'),
                      ),
                    ],
                  ),
                  if (!open)
                    Text(
                      preview.isEmpty ? '尚未填寫' : preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    )
                  else
                    TextField(
                      controller: _controllers[key],
                      minLines: 4,
                      maxLines: 10,
                      onChanged: (_) => _markDirty(),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _refundEditor() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text('退款條款版本：v$_refundVersion（申請退款時閱讀，不參與預約勾選）'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('啟用退款條款'),
          value: _refundEnabled,
          onChanged: (bool value) {
            setState(() {
              _refundEnabled = value;
              _dirty = true;
            });
          },
        ),
        TextField(
          controller: _refundTitle,
          decoration: const InputDecoration(
            labelText: '標題',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _markDirty(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _refundDescription,
          decoration: const InputDecoration(
            labelText: '簡短說明',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _markDirty(),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () {
            setState(() {
              _refundBody.text = ShopPolicyService.refundTemplate();
              _dirty = true;
            });
          },
          child: const Text('一鍵套用退款模板'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _refundBody,
          minLines: 12,
          maxLines: 20,
          onChanged: (_) => _markDirty(),
          decoration: const InputDecoration(
            labelText: '退款規則內容',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
