// 檔案名稱：lib/features/booking/widgets/booking_detail/booking_detail_camera_section.dart
// 功能說明：入住中訂單顯示房間攝影機入口
// 📹 客戶端訂單詳情：攝影機觀看區塊

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_device_service.dart';
import 'package:url_launcher/url_launcher.dart';

class BookingDetailCameraSection extends StatelessWidget {
  const BookingDetailCameraSection({
    super.key,
    required this.data,
    required this.bookingStatus,
  });

  final Map<String, dynamic> data;
  final String bookingStatus;

  @override
  Widget build(BuildContext context) {
    final shopId = (data['shopId'] ?? '').toString();
    final roomId = (data['roomId'] ?? '').toString();

    if (bookingStatus != 'checked_in') return const SizedBox.shrink();
    if (shopId.isEmpty || roomId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ShopDeviceService.instance.watchCameraDevicesByRoom(
        shopId: shopId,
        roomId: roomId,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();
        if (!snapshot.hasData) return const SizedBox.shrink();

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const SizedBox.shrink();

        final camera = docs.first.data();
        final cameraName = (camera['name'] ?? '房間攝影機').toString();
        final url = (camera['url'] ?? '').toString();

        if (url.isEmpty) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blueGrey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.videocam, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cameraName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '此攝影機由店家提供，點擊後將開啟外部觀看頁面。',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('觀看攝影機'),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) {
                        return AlertDialog(
                          title: const Text('前往外部攝影機頁面'),
                          content: const Text('即將開啟店家提供的攝影機連結，請確認是否前往。'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('取消'),
                            ),
                            ElevatedButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('前往'),
                            ),
                          ],
                        );
                      },
                    );

                    if (confirm != true) return;

                    final uri = Uri.tryParse(url);
                    if (uri == null) return;

                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
