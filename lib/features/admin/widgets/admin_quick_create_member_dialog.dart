// lib/features/admin/widgets/admin_quick_create_member_dialog.dart
// 👤 後台快速建立會員彈窗
// 功能：手動新增訂單時，讓店家快速建立會員基本資料

import 'package:flutter/material.dart';

class AdminQuickCreateMemberDialog extends StatefulWidget {
  const AdminQuickCreateMemberDialog({
    super.key,
    required this.defaultPhone,
  });

  final String defaultPhone;

  @override
  State<AdminQuickCreateMemberDialog> createState() =>
      _AdminQuickCreateMemberDialogState();
}

class _AdminQuickCreateMemberDialogState
    extends State<AdminQuickCreateMemberDialog> {
  final TextEditingController _nameController = TextEditingController();
  late final TextEditingController _phoneController;
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emergencyNameController =
      TextEditingController();
  final TextEditingController _emergencyPhoneController =
      TextEditingController();
  final TextEditingController _emergencyRelationController =
      TextEditingController();
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
    _addressController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationController.dispose();
    _emergencyAddressController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) return;

    Navigator.pop(context, {
      'name': name,
      'phone': phone,
      'address': _addressController.text.trim(),
      'emergencyName': _emergencyNameController.text.trim(),
      'emergencyPhone': _emergencyPhoneController.text.trim(),
      'emergencyRelation': _emergencyRelationController.text.trim(),
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
                labelText: '會員姓名',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '手機號碼',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: '地址',
                hintText: '例如：新竹縣新埔鎮...',
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

            TextField(
              controller: _emergencyRelationController,
              decoration: const InputDecoration(
                labelText: '關係',
                hintText: '例如：家人、朋友、配偶',
                border: OutlineInputBorder(),
              ),
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
        ElevatedButton(
          onPressed: _submit,
          child: const Text('建立'),
        ),
      ],
    );
  }
}