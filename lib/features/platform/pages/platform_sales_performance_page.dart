// 檔案名稱：lib/features/platform/pages/platform_sales_performance_page.dart
// 功能說明：依月份查看開發業績，並與目前負責的付費店家分開。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_commercial_service.dart';

class PlatformSalesPerformancePage extends StatefulWidget {
  const PlatformSalesPerformancePage({super.key});

  @override
  State<PlatformSalesPerformancePage> createState() =>
      _PlatformSalesPerformancePageState();
}

class _PlatformSalesPerformancePageState
    extends State<PlatformSalesPerformancePage> {
  final _month = TextEditingController();
  final _entryId = TextEditingController();
  final _payoutDate = TextEditingController();
  final _payoutReference = TextEditingController();
  final _payoutAmount = TextEditingController();
  List<Map<String, dynamic>> _items = const [];
  List<Map<String, dynamic>> _responsible = const [];
  int _responsibleTotal = 0;
  int _responsibleDue = 0;
  String _responsibleNote = '';
  List<Map<String, dynamic>> _entries = const [];
  String _entryCursor = '';
  bool _entriesMore = false;
  bool _loading = false;
  String? _error;
  bool _permissionDenied = false;

  @override
  void dispose() {
    _month.dispose();
    _entryId.dispose();
    _payoutDate.dispose();
    _payoutReference.dispose();
    _payoutAmount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _permissionDenied = false;
    });
    try {
      final items = await ShopCommercialService.instance.salesMonthSummary(
        _month.text.trim(),
      );
      List<Map<String, dynamic>> responsible = const [];
      var responsibleTotal = 0;
      var responsibleDue = 0;
      var responsibleNote = '';
      try {
        final responsibleData =
            await ShopCommercialService.instance.listResponsibleShops();
        responsible = (responsibleData['items'] as List? ?? const [])
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
        responsibleTotal = (responsibleData['total'] as num?)?.toInt() ??
            responsible.length;
        responsibleDue = (responsibleData['dueCount'] as num?)?.toInt() ?? 0;
      } on ShopCommercialException catch (error) {
        responsible = const [];
        responsibleNote = error.message;
      }
      final entries = await ShopCommercialService.instance.listCommissionEntries(
        month: _month.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _responsible = responsible;
        _responsibleTotal = responsibleTotal;
        _responsibleDue = responsibleDue;
        _responsibleNote = responsibleNote;
        _entries = (entries['items'] as List? ?? const [])
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
        _entryCursor = (entries['nextCursor'] ?? '').toString();
        _entriesMore = entries['hasMore'] == true;
        _loading = false;
      });
    } on ShopCommercialException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
        _permissionDenied = error.permissionDenied;
        _items = const [];
        _responsible = const [];
      });
    }
  }

  Future<void> _actOnEntry(Map<String, dynamic> entry) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('分潤 ${entry['entryId']}'),
        content: Text(
          '店家 ${entry['shopId'] ?? ''}\n'
          '受益業務 ${entry['beneficiaryRepId'] ?? ''}\n'
          '原金額 ${commercialMoney(entry['amountMinor'])}\n'
          '可結算 ${commercialMoney(entry['openMinor'] ?? entry['amountMinor'])}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'settleable'),
            child: const Text('確認可結算'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancelled'),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'paid'),
            child: const Text('登記發放'),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    try {
      await ShopCommercialService.instance.settleCommission(
        entryId: '${entry['entryId']}',
        action: action,
      );
      if (!mounted) return;
      await _load();
    } on ShopCommercialException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _saveRule() async {
    final percent = TextEditingController();
    final fixed = TextEditingController();
    var enabled = false;
    var mode = 'percent';
    var appliesTo = 'both';
    var beneficiary = 'origin';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('新增分潤規則版本'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('預設不啟用。沒有啟用中的規則時，確認收款不會產生分潤。'),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('啟用這一版'),
                      value: enabled,
                      onChanged: (value) => setLocal(() => enabled = value),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: mode,
                      decoration: const InputDecoration(labelText: '計算方式'),
                      items: const [
                        DropdownMenuItem(value: 'percent', child: Text('百分比')),
                        DropdownMenuItem(value: 'fixed', child: Text('固定金額')),
                      ],
                      onChanged: (value) {
                        setLocal(() => mode = value ?? 'percent');
                      },
                    ),
                    TextField(
                      controller: percent,
                      decoration: const InputDecoration(
                        labelText: '百分比',
                        hintText: '例如 10 代表 10%',
                      ),
                    ),
                    TextField(
                      controller: fixed,
                      decoration: const InputDecoration(
                        labelText: '固定金額（元）',
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: appliesTo,
                      decoration: const InputDecoration(labelText: '適用收款'),
                      items: const [
                        DropdownMenuItem(value: 'first_payment', child: Text('僅首次付費')),
                        DropdownMenuItem(value: 'renewal', child: Text('僅續費')),
                        DropdownMenuItem(value: 'both', child: Text('首次與續費')),
                      ],
                      onChanged: (value) {
                        setLocal(() => appliesTo = value ?? 'both');
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: beneficiary,
                      decoration: const InputDecoration(labelText: '受益業務'),
                      items: const [
                        DropdownMenuItem(value: 'origin', child: Text('原始開發業務')),
                        DropdownMenuItem(value: 'current', child: Text('目前負責業務')),
                      ],
                      onChanged: (value) {
                        setLocal(() => beneficiary = value ?? 'origin');
                      },
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
                  child: const Text('建立版本'),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved == true) {
      final percentValue = double.tryParse(percent.text.trim()) ?? 0;
      final fixedYuan = int.tryParse(fixed.text.trim()) ?? 0;
      try {
        await ShopCommercialService.instance.saveCommissionRule({
          'enabled': enabled,
          'mode': mode,
          'percentBps': (percentValue * 100).round(),
          'fixedMinor': fixedYuan * 100,
          'appliesTo': appliesTo,
          'beneficiary': beneficiary,
          'effectiveFrom': _month.text.trim().isEmpty
              ? ''
              : '${_month.text.trim()}-01',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已新增一版分潤規則，不會改已產生的分潤')),
          );
        }
      } on ShopCommercialException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message)),
          );
        }
      }
    }
    percent.dispose();
    fixed.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final due = _responsibleDue;
    return Scaffold(
      appBar: AppBar(title: const Text('業務業績與分潤')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '新開店數是該月原始開發業務帶進來的店，交接不會改。'
            '首次付費是該店第一筆確認收款；續費是已有付費期間後的確認收款。'
            '實收與退款只算已確認的訂閱收款，試用和贈送不算。'
            '目前負責的有效付費店家是現在的客戶數，不是這個月的開發業績。'
            '待續費是付費結束日在 30 天內，不代表下一期已經續約。'
            '年繳店家本月沒有收款，只要付費期間未到，仍算付費有效。',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _month,
            decoration: const InputDecoration(
              labelText: '月份',
              hintText: 'YYYY-MM',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(onPressed: _load, child: const Text('查看')),
              OutlinedButton(
                onPressed: _saveRule,
                child: const Text('新增未啟用規則'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading) const LinearProgressIndicator(),
          if (_permissionDenied) const Text('沒有查看這份業績的權限'),
          if (_error != null && !_permissionDenied) Text(_error!),
          if (!_loading && _error == null && _items.isEmpty)
            const Text('這個月沒有業績摘要'),
          ..._items.map((item) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item['displayName'] ?? item['repId'] ?? '業務'}'),
                    Text('新開店數：${item['newShops'] ?? 0}'),
                    Text('首次付費店家數：${item['firstPaidShops'] ?? 0}'),
                    Text('續費店家數：${item['renewalShops'] ?? 0}'),
                    Text('續費收款筆數：${item['renewalPayments'] ?? 0}'),
                    Text('當期實收：${commercialMoney(item['collectedMinor'])}'),
                    Text('當期退款：${commercialMoney(item['refundMinor'])}'),
                    Text('本期產生分潤：${commercialMoney(item['earnedCommissionMinor'])}'),
                    Text('尚未結清：${commercialMoney(item['openCommissionMinor'])}'),
                    Text('調整：${commercialMoney(item['adjustmentMinor'])}'),
                    Text('已發放分潤：${commercialMoney(item['paidCommissionMinor'])}'),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Text(
            _responsibleNote.isEmpty
                ? '目前負責的有效付費店家：$_responsibleTotal'
                : _responsibleNote,
          ),
          if (_responsibleNote.isEmpty) Text('其中待續費：$due'),
          const SizedBox(height: 12),
          const Text('分潤明細。點選後可確認、取消或登記發放。已發放不能改寫。'),
          ..._entries.map((entry) {
            final status = '${entry['status'] ?? ''}';
            return Card(
              child: ListTile(
                title: Text(
                  '${entry['shopId'] ?? ''}｜${commercialStatusLabel(status)}',
                ),
                subtitle: Text(
                  '歸屬 ${entry['accrualMonth'] ?? ''}｜'
                  '金額 ${commercialMoney(entry['amountMinor'])}｜'
                  '可結算 ${commercialMoney(entry['openMinor'] ?? entry['amountMinor'])}',
                ),
                onTap: () => _actOnEntry(entry),
              ),
            );
          }),
          if (_entriesMore)
            OutlinedButton(
              onPressed: () async {
                final more = await ShopCommercialService.instance
                    .listCommissionEntries(
                  month: _month.text.trim(),
                  cursor: _entryCursor,
                );
                if (!mounted) return;
                setState(() {
                  _entries = [
                    ..._entries,
                    ...(more['items'] as List? ?? const [])
                        .whereType<Map>()
                        .map(Map<String, dynamic>.from),
                  ];
                  _entryCursor = (more['nextCursor'] ?? '').toString();
                  _entriesMore = more['hasMore'] == true;
                });
              },
              child: const Text('載入更多分潤'),
            ),
          const Text('進階：若列表沒有出現，才用收款編號登記。'),
          TextField(
            controller: _entryId,
            decoration: const InputDecoration(labelText: '分潤編號'),
          ),
          TextField(
            controller: _payoutDate,
            decoration: const InputDecoration(
              labelText: '發放日期',
              hintText: 'YYYY-MM-DD',
            ),
          ),
          TextField(
            controller: _payoutReference,
            decoration: const InputDecoration(labelText: '參考編號'),
          ),
          TextField(
            controller: _payoutAmount,
            decoration: const InputDecoration(labelText: '實發金額（元）'),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () async {
                final yuan = int.tryParse(_payoutAmount.text.trim());
                try {
                  await ShopCommercialService.instance.settleCommission(
                    entryId: _entryId.text.trim(),
                    action: 'paid',
                    paidOn: _payoutDate.text.trim(),
                    reference: _payoutReference.text.trim(),
                    amountMinor: yuan == null ? null : yuan * 100,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已登記發放')),
                  );
                } on ShopCommercialException catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error.message)),
                  );
                }
              },
              child: const Text('登記發放'),
            ),
          ),
          ..._responsible.map((shop) {
            final dueLabel = shop['renewalDue'] == true ? '待續費' : '付費有效';
            return ListTile(
              title: Text('${shop['name'] ?? shop['shopId']}'),
              subtitle: Text(
                '$dueLabel｜付費至 ${shop['paidServiceUntil'] ?? ''}',
              ),
            );
          }),
        ],
      ),
    );
  }
}
