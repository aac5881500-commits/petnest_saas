// lib/features/platform/pages/platform_send_shop_notification_page.dart
// 🔔 平台發送店家通知
// 功能：平台後台直接發送通知給指定店家

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PlatformSendShopNotificationPage extends StatefulWidget {
  const PlatformSendShopNotificationPage({
    super.key,
    required this.shopId,
    required this.shopName,
  });

  final String shopId;
  final String shopName;

  @override
  State<PlatformSendShopNotificationPage> createState() =>
      _PlatformSendShopNotificationPageState();
}

class _PlatformSendShopNotificationPageState
    extends State<PlatformSendShopNotificationPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  bool _isSending = false;

  String _type = 'system';

  final List<Map<String, String>> _types = [
    {'value': 'system', 'label': '系統通知'},
    {'value': 'plan', 'label': '方案通知'},
    {'value': 'review', 'label': '審核通知'},
    {'value': 'warning', 'label': '違規提醒'},
    {'value': 'suspend', 'label': '停權通知'},
    {'value': 'update', 'label': '功能更新'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入標題')));
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await FirebaseFirestore.instance.collection('shop_notifications').add({
        'shopId': widget.shopId,
        'shopName': widget.shopName,
        'type': _type,
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'status': 'unread',
        'createdAt': FieldValue.serverTimestamp(),
        'readAt': null,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('通知已送出')));

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('送出失敗：$e')));
    }

    if (mounted) {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: Text('通知 ${widget.shopName}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(
              labelText: '通知類型',
              border: OutlineInputBorder(),
            ),
            items: _types
                .map(
                  (e) => DropdownMenuItem(
                    value: e['value'],
                    child: Text(e['label']!),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                _type = value;
              });
            },
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '通知標題',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _contentController,
            minLines: 6,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: '通知內容',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _isSending ? null : _send,
              icon: const Icon(Icons.send),
              label: Text(_isSending ? '送出中...' : '送出通知'),
            ),
          ),
        ],
      ),
    );
  }
}
