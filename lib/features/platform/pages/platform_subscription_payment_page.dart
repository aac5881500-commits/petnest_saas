import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_commercial_service.dart';
import 'package:petnest_saas/features/shop/pages/platform_billing_page.dart';

/// 平台只查看訂閱與收款，付款由店主透過綠界完成。
class PlatformSubscriptionPaymentPage extends StatefulWidget {
  const PlatformSubscriptionPaymentPage({super.key});

  @override
  State<PlatformSubscriptionPaymentPage> createState() =>
      _PlatformSubscriptionPaymentPageState();
}

class _PlatformSubscriptionPaymentPageState
    extends State<PlatformSubscriptionPaymentPage> {
  final _shopId = TextEditingController();
  List<Map<String, dynamic>> _items = [], _shops = [];
  String _status = 'paid_active';
  int _paid = 0, _due = 0, _collected = 0;
  bool _loading = true, _hasMore = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _shopId.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(dynamic value) =>
      (value is List ? value : const [])
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait([
        ShopCommercialService.instance.listSubscriptionPayments(
          shopId: _shopId.text.trim(),
        ),
        ShopCommercialService.instance.listSubscriptionShops(status: _status),
      ]);
      if (!mounted || generation != _generation) return;
      final summary = result[1];
      setState(() {
        _items = _rows(result[0]['items']);
        _shops = _rows(summary['items']);
        _paid = (summary['paidActiveCount'] as num?)?.toInt() ?? 0;
        _due = (summary['dueCount'] as num?)?.toInt() ?? 0;
        _collected = (summary['monthCollectedMinor'] as num?)?.toInt() ?? 0;
        _hasMore = summary['hasMore'] == true;
      });
    } on ShopCommercialException catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = '暫時無法讀取訂閱資料，請稍後重試。');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _open(String id) {
    if (id.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入店家編號，或點選下方店家')));
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => PlatformBillingPage(shopId: id)),
    );
  }

  String _plan(dynamic plan) => plan == 'pro'
      ? '旗艦版'
      : plan == 'basic'
      ? '專業版'
      : commercialPlanLabel('$plan');

  Widget _section(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('店家訂閱管理')),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('平台方案收費', [
              const Text(
                '店主在自己的後台選擇方案、續約並以綠界信用卡付款。'
                '付款經系統核對後自動續期，平台不需人工登記收款。',
              ),
              const SizedBox(height: 16),
              const Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  Chip(label: Text('專業版　999元／月')),
                  Chip(label: Text('旗艦版　1,999元／月')),
                  Chip(
                    avatar: Icon(Icons.verified_user_outlined, size: 18),
                    label: Text('僅接受綠界付款'),
                  ),
                ],
              ),
            ]),
            _section('訂閱概況', [
              Wrap(
                spacing: 24,
                runSpacing: 16,
                children: [
                  Text('本月帳務實收\n${commercialMoney(_collected)}'),
                  Text('付費有效\n$_paid 間'),
                  Text('30日內待續費\n$_due 間'),
                ],
              ),
              const SizedBox(height: 12),
              const Text('概況包含既有歷史帳務；歷史資料保留，不視為新的綠界付款。'),
            ]),
            _section('查詢店家', [
              TextField(
                controller: _shopId,
                decoration: const InputDecoration(
                  labelText: '店家編號',
                  hintText: '例如 SHOP0009',
                  prefixIcon: Icon(Icons.search),
                ),
                onSubmitted: (_) => _load(),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.search),
                    label: const Text('查詢付款紀錄'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _open(_shopId.text.trim()),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('查看綠界付款與續訂'),
                  ),
                ],
              ),
            ]),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
            if (!_loading && _error == null) ...[
              _section('店家訂閱狀態', [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in const [
                      ['paid_active', '付費有效'],
                      ['trial', '試用中'],
                      ['expiring', '即將到期'],
                      ['expired', '到期未續'],
                      ['legacy_unconfirmed', '歷史待確認'],
                    ])
                      ChoiceChip(
                        label: Text(entry[1]),
                        selected: _status == entry[0],
                        onSelected: (_) {
                          setState(() => _status = entry[0]);
                          _load();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_shops.isEmpty) const Text('目前沒有符合此狀態的店家。'),
                for (final shop in _shops)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.storefront_outlined),
                    title: Text('${shop['name'] ?? shop['shopId']}'),
                    subtitle: Text(
                      '${shop['shopId']}・${_plan(shop['plan'])}\n'
                      '${commercialStatusLabel('${shop['listStatus']}')}・'
                      '可用至 ${shop['paidUntilDate'] ?? shop['paidServiceUntil'] ?? '未設定'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open('${shop['shopId']}'),
                  ),
                if (_hasMore) const Text('本頁顯示前30間；其他店家請直接輸入店家編號查詢。'),
              ]),
              _section('付款紀錄', [
                const Text('顯示最近的帳務紀錄；續訂中、扣款失敗與待付款，請進入該店的「綠界付款與續訂」查看。'),
                const SizedBox(height: 12),
                if (_items.isEmpty) const Text('目前沒有付款紀錄。'),
                for (final item in _items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(
                      '${item['shopId']}・${_plan(item['plan'])}・'
                      '${commercialMoney(item['amountReceivedMinor'])}',
                    ),
                    subtitle: Text(
                      '${item['kind'] == 'refund' ? '歷史退款紀錄' : commercialStatusLabel('${item['status']}')}\n'
                      '${item['serviceStart'] ?? ''}～${item['serviceEnd'] ?? ''}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open('${item['shopId']}'),
                  ),
              ]),
            ],
          ],
        ),
      ),
    ),
  );
}
