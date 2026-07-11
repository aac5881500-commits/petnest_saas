// lib/features/shop/pages/shop_change_request_page.dart
// 📨 重要資料修改申請
// 功能：店家送出店名、電話、地址與社群連結修改申請

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/constants/taiwan_city_data.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ShopChangeRequestPage extends StatefulWidget {
  const ShopChangeRequestPage({
    super.key,
    required this.shopId,
    required this.shopName,
    required this.currentPhone,
    required this.currentAddress,
    required this.currentCity,
    required this.currentDistrict,
    required this.currentLicenseNumber,
    required this.currentTaxId,
    required this.currentLineUrl,
    required this.currentIgUrl,
    required this.currentFbUrl,
  });

  final String shopId;
  final String shopName;
  final String currentPhone;
  final String currentCity;
  final String currentDistrict;
  final String currentAddress;
  final String currentLicenseNumber;
  final String currentTaxId;
  final String currentLineUrl;
  final String currentIgUrl;
  final String currentFbUrl;

  @override
  State<ShopChangeRequestPage> createState() => _ShopChangeRequestPageState();
}

class _ShopChangeRequestPageState extends State<ShopChangeRequestPage> {
  final _reasonController = TextEditingController();
  final _newValueController = TextEditingController();

  String _requestType = 'phone';
  String _newCity = '新竹縣';
  String _newDistrict = '新埔鎮';

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

    if (_requestType == 'lineUrl' ||
        _requestType == 'igUrl' ||
        _requestType == 'fbUrl') {
      final error = _validateSocialUrl(
        value: _newValueController.text,
        type: _requestType,
      );

      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
    }

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請重新登入後再送出申請')));
      return;
    }

    final duplicateQuery = await FirebaseFirestore.instance
        .collection('shop_change_requests')
        .where('shopId', isEqualTo: widget.shopId)
        .where('requestType', isEqualTo: _requestType)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (duplicateQuery.docs.isNotEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此項目已有審核中的申請，請先等待審核或取消原申請')));
      return;
    }

    await FirebaseFirestore.instance.collection('shop_change_requests').add({
      'shopId': widget.shopId,
      'shopName': widget.shopName,
      'currentValue': _currentValueText(),
      'applicantEmail': currentUser.email ?? '',
      'applicantUid': currentUser.uid,

      'requestType': _requestType,

      'newValue': _requestType == 'address'
          ? '$_newCity $_newDistrict ${_newValueController.text.trim()}'
          : _newValueController.text.trim(),

      'newCity': _requestType == 'address' ? _newCity : null,
      'newDistrict': _requestType == 'address' ? _newDistrict : null,
      'newAddress': _requestType == 'address'
          ? _newValueController.text.trim()
          : null,

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

  String? _validateSocialUrl({required String value, required String type}) {
    final text = value.trim();

    if (text.isEmpty) return '請輸入網址';

    final uri = Uri.tryParse(text);

    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return '請輸入完整網址，例如 https://...';
    }

    final host = uri.host.toLowerCase();

    if (type == 'lineUrl') {
      if (host == 'line.me' ||
          host == 'www.line.me' ||
          host == 'page.line.me' ||
          host == 'lin.ee') {
        return null;
      }

      return 'LINE 連結只能使用 line.me、page.line.me 或 lin.ee';
    }

    if (type == 'igUrl') {
      if (host == 'instagram.com' || host == 'www.instagram.com') {
        return null;
      }

      return 'IG 連結只能使用 instagram.com';
    }

    if (type == 'fbUrl') {
      if (host == 'facebook.com' ||
          host == 'www.facebook.com' ||
          host == 'fb.me') {
        return null;
      }

      return 'FB 連結只能使用 facebook.com 或 fb.me';
    }

    return null;
  }

  String _currentValueText() {
    switch (_requestType) {
      case 'name':
        return widget.shopName;
      case 'phone':
        return widget.currentPhone;
      case 'address':
        return '${widget.currentCity} ${widget.currentDistrict}\n${widget.currentAddress}';
      case 'lineUrl':
        return widget.currentLineUrl;
      case 'igUrl':
        return widget.currentIgUrl;
      case 'fbUrl':
        return widget.currentFbUrl;
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
              DropdownMenuItem(value: 'lineUrl', child: Text('LINE 連結修改')),
              DropdownMenuItem(value: 'igUrl', child: Text('IG 連結修改')),
              DropdownMenuItem(value: 'fbUrl', child: Text('FB 連結修改')),
            ],
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                _requestType = value;

                if (_requestType == 'address') {
                  _newCity = '新竹縣';
                  _newDistrict = '新埔鎮';
                }

                _newValueController.clear();
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

          if (_requestType == 'address') ...[
            DropdownButtonFormField<String>(
              value: _newCity,
              decoration: const InputDecoration(
                labelText: '新縣市',
                border: OutlineInputBorder(),
              ),
              items: cityData.keys
                  .map(
                    (city) => DropdownMenuItem(value: city, child: Text(city)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _newCity = value;
                  _newDistrict = cityData[value]!.first;
                });
              },
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _newDistrict,
              decoration: const InputDecoration(
                labelText: '新區域',
                border: OutlineInputBorder(),
              ),
              items: (cityData[_newCity] ?? [])
                  .map(
                    (district) => DropdownMenuItem(
                      value: district,
                      child: Text(district),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _newDistrict = value;
                });
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _newValueController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '新詳細地址',
                border: OutlineInputBorder(),
              ),
            ),
          ] else ...[
            TextFormField(
              controller: _newValueController,
              maxLines: 1,
              keyboardType: _requestType == 'phone'
                  ? TextInputType.phone
                  : TextInputType.text,
              decoration: InputDecoration(
                labelText: _requestType == 'name'
                    ? '新店名'
                    : _requestType == 'phone'
                    ? '新電話'
                    : _requestType == 'lineUrl'
                    ? '新 LINE 連結'
                    : _requestType == 'igUrl'
                    ? '新 IG 連結'
                    : _requestType == 'fbUrl'
                    ? '新 FB 連結'
                    : '申請修改後的新資料',
                border: const OutlineInputBorder(),
              ),
            ),
          ],

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
