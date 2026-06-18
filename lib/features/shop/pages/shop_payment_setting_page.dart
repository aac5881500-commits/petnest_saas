// lib/features/shop/pages/shop_payment_setting_page.dart
// 💰 店家付款 / 訂金設定頁
// 功能：設定訂金規則、付款期限、付款方式
// 備註：銀行帳戶資料已移出，之後統一放到「收款帳戶 / 金流設定」

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShopPaymentSettingPage extends StatefulWidget {
  final String shopId;

  const ShopPaymentSettingPage({super.key, required this.shopId});

  @override
  State<ShopPaymentSettingPage> createState() => _ShopPaymentSettingPageState();
}

class _ShopPaymentSettingPageState extends State<ShopPaymentSettingPage> {
  bool _depositEnabled = false;

  String _depositType = 'fixed';
  int _depositValue = 1000;
  String _depositBase = 'room';

  bool _cash = true;
  bool _transfer = false;
  int _depositExpireHours = 12;

  final _depositValueCtrl = TextEditingController();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _depositValueCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final doc = await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .get();

    final data = doc.data();

    if (data != null) {
      _depositEnabled = data['depositEnabled'] ?? false;
      _depositType = data['depositType'] ?? 'fixed';
      _depositValue = data['depositValue'] ?? 1000;
      _depositValueCtrl.text = _depositValue.toString();
      _depositBase = data['depositBase'] ?? 'room';

      _cash = data['paymentMethods']?['cash'] ?? true;
      _transfer = data['paymentMethods']?['transfer'] ?? false;

      _depositExpireHours = data['depositExpireHours'] ?? 12;
    }

    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_depositType == 'percent') {
      if (_depositValue > 100) _depositValue = 100;
      if (_depositValue < 1) _depositValue = 1;
    }

    await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .update({
          'depositEnabled': _depositEnabled,
          'depositType': _depositType,
          'depositValue': _depositValue,
          'depositBase': _depositType == 'percent' ? _depositBase : 'total',
          'paymentMethods': {'cash': _cash, 'transfer': _transfer},
          'depositExpireHours': _depositExpireHours,
        });

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已儲存')));
  }

  void _updateDepositValue(String v) {
    int value = int.tryParse(v) ?? 0;

    if (_depositType == 'percent') {
      if (value > 100) value = 100;
      if (value < 1) value = 1;
    }

    _depositValue = value;

    final fixedText = value.toString();
    if (_depositValueCtrl.text != fixedText) {
      _depositValueCtrl.text = fixedText;
      _depositValueCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _depositValueCtrl.text.length),
      );
    }
  }

  void _changeDepositType(String value) {
    setState(() {
      _depositType = value;

      if (_depositType == 'percent') {
        if (_depositValue > 100) {
          _depositValue = 100;
          _depositValueCtrl.text = '100';
        }

        if (_depositValue < 1) {
          _depositValue = 1;
          _depositValueCtrl.text = '1';
        }

        _depositValueCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _depositValueCtrl.text.length),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('付款 / 訂金設定')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('啟用訂金'),
              value: _depositEnabled,
              onChanged: (v) => setState(() => _depositEnabled = v),
            ),

            if (_depositEnabled) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '訂金付款期限',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 8),

              ...[
                {'label': '12 小時', 'value': 12},
                {'label': '1 天', 'value': 24},
                {'label': '3 天', 'value': 72},
              ].map((item) {
                return RadioListTile<int>(
                  title: Text(item['label'].toString()),
                  value: item['value'] as int,
                  groupValue: _depositExpireHours,
                  onChanged: (v) {
                    setState(() {
                      _depositExpireHours = v ?? 12;
                    });
                  },
                );
              }),

              const Divider(height: 30),

              if (_depositType == 'percent') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '※ 訂金只會依照下方設定方式計算，請確認是否包含加值服務',
                    style: TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '訂金計算方式',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

                RadioListTile<String>(
                  title: const Text('只算房價'),
                  value: 'room',
                  groupValue: _depositBase,
                  onChanged: (v) {
                    setState(() {
                      _depositBase = v ?? 'room';
                    });
                  },
                ),

                RadioListTile<String>(
                  title: const Text('算總金額（含加值服務）'),
                  value: 'total',
                  groupValue: _depositBase,
                  onChanged: (v) {
                    setState(() {
                      _depositBase = v ?? 'total';
                    });
                  },
                ),

                const Divider(height: 30, thickness: 1),
              ],

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '訂金類型',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('固定金額'),
                      value: 'fixed',
                      groupValue: _depositType,
                      onChanged: (v) {
                        if (v == null) return;
                        _changeDepositType(v);
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('百分比'),
                      value: 'percent',
                      groupValue: _depositType,
                      onChanged: (v) {
                        if (v == null) return;
                        _changeDepositType(v);
                      },
                    ),
                  ),
                ],
              ),

              if (_depositType == 'percent')
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '※ 百分比將依照上方選擇的計算方式計算',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),

              TextField(
                controller: _depositValueCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _depositType == 'fixed' ? '訂金金額（元）' : '訂金百分比（%）',
                ),
                onChanged: _updateDepositValue,
              ),

              const SizedBox(height: 20),
            ],

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '付款方式',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            CheckboxListTile(
              title: const Text('到店付款'),
              value: _cash,
              onChanged: (v) => setState(() => _cash = v ?? false),
            ),

            CheckboxListTile(
              title: const Text('轉帳'),
              value: _transfer,
              onChanged: (v) => setState(() => _transfer = v ?? false),
            ),

            if (_transfer)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: const Text(
                  '轉帳帳戶資料將移至「收款帳戶 / 金流設定」管理。',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            const SizedBox(height: 30),

            ElevatedButton(onPressed: _save, child: const Text('儲存設定')),
          ],
        ),
      ),
    );
  }
}
