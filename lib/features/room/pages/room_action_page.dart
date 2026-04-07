// lib/features/room/pages/room_action_page.dart
// 🛠 房務操作頁（入住 / 退房 / 狀態）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class RoomActionPage extends StatelessWidget {
  const RoomActionPage({
    super.key,
required this.shopId,
required this.roomId,
required this.roomName,
required this.date,
  });

final String shopId;
final String roomId;
final String roomName;
final String date;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$roomName - $date'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            /// 🟦 入住
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
               onPressed: () async {
  await ShopService.instance.setRoomStatus(
    shopId: shopId,
    roomId: roomId,
    date: date,
    status: 'occupied', // 🔥 入住
  );

  Navigator.pop(context);
},
                child: const Text('入住'),
              ),
            ),

            const SizedBox(height: 12),

            /// 🟥 退房
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
  await ShopService.instance.setRoomStatus(
    shopId: shopId,
    roomId: roomId,
    date: date,
    status: 'available', // 🔥 退房
  );

  Navigator.pop(context);
},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('退房'),
              ),
            ),

            const SizedBox(height: 12),

            /// 🟡 清潔
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
  await ShopService.instance.setRoomStatus(
    shopId: shopId,
    roomId: roomId,
    date: date,
    status: 'cleaning',
  );

  Navigator.pop(context);
},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: const Text('設為清潔中'),
              ),
            ),

            const SizedBox(height: 12),

            /// ⚫ 關閉
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
  await ShopService.instance.setRoomStatus(
    shopId: shopId,
    roomId: roomId,
    date: date,
    status: 'blocked',
  );

  Navigator.pop(context);
},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                ),
                child: const Text('設為關閉'),
              ),
            ),

          ],
        ),
      ),
    );
  }
}