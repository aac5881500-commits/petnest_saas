// lib/features/shop/pages/shop_device_page.dart
// 📡 店家設備管理頁
// 功能：管理房間攝影機網址、啟用狀態、前台顯示開關與攝影機相容性說明

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_device_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:petnest_saas/core/utils/natural_sort.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';

class ShopDevicePage extends StatelessWidget {
  const ShopDevicePage({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('攝影機設定'),
        actions: <Widget>[ShopTaskCenterButton(shopId: shopId)],
      ),
      body: Column(
        children: [
          // 前台攝影機總開關
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('shops')
                .doc(shopId)
                .snapshots(),
            builder: (context, shopSnapshot) {
              final shopData = shopSnapshot.data?.data();

              final showCameraSection = shopData?['showCameraSection'] != false;

              return Card(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: SwitchListTile(
                  secondary: const Icon(Icons.videocam_outlined),
                  title: const Text('前台顯示攝影機'),
                  subtitle: Text(
                    showCameraSection ? '會員前台會顯示「觀看攝影機」按鈕' : '會員前台不顯示攝影機按鈕',
                  ),
                  value: showCameraSection,
                  onChanged: (value) async {
                    try {
                      await FirebaseFirestore.instance
                          .collection('shops')
                          .doc(shopId)
                          .update({
                            'showCameraSection': value,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                    } on FirebaseException catch (error) {
                      debugPrint(
                        '更新 showCameraSection 失敗：'
                        '${error.code}｜${error.message}',
                      );

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('攝影機開關儲存失敗：${error.code}')),
                      );
                    } catch (error) {
                      debugPrint('更新 showCameraSection 失敗：$error');

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('攝影機開關儲存失敗')),
                      );
                    }
                  },
                ),
              );
            },
          ),

          // 攝影機相容性提醒
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade500, width: 1.5),
            ),
            child: ListTile(
              leading: Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade900,
                size: 30,
              ),
              title: Text(
                '使用前請確認攝影機是否支援',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.orange.shade900,
                ),
              ),
              subtitle: Text(
                '大部分家用 Wi-Fi 攝影機無法直接使用',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: Colors.orange.shade900,
              ),
              onTap: () {
                _showCameraCompatibilitySheet(context);
              },
            ),
          ),

          // 房間攝影機列表
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ShopDeviceService.instance.watchDevices(shopId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint(snapshot.error.toString());

                  return Center(child: Text(snapshot.error.toString()));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = [...snapshot.data!.docs]
                  ..sort((a, b) {
                    final aData = a.data();
                    final bData = b.data();

                    final aRoomName = (aData['roomName'] ?? aData['name'] ?? '')
                        .toString();

                    final bRoomName = (bData['roomName'] ?? bData['name'] ?? '')
                        .toString();

                    return _compareRoomCodeByDigitGroup(aRoomName, bRoomName);
                  });

                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        '尚未建立房間攝影機\n'
                        '請先到房間管理新增房間，'
                        '系統會自動建立對應攝影機。',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) {
                    return const SizedBox(height: 12);
                  },
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();

                    final name = data['name']?.toString() ?? '未命名攝影機';

                    final roomName = data['roomName']?.toString() ?? '';

                    final url = data['url']?.toString() ?? '';

                    final enabled = data['enabled'] == true;

                    final platformLocked = data['platformLocked'] == true;

                    final lockedReason = (data['lockedReason'] ?? '')
                        .toString();

                    final displayTitle = roomName.isNotEmpty ? roomName : name;

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.videocam),
                        title: Row(
                          children: [
                            Expanded(child: Text(displayTitle)),
                            IconButton(
                              tooltip: '編輯攝影機',
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
                              lockedReason.isEmpty
                                  ? '平台已鎖定'
                                  : '平台已鎖定：$lockedReason',
                          ].join('｜'),
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Switch(
                              value: enabled,
                              onChanged: platformLocked
                                  ? null
                                  : (value) async {
                                      try {
                                        await ShopDeviceService.instance
                                            .updateDevice(
                                              shopId: shopId,
                                              deviceId: doc.id,
                                              data: {'enabled': value},
                                            );
                                      } catch (error) {
                                        debugPrint('更新攝影機啟用狀態失敗：$error');

                                        if (!context.mounted) return;

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('攝影機狀態更新失敗'),
                                          ),
                                        );
                                      }
                                    },
                            ),
                            IconButton(
                              tooltip: '測試開啟網址',
                              icon: const Icon(Icons.open_in_new),
                              onPressed: url.isEmpty
                                  ? null
                                  : () async {
                                      final uri = Uri.tryParse(url);

                                      if (uri == null ||
                                          uri.scheme != 'https' ||
                                          uri.host.isEmpty) {
                                        if (!context.mounted) return;

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('攝影機網址不正確'),
                                          ),
                                        );
                                        return;
                                      }

                                      final launched = await launchUrl(
                                        uri,
                                        mode: LaunchMode.externalApplication,
                                      );

                                      if (!launched && context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('無法開啟攝影機網址'),
                                          ),
                                        );
                                      }
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
          ),
        ],
      ),
    );
  }
}

void _showCameraCompatibilitySheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange.shade900,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '攝影機相容性說明',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '關閉',
                        onPressed: () {
                          Navigator.pop(sheetContext);
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: const Text(
                          '⚠ 並非所有攝影機都能使用\n\n'
                          'PetNest 不會直接連接攝影機品牌系統，'
                          '而是使用店家提供的「瀏覽器觀看網址」，'
                          '讓入住會員開啟攝影機畫面。',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        '✅ 符合以下條件即可使用',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '• 攝影機或監控系統可提供 HTTPS 網頁觀看網址\n'
                        '• 網址可直接使用 Chrome、Safari 或 Edge 開啟\n'
                        '• 不需要安裝原廠 App\n'
                        '• 不需要登入原廠 App\n'
                        '• 使用店外網路也能正常開啟\n'
                        '• 會員點擊網址後可以直接看到畫面',
                        style: TextStyle(height: 1.7),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade300),
                        ),
                        child: const Text(
                          '📹 可能可以使用的設備類型\n\n'
                          '• 提供 Web Viewer 的企業級 IP Camera\n'
                          '• 提供 HTTPS 分享網址的 NVR 監控主機\n'
                          '• 提供網頁分享功能的 NAS 監控系統\n'
                          '• 可建立外部觀看頁面的監控平台\n\n'
                          '是否能使用，仍以設備能否提供「可直接用瀏覽器開啟的 HTTPS 網址」為準。',
                          style: TextStyle(height: 1.6),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        '❌ 以下情況無法直接使用',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '• 只能透過手機 App 觀看\n'
                        '• 沒有瀏覽器觀看網址\n'
                        '• 必須安裝品牌專用程式\n'
                        '• 必須登入原廠 App\n'
                        '• 只能在店內 Wi-Fi 使用\n'
                        '• 只提供 RTSP、RTMP 或內網 IP 網址\n'
                        '• 離開店內網路後無法開啟',
                        style: TextStyle(height: 1.7),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade400),
                        ),
                        child: const Text(
                          '📌 常見家用品牌提醒\n\n'
                          '小米米家、TP-Link Tapo、Google Nest、'
                          'Ring、Arlo、Eufy、Blink、EZVIZ 等家用攝影機，'
                          '多數型號預設只能透過官方 App 觀看，'
                          '因此通常無法直接搭配 PetNest 使用。\n\n'
                          '若特定型號另外提供 HTTPS 網頁觀看網址，則仍可使用。',
                          style: TextStyle(height: 1.6),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade400),
                        ),
                        child: const Text(
                          '💡 如何自行測試\n\n'
                          '1. 把攝影機網址貼到 Chrome、Safari 或 Edge\n'
                          '2. 關閉店內 Wi-Fi，改用手機行動網路\n'
                          '3. 確認不需安裝或登入原廠 App\n'
                          '4. 確認可以直接看到攝影機畫面\n\n'
                          '以上條件都符合，才適合搭配 PetNest 使用。\n\n'
                          '若無法直接觀看，請關閉「前台顯示攝影機」功能。',
                          style: TextStyle(height: 1.6),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
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

  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('設定攝影機'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: '攝影機網址',
                  hintText: 'https://...',
                  helperText: '必須是可直接用瀏覽器開啟的 HTTPS 網址',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '備註'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
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

              final uri = Uri.tryParse(url);

              if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('請輸入有效的 HTTPS 攝影機網址')),
                );
                return;
              }

              try {
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
              } catch (error) {
                debugPrint('儲存攝影機設定失敗：$error');

                if (!context.mounted) return;

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('攝影機設定儲存失敗')));
              }
            },
            child: const Text('儲存'),
          ),
        ],
      );
    },
  ).whenComplete(() {
    urlController.dispose();
    noteController.dispose();
  });
}

int _compareRoomCodeByDigitGroup(String first, String second) {
  final pattern = RegExp(r'^(.*?)(\d+)$');

  final firstMatch = pattern.firstMatch(first.trim());
  final secondMatch = pattern.firstMatch(second.trim());

  if (firstMatch == null || secondMatch == null) {
    return naturalCompare(first, second);
  }

  final firstPrefix = firstMatch.group(1) ?? '';
  final secondPrefix = secondMatch.group(1) ?? '';

  final prefixResult = firstPrefix.toLowerCase().compareTo(
    secondPrefix.toLowerCase(),
  );

  if (prefixResult != 0) {
    return prefixResult;
  }

  final firstDigits = firstMatch.group(2) ?? '';
  final secondDigits = secondMatch.group(2) ?? '';

  // 先按照數字位數分組：
  // A1、A2 排在 A01、A02 前面
  final digitLengthResult = firstDigits.length.compareTo(secondDigits.length);

  if (digitLengthResult != 0) {
    return digitLengthResult;
  }

  final firstNumber = int.tryParse(firstDigits) ?? 0;
  final secondNumber = int.tryParse(secondDigits) ?? 0;

  return firstNumber.compareTo(secondNumber);
}
