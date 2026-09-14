// 檔案名稱：lib/features/shop/pages/shop_policy_logs_page.dart
// 功能說明：條款同意紀錄（住宿／安親分頁，批次解析會員，不顯示 UID）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/services/shop_policy_history.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';
import 'package:petnest_saas/features/shop/pages/policy_version_detail_page.dart';

class ShopPolicyLogsPage extends StatefulWidget {
  const ShopPolicyLogsPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopPolicyLogsPage> createState() => _ShopPolicyLogsPageState();
}

class _ShopPolicyLogsPageState extends State<ShopPolicyLogsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = true;
  String? _loadError;
  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];
  String _search = '';
  int? _stayCurrentVersion;
  int? _daycareCurrentVersion;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final List<Map<String, dynamic>> data = await ShopPolicyService.instance
          .getPolicyAcceptances(widget.shopId);
      final Map<String, dynamic>? policy = await ShopPolicyService.instance
          .getCheckinPolicy(widget.shopId);
      data.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        return _ts(b['acceptedAt']).compareTo(_ts(a['acceptedAt']));
      });
      if (!mounted) {
        return;
      }
      setState(() {
        _rows = data;
        _stayCurrentVersion = policy == null
            ? null
            : ShopPolicyService.servicePolicyVersion(
                policy: policy,
                serviceType: PolicyApplicableService.accommodation,
              );
        _daycareCurrentVersion = policy == null
            ? null
            : ShopPolicyService.servicePolicyVersion(
                policy: policy,
                serviceType: PolicyApplicableService.daycare,
              );
        _loading = false;
        _loadError = null;
      });
    } catch (error, stack) {
      debugPrint(error.toString());
      debugPrint(stack.toString());
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _loadError = '條款紀錄讀取失敗';
      });
    }
  }

  DateTime _ts(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatTime(dynamic ts) {
    if (ts == null) {
      return '-';
    }
    final DateTime dt = _ts(ts);
    if (dt.millisecondsSinceEpoch == 0) {
      return '-';
    }
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  List<Map<String, dynamic>> _filtered(String serviceType) {
    final String keyword = _search.trim().toLowerCase();
    return _rows.where((Map<String, dynamic> item) {
      final String type = (item['serviceType'] ?? '').toString();
      if (type != serviceType && type != ShopPolicyHistory.unknownService) {
        return false;
      }
      if (keyword.isEmpty) {
        return true;
      }
      final String name = (item['customerName'] ?? '').toString().toLowerCase();
      final String email = (item['email'] ?? '').toString().toLowerCase();
      final String phone = (item['customerPhone'] ?? '')
          .toString()
          .toLowerCase();
      final String code = (item['bookingCode'] ?? '').toString().toLowerCase();
      return name.contains(keyword) ||
          email.contains(keyword) ||
          phone.contains(keyword) ||
          code.contains(keyword);
    }).toList();
  }

  Future<void> _openVersion({
    required String serviceType,
    required int version,
  }) async {
    final Map<String, dynamic> data = await ShopPolicyService.instance
        .loadPolicyVersionSnapshot(
          shopId: widget.shopId,
          serviceType: serviceType,
          version: version,
        );
    if (!mounted) {
      return;
    }
    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ShopPolicyHistory.notFoundMessage(serviceType))),
      );
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PolicyVersionDetailPage(
          data: data,
          serviceType: serviceType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('條款同意紀錄'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const <Widget>[
            Tab(text: '住宿條款同意'),
            Tab(text: '安親條款同意'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(_loadError!),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _loadError = null;
                        });
                        _load();
                      },
                      child: const Text('重新載入'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: '搜尋姓名、email 或電話',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (String value) {
                      setState(() => _search = value);
                    },
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: <Widget>[
                      _list(
                        serviceType: PolicyApplicableService.accommodation,
                        emptyText: '目前沒有住宿條款同意紀錄',
                        currentVersion: _stayCurrentVersion,
                      ),
                      _list(
                        serviceType: PolicyApplicableService.daycare,
                        emptyText: '目前沒有安親條款同意紀錄',
                        currentVersion: _daycareCurrentVersion,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _list({
    required String serviceType,
    required String emptyText,
    required int? currentVersion,
  }) {
    final List<Map<String, dynamic>> items = _filtered(serviceType);
    if (items.isEmpty) {
      return Center(child: Text(emptyText));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        final Map<String, dynamic> item = items[index];
        final bool memberExists = item['memberExists'] == true;
        final String name = (item['customerName'] ?? '').toString().trim();
        final String email = (item['email'] ?? '').toString().trim();
        final String phone = (item['customerPhone'] ?? '').toString().trim();
        final int version = (item['acceptedVersion'] as num?)?.toInt() ?? 0;
        final bool current =
            currentVersion != null &&
            currentVersion > 0 &&
            version == currentVersion;
        return Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  memberExists && name.isNotEmpty
                      ? name
                      : (name.isNotEmpty ? name : '未填客戶姓名'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(email.isEmpty ? '未提供 email' : email),
                Text('電話：${phone.isEmpty ? '未提供' : phone}'),
                Text(
                  '訂單編號：${(item['bookingCode'] ?? '').toString().trim().isEmpty ? '-' : item['bookingCode']}',
                ),
                Text(
                  '服務類型：${(item['serviceLabel'] ?? (serviceType == PolicyApplicableService.daycare ? '安親' : '住宿')).toString()}',
                ),
                Text(
                  '條款名稱：${(item['policyTitle'] ?? '').toString().trim().isEmpty ? '-' : item['policyTitle']}',
                ),
                const SizedBox(height: 8),
                Text('條款版本：v$version'),
                Text('同意時間：${_formatTime(item['acceptedAt'])}'),
                Text(current ? '目前有效版本' : '非目前有效版本'),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      if ((item['serviceType'] ?? '').toString() ==
                          ShopPolicyHistory.unknownService) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('舊資料待確認，無法判斷服務類型')),
                        );
                        return;
                      }
                      _openVersion(serviceType: serviceType, version: version);
                    },
                    child: const Text('查看當時條款'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
