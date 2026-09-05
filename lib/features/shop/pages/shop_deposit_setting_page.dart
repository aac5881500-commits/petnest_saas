// 檔案名稱：lib/features/shop/pages/shop_deposit_setting_page.dart
// 功能說明：設定訂金規則、付款期限與付款方式
// 💰 店家訂金與收款設定頁
// 備註：目前舊長住折扣暫時保留，之後確認新版優惠正常後再移除

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShopDepositSettingPage extends StatefulWidget {
  const ShopDepositSettingPage({
    super.key,
    required this.shopId,
    this.embedded = false,
  });

  final String shopId;

  /// true：嵌入 Tab 使用，不顯示自己的 Scaffold 與 AppBar
  /// false：維持原本獨立頁面顯示方式
  final bool embedded;

  @override
  State<ShopDepositSettingPage> createState() => _ShopDepositSettingPageState();
}

class _ShopDepositSettingPageState extends State<ShopDepositSettingPage> {
  bool _depositEnabled = false;

  String _depositType = 'fixed';
  int _depositValue = 1000;
  String _depositBase = 'room';

  bool _cash = true;
  bool _transfer = false;
  int _depositExpireHours = 12;

  bool _discountEnabled = false;
  String _discountBase = 'room_pet';

  final _depositValueCtrl = TextEditingController();

  final List<Map<String, TextEditingController>> _discountRuleCtrls = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _depositValueCtrl.dispose();

    for (final item in _discountRuleCtrls) {
      item['minNights']?.dispose();
      item['discountPercent']?.dispose();
    }

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

      final discountSetting =
          data['discountSetting'] as Map<String, dynamic>? ?? {};

      _discountEnabled = discountSetting['enabled'] ?? false;
      _discountBase = discountSetting['base'] ?? 'room_pet';

      final rules = discountSetting['rules'];

      if (rules is List && rules.isNotEmpty) {
        for (final item in rules) {
          if (item is! Map) continue;

          _discountRuleCtrls.add({
            'minNights': TextEditingController(
              text: (item['minNights'] ?? '').toString(),
            ),
            'discountPercent': TextEditingController(
              text: (item['discountPercent'] ?? '').toString(),
            ),
          });
        }
      } else {
        _addDefaultDiscountRules();
      }
    } else {
      _addDefaultDiscountRules();
    }

    if (_discountRuleCtrls.isEmpty) {
      _addDefaultDiscountRules();
    }

    setState(() => _loading = false);
  }

  void _addDefaultDiscountRules() {
    _discountRuleCtrls.addAll([
      {
        'minNights': TextEditingController(text: '3'),
        'discountPercent': TextEditingController(text: '20'),
      },
      {
        'minNights': TextEditingController(text: '7'),
        'discountPercent': TextEditingController(text: '30'),
      },
    ]);
  }

  List<Map<String, int>> _buildDiscountRulesForSave() {
    final rules = <Map<String, int>>[];

    for (final item in _discountRuleCtrls) {
      final minNights = int.tryParse(item['minNights']?.text.trim() ?? '') ?? 0;

      var discountPercent =
          int.tryParse(item['discountPercent']?.text.trim() ?? '') ?? 0;

      if (minNights <= 0) continue;

      if (discountPercent < 1) discountPercent = 1;
      if (discountPercent > 99) discountPercent = 99;

      rules.add({'minNights': minNights, 'discountPercent': discountPercent});
    }

    rules.sort((a, b) => a['minNights']!.compareTo(b['minNights']!));

    return rules;
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
          'discountSetting': {
            'enabled': _discountEnabled,
            'base': _discountBase,
            'rules': _buildDiscountRulesForSave(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
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

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      const loadingView = Center(child: CircularProgressIndicator());

      if (widget.embedded) {
        return loadingView;
      }

      return const Scaffold(body: loadingView);
    }

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _sectionCard(
            title: '收款設定',
            subtitle: '設定付款方式、訂金規則與收款資訊',
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
                  {'label': '1 分鐘（測試用）', 'value': 0},
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
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _save, child: const Text('儲存設定')),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('訂金與收款設定')),
      body: content,
    );
  }
}
