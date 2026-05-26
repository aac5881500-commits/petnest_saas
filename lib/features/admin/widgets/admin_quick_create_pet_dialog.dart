// lib/features/admin/widgets/admin_quick_create_pet_dialog.dart
// 🐾 後台快速建立寵物彈窗
// 功能：手動新增訂單時，讓店家快速建立會員寵物資料

import 'package:flutter/material.dart';

class AdminQuickCreatePetDialog extends StatefulWidget {
  const AdminQuickCreatePetDialog({super.key});

  @override
  State<AdminQuickCreatePetDialog> createState() =>
      _AdminQuickCreatePetDialogState();
}

class _AdminQuickCreatePetDialogState
    extends State<AdminQuickCreatePetDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _type = 'cat';
  String _gender = '母貓';
  String _age = '未填';
  String _neuterStatus = '未結紮';
  String _medicalStatus = '未填';
  String _litterType = '未填';

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    Navigator.pop(context, {
      'name': name,
      'type': _type,
      'breed': _breedController.text.trim(),
      'gender': _gender,
      'age': _age,
      'isNeutered': _neuterStatus == '已結紮',
      'vaccine': _medicalStatus,
      'litterType': _litterType,
      'note': _noteController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('快速建立寵物'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '寵物名字',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _breedController,
              decoration: const InputDecoration(
                labelText: '品種',
                hintText: '例如：米克斯、英短、布偶',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(
                labelText: '性別',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '公貓', child: Text('公貓')),
                DropdownMenuItem(value: '母貓', child: Text('母貓')),
                DropdownMenuItem(value: '未填', child: Text('未填')),
              ],
              onChanged: (value) {
                setState(() {
                  _gender = value ?? '母貓';
                });
              },
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _age,
              decoration: const InputDecoration(
                labelText: '年齡',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '未填', child: Text('未填')),
                DropdownMenuItem(value: '1歲以下', child: Text('1歲以下')),
                DropdownMenuItem(value: '1～3歲', child: Text('1～3歲')),
                DropdownMenuItem(value: '4～7歲', child: Text('4～7歲')),
                DropdownMenuItem(value: '8～11歲', child: Text('8～11歲')),
                DropdownMenuItem(value: '12歲以上', child: Text('12歲以上')),
              ],
              onChanged: (value) {
                setState(() {
                  _age = value ?? '未填';
                });
              },
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _neuterStatus,
              decoration: const InputDecoration(
                labelText: '結紮狀況',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '未結紮', child: Text('未結紮')),
                DropdownMenuItem(value: '已結紮', child: Text('已結紮')),
                DropdownMenuItem(value: '未填', child: Text('未填')),
              ],
              onChanged: (value) {
                setState(() {
                  _neuterStatus = value ?? '未結紮';
                });
              },
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _medicalStatus,
              decoration: const InputDecoration(
                labelText: '醫療狀況',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '未填', child: Text('未填')),
                DropdownMenuItem(value: '健康', child: Text('健康')),
                DropdownMenuItem(value: '糖尿病', child: Text('糖尿病')),
                DropdownMenuItem(value: '腎臟病', child: Text('腎臟病')),
                DropdownMenuItem(value: '需每日餵藥', child: Text('需每日餵藥')),
                DropdownMenuItem(value: '其他', child: Text('其他')),
              ],
              onChanged: (value) {
                setState(() {
                  _medicalStatus = value ?? '未填';
                });
              },
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _litterType,
              decoration: const InputDecoration(
                labelText: '貓砂種類',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '未填', child: Text('未填')),
                DropdownMenuItem(value: '豆腐砂', child: Text('豆腐砂')),
                DropdownMenuItem(value: '礦砂', child: Text('礦砂')),
                DropdownMenuItem(value: '木屑砂', child: Text('木屑砂')),
                DropdownMenuItem(value: '水晶砂', child: Text('水晶砂')),
              ],
              onChanged: (value) {
                setState(() {
                  _litterType = value ?? '未填';
                });
              },
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '其他備註',
                hintText: '例如：怕生、需注意飲食、固定餵藥時間...',
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