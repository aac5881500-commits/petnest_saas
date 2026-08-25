// lib/features/platform/pages/platform_shop_device_manage_page.dart
// 📡 平台後台：單店設備管理頁
// 功能：平台查看與鎖定單一店家的攝影機 / 設備

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/platform_permission_keys.dart';
import '../../../core/services/platform_admin_service.dart';
import 'package:petnest_saas/core/services/shop_device_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PlatformShopDeviceManagePage extends StatelessWidget {
  const PlatformShopDeviceManagePage({
    super.key,
    required this.shopId,
    required this.shopName,
  });

  final String shopId;
  final String shopName;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: PlatformAdminService.instance.hasPermission(
        PlatformPermissionKeys.manageShopStatus,
      ),
      builder: (context, permissionSnapshot) {
        if (permissionSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final canManageShopStatus = permissionSnapshot.data ?? false;

        if (!canManageShopStatus) {
          return const Scaffold(body: Center(child: Text('你沒有設備管理權限')));
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('$shopName｜設備管理'),
            actions: [
              IconButton(
                tooltip: '一鍵開啟全部攝影機',
                icon: const Icon(Icons.videocam),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) {
                      return AlertDialog(
                        title: const Text('一鍵開啟全部攝影機'),
                        content: const Text('確定要解除鎖定，並開啟這間店的所有攝影機嗎？'),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('取消'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('確認開啟'),
                          ),
                        ],
                      );
                    },
                  );

                  if (ok != true) return;

                  await ShopDeviceService.instance.platformUnlockAllCameras(
                    shopId: shopId,
                  );

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已解除鎖定並開啟全部攝影機')),
                  );
                },
              ),
              IconButton(
                tooltip: '一鍵關閉全部攝影機',
                icon: const Icon(Icons.videocam_off),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) {
                      return AlertDialog(
                        title: const Text('一鍵關閉全部攝影機'),
                        content: const Text(
                          '確定要關閉並鎖定這間店的所有攝影機嗎？\n店家將無法自行重新開啟。',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('取消'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('確認關閉'),
                          ),
                        ],
                      );
                    },
                  );

                  if (ok != true) return;

                  await ShopDeviceService.instance.platformLockAllCameras(
                    shopId: shopId,
                  );

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已關閉並鎖定全部攝影機')));
                },
              ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('shops')
                .doc(shopId)
                .collection('devices')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('讀取設備失敗：${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return const Center(child: Text('此店家尚未新增設備'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();

                  final type = (data['type'] ?? 'device').toString();
                  final name = (data['name'] ?? '未命名設備').toString();
                  final roomName = (data['roomName'] ?? '').toString();
                  final url = (data['url'] ?? '').toString();
                  final enabled = data['enabled'] == true;
                  final platformLocked = data['platformLocked'] == true;
                  final lockedReason = (data['lockedReason'] ?? '').toString();

                  return Card(
                    elevation: 0,
                    color: platformLocked ? Colors.red.shade50 : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: platformLocked
                            ? Colors.red.shade100
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                type == 'camera'
                                    ? Icons.videocam
                                    : Icons.sensors,
                                color: platformLocked
                                    ? Colors.red
                                    : Colors.blueGrey,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Switch(
                                value: platformLocked,
                                activeColor: Colors.red,
                                onChanged: (value) async {
                                  if (value) {
                                    final reason = await _showLockReasonDialog(
                                      context,
                                    );
                                    if (reason == null) return;

                                    await doc.reference.update({
                                      'platformLocked': true,
                                      'lockedReason': reason,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    });
                                  } else {
                                    await doc.reference.update({
                                      'platformLocked': false,
                                      'lockedReason': '',
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('類型：${type == 'camera' ? '攝影機' : type}'),
                          if (roomName.isNotEmpty) Text('綁定房間：$roomName'),
                          Text('店家啟用：${enabled ? '是' : '否'}'),
                          Text('平台鎖定：${platformLocked ? '是' : '否'}'),
                          if (lockedReason.isNotEmpty)
                            Text('鎖定原因：$lockedReason'),
                          if (url.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final uri = Uri.tryParse(url);

                                  if (uri == null ||
                                      !url.startsWith('https://')) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('網址格式不正確，請店家重新設定'),
                                      ),
                                    );
                                    return;
                                  }

                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                },
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('檢查網址'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

Future<String?> _showLockReasonDialog(BuildContext context) async {
  final controller = TextEditingController();

  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('鎖定設備原因'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '原因',
            hintText: '例如：連結異常、違規內容、資安風險',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(dialogContext, reason);
            },
            child: const Text('確認鎖定'),
          ),
        ],
      );
    },
  );

  controller.dispose();
  return result;
}
