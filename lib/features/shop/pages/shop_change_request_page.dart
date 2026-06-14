// lib/features/shop/pages/shop_change_request_page.dart
// 📨 重要資料修改申請
// 功能：店家送出電話、地址、統編、特寵字號修改申請

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShopChangeRequestPage extends StatefulWidget {
  const ShopChangeRequestPage({
    super.key,
    required this.shopId,
    required this.shopName,
    required this.currentPhone,
    required this.currentAddress,
    required this.currentLicenseNumber,
    required this.currentTaxId,
  });

  final String shopId;
  final String shopName;

  @override
  State<ShopChangeRequestPage> createState() => _ShopChangeRequestPageState();
}

class _ShopChangeRequestPageState extends State<ShopChangeRequestPage> {
  final _reasonController = TextEditingController();
  final _newValueController = TextEditingController();

  String _requestType = 'phone';

  Future<void> _submitRequest() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請填寫修改原因')));
      return;
    }

    if (_newValueController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請填寫要修改的新資料')));
      return;
    }

    await FirebaseFirestore.instance.collection('shop_change_requests').add({
      'shopId': widget.shopId,
      'shopName': widget.shopName,

      'requestType': _requestType,
      'newValue': _newValueController.text.trim(),
      'reason': _reasonController.text.trim(),

      'status': 'pending',

      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('申請已送出')));

    Navigator.pop(context);
  }

  String _currentValueText() {
    switch (_requestType) {
      case 'name':
        return widget.shopName;
      case 'phone':
        return widget.currentPhone;
      case 'address':
        return widget.currentAddress;
      case 'licenseNumber':
        return widget.currentLicenseNumber;
      case 'taxId':
        return widget.currentTaxId;
      default:
        return '';
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _newValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('重要資料修改申請')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _requestType,
            decoration: const InputDecoration(
              labelText: '申請類型',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'name', child: Text('店名修改')),
              DropdownMenuItem(value: 'phone', child: Text('電話修改')),
              DropdownMenuItem(value: 'address', child: Text('地址修改')),
              DropdownMenuItem(value: 'licenseNumber', child: Text('特寵字號修改')),
              DropdownMenuItem(value: 'taxId', child: Text('統編修改')),
            ],
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                _requestType = value;
              });
            },
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              '目前資料：${_currentValueText().isEmpty ? '尚未設定' : _currentValueText()}',
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: _newValueController,
            maxLines: _requestType == 'address' ? 2 : 1,
            keyboardType: _requestType == 'phone'
                ? TextInputType.phone
                : TextInputType.text,
            decoration: InputDecoration(
              labelText: _requestType == 'name'
                  ? '新店名'
                  : _requestType == 'phone'
                  ? '新電話'
                  : _requestType == 'address'
                  ? '新地址'
                  : _requestType == 'licenseNumber'
                  ? '新特寵字號'
                  : _requestType == 'taxId'
                  ? '新統編'
                  : '申請修改後的新資料',
              border: const OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: _reasonController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '修改原因',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),

          ElevatedButton(onPressed: _submitRequest, child: const Text('送出申請')),
        ],
      ),
    );
  }
}
