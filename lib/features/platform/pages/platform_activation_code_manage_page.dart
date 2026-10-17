// 檔案名稱：lib/features/platform/pages/platform_activation_code_manage_page.dart
// 功能說明：建立與查詢創店激活碼。使用次數與權益由後端決定。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:petnest_saas/core/services/shop_commercial_service.dart';
import 'package:petnest_saas/features/platform/pages/platform_shop_manage_page.dart';

class PlatformActivationCodeManagePage extends StatefulWidget {
  const PlatformActivationCodeManagePage({
    super.key,
    this.initialSalesRepId = '',
  });

  final String initialSalesRepId;

  @override
  State<PlatformActivationCodeManagePage> createState() =>
      _PlatformActivationCodeManagePageState();
}

class _PlatformActivationCodeManagePageState
    extends State<PlatformActivationCodeManagePage> {
  final _search = TextEditingController();
  String _status = '';
  String _source = '';
  String _salesRepId = '';
  String? _selectedCodeId;
  List<Map<String, dynamic>> _reps = const [];
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;
  bool _permissionDenied = false;
  String _cursor = '';
  bool _migrationReady = true;

  @override
  void initState() {
    super.initState();
    _salesRepId = widget.initialSalesRepId;
    _loadReps();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadReps() async {
    try {
      final reps = await ShopCommercialService.instance.listSalesReps();
      if (!mounted) return;
      setState(() => _reps = reps);
    } on ShopCommercialException {
      // 沒有業務清單權限時，仍可管理激活碼，只是不能用業務篩選。
    }
  }

  Future<void> _migrate() async {
    var cursor = '';
    var guard = 0;
    try {
      while (guard < 40) {
        guard += 1;
        final data = await ShopCommercialService.instance.migrateActivationCodes(
          dryRun: false,
          cursor: cursor,
        );
        cursor = (data['nextCursor'] ?? '').toString();
        if (cursor.isEmpty) break;
      }
      if (!mounted) return;
      await _load();
    } on ShopCommercialException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      _permissionDenied = false;
    });
    try {
      final data = await ShopCommercialService.instance.listActivationCodes(
        query: _search.text.trim(),
        status: _status,
        source: _source,
        salesRepId: _salesRepId,
        cursor: more ? _cursor : '',
      );
      if (!mounted) return;
      final items = (data['items'] as List? ?? const [])
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
      setState(() {
        _items = more ? [..._items, ...items] : items;
        _cursor = (data['nextCursor'] ?? '').toString();
        _migrationReady = data['migrationReady'] != false;
        _loading = false;
      });
    } on ShopCommercialException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
        _permissionDenied = error.permissionDenied;
        if (!more) _items = const [];
      });
    }
  }

  Future<void> _create() async {
    final code = TextEditingController();
    final name = TextEditingController();
    final uses = TextEditingController(text: '1');
    final days = TextEditingController(text: '30');
    final campaign = TextEditingController();
    final deadline = TextEditingController();
    final note = TextEditingController();
    var moduleName = 'cat_hotel';
    var plan = 'free';
    var source = 'platform_direct';
    var repId = '';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('建立激活碼'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: '激活碼名稱'),
                    ),
                    TextField(
                      controller: code,
                      decoration: const InputDecoration(labelText: '激活碼'),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: moduleName,
                      decoration: const InputDecoration(labelText: '開通模板'),
                      items: const [
                        DropdownMenuItem(value: 'cat_hotel', child: Text('貓咪旅館')),
                        DropdownMenuItem(value: 'dog_hotel', child: Text('狗狗旅館')),
                        DropdownMenuItem(value: 'grooming', child: Text('寵物美容')),
                        DropdownMenuItem(value: 'hospital', child: Text('動物醫院')),
                        DropdownMenuItem(value: 'store', child: Text('寵物商城')),
                      ],
                      onChanged: (value) {
                        setLocal(() => moduleName = value ?? 'cat_hotel');
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: plan,
                      decoration: const InputDecoration(labelText: '方案'),
                      items: const [
                        DropdownMenuItem(value: 'free', child: Text('免費版')),
                        DropdownMenuItem(value: 'basic', child: Text('專業版')),
                        DropdownMenuItem(value: 'pro', child: Text('全模組')),
                      ],
                      onChanged: (value) => setLocal(() => plan = value ?? 'free'),
                    ),
                    TextField(
                      controller: uses,
                      decoration: const InputDecoration(labelText: '可使用次數'),
                    ),
                    TextField(
                      controller: days,
                      decoration: const InputDecoration(labelText: '試用天數'),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: source,
                      decoration: const InputDecoration(labelText: '來源'),
                      items: const [
                        DropdownMenuItem(value: 'platform_direct', child: Text('平台發放')),
                        DropdownMenuItem(value: 'sales', child: Text('業務專屬')),
                      ],
                      onChanged: (value) {
                        setLocal(() {
                          source = value ?? 'platform_direct';
                          if (source != 'sales') repId = '';
                        });
                      },
                    ),
                    if (source == 'sales')
                    DropdownButtonFormField<String>(
                      initialValue: _reps.any((rep) => rep['repId'] == repId)
                          ? repId
                          : '',
                      decoration: const InputDecoration(labelText: '所屬業務'),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('請選擇業務')),
                        ..._reps.where((rep) {
                          return rep['enabled'] != false &&
                              rep['bindingStatus'] != 'pending';
                        }).map((rep) {
                          return DropdownMenuItem(
                            value: '${rep['repId']}',
                            child: Text('${rep['displayName'] ?? ''}'),
                          );
                        }),
                      ],
                      onChanged: (value) => setLocal(() => repId = value ?? ''),
                    ),
                    TextField(
                      controller: campaign,
                      decoration: const InputDecoration(labelText: '活動／來源名稱'),
                    ),
                    TextField(
                      controller: deadline,
                      decoration: const InputDecoration(
                        labelText: '使用截止日',
                        hintText: 'YYYY-MM-DD，沒有就不填',
                      ),
                    ),
                    TextField(
                      controller: note,
                      decoration: const InputDecoration(labelText: '備註'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('建立'),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved == true) {
      if (source == 'sales' && repId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('業務專屬激活碼必須選擇已綁定的業務')),
          );
        }
      } else {
      try {
        await ShopCommercialService.instance.saveActivationCode({
          'code': code.text.trim(),
          'name': name.text.trim(),
          'module': moduleName,
          'plan': plan,
          'maxUses': int.tryParse(uses.text.trim()) ?? 1,
          'freeDays': int.tryParse(days.text.trim()) ?? 0,
          'shopSource': source,
          'salesRepId': source == 'sales' ? repId : '',
          'campaignName': campaign.text.trim(),
          'useByDate': deadline.text.trim(),
          'note': note.text.trim(),
          'enabled': true,
        });
        await _load();
      } on ShopCommercialException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message)),
          );
        }
      }
      }
    }
    code.dispose();
    name.dispose();
    uses.dispose();
    days.dispose();
    campaign.dispose();
    deadline.dispose();
    note.dispose();
  }

  String _repName(String repId) {
    for (final rep in _reps) {
      if (rep['repId'] == repId) return '${rep['displayName'] ?? ''}';
    }
    return repId.isEmpty ? '平台直客' : '業務';
  }

  Future<void> _usage(String codeId) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('使用紀錄'),
          content: SizedBox(
            width: 420,
            child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection('activation_codes')
                  .doc(codeId)
                  .collection('usage_logs')
                  .orderBy('usedAt', descending: true)
                  .limit(20)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Text('沒有權限或載入失敗');
                }
                final docs = snapshot.data?.docs ?? const [];
                if (docs.isEmpty) return const Text('查無使用紀錄');
                return ListView(
                  shrinkWrap: true,
                  children: docs.map((doc) {
                    final data = doc.data();
                    final shopId = (data['shopId'] ?? '').toString();
                    return ListTile(
                      title: Text((data['shopName'] ?? shopId).toString()),
                      subtitle: Text(
                        '${commercialSourceLabel('${data['shopSource']}')}'
                        '｜${data['campaignName'] ?? ''}',
                      ),
                      trailing: IconButton(
                        tooltip: '開啟店家',
                        onPressed: shopId.isEmpty
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PlatformShopManagePage(
                                      initialShopId: shopId,
                                    ),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.storefront_outlined),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('關閉'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('激活碼管理')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('新增激活碼'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: '搜尋名稱或代碼',
                    suffixIcon: IconButton(
                      onPressed: () => _load(),
                      icon: const Icon(Icons.search),
                    ),
                  ),
                  onSubmitted: (_) => _load(),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _migrate,
                    child: const Text('補齊舊激活碼欄位'),
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _source,
                  decoration: const InputDecoration(labelText: '來源'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('全部來源')),
                    DropdownMenuItem(value: 'platform', child: Text('平台發放')),
                    DropdownMenuItem(value: 'sales', child: Text('業務專屬')),
                  ],
                  onChanged: (value) {
                    setState(() => _source = value ?? '');
                    _load();
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: '狀態'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('全部狀態')),
                    DropdownMenuItem(value: 'active', child: Text('啟用中')),
                    DropdownMenuItem(value: 'disabled', child: Text('已停用')),
                    DropdownMenuItem(value: 'expired', child: Text('已到期')),
                    DropdownMenuItem(value: 'exhausted', child: Text('已用完')),
                  ],
                  onChanged: (value) {
                    setState(() => _status = value ?? '');
                    _load();
                  },
                ),
                if (_reps.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _salesRepId,
                    decoration: const InputDecoration(labelText: '業務'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('全部業務')),
                      ..._reps.map((rep) {
                        return DropdownMenuItem(
                          value: '${rep['repId']}',
                          child: Text('${rep['displayName'] ?? ''}'),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _salesRepId = value ?? '');
                      _load();
                    },
                  ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_permissionDenied) {
      return const Center(child: Text('沒有激活碼管理權限'));
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('重試')),
          ],
        ),
      );
    }
    if (_items.isEmpty && !_migrationReady) {
      return const Center(child: Text('舊激活碼尚未完成欄位遷移，目前不能判定沒有激活碼。'));
    }
    if (_items.isEmpty && _cursor.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('這一頁沒有符合的結果，後面還有資料。'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _load(more: true),
              child: const Text('繼續載入'),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) return const Center(child: Text('查無激活碼'));
    return LayoutBuilder(
      builder: (context, constraints) {
        final list = ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length + (_cursor.isEmpty ? 0 : 1),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return OutlinedButton(
            onPressed: () => _load(more: true),
            child: const Text('載入更多'),
          );
        }
        final item = _items[index];
        final code = '${item['code'] ?? ''}';
        final status = commercialStatusLabel('${item['status']}');
        final maxUses = item['maxUses'] ?? 0;
        final used = item['usedCount'] ?? 0;
        final remaining = item['remainingUses'] ?? 0;
        final deadline = '${item['useByDate'] ?? ''}';
        return Card(
          color: item['codeId'] == _selectedCodeId
              ? const Color(0xFFF3F8FF)
              : null,
          child: ListTile(
            title: Text(
              (item['name'] ?? '').toString().isEmpty ? code : '${item['name']}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '$code\n${_repName('${item['salesRepId'] ?? ''}')} · $status\n'
              '已用 $used / $maxUses，剩餘 $remaining'
              '${deadline.isEmpty ? '' : '\n期限 $deadline'}',
            ),
            isThreeLine: true,
            onTap: () => setState(() => _selectedCodeId = '${item['codeId']}'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'copy') {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已複製激活碼')),
                  );
                } else if (value == 'share') {
                  await Share.share('PetNest 創店激活碼：$code');
                } else if (value == 'usage') {
                  await _usage('${item['codeId']}');
                } else if (value == 'toggle') {
                  await ShopCommercialService.instance.saveActivationCode({
                    'codeId': item['codeId'],
                    'code': code,
                    'name': item['name'] ?? '',
                    'salesRepId': item['salesRepId'] ?? '',
                    'campaignName': item['campaignName'] ?? '',
                    'useByDate': item['useByDate'] ?? '',
                    'note': item['note'] ?? '',
                    'shopSource': item['shopSource'] ?? '',
                    'module': item['module'] ?? '',
                    'enabled': item['enabled'] != true,
                  });
                  await _load();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'copy', child: Text('複製')),
                const PopupMenuItem(value: 'share', child: Text('分享')),
                const PopupMenuItem(value: 'usage', child: Text('使用紀錄')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(item['enabled'] == true ? '停用' : '啟用'),
                ),
              ],
            ),
          ),
        );
      },
    );
        Map<String, dynamic>? selected;
        for (final item in _items) {
          if (item['codeId'] == _selectedCodeId) selected = item;
        }
        final detail = selected == null
            ? const Center(child: Text('選擇一筆激活碼查看期限、次數與業務'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '${selected['name'] ?? selected['code']}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text('代碼：${selected['code'] ?? ''}'),
                  Text('方案：${commercialPlanLabel('${selected['plan']}')}'),
                  Text('業務：${_repName('${selected['salesRepId'] ?? ''}')}'),
                  Text('已用 ${selected['usedCount'] ?? 0} / ${selected['maxUses'] ?? 0}'),
                  Text('剩餘 ${selected['remainingUses'] ?? 0}'),
                  Text(
                    '期限：${'${selected['useByDate'] ?? ''}'.isEmpty ? '無' : selected['useByDate']}',
                  ),
                  Text('狀態：${commercialStatusLabel('${selected['status']}')}'),
                  if ('${selected['note'] ?? ''}'.isNotEmpty)
                    Text('備註：${selected['note']}'),
                ],
              );
        if (constraints.maxWidth < 1000) return list;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('本頁 ${_items.length} 筆'),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: list),
                  const VerticalDivider(width: 1),
                  SizedBox(width: 320, child: detail),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

