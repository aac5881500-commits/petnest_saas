// lib/features/shop/pages/shop_device_page.dart
// 📡 店家設備管理頁
// 功能：房間攝影機設定，管理攝影機網址、啟用狀態與測試開啟

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_device_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ShopDevicePage extends StatelessWidget {
  const ShopDevicePage({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('攝影機設定')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ShopDeviceService.instance.watchDevices(shopId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint(snapshot.error.toString());
            return Center(child: Text(snapshot.error.toString()));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                '尚未建立房間攝影機\n請先到房間管理新增房間，系統會自動建立對應攝影機。',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final name = data['name']?.toString() ?? '未命名攝影機';
              final roomName = data['roomName']?.toString() ?? '';
              final url = data['url']?.toString() ?? '';
              final enabled = data['enabled'] == true;
              final platformLocked = data['platformLocked'] == true;
              final lockedReason = (data['lockedReason'] ?? '').toString();
              final displayTitle = roomName.isNotEmpty ? roomName : name;

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.videocam),
                  title: Row(
                    children: [
                      Expanded(child: Text(displayTitle)),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: platformLocked
                            ? null
                            : () {
                                _showEditDeviceDialog(
                                  context,
                                  shopId,
                                  doc.id,
                                  data,
                                );
                              },
                      ),
                    ],
                  ),
                  subtitle: Text(
                    [
                      '房間攝影機',
                      if (url.isEmpty) '尚未設定網址',
                      if (url.isNotEmpty) '已設定網址',
                      if (!enabled) '未啟用',
                      if (platformLocked)
                        lockedReason.isEmpty ? '平台已鎖定' : '平台已鎖定：$lockedReason',
                    ].join('｜'),
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      Switch(
                        value: enabled,
                        onChanged: platformLocked
                            ? null
                            : (value) {
                                ShopDeviceService.instance.updateDevice(
                                  shopId: shopId,
                                  deviceId: doc.id,
                                  data: {'enabled': value},
                                );
                              },
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_new),
                        onPressed: url.isEmpty
                            ? null
                            : () async {
                                final uri = Uri.tryParse(url);

                                if (uri == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('攝影機網址不正確')),
                                  );
                                  return;
                                }

                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

void _showEditDeviceDialog(
  BuildContext context,
  String shopId,
  String deviceId,
  Map<String, dynamic> data,
) {
  final urlController = TextEditingController(
    text: (data['url'] ?? '').toString(),
  );
  final noteController = TextEditingController(
    text: (data['note'] ?? '').toString(),
  );

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('設定攝影機'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: '攝影機網址',
                  hintText: 'https://...',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: '備註'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final url = urlController.text.trim();

              if (url.isEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('請輸入攝影機網址')));
                return;
              }

              if (!url.startsWith('https://')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('攝影機網址必須是 https://')),
                );
                return;
              }

              await ShopDeviceService.instance.updateDevice(
                shopId: shopId,
                deviceId: deviceId,
                data: {
                  'url': url,
                  'note': noteController.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                },
              );

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('儲存'),
          ),
        ],
      );
    },
  );
}
