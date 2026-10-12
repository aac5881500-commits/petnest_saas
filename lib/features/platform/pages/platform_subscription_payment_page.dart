// 檔案名稱：lib/features/platform/pages/platform_subscription_payment_page.dart
// 功能說明：平台人工登記與確認店家訂閱收款，不混入顧客住宿付款。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_commercial_service.dart';

class PlatformSubscriptionPaymentPage extends StatefulWidget {
  const PlatformSubscriptionPaymentPage({super.key});

  @override
  State<PlatformSubscriptionPaymentPage> createState() =>
      _PlatformSubscriptionPaymentPageState();
}

class _PlatformSubscriptionPaymentPageState
    extends State<PlatformSubscriptionPaymentPage> {
  final _shopId = TextEditingController();
  final _date = TextEditingController();
  final _reference = TextEditingController();
  final _note = TextEditingController();
  final _due = TextEditingController(text: '999');
  final _received = TextEditingController(text: '999');
  final _reason = TextEditingController();
  String? _paymentRequestId;
  bool _saving = false;
  bool _shortfall = false;
  String _preview = '';
  String _plan = 'basic';
  String _cycle = 'month';
  String _method = 'transfer';
  List<Map<String, dynamic>> _items = const [];
  List<Map<String, dynamic>> _shops = const [];
  String _shopStatus = 'paid_active';
  int _paidActiveCount = 0;
  int _dueCount = 0;
  int _monthCollectedMinor = 0;
  bool _loading = true;
  String? _error;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _shopId.dispose();
    _date.dispose();
    _reference.dispose();
    _note.dispose();
    _due.dispose();
    _received.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _permissionDenied = false;
    });
    try {
      final data = await ShopCommercialService.instance.listSubscriptionPayments(
        shopId: _shopId.text.trim(),
      );
      final shops = await ShopCommercialService.instance.listSubscriptionShops(
        status: _shopStatus,
      );
      if (!mounted) return;
      setState(() {
        _items = (data['items'] as List? ?? const [])
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
        _shops = (shops['items'] as List? ?? const [])
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
        _paidActiveCount = (shops['paidActiveCount'] as num?)?.toInt() ?? 0;
        _dueCount = (shops['dueCount'] as num?)?.toInt() ?? 0;
        _monthCollectedMinor =
            (shops['monthCollectedMinor'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } on ShopCommercialException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
        _permissionDenied = error.permissionDenied;
      });
    }
  }

  int _yuanToMinor(String text) => (int.tryParse(text.trim()) ?? 0) * 100;

  Future<void> _previewPeriod() async {
    try {
      final data = await ShopCommercialService.instance.previewSubscriptionPayment(
        shopId: _shopId.text.trim(),
        plan: _plan,
        cycle: _cycle,
        amountDueMinor: _yuanToMinor(_due.text),
        amountReceivedMinor: _yuanToMinor(_received.text),
        differenceReason: _reason.text.trim(),
        grantFullPeriodDespiteShortfall: _shortfall,
        paymentDate: _date.text.trim(),
      );
      final preview = data['preview'] is Map
          ? Map<String, dynamic>.from(data['preview'] as Map)
          : const <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _preview =
            '${preview['start'] ?? ''}～${preview['end'] ?? ''}'
            '${(data['nextPlan'] ?? '').toString().isEmpty ? '' : '，下一期才改方案'}';
      });
    } on ShopCommercialException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _register() async {
    if (_saving) return;
    setState(() => _saving = true);
    _paymentRequestId ??= 'pay${DateTime.now().microsecondsSinceEpoch}';
    try {
      final registered = await ShopCommercialService.instance
          .registerSubscriptionPayment(
            shopId: _shopId.text.trim(),
            plan: _plan,
            cycle: _cycle,
            paymentDate: _date.text.trim(),
            method: _method,
            requestId: _paymentRequestId!,
            amountDueMinor: _yuanToMinor(_due.text),
            amountReceivedMinor: _yuanToMinor(_received.text),
            differenceReason: _reason.text.trim(),
            grantFullPeriodDespiteShortfall: _shortfall,
            reference: _reference.text.trim(),
            note: _note.text.trim(),
          );
      await ShopCommercialService.instance.confirmSubscriptionPayment(
        '${registered['paymentId']}',
      );
      _paymentRequestId = null;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已確認收款。重複確認不會再延長或重算分潤。')),
      );
      await _load();
    } on ShopCommercialException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _markCommissionPaid(String paymentId) async {
    final date = TextEditingController();
    final reference = TextEditingController();
    final amount = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('登記分潤發放'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('只登記這筆收款當時產生的分潤，不會改歷史比例。'),
              TextField(
                controller: date,
                decoration: const InputDecoration(
                  labelText: '發放日期',
                  hintText: 'YYYY-MM-DD',
                ),
              ),
              TextField(
                controller: reference,
                decoration: const InputDecoration(labelText: '參考編號'),
              ),
              TextField(
                controller: amount,
                decoration: const InputDecoration(labelText: '實發金額（元，可空白）'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('登記'),
            ),
          ],
        );
      },
    );
    if (saved == true) {
      final yuan = int.tryParse(amount.text.trim());
      try {
        await ShopCommercialService.instance.settleCommission(
          entryId: 'pay_$paymentId',
          action: 'paid',
          paidOn: date.text.trim(),
          reference: reference.text.trim(),
          amountMinor: yuan == null ? null : yuan * 100,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已登記發放')),
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
    date.dispose();
    reference.dispose();
    amount.dispose();
  }

  Future<void> _refund(String paymentId) async {
    final amount = TextEditingController();
    final reason = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('退款'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('已確認收款不能直接改金額。退款會另存一筆負向紀錄。'),
              TextField(
                controller: amount,
                decoration: const InputDecoration(labelText: '退款金額（元）'),
              ),
              TextField(
                controller: reason,
                decoration: const InputDecoration(labelText: '理由'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('建立退款'),
            ),
          ],
        );
      },
    );
    if (saved == true) {
      final yuan = int.tryParse(amount.text.trim()) ?? 0;
      try {
        await ShopCommercialService.instance.refundSubscriptionPayment(
          paymentId: paymentId,
          refundMinor: yuan * 100,
          reason: reason.text.trim(),
          requestId: 'refund${DateTime.now().microsecondsSinceEpoch}',
        );
        await _load();
      } on ShopCommercialException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message)),
          );
        }
      }
    }
    amount.dispose();
    reason.dispose();
  }

  Future<void> _migrate(bool dryRun) async {
    try {
      var cursor = '';
      var scanned = 0;
      var marked = 0;
      var rounds = 0;
      while (rounds < 20) {
        final result = await ShopCommercialService.instance.migrate(
          dryRun: dryRun,
          cursor: cursor,
        );
        scanned += (result['scanned'] as num?)?.toInt() ?? 0;
        marked += (result['markedLegacy'] as num?)?.toInt() ?? 0;
        cursor = (result['nextCursor'] ?? '').toString();
        rounds += 1;
        if (cursor.isEmpty) break;
      }
      if (!mounted) return;
      final more = cursor.isEmpty ? '' : '還有資料，請再按一次。';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            dryRun
                ? '試跑：掃描 $scanned 間，可標記 $marked 間。$more'
                : '已標記 $marked 間，原有期限沒有縮短。$more',
          ),
        ),
      );
    } on ShopCommercialException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirmed = _items.where((item) {
      return item['status'] == 'confirmed' && item['kind'] != 'refund';
    }).fold<int>(0, (sum, item) {
      return sum + ((item['amountReceivedMinor'] as num?)?.toInt() ?? 0);
    });
    return Scaffold(
      appBar: AppBar(title: const Text('訂閱收款')),
      body: _permissionDenied
          ? const Center(child: Text('沒有訂閱收款權限'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  '這裡只登記店家付給平台的方案費用。試用、贈送與人工延長不產生收入。'
                  '金額由後端依方案計算，不能在畫面上自訂價格。',
                ),
                const SizedBox(height: 12),
                Text('本月實收 ${commercialMoney(_monthCollectedMinor)}'),
                Text('目前付費有效店家 $_paidActiveCount 間，30 日內待續費 $_dueCount 間'),
                Text('這頁收款合計 ${commercialMoney(confirmed)}'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final entry in const [
                      ['paid_active', '付費有效'],
                      ['trial', '試用中'],
                      ['expiring', '即將到期'],
                      ['expired', '到期未續'],
                      ['legacy_unconfirmed', '歷史資料待確認'],
                    ])
                      ChoiceChip(
                        label: Text(entry[1]),
                        selected: _shopStatus == entry[0],
                        onSelected: (_) {
                          setState(() => _shopStatus = entry[0]);
                          _load();
                        },
                      ),
                  ],
                ),
                ..._shops.map((shop) {
                  final due = shop['renewalDue'] == true ? '，尚未完成下一期' : '';
                  return ListTile(
                    title: Text('${shop['name'] ?? shop['shopId']}'),
                    subtitle: Text(
                      '${commercialStatusLabel('${shop['listStatus']}')}$due'
                      '｜可用至 ${shop['paidUntilDate'] ?? shop['paidServiceUntil'] ?? ''}',
                    ),
                  );
                }),
                const SizedBox(height: 8),
                TextField(
                  controller: _shopId,
                  decoration: const InputDecoration(labelText: '店家編號'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _plan,
                  decoration: const InputDecoration(labelText: '方案'),
                  items: const [
                    DropdownMenuItem(value: 'basic', child: Text('專業版')),
                    DropdownMenuItem(value: 'pro', child: Text('全模組')),
                  ],
                  onChanged: (value) => setState(() => _plan = value ?? 'basic'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _cycle,
                  decoration: const InputDecoration(labelText: '週期'),
                  items: const [
                    DropdownMenuItem(value: 'month', child: Text('月繳')),
                    DropdownMenuItem(value: 'year', child: Text('年繳')),
                  ],
                  onChanged: (value) => setState(() => _cycle = value ?? 'month'),
                ),
                TextField(
                  controller: _date,
                  decoration: const InputDecoration(
                    labelText: '付款日期',
                    hintText: 'YYYY-MM-DD，空白則用今天',
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _method,
                  decoration: const InputDecoration(labelText: '付款方式'),
                  items: const [
                    DropdownMenuItem(value: 'transfer', child: Text('轉帳')),
                    DropdownMenuItem(value: 'cash', child: Text('現金')),
                  ],
                  onChanged: (value) {
                    setState(() => _method = value ?? 'transfer');
                  },
                ),
                Text('標準價格：${_cycle == 'year' ? (_plan == 'pro' ? '23,988' : '11,988') : (_plan == 'pro' ? '1,999' : '999')} 元'),
                TextField(
                  controller: _due,
                  decoration: const InputDecoration(labelText: '本次應收（元）'),
                ),
                TextField(
                  controller: _received,
                  decoration: const InputDecoration(labelText: '本次實收（元）'),
                ),
                TextField(
                  controller: _reason,
                  decoration: const InputDecoration(labelText: '優惠或差異理由'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('實收不足時，仍授予完整期間'),
                  value: _shortfall,
                  onChanged: (value) => setState(() => _shortfall = value),
                ),
                if (_preview.isNotEmpty) Text('服務期間預覽：$_preview'),
                TextField(
                  controller: _reference,
                  decoration: const InputDecoration(labelText: '參考編號'),
                ),
                TextField(
                  controller: _note,
                  decoration: const InputDecoration(labelText: '備註'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: _saving ? null : _register,
                      child: Text(_saving ? '送出中' : '登記並確認收款'),
                    ),
                    OutlinedButton(
                      onPressed: _previewPeriod,
                      child: const Text('預覽期間'),
                    ),
                    OutlinedButton(onPressed: _load, child: const Text('重新查詢')),
                    OutlinedButton(
                      onPressed: () => _migrate(true),
                      child: const Text('遷移試跑'),
                    ),
                    OutlinedButton(
                      onPressed: () => _migrate(false),
                      child: const Text('標記歷史權益'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_loading) const LinearProgressIndicator(),
                if (_error != null) Text(_error!),
                if (!_loading && _error == null && _items.isEmpty)
                  const Text('沒有收款紀錄'),
                ..._items.map((item) {
                  final status = commercialStatusLabel('${item['status']}');
                  final kind = item['kind'] == 'refund' ? '退款' : '收款';
                  final canRefund = item['status'] == 'confirmed' &&
                      item['kind'] != 'refund';
                  return Card(
                    child: ListTile(
                      title: Text(
                        '$kind｜${item['shopId']}｜${commercialPlanLabel('${item['plan']}')}',
                      ),
                      subtitle: Text(
                        '$status｜${commercialMoney(item['amountReceivedMinor'])}'
                        '｜${item['serviceStart'] ?? ''}～${item['serviceEnd'] ?? ''}',
                      ),
                      trailing: canRefund
                          ? Wrap(
                              spacing: 4,
                              children: [
                                TextButton(
                                  onPressed: () => _refund('${item['paymentId']}'),
                                  child: const Text('退款'),
                                ),
                                TextButton(
                                  onPressed: () => _markCommissionPaid(
                                    '${item['paymentId']}',
                                  ),
                                  child: const Text('登記分潤發放'),
                                ),
                              ],
                            )
                          : null,
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
