// lib/features/shop/pages/shop_payout_setting_page.dart
// 🏦 收款帳戶 / 金流設定頁
// 功能：管理店家的銀行轉帳收款資料，未來可擴充第三方金流設定

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShopPayoutSettingPage extends StatefulWidget {
  const ShopPayoutSettingPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopPayoutSettingPage> createState() => _ShopPayoutSettingPageState();
}

class _ShopPayoutSettingPageState extends State<ShopPayoutSettingPage> {
  final _bankNameCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

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
    super.dispose();
  }

  Future<void> _loadData() async {
    final doc = await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .get();

    final data = doc.data() ?? {};

    _bankNameCtrl.text = (data['bankName'] ?? '').toString();
    _accountNameCtrl.text = (data['accountName'] ?? '').toString();
    _accountNumberCtrl.text = (data['accountNumber'] ?? '').toString();

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .update({
          'bankName': _bankNameCtrl.text.trim(),
          'accountName': _accountNameCtrl.text.trim(),
          'accountNumber': _accountNumberCtrl.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

    if (!mounted) return;

    setState(() => _saving = false);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('收款資料已儲存')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('收款帳戶 / 金流設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: const Text(
              '目前先設定銀行轉帳收款資料；未來第三方金流、平台代收或撥款設定也會放在這裡。',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 20),

          TextField(
            controller: _bankNameCtrl,
            decoration: const InputDecoration(
              labelText: '銀行名稱',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _accountNameCtrl,
            decoration: const InputDecoration(
              labelText: '戶名',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _accountNumberCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '帳號',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? '儲存中...' : '儲存收款資料'),
            ),
          ),
        ],
      ),
    );
  }
}
