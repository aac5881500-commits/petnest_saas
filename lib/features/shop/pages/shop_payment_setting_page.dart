// lib/features/shop/pages/shop_payment_setting_page.dart
// 💰 店家付款 / 訂金設定頁

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShopPaymentSettingPage extends StatefulWidget {
  final String shopId;

  const ShopPaymentSettingPage({
    super.key,
    required this.shopId,
  });

  @override
  State<ShopPaymentSettingPage> createState() =>
      _ShopPaymentSettingPageState();
}

class _ShopPaymentSettingPageState
    extends State<ShopPaymentSettingPage> {
  bool _depositEnabled = false;

  String _depositType = 'fixed'; 
  
  int _depositValue = 1000;

  String _depositBase = 'room'; 

  bool _cash = true;
  bool _transfer = false;

  final _bankNameCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _depositValueCtrl = TextEditingController();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

@override
void dispose() {
  _bankNameCtrl.dispose();
  _accountNameCtrl.dispose();
  _accountNumberCtrl.dispose();
  _depositValueCtrl.dispose();
  super.dispose();
}

  /// 🔥 讀取 Firebase
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

      _bankNameCtrl.text = data['bankName'] ?? '';

      _accountNameCtrl.text = data['accountName'] ?? '';

      _accountNumberCtrl.text = data['accountNumber'] ?? '';
    }

    setState(() => _loading = false);
  }

  /// 🔥 儲存
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
      'bankName': _bankNameCtrl.text,
      'accountName': _accountNameCtrl.text,
      'accountNumber': _accountNumberCtrl.text,
      'paymentMethods': {
        'cash': _cash,
        'transfer': _transfer,
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已儲存')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('付款 / 訂金設定')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// 🔥 訂金開關
            SwitchListTile(
              title: const Text('啟用訂金'),
              value: _depositEnabled,
              onChanged: (v) => setState(() => _depositEnabled = v),
            ),

            if (_depositEnabled) ...[

              if (_depositType == 'percent') ...[

  /// 🔥 區塊：計算方式
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
      style: TextStyle(
        color: Colors.red,
        fontSize: 13,
      ),
    ),
  ),

  const Align(
    alignment: Alignment.centerLeft,
    child: Text(
      '訂金計算方式',
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
  ),

  RadioListTile(
    title: const Text('只算房價'),
    value: 'room',
    groupValue: _depositBase,
    onChanged: (v) {
      setState(() {
        _depositBase = v.toString();
      });
    },
  ),

  RadioListTile(
    title: const Text('算總金額（含加值服務）'),
    value: 'total',
    groupValue: _depositBase,
    onChanged: (v) {
      setState(() {
        _depositBase = v.toString();
      });
    },
  ),

  const Divider(height: 30, thickness: 1),

],

  /// 🔥 選擇類型
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
        child: RadioListTile(
          title: const Text('固定金額'),
          value: 'fixed',
          groupValue: _depositType,
          onChanged: (v) {
            setState(() {
              _depositType = v.toString();
            });
          },
        ),
      ),
      Expanded(
        child: RadioListTile(
  title: const Text('百分比'),
  value: 'percent',
  groupValue: _depositType,
  onChanged: (v) {
    setState(() {
      _depositType = v.toString();

      // 🔥 從固定金額切到百分比時，防止 4000 這種金額被當成 4000%
      if (_depositValue > 100) {
        _depositValue = 100;
        _depositValueCtrl.text = '100';
        _depositValueCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _depositValueCtrl.text.length),
        );
      }

      if (_depositValue < 1) {
        _depositValue = 1;
        _depositValueCtrl.text = '1';
        _depositValueCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _depositValueCtrl.text.length),
        );
      }
    });
  },
),
      ),
    ],
  ),

  /// 🔥 輸入
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
      labelText: _depositType == 'fixed'
          ? '訂金金額（元）'
          : '訂金百分比（%）',
    ),
    onChanged: (v) {
  int value = int.tryParse(v) ?? 0;

  if (_depositType == 'percent') {
    if (value > 100) value = 100;
    if (value < 1) value = 1;
  }

  _depositValue = value;

  // 🔥 同步修正輸入框顯示
  _depositValueCtrl.text = value.toString();
  _depositValueCtrl.selection = TextSelection.fromPosition(
    TextPosition(offset: _depositValueCtrl.text.length),
  );
},
  ),

  const SizedBox(height: 20),
],

            /// 🔥 付款方式
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
              onChanged: (v) => setState(() => _cash = v!),
            ),

            CheckboxListTile(
              title: const Text('轉帳'),
              value: _transfer,
              onChanged: (v) => setState(() => _transfer = v!),
            ),

            const SizedBox(height: 20),

            /// 🔥 銀行資料
            if (_transfer) ...[
              TextField(
                controller: _bankNameCtrl,
                decoration: const InputDecoration(
                  labelText: '銀行名稱',
                ),
              ),
              TextField(
                controller: _accountNameCtrl,
                decoration: const InputDecoration(
                  labelText: '戶名',
                ),
              ),
              TextField(
                controller: _accountNumberCtrl,
                decoration: const InputDecoration(
                  labelText: '帳號',
                ),
              ),
            ],

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _save,
              child: const Text('儲存設定'),
            )
          ],
        ),
      ),
    );
  }
}