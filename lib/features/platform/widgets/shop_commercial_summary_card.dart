// 檔案名稱：lib/features/platform/widgets/shop_commercial_summary_card.dart
// 功能說明：店家詳細頁顯示來源、業務、權益與收款入口。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_commercial_service.dart';
import 'package:petnest_saas/features/platform/pages/platform_subscription_payment_page.dart';

class ShopCommercialSummaryCard extends StatefulWidget {
  const ShopCommercialSummaryCard({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopCommercialSummaryCard> createState() =>
      _ShopCommercialSummaryCardState();
}

class _ShopCommercialSummaryCardState extends State<ShopCommercialSummaryCard> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _permissionDenied = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ShopCommercialSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _permissionDenied = false;
    });
    try {
      final data = await ShopCommercialService.instance.shopSummary(widget.shopId);
      if (!mounted) return;
      setState(() {
        _data = data;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      );
    }
    if (_permissionDenied) {
      return const SizedBox.shrink();
    }
    if (_error != null) {
      return Text(_error!);
    }
    final data = _data ?? const <String, dynamic>{};
    final renewal = data['renewalDue'] == true ? '，30 天內需留意續費' : '';
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('開發與訂閱', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('開店來源：${commercialSourceLabel('${data['shopSource'] ?? ''}')}'),
            Text('激活碼：${data['activationCode'] ?? '無'}'),
            Text('活動：${data['campaignName'] ?? '無'}'),
            Text('開發業務：${_name(data['originSalesName'])}'),
            Text('目前負責業務：${_name(data['currentSalesName'])}'),
            Text('方案：${commercialPlanLabel('${data['plan'] ?? ''}')}'),
            Text(
              '狀態：${commercialStatusLabel('${data['listStatus'] ?? ''}')}$renewal',
            ),
            Text('試用至：${_date(data['trialUntil'])}'),
            Text('付費至：${_date(data['paidServiceUntil'])}'),
            Text('贈送至：${_date(data['giftUntil'])}'),
            Text('可用至：${_date(data['paidUntilDate'])}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _assign('current'),
                  child: const Text('交接目前負責人'),
                ),
                OutlinedButton(
                  onPressed: () => _assign('origin'),
                  child: const Text('更正原始開發業務'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PlatformSubscriptionPaymentPage(),
                  ),
                );
              },
              child: const Text('訂閱收款'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assign(String mode) async {
    List<Map<String, dynamic>> reps = const [];
    try {
      reps = await ShopCommercialService.instance.listSalesReps();
    } on ShopCommercialException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      return;
    }
    if (!mounted) return;
    var repId = '';
    final reason = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(mode == 'origin' ? '更正原始開發業務' : '交接目前負責人'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (mode == 'origin')
                    const Text('需要填寫理由。已結算分潤不會重算。'),
                  if (mode == 'current')
                    const Text('只改目前負責人，不改原始開發業務。'),
                  DropdownButtonFormField<String>(
                    initialValue: repId,
                    decoration: const InputDecoration(labelText: '業務'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('未指派')),
                      ...reps.map((rep) {
                        return DropdownMenuItem(
                          value: '${rep['repId']}',
                          child: Text('${rep['displayName'] ?? ''}'),
                        );
                      }),
                    ],
                    onChanged: (value) => setLocal(() => repId = value ?? ''),
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
                  child: const Text('儲存'),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved == true) {
      try {
        await ShopCommercialService.instance.assignShopSales(
          shopId: widget.shopId,
          mode: mode,
          salesRepId: repId,
          reason: reason.text.trim(),
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
    reason.dispose();
  }

  String _name(Object? value) {
    final text = (value ?? '').toString();
    return text.isEmpty ? '未指派' : text;
  }

  String _date(Object? value) {
    final text = (value ?? '').toString();
    return text.isEmpty ? '無' : text;
  }
}
