// 檔案名稱：lib/features/admin/widgets/admin_quick_create_member_dialog.dart
// 功能說明：手動新增訂單時，讓店家快速建立會員基本資料，地址改為縣市/區域下拉
// 👤 後台快速建立會員彈窗

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/taiwan_city_data.dart';

class AdminQuickCreateMemberDialog extends StatefulWidget {
  const AdminQuickCreateMemberDialog({super.key, required this.defaultPhone});

  final String defaultPhone;

  @override
  State<AdminQuickCreateMemberDialog> createState() =>
      _AdminQuickCreateMemberDialogState();
}

class _AdminQuickCreateMemberDialogState
    extends State<AdminQuickCreateMemberDialog> {
  final TextEditingController _nameController = TextEditingController();
  late final TextEditingController _phoneController;

  String? _city;
  String? _district;
  final TextEditingController _detailAddressController =
      TextEditingController();

  final TextEditingController _emergencyNameController =
      TextEditingController();
  final TextEditingController _emergencyPhoneController =
      TextEditingController();

  String _emergencyRelation = '父母';

  final TextEditingController _emergencyAddressController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.defaultPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _detailAddressController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyAddressController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入會員姓名')));
      return;
    }

    if (phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入手機號碼')));
      return;
    }

    if (!RegExp(r'^09\d{8}$').hasMatch(phone)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('手機號碼格式錯誤，請輸入 09 開頭共 10 碼')));
      return;
    }

    final fullAddress =
        '${_city ?? ''}${_district ?? ''}${_detailAddressController.text.trim()}';

    Navigator.pop(context, {
      'name': name,
      'phone': phone,
      'address': fullAddress,
      'emergencyName': _emergencyNameController.text.trim(),
      'emergencyPhone': _emergencyPhoneController.text.trim(),
      'emergencyRelation': _emergencyRelation,
      'emergencyAddress': _emergencyAddressController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('快速建立會員'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '會員姓名（必填）',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: const InputDecoration(
                labelText: '手機號碼（必填）',
                hintText: '09xxxxxxxx',
                counterText: '',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _city,
              decoration: const InputDecoration(
                labelText: '縣市',
                border: OutlineInputBorder(),
              ),
              items: cityData.keys.map((city) {
                return DropdownMenuItem<String>(value: city, child: Text(city));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _city = value;
                  _district = null;
                });
              },
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _district,
              decoration: const InputDecoration(
                labelText: '區域',
                border: OutlineInputBorder(),
              ),
              items: (_city == null ? <String>[] : cityData[_city]!).map((
                district,
              ) {
                return DropdownMenuItem<String>(
                  value: district,
                  child: Text(district),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _district = value;
                });
              },
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _detailAddressController,
              decoration: const InputDecoration(
                labelText: '詳細地址',
                hintText: '例如：中正路 1 號',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _emergencyNameController,
              decoration: const InputDecoration(
                labelText: '緊急聯絡人',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _emergencyPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '緊急聯絡電話',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _emergencyRelation,
              decoration: const InputDecoration(
                labelText: '關係',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '父母', child: Text('父母')),
                DropdownMenuItem(value: '夫妻', child: Text('夫妻')),
                DropdownMenuItem(value: '配偶', child: Text('配偶')),
                DropdownMenuItem(value: '兄弟姊妹', child: Text('兄弟姊妹')),
                DropdownMenuItem(value: '情侶', child: Text('情侶')),
                DropdownMenuItem(value: '朋友', child: Text('朋友')),
              ],
              onChanged: (value) {
                setState(() {
                  _emergencyRelation = value ?? '父母';
                });
              },
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _emergencyAddressController,
              decoration: const InputDecoration(
                labelText: '緊急聯絡地址',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('建立')),
      ],
    );
  }
}
