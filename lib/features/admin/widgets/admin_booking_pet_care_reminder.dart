// 檔案名稱：lib/features/admin/widgets/admin_booking_pet_care_reminder.dart
// 功能說明：訂單有寵物時固定顯示照護資料提醒，不依表單解析結果決定。

import 'package:flutter/material.dart';

class AdminBookingPetCareReminderCard extends StatelessWidget {
  const AdminBookingPetCareReminderCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFCC80)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.info_outline, color: Color(0xFFEF6C00), size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '寵物照護資料提醒',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE65100),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '請點選上方寵物卡，查看寵物基本資料、安全資訊與店家照護資料。',
                    style: TextStyle(height: 1.4, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
